/* Compatibility shim: cuetools -> libcue */
#include <libcue/libcue.h>

/* cue_parse(FILE*) was renamed to cue_parse_file(FILE*) in libcue */
#define cue_parse cue_parse_file
