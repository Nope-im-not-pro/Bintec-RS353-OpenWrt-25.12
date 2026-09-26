/*
 * Stub fuer port/tests/boss_test.sh: Auszug aus
 * https://github.com/openwrt/openwrt/blob/openwrt-25.12/package/system/mtd/src/mtd.h
 * (Branch openwrt-25.12; bis 24.10, Commit b3f41971393f, ohne write_mode).
 * Nur die Deklarationen, die boss.c nutzt, typgleich zu Upstream, plus
 * mtd_fixboss() wie in port/patches/src_package_system_mtd_src_mtd.h.diff.
 * <stddef.h> fuer size_t ist Zusatz des Stubs (Upstream setzt es voraus);
 * <stdbool.h> fuer bool write_mode.
 */
#ifndef __mtd_h
#define __mtd_h

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

extern int quiet;
extern int mtdsize;
extern int erasesize;

extern int mtd_check_open(const char *mtd, bool write_mode);
extern int mtd_erase_block(int fd, int offset);

extern int mtd_fixboss(const char *mtd, size_t offset, size_t data_size) __attribute__ ((weak));
#endif /* __mtd_h */
