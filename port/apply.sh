#!/bin/bash
# Portiert das Bintec-RS353-Patchset auf einen OpenWrt-25.12-Quellbaum.
# Aufruf im Container:  bash /build/port/apply.sh /build/openwrt
# Aufruf ohne Docker:   build_rs353_linux.sh ruft
#                       bash "$WORKDIR/port/apply.sh" "$WORKDIR/openwrt"
# Idempotent: jeder Schritt prueft vorher, ob er schon gesetzt ist.
set -euo pipefail

TREE="${1:-/build/openwrt}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$TREE"

step() { printf '== %s\n' "$*"; }

# --- 1.1 Neue Dateien ------------------------------------------------------
step "1.1 neue Dateien kopieren"
cp -v "$HERE/tree/package/system/mtd/src/boss.c" package/system/mtd/src/
cp -v "$HERE/tree/target/linux/generic/files/drivers/mtd/mtdsplit/mtdsplit_bintec.c" \
      target/linux/generic/files/drivers/mtd/mtdsplit/
cp -v "$HERE/tree/target/linux/lantiq/base-files/etc/uci-defaults/09_fix_crc.sh" \
      target/linux/lantiq/base-files/etc/uci-defaults/
chmod 755 target/linux/lantiq/base-files/etc/uci-defaults/09_fix_crc.sh
cp -v "$HERE/tree/target/linux/lantiq/files/arch/mips/boot/dts/lantiq/vr9_bintec_rs353.dts" \
      target/linux/lantiq/files/arch/mips/boot/dts/lantiq/

# --- 1.2/1.4 Diffs, die gegen 25.12 sauber greifen -------------------------
step "1.2/1.4 Fork-Diffs anwenden"
for d in src_package_system_mtd_src_mtd.c \
         src_package_system_mtd_src_mtd.h \
         src_target_linux_generic_files_drivers_mtd_mtdsplit_Kconfig \
         src_target_linux_lantiq_image_lzma-loader_src_board-lantiq.c \
         src_target_linux_lantiq_image_lzma-loader_src_loader.c \
         src_target_linux_lantiq_xrx200_base-files_lib_upgrade_platform.sh ; do
  p="$HERE/patches/$d.diff"
  # Idempotenz-Marker: erste eingefuegte Zeile des Diffs im Zielfile.
  # -R-Check taugt nicht, weil -C1-Fuzz den Rueckwaerts-Test scheitern
  # laesst und der Vorwaerts-Apply dann doppelt einfuegt.
  tgt=$(sed -n 's|^+++ b/||p' "$p" | head -n1)
  mark=$(grep '^+' "$p" | grep -v '^+++' | sed 's/^+//'          | grep -v '^[[:space:]]*$' | awk 'length($0)>8' | head -n1)
  if [ -n "$tgt" ] && [ -n "$mark" ] && grep -qF -- "$mark" "$tgt"; then
    echo "   already applied $d"
  elif git apply --check -p1 -C1 "$p" 2>/dev/null; then
    git apply -p1 -C1 "$p"
    echo "   applied $d"
  else
    echo "   FAIL $d" >&2; exit 1
  fi
done

# --- Handport: mtd/src/Makefile (Kontext in 24.10 um obj.qualcommax erweitert)
step "1.2 mtd/src/Makefile obj.lantiq"
if ! grep -q '^obj.lantiq' package/system/mtd/src/Makefile; then
  sed -i 's/^obj\.qualcommax = linksys_bootcount\.o$/&\nobj.lantiq = boss.o/' \
      package/system/mtd/src/Makefile
  grep -q '^obj.lantiq = boss.o' package/system/mtd/src/Makefile
fi

# --- Handport: mtdsplit/Makefile (U5: frueherer Diff war am Dateiende
# verankert, in 25.12 folgen nach mtdsplit_elf.o weitere Zeilen)
step "1.4 mtdsplit/Makefile mtdsplit_bintec.o"
MSM=target/linux/generic/files/drivers/mtd/mtdsplit/Makefile
if ! grep -q 'mtdsplit_bintec\.o' "$MSM"; then
  sed -i 's/^obj-$(CONFIG_MTD_SPLIT_ELF_FW) += mtdsplit_elf\.o$/&\nobj-$(CONFIG_MTD_SPLIT_BINTEC_FW) += mtdsplit_bintec.o/' \
      "$MSM"
  grep -qxF 'obj-$(CONFIG_MTD_SPLIT_BINTEC_FW) += mtdsplit_bintec.o' "$MSM"
fi

# --- 1.3 B7: Kernelconfig 6.12 --------------------------------------------
step "1.3 CONFIG_MTD_SPLIT_BINTEC_FW nach xrx200/config-6.12"
CFG=target/linux/lantiq/xrx200/config-6.12
if ! grep -q '^CONFIG_MTD_SPLIT_BINTEC_FW=y' "$CFG"; then
  sed -i 's/^CONFIG_MTD_RAW_NAND=y$/&\nCONFIG_MTD_SPLIT_BINTEC_FW=y/' "$CFG"
  grep -q '^CONFIG_MTD_SPLIT_BINTEC_FW=y' "$CFG"
fi

# --- 2.1 B3: firmware-utils-Patch ------------------------------------------
step "2.1 mkbossimg-Patch nach tools/firmware-utils/patches"
# Bewusstes Ueberschreiben statt Idempotenz-Guard: Ziel ist eine reine Kopie
# der Port-Kit-Datei, kein Einfuegen in fremden Inhalt. Ein zweiter Lauf
# schreibt denselben Inhalt und zieht eine im Port-Kit geaenderte Fassung nach.
mkdir -p tools/firmware-utils/patches
cp -v "$HERE/patches/000-add-mkbossimg.patch" tools/firmware-utils/patches/

# --- 2.2 B4: Kernelpatch nach patches-6.12 ---------------------------------
step "2.2 lantiq-flash EBU-Endianness-Patch nach patches-6.12"
# Bewusstes Ueberschreiben, siehe 2.1: reine Kopie unter festem Zielnamen.
# U2: 25.12 nummeriert dreistellig; 161 sortiert nach 160-owrt-..., das den
# Patch-Kontext (ltq_mtd->map[i]) erst anlegt.
cp -v "$HERE/patches/0999-MTD-lantiq-flash-map-add-ebu-endianness-check.patch" \
      target/linux/lantiq/patches-6.12/161-owrt-lantiq-flash-map-add-ebu-endianness-check.patch

# --- 2.4/3.2 B5: Image-Makefile-Bausteine ----------------------------------
# Kein Fork-eigenes Build/lzma-loader mehr. Stattdessen Build/loader-common
# von 25.12 mit ueberschriebenem LZMA_TEXT_START (spaetere Kommandozeilen-
# Zuweisung gewinnt bei make).
step "3.2 Build/rs353-* nach target/linux/lantiq/image/Makefile"
MK=target/linux/lantiq/image/Makefile
if ! grep -q 'Build/rs353-cev' "$MK"; then
  python3 - "$MK" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8", newline="").read()
anchor = "define Build/loader-common\n"
# raw-String: x-Escapes muessen als Text im Makefile landen, nicht als Bytes.
block = r"""define Build/rs353-loader-kernel
	$(call Build/loader-common,LOADER_DATA="$@" LZMA_TEXT_START=0x80a00000)
endef

define Build/rs353-cev
	rm -f $(KDIR)/boss.bin.gz
	# CEV-Header (Magic). Der Name "boss.bin" muss im gzip-Header stehen.
	echo -ne "\x10\x00\x00\x02\x00\x00\x00\x00\x43\x45\x56\x00\x00\x00\x00\x00" > $(KDIR)/boss.bin
	cat $@ >> $(KDIR)/boss.bin
	gzip $(KDIR)/boss.bin
	# Platzhalter-BOSS-Header, damit das Image auf Flash-Sektoren ausgerichtet ist.
	dd if=/dev/zero of=$(KDIR)/boss.1 bs=52 count=1
	cat $(KDIR)/boss.bin.gz >> $(KDIR)/boss.1
	dd if=$(KDIR)/boss.1 of=$@ bs=131072 conv=sync
endef

define Build/rs353-boss-header
	# mkbossimg schreibt immer nach ./bossImage.img. Deshalb in einem pro
	# Image eindeutigen Verzeichnis unter $(KDIR) arbeiten statt im CWD.
	rm -rf $(KDIR)/rs353-boss.$(notdir $@)
	mkdir -p $(KDIR)/rs353-boss.$(notdir $@)
	( cd $(KDIR)/rs353-boss.$(notdir $@) && mkbossimg rs353 $@ )
	mv $(KDIR)/rs353-boss.$(notdir $@)/bossImage.img $@
	rmdir $(KDIR)/rs353-boss.$(notdir $@)
endef

"""
assert s.count(anchor) == 1
s = s.replace(anchor, block + anchor)
io.open(p, "w", encoding="utf-8", newline="").write(s)
PY
  grep -q 'Build/rs353-boss-header' "$MK"
fi

# --- 3.1 Device-Definition in vr9.mk ---------------------------------------
# B2: wpad-mini -> wpad-basic-mbedtls. B6: kmod-swconfig entfaellt (DSA).
# U7: GPHY-Firmware ist in 25.12 eigenes Paket; DTS setzt GPHY_MODE_GE ->
# phy11g, beide VR9-Revisionen, da die Revision des Geraets nicht belegt ist.
step "3.1 Device/bintec_rs353 nach image/vr9.mk"
VR9=target/linux/lantiq/image/vr9.mk
if ! grep -q 'Device/bintec_rs353' "$VR9"; then
  python3 - "$VR9" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8", newline="").read()
anchor = "define Device/bt_homehub-v5a\n"
# raw-String: Backslash-Zeilenfortsetzung muss im Makefile erhalten bleiben.
block = r"""define Device/bintec_rs353
  $(Device/dsa-migration)
  DEVICE_VENDOR := Bintec
  DEVICE_MODEL := RS353
  BOARD_NAME := bintec_rs353
  KERNEL := kernel-bin | append-dtb | lzma | rs353-loader-kernel | rs353-cev
  IMAGE/boss-image.cev = append-kernel | append-rootfs | pad-rootfs | rs353-boss-header | append-metadata
  IMAGES := boss-image.cev
  # H5 Herkunft: Wert stammt aus dem Fork openwrt-RS353_1, Branch
  # openwrt-22.03-old, gesetzt im ersten Commit a9a054d8ad (2018-05-23).
  # Derselbe Wert steht dort bei arcadyan_arv7519rw22; eine RS353-spezifische
  # Herleitung ist nicht belegt. Die firmware-Partition fasst 32000 KiB
  # (0xc0000 + 0x1F40000), das Limit liegt 768 KiB darunter.
  # AM GERAET ZU VERIFIZIEREN: reale Obergrenze des BOSS-Bootmonitors.
  IMAGE_SIZE := 31232k
  DEVICE_PACKAGES := kmod-usb-dwc2 kmod-ath9k kmod-i2c-gpio kmod-rtc-s35390a \
	kmod-usb-ledtrig-usbport wpad-basic-mbedtls \
	xrx200-rev1.1-phy11g-firmware xrx200-rev1.2-phy11g-firmware
  SUPPORTED_DEVICES += rs353
endef
TARGET_DEVICES += bintec_rs353

"""
assert s.count(anchor) == 1
s = s.replace(anchor, block + anchor)
io.open(p, "w", encoding="utf-8", newline="").write(s)
PY
  grep -q 'TARGET_DEVICES += bintec_rs353' "$VR9"
fi

# --- 3.3 board.d/02_network ------------------------------------------------
step "3.3 bintec,rs353 nach board.d/02_network"
NET=target/linux/lantiq/xrx200/base-files/etc/board.d/02_network
if ! grep -q "bintec,rs353" "$NET"; then
  python3 - "$NET" <<'PY'
import io, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8", newline="").read()
# Nur der Treffer in lantiq_setup_interfaces. Der zweite liegt in
# lantiq_setup_macs und betrifft den RS353 nicht (MAC kommt aus nvmem).
cut = s.index("lantiq_setup_macs")
head, tail = s[:cut], s[cut:]
TAB = chr(9)
BS = chr(92)
old = TAB + "arcadyan,arv7519rw22)" + chr(10)
new = TAB + "arcadyan,arv7519rw22|" + BS + chr(10) + TAB + "bintec,rs353)" + chr(10)
assert head.count(old) == 1
s = head.replace(old, new) + tail
io.open(p, "w", encoding="utf-8", newline="").write(s)
PY
  grep -q "bintec,rs353" "$NET"
fi

echo
echo "PORT_APPLY_OK"
