#!/bin/sh
# Port-Kit auf einen OpenWrt-24.10-Baum (vorbereitet nach BUILD_HOWTO.md
# Abschnitt 4) anwenden, RS353-Profil setzen, bauen, statisch pruefen.
set -e
TREE="${1:-/build/openwrt}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$TREE"

step() { echo; echo "== $*"; }

step "4.0 Port-Kit anwenden"
bash "$HERE/apply.sh" "$TREE"

step "4.0 Profil auf RS353 umstellen"
# H3: Sicherungskopie vor dem destruktiven sed. Rueckweg: cp .config.bak .config
# touch legt eine fehlende .config an (frischer Baum).
touch .config
cp .config .config.bak
sed -i '/^CONFIG_TARGET_lantiq_xrx200_DEVICE_/d;/^CONFIG_TARGET_PROFILE=/d' .config
printf 'CONFIG_TARGET_lantiq=y\nCONFIG_TARGET_lantiq_xrx200=y\nCONFIG_TARGET_lantiq_xrx200_DEVICE_bintec_rs353=y\n' >> .config
make defconfig >/dev/null
grep -q '^CONFIG_TARGET_PROFILE="DEVICE_bintec_rs353"' .config

step "4.1 Build"
# K3: Die Pipe nach tail wuerde den Exit-Status von make verschlucken,
# pipefail gibt es unter #!/bin/sh nicht. Deshalb make ohne Pipe in ein Log
# schreiben, Endmarker setzen (Muster aus BUILD_HOWTO.md Abschnitt 7) und den
# Marker pruefen. set -e bricht hier ab, bevor PHASE4_OK erreicht wird.
# JOBS (Default 4) und BUILDLOG sind per Umgebung ueberschreibbar.
BUILDLOG="${BUILDLOG:-/build/rs353-build.log}"
# M11: Startmarke. Das spaeter gesuchte Image muss juenger als diese Datei
# sein, sonst stammt es aus einem frueheren Lauf.
STAMP=/tmp/rs353-build.stamp
rm -f "$STAMP"
touch "$STAMP"
{ make -j"${JOBS:-4}" && echo RS353_BUILD_OK || echo RS353_BUILD_FAIL; } >"$BUILDLOG" 2>&1
tail -40 "$BUILDLOG"
grep -q "^RS353_BUILD_OK$" "$BUILDLOG"

step "4.1 Image-Groesse"
IMG=$(find bin/targets/lantiq/xrx200 -maxdepth 1 -name '*bintec*boss-image.cev' -newer "$STAMP" 2>/dev/null | head -n1)
# Leer, wenn der Build kein frisches Image erzeugt hat.
test -n "$IMG"
SZ=$(stat -c %s "$IMG")
echo "image: $IMG"
echo "bytes: $SZ  limit: $((31232*1024))"
test "$SZ" -le $((31232*1024))

step "4.2 CHECK_DTBS (INFO, keine Assertion - Ausgabe manuell bewerten)"
# Bewusst keine Pruefung: der Filter trifft auch Treffer fremder Targets,
# ein Abbruch waere nicht aussagekraeftig. Exit-Status wird verworfen.
make target/linux/compile CHECK_DTBS=1 V=s 2>&1 | grep -iE "vr9_bintec_rs353|Warning|error" | head -30 || true

step "4.3 mtdsplit-Offsets (INFO, keine Assertion - Ausgabe manuell bewerten)"
# Bewusst keine Pruefung: die Soll-Offsets stehen in BUILD_HOWTO.md und
# werden gegen diese Ausgabe von Hand abgeglichen.
grep -n "partition@\|reg = <" target/linux/lantiq/files/arch/mips/boot/dts/lantiq/vr9_bintec_rs353.dts | head -30

echo
echo "PHASE4_OK"
