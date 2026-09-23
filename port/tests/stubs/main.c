/*
 * Treiber fuer port/tests/boss_test.sh.
 * Aufruf: <bin> [-c datasize] [-o offset] <image>  (analog N2,
 * "mtd [-c datasize] [-o offset] fixboss <device>").
 * Optionen wie in mtd.c (openwrt-24.10): strtoul(optarg, 0, 0).
 * Exit-Code = Rueckgabewert von mtd_fixboss(); Fehler in boss.c enden
 * dort mit exit(1). Usage-Fehler: Exit 2, damit sie nicht als
 * erwarteter boss.c-Fehler durchgehen.
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "mtd.h"

static int usage(const char *prog)
{
	fprintf(stderr, "usage: %s [-c datasize] [-o offset] <image>\n", prog);
	return 2;
}

int main(int argc, char **argv)
{
	size_t offset = 0, data_size = 0;
	int ch;

	while ((ch = getopt(argc, argv, "c:o:")) != -1) {
		switch (ch) {
		case 'c':
			errno = 0;
			data_size = strtoul(optarg, 0, 0);
			if (errno)
				return usage(argv[0]);
			break;
		case 'o':
			errno = 0;
			offset = strtoul(optarg, 0, 0);
			if (errno)
				return usage(argv[0]);
			break;
		default:
			return usage(argv[0]);
		}
	}

	if (argc - optind != 1)
		return usage(argv[0]);

	return mtd_fixboss(argv[optind], offset, data_size);
}
