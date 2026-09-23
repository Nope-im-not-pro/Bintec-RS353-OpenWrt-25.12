#!/bin/sh
#
# 09_fix_crc.sh - BOSS-Header der firmware-Partition beim ersten Boot
# pruefen und bei Bedarf korrigieren (Bintec RS353).
#
# Fallback-Pfad nach dem Erstflash: "mtd fixboss firmware" prueft zuerst
# image_length und crc32 im BOSS-Header des ersten Erase-Blocks und
# schreibt den Block nur bei Abweichung neu. Im sysupgrade-Weg hat
# platform.sh (check_fixboss / do_fixboss) bereits korrigiert; der Aufruf
# hier ist dann ein Lauf ohne Schreibzugriff. Schlaegt der Aufruf fehl,
# liefert das Skript 1; uci_apply_defaults laesst es dann liegen und
# wiederholt es beim naechsten Boot.
#

. /lib/functions.sh
. /lib/functions/lantiq.sh

do_fixboss() {
	if ! mtd fixboss firmware 1>/tmp/fixboss.log 2>&1; then
		logger -t fixboss "FAILED: mtd fixboss firmware, see /tmp/fixboss.log"
		return 1
	fi

	if grep -q 'checksum ok' /tmp/fixboss.log; then
		logger -t fixboss "OK: BOSS header of partition firmware unchanged (checksum ok)"
	else
		logger -t fixboss "OK: BOSS header of partition firmware rewritten"
	fi
	return 0
}

board=$(board_name)
case "$board" in
"bintec,rs353")
	do_fixboss
	;;
esac
