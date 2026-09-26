#!/usr/bin/env bash
# =============================================================================
# build_rs353_linux.sh
#
# Baut das OpenWrt-25.12-Image fuer den Bintec RS353 auf einem Linux-Rechner.
# OHNE Docker. Alles laeuft direkt auf dem Host.
#
# Fuer Laien gedacht: einmal starten, warten, fertiges Image einsammeln.
#
#   bash build_rs353_linux.sh
#
# Optionen:
#   --workdir PFAD   Arbeitsordner (Vorgabe: $HOME/openwrt-rs353-build)
#   --jobs N         Parallele Compiler-Prozesse (Vorgabe: 4, siehe F7)
#   --skip-deps      Paketinstallation ueberspringen (wenn schon erledigt)
#   -h | --help      Diese Hilfe
#
# Dauer: erster Lauf 1 bis 3 Stunden. Abbruch ist unschaedlich, ein erneuter
# Start setzt an der Abbruchstelle wieder an.
#
# Vor dem Flashen zwingend BUILD_HOWTO.md Abschnitt 9 lesen.
# =============================================================================
set -euo pipefail

# --- Vorgaben ---------------------------------------------------------------
WORKDIR="${HOME}/openwrt-rs353-build"
JOBS=4
SKIP_DEPS=0
OPENWRT_BRANCH="openwrt-25.12"
OPENWRT_URL="https://git.openwrt.org/openwrt/openwrt.git"
IMAGE_LIMIT_KIB=31232          # Obergrenze aus port/apply.sh, nicht anheben
MIN_FREE_GIB=40
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEP="Start"

# --- Hilfsfunktionen --------------------------------------------------------
say()  { printf '\n== %s\n' "$*"; }
info() { printf '   %s\n' "$*"; }
# Explizites exit loest die ERR-Falle nicht aus, daher ruft die() on_error selbst auf.
die()  { printf '\nFEHLER (%s): %s\n' "$STEP" "$*" >&2; on_error; exit 1; }

on_error() {
    printf '\n-----------------------------------------------------------\n' >&2
    printf 'Abgebrochen im Schritt: %s\n' "$STEP" >&2
    printf 'Protokoll: %s\n' "${BUILDLOG:-${APPLYLOG:-noch keines}}" >&2
    printf 'Hilfe: BUILD_HOWTO.md, Abschnitt 10 (Typische Fehler)\n' >&2
    printf -- '-----------------------------------------------------------\n' >&2
}
trap on_error ERR

usage() { sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0; }

# --- Argumente --------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --workdir)  WORKDIR="${2:?--workdir braucht einen Pfad}"; shift 2 ;;
        --jobs)     JOBS="${2:?--jobs braucht eine Zahl}"; shift 2 ;;
        --skip-deps) SKIP_DEPS=1; shift ;;
        -h|--help)  usage ;;
        *)          die "Unbekannte Option: $1 (Hilfe: --help)" ;;
    esac
done
case "$JOBS" in ''|*[!0-9]*) die "--jobs braucht eine Zahl, nicht '$JOBS'" ;; esac
[ "$JOBS" -ge 1 ] || die "--jobs muss mindestens 1 sein"

# =============================================================================
say "SCHRITT 1/10  Rechner pruefen"
STEP="1/10 Rechner pruefen"

[ "$(id -u)" -ne 0 ] || die "Nicht als root starten. OpenWrt bricht den Build als root ab.
   Als normaler Benutzer starten: bash build_rs353_linux.sh"

[ -f "$PROJECT_DIR/port/apply.sh" ] || die "port/apply.sh nicht gefunden neben diesem Skript.
   Erwartet: $PROJECT_DIR/port/apply.sh
   Das Skript muss im Projektordner OpenWRT_Update liegen."
[ -d "$PROJECT_DIR/port/patches" ] || die "port/patches fehlt. Projektordner unvollstaendig."
[ -d "$PROJECT_DIR/port/tree" ]    || die "port/tree fehlt. Projektordner unvollstaendig."

info "Projektordner: $PROJECT_DIR"
info "Arbeitsordner: $WORKDIR"
info "Parallele Prozesse: $JOBS   (Kerne vorhanden: $(nproc 2>/dev/null || echo '?'))"

# =============================================================================
say "SCHRITT 2/10  Benoetigte Programme installieren"
STEP="2/10 Pakete installieren"

PKGS_PFLICHT="build-essential clang flex bison g++ gawk gettext git \
libncurses-dev libssl-dev python3 python3-dev python3-setuptools rsync unzip \
zlib1g-dev file wget swig time ca-certificates libelf-dev ecj fastjar \
java-propose-classpath java-wrappers jq quilt xsltproc zstd"
# Diese fehlen je nach Distribution, sind aber nicht zwingend
# (python3-distutils z. B. fehlt ab Ubuntu 24.04 / Python 3.12):
PKGS_OPTIONAL="gcc-multilib g++-multilib python3-distutils"
# Paketsatz deckungsgleich mit docker/Dockerfile (python3-distutils dort
# ebenfalls optional, "|| true"). Bewusste Abweichungen:
#   - Dockerfile installiert zusaetzlich less nano procps (Bedienung im Container).
#   - Dockerfile installiert gcc-multilib g++-multilib fest (Debian-Basis bekannt).

if [ "$SKIP_DEPS" -eq 1 ]; then
    info "uebersprungen (--skip-deps)"
elif command -v apt-get >/dev/null 2>&1; then
    command -v sudo >/dev/null 2>&1 || die "sudo fehlt. Pakete von Hand installieren:
   apt-get install $PKGS_PFLICHT
   Danach erneut starten mit: bash build_rs353_linux.sh --skip-deps"
    info "Debian/Ubuntu erkannt. Es folgt eine Passwortabfrage von sudo."
    sudo apt-get update
    # shellcheck disable=SC2086
    sudo apt-get install -y --no-install-recommends $PKGS_PFLICHT
    for p in $PKGS_OPTIONAL; do
        sudo apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1 \
            && info "optional installiert: $p" \
            || info "optional nicht verfuegbar, unkritisch: $p"
    done
else
    die "Kein apt-get gefunden. Diese Distribution wird hier nicht automatisch bedient.
   Bitte die Entsprechungen dieser Pakete von Hand installieren:
     $PKGS_PFLICHT
   Fedora heissen sie z. B. ncurses-devel, openssl-devel, elfutils-libelf-devel,
   Arch z. B. base-devel, ncurses, openssl, libelf.
   Danach erneut starten mit: bash build_rs353_linux.sh --skip-deps"
fi

for t in git make gcc g++ python3 rsync unzip wget quilt; do
    command -v "$t" >/dev/null 2>&1 || die "'$t' fehlt weiterhin. Installation pruefen."
done
info "alle Pflichtprogramme vorhanden"

# =============================================================================
say "SCHRITT 3/10  Arbeitsordner pruefen"
STEP="3/10 Arbeitsordner"

mkdir -p "$WORKDIR"
WORKDIR="$(cd "$WORKDIR" && pwd)"

# Gross- und Kleinschreibung: der OpenWrt-Baum enthaelt Dateien, die sich nur
# darin unterscheiden. Auf NTFS/exFAT/FAT-Mounts zerfaellt der Baum.
printf 'a' > "$WORKDIR/.casetest_A"
printf 'b' > "$WORKDIR/.casetest_a"
CASE_N=$(find "$WORKDIR" -maxdepth 1 -name '.casetest_*' | wc -l)
rm -f "$WORKDIR/.casetest_A" "$WORKDIR/.casetest_a"
[ "$CASE_N" -eq 2 ] || die "Der Arbeitsordner unterscheidet Gross- und Kleinschreibung nicht.
   Das ist typisch fuer eingebundene Windows-Laufwerke (NTFS/exFAT/FAT).
   Einen Ordner im echten Linux-Dateisystem waehlen, z. B.:
   bash build_rs353_linux.sh --workdir \$HOME/openwrt-rs353-build"
info "Gross-/Kleinschreibung wird unterschieden"

FREE_KIB=$(df -Pk "$WORKDIR" | awk 'NR==2 {print $4}')
FREE_GIB=$(( FREE_KIB / 1024 / 1024 ))
[ "$FREE_GIB" -ge "$MIN_FREE_GIB" ] || die "Zu wenig freier Platz: ${FREE_GIB} GB frei, ${MIN_FREE_GIB} GB noetig.
   Platz schaffen oder anderen Ordner waehlen: --workdir /pfad/mit/platz"
info "freier Platz: ${FREE_GIB} GB"

# =============================================================================
say "SCHRITT 4/10  OpenWrt-Quellen holen"
STEP="4/10 Quellen holen"

TREE="$WORKDIR/openwrt"
if [ -d "$TREE/.git" ]; then
    info "Quellbaum ist bereits vorhanden, wird nicht neu geholt"
else
    git clone --branch "$OPENWRT_BRANCH" "$OPENWRT_URL" "$TREE"
fi
cd "$TREE"
info "Stand: $(git log --oneline -1)"

# =============================================================================
say "SCHRITT 5/10  Paketquellen (Feeds) einrichten"
STEP="5/10 Feeds"

./scripts/feeds update -a
./scripts/feeds install -a
for f in base luci packages routing; do
    [ -d "package/feeds/$f" ] || die "Feed '$f' fehlt. Netzverbindung pruefen und erneut starten."
done
info "Feeds base, luci, packages, routing eingehaengt"

# =============================================================================
say "SCHRITT 6/10  RS353-Port einspielen"
STEP="6/10 Port einspielen"

PORT_DIR="$WORKDIR/port"
rm -rf "$PORT_DIR"
cp -r "$PROJECT_DIR/port" "$PORT_DIR"
chmod 755 "$PORT_DIR/apply.sh"
info "Port-Kit kopiert nach $PORT_DIR"

APPLYLOG="$WORKDIR/apply.log"
APPLY_RC=0
bash "$PORT_DIR/apply.sh" "$TREE" >"$APPLYLOG" 2>&1 || APPLY_RC=$?
tail -30 "$APPLYLOG"
[ "$APPLY_RC" -eq 0 ] || die "port/apply.sh ist gescheitert (Exit $APPLY_RC).
   Oben stehen die letzten 30 Zeilen, vollstaendig in: $APPLYLOG"
info "apply.sh-Protokoll: $APPLYLOG"

# Gegenprobe gemaess BUILD_HOWTO F5: fuenf Marken muessen im Baum stehen.
STEP="6/10 Port gegenpruefen"
check_mark() {
    grep -q "$1" "$2" || die "Der Port ist unvollstaendig: '$1' fehlt in $2.
   Sauberer Neuanfang des Quellbaums:
     cd $TREE && git checkout -- . && git clean -fd
   Danach dieses Skript erneut starten."
}
check_mark 'CMD_FIXBOSS'          package/system/mtd/src/mtd.c
check_mark 'MTD_SPLIT_BINTEC_FW'  target/linux/generic/files/drivers/mtd/mtdsplit/Kconfig
check_mark 'obj.lantiq = boss.o'  package/system/mtd/src/Makefile
check_mark 'Build/rs353-cev'      target/linux/lantiq/image/Makefile
check_mark 'bintec,rs353'         target/linux/lantiq/xrx200/base-files/etc/board.d/02_network
info "alle fuenf Pruefmarken gefunden"

# =============================================================================
say "SCHRITT 7/10  Geraeteprofil auf Bintec RS353 setzen"
STEP="7/10 Profil setzen"

touch .config
cp .config .config.bak
sed -i '/^CONFIG_TARGET_lantiq_xrx200_DEVICE_/d;/^CONFIG_TARGET_PROFILE=/d' .config
printf 'CONFIG_TARGET_lantiq=y\nCONFIG_TARGET_lantiq_xrx200=y\nCONFIG_TARGET_lantiq_xrx200_DEVICE_bintec_rs353=y\n' >> .config
make defconfig >/dev/null
grep -q '^CONFIG_TARGET_PROFILE="DEVICE_bintec_rs353"' .config \
    || die "Das Profil wurde nicht gesetzt. Sicherung zurueckholen:
     cd $TREE && cp .config.bak .config && make defconfig
   Siehe BUILD_HOWTO.md, Abschnitt F9."
info 'CONFIG_TARGET_PROFILE="DEVICE_bintec_rs353"'

# =============================================================================
say "SCHRITT 8/10  Bauen (dauert 1 bis 3 Stunden)"
STEP="8/10 Bauen"

BUILDLOG="$WORKDIR/rs353-build.log"
[ -f "$BUILDLOG" ] && mv -f "$BUILDLOG" "$BUILDLOG.prev"
STAMP="$WORKDIR/.rs353-build.stamp"
rm -f "$STAMP"; touch "$STAMP"

info "Protokoll: $BUILDLOG"
info "Mitlesen in einem zweiten Fenster:  tail -f $BUILDLOG"
info "Abbruch mit Strg+C ist erlaubt, ein neuer Lauf setzt an der Stelle wieder an."

set +e
make -j"$JOBS" >>"$BUILDLOG" 2>&1 &
MAKE_PID=$!
START_TS=$(date +%s)
while kill -0 "$MAKE_PID" 2>/dev/null; do
    sleep 60
    kill -0 "$MAKE_PID" 2>/dev/null || break
    MIN=$(( ( $(date +%s) - START_TS ) / 60 ))
    LAST=$(tail -n 1 "$BUILDLOG" 2>/dev/null | cut -c1-70)
    printf '   laeuft seit %s min | %s\n' "$MIN" "$LAST"
done
MAKE_RC=0
wait "$MAKE_PID" || MAKE_RC=$?
set -e

if [ "$MAKE_RC" -eq 0 ]; then
    echo RS353_BUILD_OK >> "$BUILDLOG"
else
    echo RS353_BUILD_FAIL >> "$BUILDLOG"
    tail -40 "$BUILDLOG"
    die "Der Build ist gescheitert (Exit $MAKE_RC).
   Die echte Fehlermeldung finden:
     grep -n -iE 'error|Error [0-9]+' $BUILDLOG | tail -20
   Danach einmal langsam und ausfuehrlich nachfahren:
     cd $TREE && make -j1 V=s 2>&1 | tail -80
   Siehe BUILD_HOWTO.md, Abschnitte F6 und F7."
fi
info "Build erfolgreich beendet (RS353_BUILD_OK)"

# =============================================================================
say "SCHRITT 9/10  Image pruefen"
STEP="9/10 Image pruefen"

OUTDIR_SRC="bin/targets/lantiq/xrx200"
IMG=$(find "$OUTDIR_SRC" -maxdepth 1 -name '*bintec*boss-image.cev' -newer "$STAMP" 2>/dev/null | head -n1)
[ -n "$IMG" ] || die "Kein frisches Image gefunden in $TREE/$OUTDIR_SRC.
   Der Build meldete Erfolg, hat aber nichts erzeugt. Protokoll pruefen: $BUILDLOG"

SZ=$(stat -c %s "$IMG")
LIMIT=$(( IMAGE_LIMIT_KIB * 1024 ))
info "Datei:  $IMG"
info "Groesse: $SZ Bytes   Grenze: $LIMIT Bytes"
[ "$SZ" -le "$LIMIT" ] || die "Das Image ist zu gross und passt nicht in den Flash.
   Ursache sind fast immer zusaetzlich gewaehlte Pakete.
   Grenze NICHT anheben (Begruendung: BUILD_HOWTO.md Abschnitt 9).
   Auswahl verkleinern:  cd $TREE && make menuconfig
   Siehe BUILD_HOWTO.md, Abschnitt F8."
info "Groesse in Ordnung (SIZE_OK)"

IMG_NAME=$(basename "$IMG")
if [ ! -f "$OUTDIR_SRC/sha256sums" ]; then
    info "Hinweis: sha256sums fehlt, Gegenprobe entfaellt, unkritisch."
else
    SUMLINE=$(awk -v f="$IMG_NAME" '$2 == f || $2 == "*" f' "$OUTDIR_SRC/sha256sums")
    if [ -z "$SUMLINE" ]; then
        die "$IMG_NAME steht nicht in sha256sums, die Gegenprobe ist nicht moeglich.
   Ein ungeprueftes Image darf nicht geflasht werden.
   Von Hand nachsehen:  cd $TREE/$OUTDIR_SRC && cat sha256sums"
    else
        ( cd "$OUTDIR_SRC" && printf '%s\n' "$SUMLINE" | sha256sum -c - ) \
            || die "Die Pruefsumme des Images stimmt nicht mit sha256sums ueberein.
   Das Image ist beschaedigt oder veraltet und darf nicht geflasht werden.
   Von Hand nachpruefen:  cd $TREE/$OUTDIR_SRC && sha256sum -c sha256sums"
    fi
fi

# =============================================================================
say "SCHRITT 10/10  Ergebnis ablegen"
STEP="10/10 Ergebnis ablegen"

OUT="$PROJECT_DIR/out"
mkdir -p "$OUT"
cp -f "$IMG" "$OUT/"
if [ -f "$OUTDIR_SRC/sha256sums" ]; then cp -f "$OUTDIR_SRC/sha256sums" "$OUT/"; fi
info "kopiert nach: $OUT/$(basename "$IMG")"

trap - ERR
cat <<EOF

=============================================================================
FERTIG.

Image:      $OUT/$(basename "$IMG")
Groesse:    $SZ Bytes (Grenze $LIMIT)
Protokoll:  $BUILDLOG
Quellbaum:  $TREE

NICHT SOFORT FLASHEN.
Zuerst BUILD_HOWTO.md Abschnitt 9 lesen. Dort stehen drei Punkte, die nur am
Geraet selbst geklaert werden koennen:
  - den BOSS-Header eines Herstellerimages gegenpruefen,
  - den ersten Flash ueber den Bootmonitor an der seriellen Konsole fahren,
    NICHT ueber sysupgrade,
  - nach dem ersten Start sofort 'logread' und '/tmp/fixboss.log' ansehen.
Serielle Konsole bereitlegen: 3,3 V TTL, 115200 8N1. Ohne sie gibt es keinen
Rueckweg, wenn das Geraet nicht mehr startet.
=============================================================================
EOF
