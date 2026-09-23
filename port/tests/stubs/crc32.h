/*
 * Stub fuer port/tests/boss_test.sh: unveraenderte Kopie von
 * https://github.com/openwrt/openwrt/blob/openwrt-24.10/package/system/mtd/src/crc32.h
 * (Branch openwrt-24.10, letzter Commit auf der Datei 4ebf19b48f).
 * crc32buf(): Poly 0xedb88320, Startwert 0xFFFFFFFF, OHNE
 * Endinvertierung - daher ~crc32buf() in boss.c.
 */

#ifndef CRC32_H
#define CRC32_H

#include <stdint.h>

extern const uint32_t crc32_table[256];

/* Return a 32-bit CRC of the contents of the buffer. */

static inline uint32_t
crc32(uint32_t val, const void *ss, int len)
{
	const unsigned char *s = ss;
	while (--len >= 0)
		val = crc32_table[(val ^ *s++) & 0xff] ^ (val >> 8);
	return val;
}

static inline unsigned int crc32buf(char *buf, size_t len)
{
	return crc32(0xFFFFFFFF, buf, len);
}



#endif
