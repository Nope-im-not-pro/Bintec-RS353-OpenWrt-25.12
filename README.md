# OpenWRT_Update

Arbeitsverzeichnis für die Aktualisierung des OpenWrt-Supports des Routers
**Bintec RS353** (Lantiq VR9, Subtarget xrx200).

## Zweck
Grundlage sind zwei fremde Forks des RS353-Projekts. Sie liegen nur lokal als
Referenz, nicht in diesem Repo; Adressen und Commits stehen unter
[Herkunft](#herkunft). Der Gerätesupport liegt ausgecheckt nur in
`openwrt-RS353_1` (Stand OpenWrt 22.03, 2023); in `openwrt-RS353_2` ist
`master` ohne RS353-Dateien ausgecheckt, der Support steckt dort in den
Branches `openwrt-22.03` und `old_2021`.

Daraus ist ein Port-Kit gegen **OpenWrt 24.10** entstanden (`port/`). Es wird
auf einen frischen 24.10-Quellbaum angewandt und erzeugt das flashbare Image
`*-bintec_rs353-boss-image.cev`.

Bauanleitung: `BUILD_HOWTO.md` (mit Inhaltsverzeichnis).
Hintergrund und Schritte: `PLAN.md`, Befunde des Reviews: `REVIEW_BEFUNDE.md`
(beide lokal, nicht im Repo).

## Struktur
| Pfad | Inhalt |
|---|---|
| `port/` | Port-Kit 24.10: `apply.sh`, `phase4.sh`, `patches/`, `tree/` |
| `port/tests/` | Host-Test für `mtd fixboss`: `boss_test.sh` und `stubs/`, siehe [Git-Stand](#git-stand) und `BUILD_HOWTO.md` Abschnitt 9 |
| `docker/` | `Dockerfile` des Buildhosts, nur für den Windows-Docker-Weg |
| `build_rs353_linux.sh` | Ein-Kommando-Build auf einem Linux-Host, ohne Docker |
| `BUILD_HOWTO.md` | Schritt-für-Schritt-Anleitung, Docker-Weg und Linux-Weg |
| `openwrt-RS353_1/` | Fork Xernium, Referenz (lokal, nicht im Git, siehe Herkunft) |
| `openwrt-RS353_2/` | Fork armSeb (Original), Referenz (lokal, nicht im Git, siehe Herkunft) |
| `out/` | Ergebnis-Images (wird beim Bauen angelegt) |

## Setup
Der Build braucht ein **case-sensitives Dateisystem**. Das ist der einzige Grund
für den Container in `docker/`.

- **Linux-Host:** kein Docker nötig. Pakete installiert das Build-Skript selbst.
- **Windows-Host, WSL2:** empfohlen. WSL2 bringt ein case-sensitives ext4 mit,
  das Linux-Skript läuft dort unverändert. `BUILD_HOWTO.md` Abschnitt 14.
- **Windows-Host, Docker:** Docker Desktop im Linux-Container-Modus. Der
  Quellbaum liegt im Named Volume, nicht im Windows-Bind-Mount.

## Aufruf

Linux, ein Kommando:

```bash
bash build_rs353_linux.sh
```

Optionen: `--workdir PFAD`, `--jobs N` (Vorgabe 4), `--skip-deps`, `--help`.
Ergebnis liegt danach in `out/`. Details: `BUILD_HOWTO.md` Abschnitt 13.

Windows mit WSL2: `BUILD_HOWTO.md` Abschnitt 14 (dasselbe Skript in einer
Ubuntu-Distribution).

Windows mit Docker: `BUILD_HOWTO.md` Abschnitte 2 bis 8.

Von Hand: `<baum>` ist ein frischer Klon des Branches `openwrt-24.10` aus
`https://git.openwrt.org/openwrt/openwrt.git` auf einem case-sensitiven
Dateisystem, dieselbe Quelle wie im Build-Skript
(`build_rs353_linux.sh:29-30`). Die Reihenfolge folgt dem Skript: klonen,
Feeds, `apply.sh`, bauen (`build_rs353_linux.sh:161`, `:170-171`, `:189`).
Klon und `apply.sh` laufen vom Projekt-Root aus, die übrigen Schritte im Baum:

```bash
git clone --branch openwrt-24.10 https://git.openwrt.org/openwrt/openwrt.git <baum>
( cd <baum> && ./scripts/feeds update -a && ./scripts/feeds install -a )
bash port/apply.sh <baum>
cd <baum>
make menuconfig   # Target: Lantiq / XRX200 / Bintec RS353
make -j4
```

## Vor dem Flashen
`BUILD_HOWTO.md` Abschnitt 9 ist Pflichtlektüre. Der erste Flash läuft über
den Bootmonitor an der seriellen Konsole (3,3 V TTL, 115200 8N1), nicht über
`sysupgrade`. Ohne serielle Konsole gibt es keinen Rückweg.

## Herkunft

Der Port in `port/` ist aus zwei fremden Forks abgeleitet. Diese Forks sind
nicht Teil dieses Repos und werden zum Bauen nicht gebraucht:
`build_rs353_linux.sh` klont einen frischen OpenWrt-24.10-Baum und wendet
`port/` darauf an.

| Ordner lokal | Repo | Branch | Commit | Datum | Rolle |
|---|---|---|---|---|---|
| `openwrt-RS353_1/` | https://github.com/Xernium/openwrt-RS353 | `openwrt-22.03-old` | `d3da2ba5bc2f972e51f8b87c3192768670477e50` | 2023-02-15 | Basis des Ports, enthält den RS353-Support |
| `openwrt-RS353_2/` | https://github.com/armSeb/openwrt-RS353 | `master` | `118cbae7820c4bc8d403f7f7ca7c914b2b467bc6` | 2022-10-26 | Original-Fork, Quervergleich |

Wer die Bäume ansehen will, klont sie selbst:

```bash
git clone https://github.com/Xernium/openwrt-RS353 openwrt-RS353_1
git -C openwrt-RS353_1 checkout d3da2ba5bc
git clone https://github.com/armSeb/openwrt-RS353 openwrt-RS353_2
git -C openwrt-RS353_2 checkout 118cbae782
```

Auf `master` von `openwrt-RS353_2` liegen keine RS353-Dateien. Der Inhalt
steckt in den Branches `openwrt-22.03` und `old_2021`; der Branch
`openwrt-24.10` enthält keine RS353-Dateien.

## Git-Stand

Die `.gitignore`-Regel `*.sh` hält Skripte grundsätzlich aus dem Repo. Die
vier Skripte, die zum Bauen gebraucht werden, sind einzeln ausgenommen:

| Datei | Zweck |
|---|---|
| `build_rs353_linux.sh` | Einstieg auf dem Linux-Host |
| `port/apply.sh` | Patchset auf den Quellbaum anwenden |
| `port/phase4.sh` | Profil setzen, bauen, statische Checks |
| `port/tree/.../uci-defaults/09_fix_crc.sh` | läuft auf dem Gerät, CRC-Fix |

Ein reiner GitHub-Klon kann damit bauen.

`port/tests/boss_test.sh` fällt unter die Regel `*.sh` (`.gitignore:3`) und ist
nicht ausgenommen, also nicht versioniert. Zum Bauen wird es nicht gebraucht.

Die beiden Fork-Ordner standen bis 2026-09-15 als Gitlink (Modus `160000`) im
Index, ohne `.gitmodules`. Auf GitHub ergab das einen Ordner, dessen Klick ins
Leere führt. Die Einträge sind entfernt, die Ordner bleiben lokal liegen und
sind in `.gitignore` gesperrt. Herkunftsnachweis ist der Commit oben statt eines
Submodule-Pins.

`.gitattributes` erzwingt LF im Arbeitsbaum (`* text=auto eol=lf`). Ohne das
würde ein Windows-Klon mit `core.autocrlf=true` CRLF in die Skripte schreiben;
auf dem Linux-Build-Host bricht das mit `bad interpreter` ab, und `git apply`
verwirft die Patches unter `port/patches/`.
