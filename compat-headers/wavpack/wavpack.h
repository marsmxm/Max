/*
 * Compat shim: rename wavpack's ChunkHeader to avoid conflict
 * with CarbonCore/AIFF.h's ChunkHeader typedef.
 */
#ifndef COMPAT_WAVPACK_H
#define COMPAT_WAVPACK_H

#define ChunkHeader WavpackChunkHeader
#define ChunkHeaderFormat WavpackChunkHeaderFormat
#include_next <wavpack/wavpack.h>
#undef ChunkHeader
#undef ChunkHeaderFormat

#endif /* COMPAT_WAVPACK_H */
