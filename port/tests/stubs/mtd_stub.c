/*
 * Stub-mtd-Schicht fuer port/tests/boss_test.sh. Ersetzt die Teile von
 * mtd.c (openwrt-24.10, package/system/mtd/src/mtd.c), die boss.c
 * braucht, durch eine Image-Datei statt /dev/mtd*:
 * - mtd_check_open(): Datei O_RDWR oeffnen, mtdsize = Dateigroesse,
 *   erasesize = 0x20000 (RS353-NOR).
 * - mtd_erase_block(): jeden Aufruf als eine Zeile an die Datei aus
 *   BOSS_TEST_ERASE_LOG anhaengen (falls gesetzt), dann den Block mit
 *   0xFF fuellen. Nicht ausgerichtete oder zu grosse Bereiche liefern
 *   wie MEMERASE einen Fehler (EINVAL).
 */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#include "mtd.h"

int quiet;
int mtdsize = 0;
int erasesize = 0;

int mtd_check_open(const char *mtd)
{
	struct stat st;
	int fd;

	fd = open(mtd, O_RDWR);
	if (fd < 0)
		return -1;
	if (fstat(fd, &st)) {
		close(fd);
		return -1;
	}
	mtdsize = st.st_size;
	erasesize = 0x20000;
	return fd;
}

int mtd_erase_block(int fd, int offset)
{
	const char *log = getenv("BOSS_TEST_ERASE_LOG");
	FILE *f;
	char *ff;
	ssize_t res;

	if (log) {
		f = fopen(log, "a");
		if (!f)
			return -1;
		fprintf(f, "mtd_erase_block offset=0x%x length=0x%x\n",
			(unsigned int)offset, (unsigned int)erasesize);
		fclose(f);
	}

	if (offset < 0 || offset % erasesize || offset + erasesize > mtdsize) {
		errno = EINVAL;
		return -1;
	}

	ff = malloc(erasesize);
	if (!ff)
		return -1;
	memset(ff, 0xff, erasesize);
	res = pwrite(fd, ff, erasesize, offset);
	free(ff);
	return res == erasesize ? 0 : -1;
}
