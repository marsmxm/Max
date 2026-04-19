/* Compatibility shim: cuetools -> libcue */
#include <libcue/libcue.h>

/* cd_get_catalog was removed in libcue; emulate via cdtext UPC/ISRC */
static inline const char *cd_get_catalog(const Cd *cd) {
    Cdtext *cdtext = cd_get_cdtext(cd);
    if (cdtext)
        return cdtext_get(PTI_UPC_ISRC, cdtext);
    return NULL;
}
