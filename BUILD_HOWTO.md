# BUILD_HOWTO - Bintec RS353 auf OpenWrt 24.10 bauen

Schritt-für-Schritt-Anleitung vom leeren Rechner bis zum fertigen Image
`*-bintec_rs353-boss-image.cev`.

Jeder Schritt hat einen kopierbaren Befehl und darunter eine Zeile, woran der
Erfolg erkennbar ist. Befehle laufen auf dem Windows-Host, sofern nicht
ausdrücklich "im Container" dabeisteht.

Feste Namen, die in der ganzen Anleitung vorkommen:

| Name | Bedeutung |
|---|---|
| `openwrt-rs353-build:24.10` | Docker-Image des Buildhosts |
| `owrt-build` | Laufender Container |
| `openwrt-rs353-src` | Named Volume, im Container auf `/build` gemountet |
| `/build/openwrt` | Produktiver OpenWrt-24.10-Quellbaum |
| `/build/portcheck` | Zweitbaum zum gefahrlosen Testen des Port-Kits |
| `/build/port` | Kopie des Port-Kits im Container |

Vor dem ersten Lauf Abschnitt 9, 10 und 11 lesen. Dort stehen die Fallen, die in
diesem Projekt bereits aufgetreten sind.

---

<!-- TOC -->
## Inhalt

- [0. Voraussetzungen](#0-voraussetzungen)
- [1. Repo-Aufbau](#1-repo-aufbau)
- [2. Build-Docker-Image bauen](#2-build-docker-image-bauen)
- [3. Container starten](#3-container-starten)
- [4. Quellbaum und Feeds vorbereiten](#4-quellbaum-und-feeds-vorbereiten)
  - [4.1 OpenWrt 24.10 klonen](#41-openwrt-2410-klonen)
  - [4.2 Stand prüfen](#42-stand-prüfen)
  - [4.3 Feeds holen und einhängen](#43-feeds-holen-und-einhängen)
  - [4.4 Zweitbaum für gefahrloses Testen (empfohlen)](#44-zweitbaum-für-gefahrloses-testen-empfohlen)
- [5. Port-Kit anwenden](#5-port-kit-anwenden)
  - [5.1 Port-Kit in den Container kopieren](#51-port-kit-in-den-container-kopieren)
  - [5.2 Gleichstand prüfen](#52-gleichstand-prüfen)
  - [5.3 Ausführbar machen](#53-ausführbar-machen)
  - [5.4 Probelauf gegen den Zweitbaum](#54-probelauf-gegen-den-zweitbaum)
  - [5.5 Anwenden auf den produktiven Baum](#55-anwenden-auf-den-produktiven-baum)
  - [5.6 Kontrolle, was sich geändert hat](#56-kontrolle-was-sich-geändert-hat)
- [6. Profil auf das Gerät setzen](#6-profil-auf-das-gerät-setzen)
  - [6.1 Sicherung anlegen und Profil setzen](#61-sicherung-anlegen-und-profil-setzen)
  - [6.2 Profil verifizieren](#62-profil-verifizieren)
  - [6.3 Gerätenamen gegenprüfen](#63-gerätenamen-gegenprüfen)
- [7. Build starten](#7-build-starten)
  - [7.1 Parallelität festlegen](#71-parallelität-festlegen)
  - [7.2 Bauen](#72-bauen)
  - [7.3 Fortschritt verfolgen](#73-fortschritt-verfolgen)
  - [7.4 Ende feststellen](#74-ende-feststellen)
  - [7.5 Bei einem Fehlschlag: laut bauen](#75-bei-einem-fehlschlag-laut-bauen)
- [8. Ergebnis-Image finden](#8-ergebnis-image-finden)
  - [8.1 Größe gegen das Limit prüfen](#81-größe-gegen-das-limit-prüfen)
  - [8.2 Prüfsumme gegenlesen](#82-prüfsumme-gegenlesen)
  - [8.3 Image auf den Windows-Host holen](#83-image-auf-den-windows-host-holen)
- [9. Vor dem Flashen lesen](#9-vor-dem-flashen-lesen)
- [10. Typische Fehler und ihre Behebung](#10-typische-fehler-und-ihre-behebung)
  - [F1 - Cannot connect to the Docker daemon](#f1---cannot-connect-to-the-docker-daemon)
  - [F2 - No such container: owrt-build](#f2---no-such-container-owrt-build)
  - [F3 - You are building with the root user](#f3---you-are-building-with-the-root-user)
  - [F4 - apply.sh bricht mit FAIL &lt;name&gt; ab](#f4---applysh-bricht-mit-fail-name-ab)
  - [F5 - already applied obwohl nichts angewandt wurde](#f5---already-applied-obwohl-nichts-angewandt-wurde)
  - [F6 - Build endet mit RS353_BUILD_FAIL, Ursache unklar](#f6---build-endet-mit-rs353_build_fail-ursache-unklar)
  - [F7 - Objektdateien mit Länge 0 nach einem harten Abbruch](#f7---objektdateien-mit-länge-0-nach-einem-harten-abbruch)
  - [F8 - SIZE_TOO_BIG in Schritt 8.1](#f8---size_too_big-in-schritt-81)
  - [F9 - .config ist nach einem Fehlversuch durcheinander](#f9---config-ist-nach-einem-fehlversuch-durcheinander)
  - [F10 - Änderung am Port-Kit wirkt nicht](#f10---änderung-am-port-kit-wirkt-nicht)
  - [F11 - phase4.sh meldet PHASE4_OK, obwohl nichts gebaut wurde](#f11---phase4sh-meldet-phase4_ok-obwohl-nichts-gebaut-wurde)
  - [F12 - sh: bad substitution oder Abbruch direkt beim Start von apply.sh](#f12---sh-bad-substitution-oder-abbruch-direkt-beim-start-von-applysh)
- [11. Wiederaufnahme nach Abbruch](#11-wiederaufnahme-nach-abbruch)
  - [11.1 Sauber abbrechen](#111-sauber-abbrechen)
  - [11.2 Zustand prüfen](#112-zustand-prüfen)
  - [11.3 Fortsetzen](#113-fortsetzen)
  - [11.4 Nach einem Neustart des Rechners](#114-nach-einem-neustart-des-rechners)
  - [11.5 Alles verwerfen und neu anfangen](#115-alles-verwerfen-und-neu-anfangen)
- [12. Kurzreferenz](#12-kurzreferenz)
- [13. Linux-Host ohne Docker](#13-linux-host-ohne-docker)
  - [13.1 Ein Kommando](#131-ein-kommando)
  - [13.2 Was das Skript tut](#132-was-das-skript-tut)
  - [13.3 Grenzen](#133-grenzen)
- [14. WSL2 auf dem Windows-Host](#14-wsl2-auf-dem-windows-host)
  - [14.1 Distribution einrichten](#141-distribution-einrichten)
  - [14.2 Bauen](#142-bauen)
  - [14.3 Image auf den Windows-Host holen](#143-image-auf-den-windows-host-holen)
  - [14.4 Grenzen](#144-grenzen)

<!-- /TOC -->

---
## 0. Voraussetzungen

Was auf dem Windows-Host vorhanden sein muss:

| Ding | Mindestanforderung | Prüfbefehl |
|---|---|---|
| Docker Desktop | läuft, Linux-Container-Modus | `docker version` |
| Freier Plattenplatz | 40 GB im Docker-Datenbereich | `docker system df` |
| Arbeitsspeicher | 8 GB, besser 16 GB | Task-Manager |
| CPU-Kerne | 4 oder mehr | Task-Manager |
| Projektordner | `<PFAD>\OpenWRT_Update` | `dir` |

`<PFAD>` steht in dieser Anleitung für den Ordner auf dem Windows-Host, in dem
`OpenWRT_Update` liegt, etwa `C:\Projekte`. In der WSL-Schreibweise aus 14.3
(`/mnt/c/<PFAD>/...`) entfällt der Laufwerksbuchstabe, dort also `Projekte`.

Auf dem Host wird NICHT gebaut. Alles Compilieren passiert im Container. Grund:
Windows-Dateisysteme unterscheiden Groß- und Kleinschreibung nicht, der
OpenWrt-Quellbaum enthält aber Dateien, die sich nur darin unterscheiden. Ein
Bind-Mount von Windows nach Linux zerstört den Baum.

Docker ist damit reine Windows-Krücke, keine Build-Anforderung. Auf einem
Linux-Rechner fällt dieser Grund weg, dort wird ohne Docker direkt auf dem Host
gebaut. Dieser Weg steht in Abschnitt 13 und ist mit einem Skript abgedeckt.

Auch auf Windows ist Docker Desktop nicht die einzige Möglichkeit: WSL2 stellt
ein case-sensitives ext4 bereit und führt dasselbe Skript aus. Abschnitt 14.

```bash
docker version
```

Erfolg: Es erscheinen zwei Blöcke, `Client` und `Server`, und im Server-Block
steht `OS/Arch: linux/amd64`. Fehlt der Server-Block, läuft der Docker-Dienst
nicht.

---

## 1. Repo-Aufbau

So ist der Projektordner aufgebaut. Nichts davon muss von Hand erzeugt werden,
es ist bereits vorhanden.

```text
<PFAD>\OpenWRT_Update\
+-- docker\
|   \-- Dockerfile                  Buildhost-Definition (Debian bookworm, gepinnt)
+-- port\                           das "Port-Kit": alles Gerätespezifische
|   +-- apply.sh                    trägt das Port-Kit in einen Quellbaum ein
|   +-- phase4.sh                   Profil setzen, bauen, prüfen (siehe F11)
|   +-- patches\                    9 Diffs/Patches gegen 24.10
|   +-- tests\                      Host-Test für mtd fixboss (Abschnitt 9)
|   \-- tree\                       4 komplett neue Dateien
|       +-- package\system\mtd\src\boss.c
|       +-- target\linux\generic\files\drivers\mtd\mtdsplit\mtdsplit_bintec.c
|       +-- target\linux\lantiq\base-files\etc\uci-defaults\09_fix_crc.sh
|       \-- target\linux\lantiq\files\arch\mips\boot\dts\lantiq\vr9_bintec_rs353.dts
+-- build_rs353_linux.sh            Build ohne Docker (Abschnitt 13 und 14)
+-- BUILD_HOWTO.md                  diese Datei
\-- README.md, CHANGELOG.md
```

Was das Port-Kit inhaltlich tut, in einem Satz: es fügt dem OpenWrt-Baum das
Gerät `bintec_rs353` hinzu - Device Tree, Flash-Aufteilung, das
BOSS-Containerformat des Herstellers und die Netzwerkkonfiguration.

```powershell
dir <PFAD>\OpenWRT_Update\port\patches
```

Erfolg: Es werden 9 Dateien gelistet - sieben `*.diff`, dazu
`000-add-mkbossimg.patch` und
`0999-MTD-lantiq-flash-map-add-ebu-endianness-check.patch`.

---

## 2. Build-Docker-Image bauen

Das Image bringt alle Compiler und Hilfsprogramme mit, die OpenWrt braucht.
Einmal bauen, danach wiederverwenden.

Das Basis-Image ist auf ein datiertes Tag samt Digest festgelegt
(`docker/Dockerfile:4`), jeder Neubau startet damit vom selben Stand.
Aktualisieren heißt: ein neueres datiertes `bookworm-<datum>-slim`-Tag wählen,
dessen Digest neu ermitteln und beides in dieser Zeile eintragen.

`gcc-multilib` (`docker/Dockerfile:12`) gibt es in Debian bookworm nur für
amd64 und einige andere Architekturen, nicht für arm64. Auf einem Host, der
nicht amd64 ist, `--platform linux/amd64` an `docker build` und an `docker run`
(Abschnitt 3) anhängen.

```powershell
docker build -t openwrt-rs353-build:24.10 --build-arg UID=1000 --build-arg GID=1000 <PFAD>\OpenWRT_Update\docker
```

Erfolg: Letzte Zeile lautet `naming to docker.io/library/openwrt-rs353-build:24.10`
oder `Successfully tagged openwrt-rs353-build:24.10`. Dauer beim ersten Mal 5
bis 15 Minuten.

Gegenprobe, falls unklar ist ob das Image schon existiert:

```bash
docker images openwrt-rs353-build:24.10
```

Erfolg: Eine Zeile mit `TAG 24.10` und einer Größe um 1.6 GB.

---

## 3. Container starten

Der Container bekommt ein Named Volume auf `/build`. Das Volume liegt im
Linux-Dateisystem von Docker, nicht auf `C:`. Genau das ist der Punkt: kein
Windows-Dateisystem im Quellbaum.

```bash
docker run -d --name owrt-build -v openwrt-rs353-src:/build -w /build openwrt-rs353-build:24.10 sleep infinity
```

Erfolg: Es wird eine 64-stellige Container-ID ausgegeben.

```bash
docker ps --filter name=owrt-build
```

Erfolg: Eine Zeile mit `owrt-build` und Status `Up ...`.

Meldet Docker `Conflict. The container name "/owrt-build" is already in use`,
existiert der Container bereits. Dann nur starten statt neu anlegen:

```bash
docker start owrt-build
```

Erfolg: Die Ausgabe ist die Zeile `owrt-build`.

Mit dem Container arbeiten: jeder Befehl "im Container" folgt diesem Muster.

```bash
docker exec -u build owrt-build bash -lc "whoami; pwd"
```

Erfolg: Zwei Zeilen, `build` und `/build`. Steht dort `root`, fehlt das
`-u build`; ohne Nutzerwechsel bricht OpenWrt den Build mit einer Root-Warnung
ab.

---

## 4. Quellbaum und Feeds vorbereiten

### 4.1 OpenWrt 24.10 klonen

```bash
docker exec -u build owrt-build bash -lc "cd /build && git clone --branch openwrt-24.10 https://git.openwrt.org/openwrt/openwrt.git openwrt"
```

Erfolg: Letzte Zeile `Resolving deltas: 100% (...)`, danach existiert
`/build/openwrt`. Existiert der Baum schon, bricht git mit
`destination path 'openwrt' already exists` ab - das ist ab dem zweiten Lauf der
Normalfall, Schritt überspringen.

### 4.2 Stand prüfen

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && git log --oneline -1"
```

Erfolg: Eine Zeile wie `a1ea57b kernel: bump 6.6 to 6.6.151`. Der genaue Hash
darf abweichen; entscheidend ist ein Commit aus dem Zweig `openwrt-24.10`.

### 4.3 Feeds holen und einhängen

Feeds sind die Paketquellen (LuCI-Weboberfläche, Zusatzpakete, Routing).

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && ./scripts/feeds update -a && ./scripts/feeds install -a"
```

Erfolg: Die Ausgabe endet ohne `ERROR:`.

```bash
docker exec -u build owrt-build bash -lc "ls /build/openwrt/package/feeds"
```

Erfolg: Genau die vier Ordner `base`, `luci`, `packages`, `routing`.

### 4.4 Zweitbaum für gefahrloses Testen (empfohlen)

Das Port-Kit zuerst gegen eine Kopie fahren. Geht dabei etwas schief, bleibt der
produktive Baum unberührt.

```bash
docker exec -u build owrt-build bash -lc "cd /build && [ -d portcheck ] || git clone --shared /build/openwrt portcheck"
```

Erfolg: `/build/portcheck` existiert. Bei bereits vorhandenem Ordner gibt der
Befehl nichts aus - ebenfalls Erfolg.

---

## 5. Port-Kit anwenden

### 5.1 Port-Kit in den Container kopieren

Wichtig zu verstehen: Der Container hat KEINEN Zugriff auf `C:`. Es gibt keinen
Bind-Mount. Das Port-Kit muss aktiv hineinkopiert werden - und zwar nach jeder
Änderung auf dem Windows-Host erneut. Wer das vergisst, baut stillschweigend
mit einem alten Stand.

```powershell
docker cp <PFAD>\OpenWRT_Update\port owrt-build:/build/port
```

Erfolg: Kein Fehlertext.

```bash
docker exec -u build owrt-build bash -lc "ls -1 /build/port"
```

Erfolg: Es erscheinen `apply.sh`, `phase4.sh`, `patches`, `tree`. Fehlt
`phase4.sh`, wurde der Kopierschritt nicht ausgeführt - dann 5.1 wiederholen,
bevor es weitergeht.

### 5.2 Gleichstand prüfen

Vergleicht die Prüfsumme beider Seiten. Nur wenn sie übereinstimmen, baut der
Container das, was auf dem Host liegt.

```bash
docker exec -u build owrt-build bash -lc "md5sum /build/port/apply.sh"
```

Erfolg: Der ausgegebene Hash stimmt mit dem des Hosts überein.

```powershell
certutil -hashfile <PFAD>\OpenWRT_Update\port\apply.sh MD5
```

Erfolg: Die mittlere Zeile enthält denselben Hash wie oben (Groß- und
Kleinschreibung ignorieren).

### 5.3 Ausführbar machen

`docker cp` überträgt die Windows-Rechte nicht sinnvoll.

```bash
docker exec -u build owrt-build bash -lc "chmod 755 /build/port/apply.sh /build/port/phase4.sh"
```

Erfolg: Keine Ausgabe.

### 5.4 Probelauf gegen den Zweitbaum

`apply.sh` ist ein Bash-Skript mit `set -euo pipefail` und muss mit `bash`
gestartet werden, nicht mit `sh`.

```bash
docker exec -u build owrt-build bash -lc "bash /build/port/apply.sh /build/portcheck"
```

Erfolg: Die letzte Zeile lautet `PORT_APPLY_OK`. Dazwischen steht für jeden der
sieben `*.diff` eine Zeile `applied ...`, bei einem erneuten Lauf
`already applied ...` (`port/apply.sh:42-45`). Die neuen Dateien und die zwei
kopierten Patches erscheinen als `cp -v`-Zeilen, die Handports nur als
`== `-Schrittzeile. Bricht es mit `FAIL <name>` ab, siehe F4.

### 5.5 Anwenden auf den produktiven Baum

Erst ausführen, wenn 5.4 `PORT_APPLY_OK` geliefert hat.

```bash
docker exec -u build owrt-build bash -lc "bash /build/port/apply.sh /build/openwrt"
```

Erfolg: Wieder `PORT_APPLY_OK` als letzte Zeile.

### 5.6 Kontrolle, was sich geändert hat

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && git status --porcelain"
```

Erfolg: Richtwert 18 Zeilen, abgezählt an den Schritten von `apply.sh` -
zwölf mit `M` (geänderte Dateien: sieben per `*.diff`, fünf per Handport in
`mtd/src/Makefile`, `config-6.6`, `image/Makefile`, `vr9.mk`, `02_network`)
und sechs mit `??` (neue Dateien: `vr9_bintec_rs353.dts`, `boss.c`,
`mtdsplit_bintec.c`, `09_fix_crc.sh`, die beiden kopierten Patches). Ist ein
Zielordner neu, zeigt git statt der Datei den Ordner. Ist die Liste leer,
wurde nichts angewandt.

Zur Wiederholbarkeit: `apply.sh` erkennt bereits angewandte Patches und meldet
dann `already applied ...`. Ein zweiter Lauf ist daher unschädlich. Die
Erkennung arbeitet aber mit einer Textsuche, nicht mit einer echten
Patch-Prüfung - Gegenprobe siehe F5.

---

## 6. Profil auf das Gerät setzen

### 6.1 Sicherung anlegen und Profil setzen

Der Befehl löscht gezielt die bisherigen Geräte- und Profilzeilen aus der
`.config` und trägt den RS353 ein. Das `cp .config .config.bak` davor ist die
Sicherung; ohne sie ist ein Fehlversuch nur durch kompletten Neuaufbau der
Konfiguration zu reparieren.

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && cp .config .config.bak 2>/dev/null; sed -i '/^CONFIG_TARGET_lantiq_xrx200_DEVICE_/d;/^CONFIG_TARGET_PROFILE=/d' .config 2>/dev/null; printf 'CONFIG_TARGET_lantiq=y\nCONFIG_TARGET_lantiq_xrx200=y\nCONFIG_TARGET_lantiq_xrx200_DEVICE_bintec_rs353=y\n' >> .config && make defconfig"
```

Erfolg: Der Befehl endet ohne Fehler, `make defconfig` schreibt eine bereinigte
`.config`.

### 6.2 Profil verifizieren

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && grep -E '^CONFIG_TARGET_(PROFILE|lantiq_xrx200_DEVICE_bintec_rs353)' .config"
```

Erfolg: Genau zwei Zeilen:

```text
CONFIG_TARGET_PROFILE="DEVICE_bintec_rs353"
CONFIG_TARGET_lantiq_xrx200_DEVICE_bintec_rs353=y
```

Fehlt die `PROFILE`-Zeile, hat `make defconfig` das Gerät nicht gefunden - dann
wurde das Port-Kit nicht vollständig angewandt, zurück zu Schritt 5.

### 6.3 Gerätenamen gegenprüfen

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && make -s target/info 2>/dev/null | grep -A4 bintec_rs353 | head -12"
```

Erfolg: Es erscheint der Eintrag mit `Bintec RS353` und den unterstützten
Gerätenamen `bintec,rs353` und `rs353`.

---

## 7. Build starten

### 7.1 Parallelität festlegen

`-j` gibt an, wie viele Compiler-Prozesse gleichzeitig laufen. Mehr ist nicht
automatisch besser: In diesem Projekt hat `-j8` den Host so belastet, dass der
Build hart beendet werden musste und dabei acht Objektdateien mit Länge 0
zurückblieben (siehe F7). Empfehlung: `-j4`, und nur erhöhen, wenn der Rechner
sichtbar Luft hat.

`port/phase4.sh` liest die Parallelität aus der Umgebungsvariable `JOBS`
(Vorgabe 4) und den Log-Pfad aus `BUILDLOG` (Vorgabe `/build/rs353-build.log`),
siehe F11. `build_rs353_linux.sh` nimmt `--jobs N` (Vorgabe 4, 13.1).

### 7.2 Bauen

Der Build läuft lange (erstmalig 1 bis 3 Stunden), deshalb im Hintergrund mit
Protokoll in eine Datei. Die Endmarke wird von `make` selbst abhängig gemacht,
nicht von einer Pipe.

```bash
docker exec -u build -d owrt-build bash -lc "cd /build/openwrt && { make -j4 && echo RS353_BUILD_OK || echo RS353_BUILD_FAIL; } > /build/rs353-build.log 2>&1"
```

Erfolg: Der Befehl kehrt sofort zurück (`-d` = detached). Der Build läuft
weiter, auch wenn das Terminal geschlossen wird.

### 7.3 Fortschritt verfolgen

```bash
docker exec -u build owrt-build bash -lc "tail -20 /build/rs353-build.log"
```

Erfolg: Es erscheinen `make[n] -C ...`-Zeilen. Solange sich die Ausgabe bei
Wiederholung ändert, läuft der Build.

### 7.4 Ende feststellen

```bash
docker exec -u build owrt-build bash -lc "grep -E 'RS353_BUILD_(OK|FAIL)' /build/rs353-build.log"
```

Erfolg: `RS353_BUILD_OK`. Erscheint nichts, läuft der Build noch. Erscheint
`RS353_BUILD_FAIL`, weiter mit Abschnitt 10.

Warum die Endmarke wichtig ist: Der Exit-Status eines Builds geht verloren,
sobald die Ausgabe durch eine Pipe läuft (etwa `make | tail`). Dann meldet die
Pipe Erfolg, obwohl der Build gescheitert ist. Die Marke `RS353_BUILD_OK` wird
nur geschrieben, wenn `make` selbst erfolgreich war. Sie ist die einzige
verlässliche Aussage.

### 7.5 Bei einem Fehlschlag: laut bauen

Der parallele Build vermischt die Ausgaben. Zum Diagnostizieren einmal seriell
und ausführlich nachfahren - das bricht an derselben Stelle ab, dann aber
lesbar.

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && make -j1 V=s 2>&1 | tail -80"
```

Erfolg im Sinne der Diagnose: Die letzten Zeilen nennen Datei und Zeile des
eigentlichen Fehlers.

---

## 8. Ergebnis-Image finden

```bash
docker exec -u build owrt-build bash -lc "ls -l /build/openwrt/bin/targets/lantiq/xrx200/ | grep -i bintec"
```

Erfolg: Eine Datei, deren Name auf `-boss-image.cev` endet.

### 8.1 Größe gegen das Limit prüfen

Das Flash-Fach für die Firmware ist begrenzt. Ein zu großes Image passt nicht
und darf nicht auf das Gerät.

```bash
docker exec -u build owrt-build bash -lc 'IMG=$(ls /build/openwrt/bin/targets/lantiq/xrx200/*bintec*boss-image.cev | head -n1); SZ=$(stat -c %s "$IMG"); echo "$IMG"; echo "bytes=$SZ limit=$((31232*1024))"; [ "$SZ" -le $((31232*1024)) ] && echo SIZE_OK || echo SIZE_TOO_BIG'
```

Erfolg: Letzte Zeile `SIZE_OK`.

### 8.2 Prüfsumme gegenlesen

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt/bin/targets/lantiq/xrx200 && sha256sum -c sha256sums 2>/dev/null | grep -i bintec"
```

Erfolg: Die Zeile endet mit `: OK`.

### 8.3 Image auf den Windows-Host holen

```powershell
docker cp owrt-build:/build/openwrt/bin/targets/lantiq/xrx200 <PFAD>\OpenWRT_Update\out
```

Erfolg: Der Ordner `out\xrx200` existiert auf dem Host und enthält die
`.cev`-Datei sowie `sha256sums`.

---

## 9. Vor dem Flashen lesen

Das Image ist gebaut - damit ist es noch nicht gerätereif. Die kritischen
Befunde des statischen Reviews (K1, K2, K3) sind im Port-Kit umgesetzt. Was
bleibt, sind Vorbehalte, die nur am Gerät selbst entschieden werden können.
Sie stehen hier, damit niemand ahnungslos flasht.

| Punkt | Worum es geht | Quelle | Was zu tun ist |
|---|---|---|---|
| Header-Semantik | Beide Seiten folgen seit K1 demselben Vertrag: `image_length` führt den geprüften Bereich mit, `crc32` deckt genau diese Bytes hinter dem 52-Byte-Header ab, beide big-endian. Der Umfang unterscheidet sich bewusst - `mkbossimg` die ganze Nutzlast (die Datei wird vor dem Flashen als Ganzes geprüft), `mtd fixboss` nach dem Flashen nur den ersten Erase-Block (jffs2/rootfs_data schreiben in dieselbe Partition), also `image_length = erasesize - 52` (`0x1FFCC` bei 128-KiB-Blöcken). `mtd fixboss` ist idempotent: Stimmen beide Felder bereits, meldet es `checksum ok`, löscht und schreibt nichts und endet mit 0. `-c` ist auf `erasesize - 52` begrenzt, `-o` muss auf einer Erase-Block-Grenze liegen, sonst Exit 1 ohne Schreibzugriff. Evidenzstand: Die Semantik ist indirekt durch die Fork-Historie belegt (dort läuft `fixboss` seit Commit `38f9a7d899`, das Gerät bootet mit diesem Header). Unbelegt ist, ob der BOSS-Bootmonitor den geprüften Bereich tatsächlich aus `image_length` ableitet. Verhalten am Gerät und des Bootmonitors NICHT verifiziert. | `port/tree/package/system/mtd/src/boss.c:78-120` (Vertrag, Evidenzstand `:107-110`, Gerätetest `:111-115`), `:121-122` (Vorgabe `erasesize - 52`), `:124-134` (Grenzen `-o`/`-c`), `:181-189` (Prüfung, `checksum ok`), `:191-192` (Schreiben); `port/patches/000-add-mkbossimg.patch:150-171` (Vertrag), `:181-182` | Beim ersten Flash den diskriminierenden Gerätetest aus `boss.c:111-115` im Blick haben: Bootet das Gerät mit dem `fixboss`-Header nicht, mit dem unveränderten `mkbossimg`-Header aber schon, ist die Block-0-Semantik falsch und neu zu entscheiden. Die Zeile `BOSS header found ! Old Image Length ...` (`boss.c:164-166`) hält die Werte vor dem Umschreiben fest und ist am Gerät der Beleg für den Ausgangszustand. Den Header eines funktionierenden Herstellerimages auslesen und `image_length` gegen `erasesize - 52` sowie gegen die Partitionsgröße vergleichen ist informativ, nicht entscheidend (`boss.c:116-119`). |
| Erstflash-Weg | Der sysupgrade-Pfad ruft `mtd fixboss` aus der noch laufenden ALTEN Firmware auf. Eine Herstellerfirmware kennt dieses Kommando nicht. Seit K2 wird die Verfügbarkeit VOR dem Schreiben geprüft (`check_fixboss`) und der Rückgabewert danach ausgewertet (`do_fixboss`), beides mit Abbruch und lauter Meldung auf stderr. Scheitert `mtd fixboss` nach dem Schreiben, meldet `do_fixboss` unter anderem `the bootmonitor may refuse the new image, recover via bootmonitor/TFTP flash` und endet mit `exit 1`. Was procd danach tut, ist NICHT verifiziert. Der Weg scheitert damit sichtbar statt still - lauffähig für den Erstflash aus Herstellerfirmware wird er dadurch nicht. | `port/patches/src_target_linux_lantiq_xrx200_base-files_lib_upgrade_platform.sh.diff:9-13` (Aufrufstelle), `:24-36` (`check_fixboss`), `:38-46` (Fallback-Kette, procd), `:47-55` (`do_fixboss`, Meldung `:49-51`) | Den ersten Flash über den Bootmonitor an der seriellen Konsole fahren, nicht über sysupgrade. |
| Flüchtiges Protokoll | Das Startskript wertet seit H1 den Rückgabewert von `mtd fixboss` aus: bei Fehlschlag gibt es 1 zurück, `uci_apply_defaults` lässt es dann liegen und wiederholt es beim nächsten Boot. Die Ausgabe landet in `/tmp/fixboss.log`, zusätzlich meldet `logger` Erfolg oder Fehlschlag ins Systemlog. Bei Erfolg unterscheidet es `unchanged (checksum ok)` (Header stimmte schon, etwa weil `platform.sh` im sysupgrade-Weg korrigiert hat) von `rewritten`. `/tmp/fixboss.log` enthält außerdem, sobald ein BOSS-Header erkannt ist, die Zeile `BOSS header found ! ...` mit den vorherigen Werten. Beides liegt im RAM. | `port/tree/target/linux/lantiq/base-files/etc/uci-defaults/09_fix_crc.sh:18-30` (Meldungen `:20`, `:25`, `:27`) | Nach dem ersten Boot sofort `logread` und `/tmp/fixboss.log` ansehen, solange das Gerät noch läuft. `/tmp` ist flüchtig - nach einem Neustart ist das Protokoll weg. |

Serielle Konsole bereitlegen (3,3 V TTL, 115200 8N1). Ohne sie gibt es keinen
Rückweg, wenn das Gerät nicht mehr startet.

Host-Test für `mtd fixboss`: `bash port/tests/boss_test.sh` aus dem Repo-Root,
nur auf Linux/WSL. Er baut `boss.c` mit den Stubs aus `port/tests/stubs/` in
einem `mktemp -d`-Verzeichnis, arbeitet auf einer Image-Datei statt auf
`/dev/mtd*` und schreibt nichts ins Repo. Voraussetzungen: `cc` oder `gcc`,
`mtd/mtd-user.h` (Debian/Ubuntu: `linux-libc-dev`), `python3` mit `zlib`,
`sha256sum`. Die Testfälle F1 bis F6 (nicht die Fehler aus Abschnitt 10)
prüfen: korrekter Header bleibt unberührt, `mkbossimg`-Header wird genau einmal
umgeschrieben, falsches Magic, `-o 0x10` und `-c 0x1FFCD` enden mit Exit 1 ohne
Erase, ein zweiter Lauf meldet `checksum ok`. Die Variable
`BOSS_TEST_ERASE_LOG` setzt das Skript selbst. Exit-Codes: 0 mit `6/6 OK`,
1 bei `FAIL ...` oder `FAIL build`, 2 mit `NICHT ausgefuehrt: <liste>` auf
stderr, wenn eine Voraussetzung fehlt (`port/tests/boss_test.sh:15-22`,
`:152-216`). NICHT verifiziert: Build und Fälle F1 bis F6 (belegt ist nur der
Abbruchpfad mit Exit 2 auf dem Windows-Host) sowie das Verhalten des
Bootmonitors, denn der Test läuft nicht am Gerät. `boss_test.sh` fällt unter
die `.gitignore`-Regel `*.sh` und wird nicht versioniert.

Zwei weitere Punkte aus dem Review, die kein Bauhindernis sind, aber vor dem
Flashen bekannt sein sollten:

- USB-Stromversorgung: Die in Kernel 6.6 entfallene Eigenschaft
  `enable-active-low` ist entfernt, die Schaltrichtung steht jetzt im GPIO-Flag
  selbst (`gpio = <&gpio 14 GPIO_ACTIVE_LOW>;`, `vr9_bintec_rs353.dts:143`,
  Vermerk in `:142`). Ob ACTIVE_LOW der realen Beschaltung entspricht, ist nur
  am Gerät messbar. Folge im schlechtesten Fall: USB-Anschluss bleibt tot oder
  ist dauerhaft bestromt. Kein Brick-Risiko.
- Partitionsgröße: Die Firmware-Partition im Device Tree ist 32000 KiB groß
  (`vr9_bintec_rs353.dts:67`), das Limit im Bauplan steht auf 31232 KiB
  (`port/apply.sh:153`). Die Herkunft des Werts ist dort dokumentiert
  (`port/apply.sh:147-152`): übernommen aus dem Fork `openwrt-RS353_1`, Branch
  `openwrt-22.03-old`, ohne RS353-spezifische Herleitung. Die reale Obergrenze
  des BOSS-Bootmonitors ist am Gerät zu verifizieren. Das Limit nicht
  eigenmächtig anheben.

---

## 10. Typische Fehler und ihre Behebung

### F1 - `Cannot connect to the Docker daemon`

Docker Desktop läuft nicht.

```bash
docker info
```

Erfolg: Ein langer Block mit `Server Version:`. Kommt stattdessen die
Fehlermeldung, Docker Desktop starten und warten, bis das Wal-Symbol ruhig ist.

### F2 - `No such container: owrt-build`

Der Container wurde entfernt oder nie angelegt.

```bash
docker ps -a --filter name=owrt-build
```

Erfolg: Der Container ist gelistet und kann mit `docker start owrt-build`
gestartet werden. Ist die Liste leer, mit dem `docker run` aus Schritt 3 neu
anlegen; das Volume `openwrt-rs353-src` und damit der Quellbaum bleiben dabei
erhalten.

### F3 - `You are building with the root user`

Das `-u build` wurde vergessen. Alle Befehle im Container brauchen es.

```bash
docker exec -u build owrt-build bash -lc "id -un"
```

Erfolg: Ausgabe `build`.

### F4 - `apply.sh` bricht mit `FAIL <name>` ab

Ein Patch passt nicht mehr auf den Quellbaum, meist weil der Baum bereits halb
bearbeitet ist oder sich der OpenWrt-Zweig bewegt hat.

Zustand sichtbar machen:

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && git status --porcelain"
```

Erfolg der Diagnose: Die Liste zeigt, welche Dateien bereits angefasst wurden.

Sauberer Neuanfang des Quellbaums - verwirft alle lokalen Änderungen, auch die
des Port-Kits, aber nicht den Build-Fortschritt:

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && git checkout -- . && git clean -fd"
```

Erfolg: `git status --porcelain` gibt danach nichts mehr aus. Anschließend
Schritt 5 wiederholen.

### F5 - `already applied` obwohl nichts angewandt wurde

`apply.sh` erkennt einen bereits angewandten Patch daran, dass es die erste
eingefügte Zeile im Zielfile wiederfindet (`port/apply.sh:39-41`). Kommt diese
Zeichenfolge aus anderem Grund vor, wird der Patch stillschweigend
übersprungen, und der Fehler fällt erst beim Bauen oder gar nicht auf.

Gegenprobe - diese fünf Marken müssen nach einem vollständigen Apply
vorhanden sein:

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && grep -c CMD_FIXBOSS package/system/mtd/src/mtd.c; grep -c MTD_SPLIT_BINTEC_FW target/linux/generic/files/drivers/mtd/mtdsplit/Kconfig; grep -c 'obj.lantiq = boss.o' package/system/mtd/src/Makefile; grep -c 'Build/rs353-cev' target/linux/lantiq/image/Makefile; grep -c 'bintec,rs353' target/linux/lantiq/xrx200/base-files/etc/board.d/02_network"
```

Erfolg: Fünf Zahlen, jede größer als 0. Steht irgendwo `0`, fehlt dieser
Teil - dann F4 (sauberer Neuanfang) und Schritt 5 erneut.

### F6 - Build endet mit `RS353_BUILD_FAIL`, Ursache unklar

Erst die echte Fehlermeldung holen, nicht raten.

```bash
docker exec -u build owrt-build bash -lc "grep -n -iE 'error|Error [0-9]+' /build/rs353-build.log | tail -20"
```

Erfolg: Die Trefferliste nennt die abbrechende Datei. Danach mit 7.5 seriell
nachfahren.

### F7 - Objektdateien mit Länge 0 nach einem harten Abbruch

Wurde ein Build mit `kill -9` oder durch Abschalten des Containers beendet,
können halb geschriebene Objektdateien liegen bleiben. Der nächste Build
scheitert dann an scheinbar zufälliger Stelle - genau das ist in diesem Projekt
in `toolchain/gcc/initial` passiert.

Aufspüren:

```bash
docker exec -u build owrt-build bash -lc "find /build/openwrt/build_dir -name '*.o' -size 0 | head -20"
```

Erfolg: Keine Ausgabe. Kommen Pfade, das betroffene Paket zurücksetzen -
Beispiel für den Compiler selbst:

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && make toolchain/gcc/initial/clean"
```

Erfolg: Der Befehl endet ohne Fehler; die 0-Byte-Suche oben liefert danach
nichts mehr.

Merksatz: Builds nie mit `kill -9` beenden. Abschnitt 11 zeigt den sauberen Weg.

### F8 - `SIZE_TOO_BIG` in Schritt 8.1

Das Image überschreitet 31232 KiB. Ursache sind fast immer zusätzlich
ausgewählte Pakete.

```bash
docker exec -u build owrt-build bash -lc "ls -lS /build/openwrt/bin/targets/lantiq/xrx200/packages | head -20"
```

Erfolg der Diagnose: Die größten Pakete stehen oben. Auswahl über
`make menuconfig` reduzieren, danach Schritt 7 wiederholen. Das Limit selbst
nicht anheben - Begründung in Abschnitt 9.

### F9 - `.config` ist nach einem Fehlversuch durcheinander

Schritt 6.1 löscht Zeilen aus der `.config`. Geht dabei etwas schief, hilft die
dort angelegte Sicherung:

```bash
docker exec -u build owrt-build bash -lc "cd /build/openwrt && cp .config.bak .config && make defconfig"
```

Erfolg: `grep CONFIG_TARGET_PROFILE .config` zeigt wieder einen Wert. Existiert
keine `.config.bak`, die `.config` löschen und Schritt 6.1 komplett neu fahren.

### F10 - Änderung am Port-Kit wirkt nicht

Klassiker. Der Container arbeitet mit einer Kopie, nicht mit dem Windows-Ordner.

```bash
docker exec -u build owrt-build bash -lc "md5sum /build/port/apply.sh"
```

Erfolg: Der Hash entspricht dem Host-Stand aus 5.2. Weicht er ab, Schritt 5.1
wiederholen - und daran denken, dass danach auch 5.5 noch einmal nötig ist.

### F11 - `phase4.sh` meldet `PHASE4_OK`, obwohl nichts gebaut wurde

`port/phase4.sh` führt die Schritte 5 bis 8 in einem Rutsch aus. Die früher
hier genannten Schwächen sind behoben:

- `phase4.sh:36` schreibt `make` ohne Pipe in das Log und setzt den Endmarker
  `RS353_BUILD_OK` / `RS353_BUILD_FAIL` selbst, `phase4.sh:38` prüft ihn. Der
  Exit-Status geht nicht mehr in einer Pipe verloren.
- `JOBS` (Vorgabe 4) und `BUILDLOG` (Vorgabe `/build/rs353-build.log`) sind
  optionale Umgebungsvariablen (`phase4.sh:29-30`, `:36`).
- `phase4.sh:17-18` legt eine fehlende `.config` an (`touch`) und sichert sie
  vor dem `sed` als `.config.bak`. `phase4.sh:20` hängt danach die drei Zeilen
  `CONFIG_TARGET_lantiq=y`, `CONFIG_TARGET_lantiq_xrx200=y` und
  `CONFIG_TARGET_lantiq_xrx200_DEVICE_bintec_rs353=y` an. Das Profil lässt sich
  damit auch in einem frischen Baum ohne `.config` setzen. Rückweg:
  `cp .config.bak .config`.
- `phase4.sh:33-35` setzt die Zeitmarke `/tmp/rs353-build.stamp`,
  `phase4.sh:41-43` sucht nur Images, die jünger sind als diese Marke, und
  bricht ab, wenn keines gefunden wurde. Ein altes Artefakt besteht die
  Größenprüfung nicht mehr.

Maßgeblich für den Build-Erfolg bleibt trotzdem die Marke aus 7.4 im Log.
Wer sicher gehen will, löscht vor dem Lauf die alten Artefakte:

```bash
docker exec -u build owrt-build bash -lc "rm -f /build/openwrt/bin/targets/lantiq/xrx200/*bintec*"
```

Erfolg: Keine Ausgabe; die Image-Suche aus Schritt 8 liefert danach nichts mehr,
bis neu gebaut wurde. `PHASE4_OK` wird nur erreicht, wenn
`grep -q "^RS353_BUILD_OK$"` in `phase4.sh:38` zugeschlagen hat und ein frisches
Image gefunden wurde; die Marke aus 7.4 im Log (`BUILDLOG`, Vorgabe
`/build/rs353-build.log`) bleibt der Beleg.

### F12 - `sh: bad substitution` oder Abbruch direkt beim Start von apply.sh

`apply.sh` ist ein Bash-Skript. Wird es mit `sh` gestartet, scheitern
`set -o pipefail` und andere Bash-Konstrukte.

```bash
docker exec -u build owrt-build bash -lc "head -1 /build/port/apply.sh"
```

Erfolg: Ausgabe `#!/bin/bash`. Aufruf immer mit `bash /build/port/apply.sh ...`
wie in 5.4 und 5.5.

---

## 11. Wiederaufnahme nach Abbruch

OpenWrt-Builds sind fortsetzbar. Fertige Teile werden nicht neu gebaut.

### 11.1 Sauber abbrechen

Nie `kill -9`, sonst F7. `SIGTERM` gibt `make` die Gelegenheit, angefangene
Zieldateien selbst zu entfernen.

```bash
docker exec -u build owrt-build bash -lc "pkill -TERM -f 'make -j' ; sleep 3 ; pgrep -c -f 'make -j' || echo NO_MAKE_RUNNING"
```

Erfolg: Ausgabe `NO_MAKE_RUNNING` oder die Zahl `0`.

### 11.2 Zustand prüfen

```bash
docker exec -u build owrt-build bash -lc "find /build/openwrt/build_dir /build/openwrt/staging_dir -name '*.o' -size 0 2>/dev/null | grep -v cmake | head"
```

Erfolg: Keine Ausgabe. Kommen Treffer, das betroffene Paket nach F7 säubern.
Treffer unterhalb von `cmake`-Testverzeichnissen sind harmlos und werden hier
bewusst ausgefiltert.

### 11.3 Fortsetzen

```bash
docker exec -u build -d owrt-build bash -lc "cd /build/openwrt && { make -j4 && echo RS353_BUILD_OK || echo RS353_BUILD_FAIL; } >> /build/rs353-build.log 2>&1"
```

Erfolg: Der Befehl kehrt sofort zurück; `tail -5 /build/rs353-build.log` zeigt
nach kurzer Zeit wieder laufende `make`-Zeilen. Bereits fertige Pakete werden
übersprungen, der Build setzt an der Abbruchstelle an.

### 11.4 Nach einem Neustart des Rechners

Der Container ist gestoppt, Volume und Quellbaum sind unversehrt.

```bash
docker start owrt-build
```

Erfolg: Ausgabe `owrt-build`. Danach direkt mit 11.3 fortsetzen - die Schritte 2
bis 6 entfallen, solange am Port-Kit nichts geändert wurde.

### 11.5 Alles verwerfen und neu anfangen

Nur im Notfall. Löscht den kompletten Quellbaum samt Build-Fortschritt; der
nächste Durchlauf beginnt wieder bei Stunde null.

```bash
docker rm -f owrt-build; docker volume rm openwrt-rs353-src
```

Erfolg: Beide Befehle geben den jeweiligen Namen aus. Danach bei Schritt 3
wieder einsteigen.

---

## 12. Kurzreferenz

Der komplette Weg in der richtigen Reihenfolge, wenn alles bereits einmal lief:

| Schritt | Befehl (verkürzt) | Erfolgsmarke |
|---|---|---|
| 3 | `docker start owrt-build` | `owrt-build` |
| 5.1 | `docker cp <PFAD>\OpenWRT_Update\port owrt-build:/build/port` | keine Fehlermeldung |
| 5.2 | `md5sum /build/port/apply.sh` | Hash gleich Host |
| 5.3 | `chmod 755 /build/port/*.sh` | keine Ausgabe |
| 5.5 | `bash /build/port/apply.sh /build/openwrt` | `PORT_APPLY_OK` |
| 6.2 | `grep CONFIG_TARGET_PROFILE .config` | `"DEVICE_bintec_rs353"` |
| 7.2 | `make -j4` im Hintergrund, Log `/build/rs353-build.log` | - |
| 7.4 | `grep RS353_BUILD_ /build/rs353-build.log` | `RS353_BUILD_OK` |
| 8.1 | Größenprüfung gegen 31232k | `SIZE_OK` |
| 8.3 | `docker cp ... <PFAD>\OpenWRT_Update\out` | Datei liegt auf dem Host |
| 9 | Header und Flash-Weg prüfen | serielle Konsole bereit |

---

## 13. Linux-Host ohne Docker

Auf einem Linux-Rechner entfällt der einzige Grund für den Container
(Abschnitt 0). Der Build läuft direkt auf dem Host. Der Container-Inhalt
besteht nur aus Distro-Paketen und einem Nicht-root-Benutzer, siehe
`docker/Dockerfile`.

### 13.1 Ein Kommando

Im Projektordner:

```bash
bash build_rs353_linux.sh
```

Erfolg: Das Skript endet mit dem Block `FERTIG.` und nennt den Pfad des Images
unter `out/`. Fehlschlag: Es endet mit `FEHLER (<Schritt>)` und nennt das
Protokoll und den passenden Abschnitt dieser Anleitung.

Optionen:

| Option | Wirkung | Vorgabe |
|---|---|---|
| `--workdir PFAD` | Arbeitsordner für Quellbaum und Logs | `$HOME/openwrt-rs353-build` |
| `--jobs N` | Parallele Compiler-Prozesse, ganze Zahl ab 1 | `4` |
| `--skip-deps` | Paketinstallation überspringen | aus |
| `-h`, `--help` | Hilfe | - |

### 13.2 Was das Skript tut

Zehn Schritte, jeder mit eigener Erfolgsprüfung. Die Zuordnung zu den
Docker-Abschnitten dieser Anleitung:

| Schritt | Inhalt | entspricht |
|---|---|---|
| 1 | Nicht-root, Projektordner vollständig | F3, Abschnitt 1 |
| 2 | Pakete per `apt-get` installieren | `docker/Dockerfile` |
| 3 | Groß-/Kleinschreibung und 40 GB Platz prüfen | Abschnitt 0 |
| 4 | `git clone --branch openwrt-24.10` | 4.1, 4.2 |
| 5 | `feeds update -a` und `install -a` | 4.3 |
| 6 | `bash port/apply.sh` mit Log, danach fünf Prüfmarken | 5.5, F5 |
| 7 | Profil setzen, `.config.bak` sichern | 6.1, 6.2, F9 |
| 8 | `make -j<N>` in Datei, Endmarker statt Pipe | 7.2, 7.4 |
| 9 | Image jünger als Startmarke, Größe gegen 31232k, sha256 | 8.1, 8.2, F11 |
| 10 | Kopie nach `out/`, Warnung vor dem Flashen | 8.3, Abschnitt 9 |

Protokolle und Prüfungen im Einzelnen:

- `--jobs` muss eine ganze Zahl ab 1 sein, sonst bricht das Skript vor
  Schritt 1 ab (`build_rs353_linux.sh:63-64`).
- `$WORKDIR` ist der Arbeitsordner aus `--workdir`.
- Schritt 6 schreibt die Ausgabe von `apply.sh` nach `$WORKDIR/apply.log` und
  zeigt davon die letzten 30 Zeilen. Scheitert `apply.sh`, nennt die
  Fehlermeldung den Pfad dieses Logs (`build_rs353_linux.sh:187-193`).
- Schritt 8 schreibt nach `$WORKDIR/rs353-build.log`. Ein Log aus einem
  früheren Lauf wird vorher zu `rs353-build.log.prev` umbenannt, es bleibt
  also genau ein Vorgänger erhalten (`build_rs353_linux.sh:229-230`).
- Schritt 9 prüft per `sha256sum -c` nur die Zeile des RS353-Images aus
  `sha256sums`. Fehlt `sha256sums`, erscheint ein Hinweis und der Lauf geht
  weiter (unkritisch). Fehlt die Zeile des Images oder weicht die Prüfsumme
  ab, bricht das Skript ab (`build_rs353_linux.sh:287-302`).

Bewusste Festlegungen: Vorgabe `-j4` statt `nproc`, weil höhere Parallelität
in diesem Projekt bereits zu Speichermangel geführt hat (F7). `make` schreibt ohne Pipe in
eine Datei, sonst geht der Exit-Status verloren (7.4). Das gefundene Image muss
jünger sein als eine vor dem Build gesetzte Marke, sonst wird ein Altbestand
als Erfolg gemeldet (F11).

### 13.3 Grenzen

- Nur Debian und Ubuntu installieren Pakete selbsttätig. Andere Distributionen:
  Das Skript nennt die Paketliste und bricht ab, danach `--skip-deps`.
- Der Arbeitsordner muss im Linux-Dateisystem liegen. Eingebundene
  Windows-Laufwerke (NTFS, exFAT) fallen im Test in Schritt 3 durch.
- `port/apply.sh`, `port/phase4.sh` und `port/tree/.../09_fix_crc.sh` sind in
  `.gitignore` von der `*.sh`-Regel ausgenommen und liegen im Repo. Ein reiner
  GitHub-Klon kann bauen.
- Zeilenenden: `.gitattributes` setzt `* text=auto eol=lf`. Wer älter geklonte
  Kopien mit CRLF herumliegen hat, klont neu. Ein Skript mit CRLF bricht auf dem
  Linux-Host mit `bad interpreter` ab.
- Abschnitt 9 gilt unverändert. Das Skript erzeugt ein Image, es sagt nichts
  darüber aus, ob dieses Image auf dem Gerät startet.

---

## 14. WSL2 auf dem Windows-Host

WSL2 ist eine vollwertige Linux-VM mit einem ext4-Dateisystem in einer VHDX.
Groß- und Kleinschreibung werden dort unterschieden, damit fällt der einzige
Grund für Docker Desktop weg (Abschnitt 0). Gebaut wird mit dem Skript aus
Abschnitt 13, unverändert.

Voraussetzungen auf dem Windows-Host:

| Ding | Mindestanforderung | Prüfbefehl |
|---|---|---|
| Virtualisierung | im BIOS aktiv | `systeminfo` (Hyper-V-Anforderungen) |
| WSL | Version 2 | `wsl --status` |
| Freier Plattenplatz | 40 GB auf dem Laufwerk der VHDX (meist C:) | `Get-PSDrive C` |
| Arbeitsspeicher | 8 GB, besser 16 GB | Task-Manager |
| CPU-Kerne | 4 oder mehr | Task-Manager |

### 14.1 Distribution einrichten

Erst prüfen, was vorhanden ist:

```powershell
wsl --status
wsl -l -v
```

Erfolg: `Standardversion: 2` und in der Liste eine Distribution wie `Ubuntu`.
Steht dort nur `docker-desktop`, ist das die interne Utility-VM von Docker
Desktop. Sie hat keinen dauerhaften Paketmanager und wird bei Docker-Updates
ersetzt. Darin wird nicht gebaut.

Distribution nachinstallieren:

```powershell
wsl --install -d Ubuntu-24.04
```

Erfolg: Nach dem Neustart der Shell fragt Ubuntu einmalig nach Benutzername und
Passwort. Dieser Benutzer ist kein root - genau so muss es sein. Der Build
bricht als root ab (F3), und `build_rs353_linux.sh` prüft das in Schritt 1.

Danach die Distribution betreten:

```powershell
wsl -d Ubuntu-24.04
```

Erfolg: Der Prompt zeigt `<benutzer>@<rechner>:~$`, und `id -u` liefert eine
Zahl ungleich 0.

### 14.2 Bauen

Innerhalb von WSL, im Linux-Dateisystem:

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/Nope-im-not-pro/Bintec-RS353-OpenWrt-24.10 ~/rs353
cd ~/rs353
bash build_rs353_linux.sh --jobs 6
```

Erfolg und Fehlschlag wie in 13.1: Endblock `FERTIG.` mit Pfad unter `out/`,
sonst `FEHLER (<Schritt>)`.

Der Klon ins Linux-Dateisystem ist nicht optional. Er stellt zugleich sicher,
dass `.gitattributes` greift und die Skripte LF haben (13.3).

`--jobs` richtet sich nach Kernen und Arbeitsspeicher. Acht Kerne vertragen
`--jobs 6`. Bricht der Build mit Speichermangel oder Objektdateien der Länge 0
ab, zurück auf die Vorgabe 4 (F7).

### 14.3 Image auf den Windows-Host holen

Aus WSL heraus:

```bash
cp out/*.cev /mnt/c/<PFAD>/OpenWRT_Update/out/
```

Oder aus Windows heraus über den Netzwerkpfad:

```text
\\wsl$\Ubuntu-24.04\home\<benutzer>\rs353\out\
```

Erfolg: Die `.cev`-Datei liegt auf dem Windows-Laufwerk und hat dieselbe Größe
wie in WSL. Prüfsumme gegenlesen wie in 8.2.

### 14.4 Grenzen

- Der Arbeitsordner darf nicht unter `/mnt/c` oder einem anderen eingebundenen
  Windows-Laufwerk liegen. Das ist NTFS über DrvFs: nicht case-sensitiv und bei
  den vielen kleinen Dateien eines OpenWrt-Baums um ein Vielfaches langsamer.
  Der Test in Schritt 3 des Skripts fängt das ab. Die Vorgabe
  `$HOME/openwrt-rs353-build` ist bereits richtig.
- Die VHDX wächst mit dem Build und schrumpft nicht von selbst wieder. Nach
  einem Abbruch oder Neuanfang bleibt der Platz belegt, bis die Datei von Hand
  verkleinert wird.
- Reicht der Arbeitsspeicher auf dem Windows-Host während des Builds nicht,
  begrenzt `%UserProfile%\.wslconfig` die VM:

  ```ini
  [wsl2]
  memory=16GB
  swap=8GB
  ```

  Wirkt erst nach `wsl --shutdown`.
- `wsl --shutdown` beendet die VM hart. Während eines laufenden Builds ist das
  ein harter Abbruch, Nacharbeit nach Abschnitt 11.
- Abschnitt 9 gilt unverändert. WSL beseitigt ein Umgebungshindernis, es sagt
  nichts darüber aus, ob das erzeugte Image auf dem Gerät startet.
