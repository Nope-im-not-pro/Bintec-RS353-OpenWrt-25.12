# Changelog - OpenWRT_Update

Format: SemVer + ISO-Datum. Sektionen: Hinzugefügt / Geändert / Behoben / Entfernt / Verifiziert.

## [0.3.0] - 2026-09-23
### Hinzugefügt
- `port/tests/boss_test.sh`: Host-Test für `mtd fixboss`. Baut `boss.c` mit
  den Stubs aus `port/tests/stubs/` in einem `mktemp -d`-Verzeichnis, arbeitet
  auf einer Image-Datei statt auf `/dev/mtd*` und prüft die Fälle F1 bis F6:
  korrekter Header bleibt unberührt, `mkbossimg`-Header wird genau einmal
  umgeschrieben, falsches Magic, `-o 0x10` und `-c 0x1FFCD` enden mit Exit 1
  ohne Erase, ein zweiter Lauf meldet `checksum ok`. Exit-Codes: 0 mit
  `6/6 OK`, 1 bei `FAIL ...` oder Build-Fehler, 2 mit
  `NICHT ausgefuehrt: <liste>`, wenn eine Voraussetzung fehlt. Das Skript
  fällt unter die `.gitignore`-Regel `*.sh` und wird nicht versioniert.
- `port/tests/stubs/`: `crc32.c`, `crc32.h`, `main.c`, `mtd.h`, `mtd_stub.c`
  für den Host-Build von `boss.c`. `crc32.c` und `crc32.h` sind bis auf einen
  vorangestellten Herkunftskommentar unveränderte Kopien aus openwrt-24.10.
  Die Stubs sind nicht getrackt und nicht ignoriert.
- `port/patches/src_package_system_mtd_src_mtd.c.diff`: Usage-Zeile für
  `-o offset` (nur für `fixboss`).

### Geändert
- `README.md`: Verweise auf `PLAN.md` und `REVIEW_BEFUNDE.md` als "lokal, nicht
  im Repo" gekennzeichnet. Beide fallen unter die `.gitignore`-Regel `*.md` und
  wären auf GitHub tote Referenzen.
- `README.md`, Abschnitt "Aufruf": Block "Von Hand" nennt die Vorbedingung
  (frisch geklonter OpenWrt-24.10-Baum auf case-sensitivem Dateisystem) und
  beginnt mit `bash port/apply.sh <baum>` vor Feeds und `make menuconfig`.
- `README.md`: Codeblöcke "Von Hand" und "Herkunft" tragen das Sprach-Tag
  `bash`.
- `README.md`, Abschnitt "Herkunft": Branch-Liste von `openwrt-RS353_2`
  korrigiert. RS353-Support liegt in `openwrt-22.03` und `old_2021`,
  `openwrt-24.10` enthält keine RS353-Dateien; deckt sich jetzt mit Abschnitt
  "Zweck".
- `CHANGELOG.md`: Abschnitt `[Unreleased]` angelegt. 0.2.3: "NICHT erledigt:
  Commit und Push" als überholt markiert und mit `origin/main` belegt. 0.2.2:
  nicht mehr auffindbarer Commit-Verweis durch den Abgleich mit der heutigen
  Historie ersetzt. 0.1.0: Werkzeugname des Scaffolds und Eintrag zur lokalen
  Snapshot-Baseline entfernt.
- `CHANGELOG.md`: `[Unreleased]` als `[0.3.0] - 2026-09-23` versioniert.
  0.2.3 in die Sektionsreihenfolge des Kopfs gebracht. 0.2.2 (Bezug auf den
  Sitzungsbeginn) und 0.1.0 (Verweis auf einen Subagent) neutral gefasst,
  Aussagen unverändert.
- `README.md`, Block "Von Hand": nennt Quelle und Branch wie das Build-Skript,
  beginnt mit `git clone` und folgt der Reihenfolge des Build-Skripts (Feeds
  vor `apply.sh`). Die oben genannte Reihenfolge "`apply.sh` vor Feeds" ist
  damit überholt.
- `README.md`: Struktur-Tabelle um `port/tests/` ergänzt, `docker/` als Teil
  des Windows-Docker-Wegs beschrieben. "Herkunft" enthält `git clone` und
  `git checkout` beider Forks. "Git-Stand" nennt `port/tests/boss_test.sh` als
  nicht versioniert.
- `BUILD_HOWTO.md`: Verzeichnisbaum zeigt nur getrackte Dateien, Patch-Zahl 9.
  Absolute lokale Pfade durch `<PFAD>` ersetzt und in Abschnitt 0 erklärt.
  Code-Fences mit Sprach-Tags `text`, `powershell`, `ini`; drei Blöcke von
  `bash` auf `powershell`. Abschnitt 2: Pin des Basis-Images, Update-Weg,
  `--platform linux/amd64`. 5.4: Erfolgsausgabe von `apply.sh`. 7.1 und F11:
  `JOBS` und `BUILDLOG`; F11 zusätzlich `touch .config`. Abschnitt 9:
  Semantik von `fixboss`, Idempotenz, Grenzen von `-c` und `-o`, Meldungen
  `unchanged (checksum ok)` und `rewritten`, Host-Test. 13.2: `apply.log` und
  `rs353-build.log.prev`. Zeilenverweise auf `apply.sh` und `phase4.sh`
  nachgezogen.
- `port/tree/package/system/mtd/src/boss.c`, `mtd_fixboss()`: vergleicht nach
  der Magic-Prüfung `image_length` und `crc32` mit den berechneten Werten. Bei
  Übereinstimmung Meldung `checksum ok`, kein Erase, kein Schreiben, Exit 0.
- `boss.c`, `mtd_fixboss()`: geprüfter Bereich bleibt Block 0 hinter dem
  52-Byte-Header (`erasesize - 52`). Ein `-c` über diesem Wert endet mit
  Exit 1 vor jedem Schreibzugriff. Die Meldung "BOSS header found !" zeigt die
  alten Werte von `image_length` und `crc32`. Kommentar K1 um Evidenzstand und
  diskriminierenden Gerätetest ergänzt, Lese-Prüfung als informativ markiert.
- `port/tree/target/linux/lantiq/base-files/etc/uci-defaults/09_fix_crc.sh`:
  Der Kommentar zum Fallback nach dem Erstflash beschreibt die Prüfung vor dem
  Schreiben und den Lauf ohne Schreibzugriff im sysupgrade-Weg. Die
  `logger`-Meldung unterscheidet
  "unchanged (checksum ok)" und "rewritten".
- `docker/Dockerfile`: Basis-Image `debian:bookworm-20260918-slim` mit Digest
  gepinnt (vorher `debian:bookworm-slim`). `python3-distutils` wird optional
  installiert wie in `build_rs353_linux.sh`.
- `build_rs353_linux.sh`: Kommentar zur Paketliste (`python3-distutils`
  optional, bewusste Abweichungen vom Dockerfile). Der Case-Test zählt per
  `find` statt `ls -a | grep -c`.
- `port/phase4.sh`: `make -j` mit `JOBS` (Default 4) statt `$(nproc)`.
  `BUILDLOG` per Umgebung überschreibbar, Default `/build/rs353-build.log`.
  Kopfkommentar ohne Verweis auf einen lokalen Plan.
- `port/apply.sh`: Kopfkommentar nennt den zweiten Aufrufweg über
  `build_rs353_linux.sh`.
- `port/tree/target/linux/generic/files/drivers/mtd/mtdsplit/mtdsplit_bintec.c`:
  `kcalloc(n, size)` statt `kzalloc(n * size)`.
- Lokale Doku `ERKLAERUNG.md`, `MVC.md`, `INFRA.md` (lokal, nicht im Repo):
  Entscheidungen zur Block-0-Semantik und Idempotenz von `fixboss` und zum
  Erhalt von `phase4.sh`, Host-Test in der Schichtenzuordnung, Build-Host mit
  Pin, `--platform linux/amd64`, Log-Pfaden und `JOBS`.

### Behoben
- `build_rs353_linux.sh`, `die()`: ein explizites `exit` löst die ERR-Falle
  nicht aus, der Abbruch-Kasten mit Schritt und Protokollpfad fehlte. `die()`
  ruft jetzt `on_error` selbst auf. Schritt "8/10 Bauen" fängt den Exit-Code
  von `wait` per `|| MAKE_RC=$?` ab, damit der Kasten bei Build-Fehler genau
  einmal erscheint.
- `build_rs353_linux.sh`, Schritt "6/10 Port einspielen": `apply.sh` lief in
  `| tail -30`, nur die letzten 30 Zeilen blieben, ein Protokoll fehlte. Jetzt
  vollständige Ausgabe in `$WORKDIR/apply.log`, die Konsole zeigt die letzten
  30 Zeilen; der Exit-Code wird ausgewertet, bei Fehler Abbruch mit Log-Pfad.
  `on_error` nennt `apply.log`, solange kein Build-Log existiert.
- `build_rs353_linux.sh`, Schritt "9/10 Image pruefen": eine abweichende
  Prüfsumme war nur ein Hinweis. Jetzt wird nur die Zeile des RS353-Images
  geprüft; Abweichung und fehlende Zeile brechen ab, eine fehlende Datei
  `sha256sums` bleibt ein Hinweis.
- `port/phase4.sh`: `cp .config .config.bak` scheiterte in einem frischen Baum
  unter `set -e`. Jetzt `touch .config` davor. Die Profilzeilen setzen Target,
  Subtarget und Gerät, zeichengleich mit `build_rs353_linux.sh`.
- `boss.c`, `mtd_fixboss()`: ein nicht auf `erasesize` ausgerichtetes `-o`
  ergab eine falsche CRC, weil die Daten ohne den Offset im Block gelesen
  wurden. Jetzt Exit 1 vor jedem Schreibzugriff.
- `boss.c`, `mtd_fixboss()`: `%zx` für `size_t`, Vorzeichenvergleich beim
  Lesen, Magic-Prüfung vor dem Ändern des Headers, Tippfehler "erease",
  Freigabe von Speicher und Dateideskriptor auf allen Fehlerpfaden
  (`goto err`), redundante `pread`/`pwrite`-Prototypen entfernt.
- `port/patches/src_package_system_mtd_src_mtd.c.diff`: Usage-Text
  "fix the boss checksum in bootmonitor parameters" durch "recompute BOSS
  firmware header checksum" ersetzt, `if(` durch `if (`, Hunk-Header
  angepasst.
- `port/patches/src_target_linux_lantiq_xrx200_base-files_lib_upgrade_platform.sh.diff`,
  `do_fixboss()`: die Fehlermeldung "do not reboot" setzte eine laufende
  Shell voraus. `exit 1` beendet `do_stage2` vor dessen `reboot -f`, das
  Weitere entscheidet procd. Die neuen Meldungen nennen die veraltete
  Prüfsumme, die Wiederherstellung über Bootmonitor/TFTP und die Wiederholung
  durch `09_fix_crc.sh`.
- `09_fix_crc.sh`: Kopfzeile "Copyright (C) 2007 OpenWrt.org" traf nicht zu,
  durch eine Zweckzeile ersetzt.
- `port/tree/target/linux/lantiq/files/arch/mips/boot/dts/lantiq/vr9_bintec_rs353.dts`:
  Unit-Adressen `partition@0x20000` usw. auf `@20000`, `@40000`, `@80000`,
  `@c0000` (dtc-Warnung `unit_address_format`), `reg` unverändert.

### Entfernt
- `README.md`, Struktur-Tabelle: Zeilen `z_INFOS/`, `restore.py`, `modules/`,
  `models/`/`controllers/`/`services/`/`templates/` und `tests/` (lokal bzw.
  leer, nicht im Repo). Verbleibende Pfade außerhalb des Repos
  (`openwrt-RS353_1/`, `openwrt-RS353_2/`, `out/`) sind als lokal bzw.
  Build-Ergebnis gekennzeichnet.
- `README.md`: Abschnitt "Kaskade" (interner Vermerk ohne Nutzen für Leser).
- `port/patches/src_target_linux_lantiq_xrx200_base-files_etc_board.d_02_network.diff`:
  Patch-Zahl 10 auf 9. `port/apply.sh` Schritt 3.3 schreibt `02_network`
  selbst. Die Datei liegt lokal in `port/z_ALT/` (per `.gitignore`-Regel `z_*`
  nicht im Repo).
- `docker/Dockerfile`: `ENV FORCE_UNSAFE_CONFIGURE=0` (ohne Wirkung).
- `docker/Dockerfile`: `python3-distutils` aus der Pflichtliste der Pakete
  (jetzt optional, siehe Geändert).

### Verifiziert
- `grep -n` auf Code-Fences in `README.md`: alle drei öffnenden Fences tragen
  `bash`, die übrigen sind schließende Fences.
- `*.md`-Verweise in `README.md` gegen `git ls-files`: `BUILD_HOWTO.md`
  getrackt; `PLAN.md` und `REVIEW_BEFUNDE.md` nicht getrackt und als lokal
  markiert.
- Lokaler Fork `openwrt-RS353_2`: `git ls-tree -r` findet RS353-Dateien in
  `origin/openwrt-22.03` und `origin/old_2021`, keine in `origin/openwrt-24.10`.
- `git log --oneline origin/main` listet `02738c2` und `af2805d`; alle
  Commit-SHAs in dieser Datei stammen aus dieser Liste.
  `git show --summary 02738c2` meldet `delete mode 160000` für beide
  Fork-Ordner.
- `git tag -l` ist leer, daher keine Compare-Links.
- `grep -nP '[\x{2013}\x{2014}]'` auf `README.md` und `CHANGELOG.md`: keine
  Treffer.
- `bash -n` auf `build_rs353_linux.sh`, `port/apply.sh` und
  `port/tests/boss_test.sh`, `sh -n` auf `port/phase4.sh` und `09_fix_crc.sh`:
  jeweils Exit 0.
- `git apply --stat` auf `src_package_system_mtd_src_mtd.c.diff` und
  `src_target_linux_lantiq_xrx200_base-files_lib_upgrade_platform.sh.diff`:
  Exit 0 (nur Syntax).
- `port/patches/`: 9 Dateien `*.diff`/`*.patch`, jeder Dateistamm wird in
  `port/apply.sh` referenziert.
- DTS: `grep -c 'partition@0x'` ergibt 0, `git diff` enthält keine geänderte
  `reg`-Zeile. `mtdsplit_bintec.c`: `kcalloc` 1 Treffer, `kzalloc` 0.
- Profilzeile in `port/phase4.sh` und `build_rs353_linux.sh` per Vergleich der
  `grep -o`-Ausgabe zeichengleich.
- Digest des Basis-Images per lesendem Abruf der Docker-Hub-API und `HEAD`
  gegen die Registry bestätigt, beide liefern denselben Digest.
- `port/tests/stubs/crc32.c` und `crc32.h`: nach dem Herkunftskommentar
  byte-identisch mit openwrt-24.10 (lesender Abgleich). CRC-32 von
  "123456789" unabhängig nachgerechnet: `0xcbf43926`. Die Python-Prüffunktion
  `check_rewrite` in `boss_test.sh` weist fünf Header-Mutanten (Little Endian,
  ohne Invertierung, falsche Länge, Byte aus Block 1, `unknown1` genullt) mit
  Exit 1 ab.
- `bash port/tests/boss_test.sh` auf dem Windows-Host: Exit 2,
  `NICHT ausgefuehrt: cc/gcc`.
- `git check-ignore -v`: `port/tests/boss_test.sh` über die Regel `*.sh`,
  `port/z_ALT` über die Regel `z_*`; `port/tests/stubs/*` nicht ignoriert,
  `git ls-files port/tests` leer.
- `grep -nP '[\x{2013}\x{2014}]'` (Locale `C.UTF-8`), CR-Zählung und
  BOM-Prüfung auf `CHANGELOG.md`: keine Treffer.
- `BUILD_HOWTO.md`: TOC-Anker gegen alle Überschriften aufgelöst (60/60 Links,
  62 Überschriften, ohne Link nur Titel und "Inhalt");
  `grep -nP '[\x{2013}\x{2014}]'` (Locale `C.UTF-8`), CR-Zählung,
  BOM-Prüfung: keine Treffer.
- NICHT verifiziert:
  - OpenWrt-Build unter Linux und im Docker-Container sowie der Bau des
    Docker-Images.
  - Lauf des Host-Tests mit den Fällen F1 bis F6 (kein Compiler auf dem
    Windows-Host).
  - `gcc -Wall -Wextra` auf `boss.c` und `mtdsplit_bintec.c`, `shellcheck`
    auf die Skripte.
  - `dtc` auf `vr9_bintec_rs353.dts`.
  - `git apply --check` der Patches gegen einen openwrt-24.10-Baum.
  - Verhalten auf einem case-sensitiven Linux-Dateisystem.
  - Gerät: Flashen, Booten und `mtd fixboss` auf echtem MTD.
  - Prüfmechanismus des BOSS-Bootmonitors (Bereich aus `image_length`).
  - Verhalten von procd nach `exit 1` in `do_fixboss()`.
  - Darstellung auf GitHub.

## [0.2.4] - 2026-09-15
### Hinzugefügt
- `BUILD_HOWTO.md` Abschnitt 14 "WSL2 auf dem Windows-Host": Voraussetzungs-
  Tabelle, 14.1 Distribution einrichten (`wsl --status`, `wsl -l -v`,
  `wsl --install -d Ubuntu-24.04`, Nicht-root-Benutzer), 14.2 Bauen (Klon ins
  Linux-Dateisystem, `build_rs353_linux.sh --jobs 6`), 14.3 Image holen
  (`/mnt/c` oder `\\wsl$`), 14.4 Grenzen. TOC um fünf Einträge ergänzt.
- Hinweis in Abschnitt 0, dass Docker Desktop auf Windows nicht der einzige Weg
  ist.

### Geändert
- `README.md`: Setup trennt Windows in WSL2 (empfohlen) und Docker; Aufruf nennt
  den WSL-Weg.
- `ERKLAERUNG.md`: Entscheidung WSL2 als bevorzugter Windows-Weg, Docker-Weg
  bleibt für Rechner ohne Virtualisierung erhalten; Doku statt Skript-Änderung.

### Verifiziert
- Auf diesem Host geprüft: `wsl --status` meldet Standardversion 2,
  `wsl -l -v` listet ausschließlich `docker-desktop` (Dockers Utility-VM, als
  Build-Umgebung ungeeignet). Hardware 31,9 GB RAM, 8 Kerne, 174,6 GB frei auf
  C: - reicht für die 40-GB-Anforderung.
- Neue Überschriften und TOC-Anker stimmen überein (`## 14.`, `### 14.1` bis
  `### 14.4`).
- `tr -cd CR | wc -c` auf `BUILD_HOWTO.md`: 0 Bytes.
- NICHT verifiziert: ein Build in WSL. Es ist keine nutzbare Distribution
  installiert, der Ablauf aus Abschnitt 14 ist nicht durchlaufen.

## [0.2.3] - 2026-09-15
### Hinzugefügt
- `README.md`: Abschnitt "Herkunft" mit Repo-URL, Branch, Commit-SHA und Datum
  beider Forks, Klon-Kommando und Hinweis, dass auf `master` von
  `openwrt-RS353_2` keine RS353-Dateien liegen.
- `.gitignore`: `openwrt-RS353_1/`, `openwrt-RS353_2/` gesperrt, mit
  Begründung (rund 500 MB Fremdcode ohne Nutzen für den Build).

### Geändert
- `README.md`: Zweck und Struktur-Tabelle nennen die Forks als lokale Referenz
  außerhalb des Repos; Abschnitt "Git-Stand" erklärt die entfernten Gitlinks;
  `port/`-Zeile auf den tatsächlichen Inhalt gebracht.
- `MVC.md`: Fremdcode-Bullet vermerkt "nur lokal, seit 2026-09-15 nicht im Git".
- `ERKLAERUNG.md`: Entscheidung Gitlink-Entfernung gegen Submodul und gegen
  Einchecken des Fremdcodes, mit Begründung.

### Entfernt
- Gitlinks `openwrt-RS353_1` und `openwrt-RS353_2` (Modus `160000`) aus dem
  Index. Es gab kein `.gitmodules`, also weder Submodul noch Inhalt; auf GitHub
  ergab das zwei Ordner, deren Klick ins Leere führt. `git rm --cached`
  scheitert an solchen Einträgen (`pathspec did not match any files`), entfernt
  wurde mit `git update-index --force-remove`. Arbeitsverzeichnisse unberührt.

### Verifiziert
- `git ls-files -s | grep 160000` liefert keine Zeile mehr.
- `git status --short`: `D openwrt-RS353_1`, `D openwrt-RS353_2` gestaged,
  23 Dateien getrackt.
- `openwrt-RS353_1/.git` und `openwrt-RS353_2/.git` liegen unverändert auf
  Platte; `git check-ignore -v` weist beide Ordner den `.gitignore`-Zeilen zu.
- NICHT erledigt zum Zeitpunkt dieses Eintrags: Commit und Push. Überholt:
  Commit `02738c2` auf `origin/main` (`git log --oneline origin/main`) löscht
  beide Gitlinks (`delete mode 160000`); der Vorgänger `af2805d` enthält sie
  noch.

## [0.2.2] - 2026-09-15
### Hinzugefügt
- `.gitattributes`: `* text=auto eol=lf` plus explizite Regeln für `*.sh`,
  `*.patch`, `*.diff`, `*.dts`, `*.c`, `*.h`, `Makefile`, `Dockerfile`;
  `*.cev`, `*.bin`, `*.img`, `*.gz` als `binary`. Grund: `core.autocrlf=true`
  ist auf dem Windows-Host gesetzt, ein Windows-Klon bekäme sonst CRLF. Ein
  Skript mit CRLF bricht auf dem Linux-Host mit `bad interpreter` ab, ein Patch
  mit CRLF wird von `git apply` verworfen.
- `.gitignore`: Ausnahmen `!port/apply.sh`, `!port/phase4.sh`,
  `!port/tree/target/linux/lantiq/base-files/etc/uci-defaults/09_fix_crc.sh`.

### Geändert
- `README.md`: Abschnitt "Bekannte Lücke im Git-Stand" ersetzt durch
  "Git-Stand" mit Tabelle der vier ausgenommenen Skripte und Hinweis auf die
  LF-Erzwingung.
- `BUILD_HOWTO.md` 13.3: Grenze "Port-Skripte fehlen im Repo" entfällt, statt
  dessen Hinweis auf LF-Zwang und alte CRLF-Klone.

### Behoben
- Letzte Zeile in `.gitignore` hatte CRLF, jetzt durchgängig LF.

### Verifiziert
- `git check-ignore -q` meldet für alle vier Skripte "trackbar"; `git add -n`
  listet `.gitattributes`, `.gitignore`, `port/apply.sh`, `port/phase4.sh`,
  `port/tree/.../09_fix_crc.sh`.
- `git check-attr text eol` liefert `text: set / eol: lf` für `*.sh` und
  `*.patch`, `text: auto / eol: lf` für `*.md`.
- `git ls-files --eol`: `i/lf w/lf` für alle geprüften Dateien, keine
  Renormalisierung nötig.
- `tr -cd CR | wc -c` auf `.gitattributes` und `.gitignore`: 0 Bytes.
- NICHT verifiziert: Verhalten eines frischen Windows-Klons. Auf diesem Host
  wurde kein zweiter Klon gezogen.
- NICHT behoben: die beiden vor diesem Arbeitsstand vorhandenen Commits. Stand
  dieses Eintrags: Reflog und `origin/main` zeigten auf denselben einzelnen
  Commit, `git fsck --lost-found` war leer, nicht wiederherstellbar. Dieser
  Commit ist in der heutigen Historie nicht enthalten;
  `git log --oneline --all` listet nur `af2805d` und `02738c2`.

## [0.2.1] - 2026-09-15
### Hinzugefügt
- `BUILD_HOWTO.md`: verlinktes Inhaltsverzeichnis (55 Einträge, Abschnitte 0
  bis 13 samt F1-F12), eingefasst in `<!-- TOC -->` / `<!-- /TOC -->`.

### Geändert
- `README.md`: Struktur um `port/`, `docker/`, `build_rs353_linux.sh`, `out/`
  ergänzt; Setup nach Linux- und Windows-Weg getrennt; Aufruf auf das
  Build-Skript umgestellt; Artefaktname `*-boss-image.cev`; Hinweis auf den
  seriellen Erstflash; Git-Lücke bei `port/*.sh` benannt.
- `INFRA.md`: Artefakt von `*-sysupgrade.bin` auf
  `*-bintec_rs353-boss-image.cev` korrigiert; Erstflash über Bootmonitor statt
  Web-UI/sysupgrade; Build-Host-Tabelle Linux/Windows; Arbeitsordner, Named
  Volume, Größengrenze 31232k, serielle Parameter ergänzt.
- `MVC.md`: Eigencode eingeordnet (`build_rs353_linux.sh`, `port/apply.sh`,
  `port/phase4.sh` als Service-Schicht; `port/patches`, `port/tree` als Daten);
  Root-Ablage des Einstiegsskripts als bewusste Abweichung begründet.
- `ERKLAERUNG.md`: Entscheidungen zu Docker als Windows-Krücke, Skript statt
  Kommandoliste, Endmarker statt Pipe, Zeitstempel-Fund des Images, `-j4`,
  unverändertes `IMAGE_SIZE`; offener Punkt Geräte-Reife.

### Verifiziert
- TOC-Anker aus den Überschriften erzeugt (GitHub-Schema), Codeblöcke
  übersprungen, `<name>` in F4 als `&lt;name&gt;` maskiert.
- NICHT verifiziert: gerenderte Sprungziele. Auf diesem Host wurde kein
  Markdown-Renderer ausgeführt.

## [0.2.0] - 2026-09-15
### Hinzugefügt
- `build_rs353_linux.sh`: Ein-Kommando-Build für Laien auf einem Linux-Host,
  ohne Docker. Zehn Schritte mit je eigener Erfolgsprüfung: Nicht-root-Test,
  Paketinstallation nach `docker/Dockerfile`, Test auf Groß-/Kleinschreibung
  und 40 GB Platz, Klon `openwrt-24.10`, Feeds, `port/apply.sh` plus fünf
  Prüfmarken, Profil mit `.config.bak`, `make -j4` ohne Pipe mit Endmarker
  `RS353_BUILD_OK`/`RS353_BUILD_FAIL`, Stamp-Frischeprüfung und 31232k-Limit,
  Kopie nach `out/`. Optionen `--workdir`, `--jobs`, `--skip-deps`.

### Geändert
- `BUILD_HOWTO.md`: neuer Abschnitt 13 (Linux-Host ohne Docker) mit Aufruf,
  Optionen, Zuordnung der Skript-Schritte zu den Docker-Abschnitten und
  Grenzen. Abschnitt 0 nennt Docker nun ausdrücklich als Windows-Krücke.
- `.gitignore`: `!build_rs353_linux.sh` in die Ausnahmeliste der `*.sh`-Regel.

### Verifiziert
- `bash -n build_rs353_linux.sh` -> SYNTAX_OK. Datei ASCII, LF, keine CR.
- `git add -n build_rs353_linux.sh` -> `add 'build_rs353_linux.sh'`, die
  Whitelist greift.
- NICHT verifiziert: ein echter Durchlauf. Der Entwicklungshost ist Windows,
  ein Linux-Build war nicht ausführbar. `shellcheck` ist hier nicht
  installiert. Der erste Lauf auf einem Linux-Rechner steht aus.

## [0.1.0] - 2026-09-14
### Hinzugefügt
- Initiales Scaffold des Projekts `OpenWRT_Update`.
- Pflicht-Doku befüllt: README.md, INFRA.md, MVC.md, ERKLAERUNG.md.
- PLAN.md: Ausgangslage beider RS353-Forks, Portierungsschritte, offene Punkte.
- .gitignore mit Pflichteinträgen.

### Behoben
- BOM aus .gitignore entfernt; README-Aussage zum RS353-Support je Tree korrigiert;
  z_INFOS/ und restore.py in README-Struktur ergänzt.

### Verifiziert
- Scaffold idempotent durchgelaufen, 13 Objekte erzeugt.
- Fork-Stand aus Git-Historie gelesen (Xernium openwrt-22.03-old 2023-02-15;
  armSeb master 2022-10-26), RS353-Dateien in Tree _1 lokalisiert.
- Doku-Review: Befunde behoben, Git-Fakten und Dateipfade bestätigt.
