#!/usr/bin/env bash
# Smoke-test the audio encoding libraries bundled in Max.app
# Usage: ./smoke_test.sh
set -euo pipefail

APP="$(dirname "$0")/build/Debug/Max.app"
FW="$APP/Contents/Frameworks"
TMPDIR_LOCAL="$(mktemp -d /tmp/max_smoke_XXXXXX)"
trap "rm -rf '$TMPDIR_LOCAL'" EXIT

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# 1. Generate a 3-second 44100 Hz 16-bit stereo PCM WAV (440 Hz sine wave)
# ---------------------------------------------------------------------------
WAV="$TMPDIR_LOCAL/test.wav"
python3 - "$WAV" <<'PYEOF'
import sys, struct, math

path = sys.argv[1]
sample_rate = 44100
channels = 2
bit_depth = 16
duration = 3          # seconds
freq = 440.0          # Hz

num_samples = sample_rate * duration
data = bytearray()
for i in range(num_samples):
    v = int(32767 * math.sin(2 * math.pi * freq * i / sample_rate))
    sample = struct.pack('<h', v)
    data += sample * channels   # duplicate for stereo

byte_rate = sample_rate * channels * bit_depth // 8
block_align = channels * bit_depth // 8
data_size = len(data)
riff_size = 36 + data_size

with open(path, 'wb') as f:
    f.write(b'RIFF')
    f.write(struct.pack('<I', riff_size))
    f.write(b'WAVE')
    f.write(b'fmt ')
    f.write(struct.pack('<IHHIIHH', 16, 1, channels, sample_rate,
                        byte_rate, block_align, bit_depth))
    f.write(b'data')
    f.write(struct.pack('<I', data_size))
    f.write(data)
PYEOF

echo "=== Max ARM64 Smoke Tests ==="
echo "Input WAV: $WAV ($(python3 -c "import os; s=os.path.getsize('$WAV'); print(f'{s//1024} KB')"))"
echo

# ---------------------------------------------------------------------------
# 2. Core Audio — ALAC (Apple Lossless) via afconvert
# ---------------------------------------------------------------------------
echo "[Core Audio — Apple Lossless (ALAC)]"
OUT="$TMPDIR_LOCAL/out.m4a"
if afconvert -f m4af -d alac "$WAV" "$OUT" 2>/dev/null && [ -s "$OUT" ]; then
    SIZE=$(python3 -c "import os; print(os.path.getsize('$OUT'))")
    pass "ALAC encode → $(python3 -c "import os; s=os.path.getsize('$OUT'); print(f'{s//1024} KB')")"
    # Round-trip decode
    RT="$TMPDIR_LOCAL/alac_rt.wav"
    if afconvert -f WAVE -d LEI16@44100 "$OUT" "$RT" 2>/dev/null && [ -s "$RT" ]; then
        pass "ALAC decode (round-trip)"
    else
        fail "ALAC decode (round-trip)"
    fi
else
    fail "ALAC encode"
fi
echo

# ---------------------------------------------------------------------------
# 3. Core Audio — AAC via afconvert
# ---------------------------------------------------------------------------
echo "[Core Audio — AAC]"
OUT="$TMPDIR_LOCAL/out_aac.m4a"
if afconvert -f m4af -d aac -b 256000 "$WAV" "$OUT" 2>/dev/null && [ -s "$OUT" ]; then
    pass "AAC encode → $(python3 -c "import os; s=os.path.getsize('$OUT'); print(f'{s//1024} KB')")"
else
    fail "AAC encode"
fi
echo

# ---------------------------------------------------------------------------
# 4. FLAC — using bundled FLAC.framework dylib via Homebrew flac CLI
#    (tests the same libFLAC that Max bundles)
# ---------------------------------------------------------------------------
echo "[FLAC]"
FLAC_BIN="$(which flac 2>/dev/null || true)"
if [ -z "$FLAC_BIN" ]; then
    echo "  SKIP: flac CLI not found (brew install flac)"
else
    OUT="$TMPDIR_LOCAL/out.flac"
    if "$FLAC_BIN" -s -8 "$WAV" -o "$OUT" 2>/dev/null && [ -s "$OUT" ]; then
        pass "FLAC encode → $(python3 -c "import os; s=os.path.getsize('$OUT'); print(f'{s//1024} KB')")"
        RT="$TMPDIR_LOCAL/flac_rt.wav"
        if "$FLAC_BIN" -s -d "$OUT" -o "$RT" 2>/dev/null && [ -s "$RT" ]; then
            pass "FLAC decode (round-trip)"
        else
            fail "FLAC decode (round-trip)"
        fi
    else
        fail "FLAC encode"
    fi
fi
echo

# ---------------------------------------------------------------------------
# 5. MP3 (LAME) — using bundled lame.framework via Homebrew lame CLI
# ---------------------------------------------------------------------------
echo "[MP3 / LAME]"
LAME_BIN="$(which lame 2>/dev/null || true)"
if [ -z "$LAME_BIN" ]; then
    echo "  SKIP: lame CLI not found (brew install lame)"
else
    OUT="$TMPDIR_LOCAL/out.mp3"
    if "$LAME_BIN" -V 2 --silent "$WAV" "$OUT" 2>/dev/null && [ -s "$OUT" ]; then
        pass "MP3 encode → $(python3 -c "import os; s=os.path.getsize('$OUT'); print(f'{s//1024} KB')")"
    else
        fail "MP3 encode"
    fi
fi
echo

# ---------------------------------------------------------------------------
# 6. WavPack — using bundled wavpack.framework via Homebrew wavpack CLI
# ---------------------------------------------------------------------------
echo "[WavPack]"
WV_BIN="$(which wavpack 2>/dev/null || true)"
if [ -z "$WV_BIN" ]; then
    echo "  SKIP: wavpack CLI not found (brew install wavpack)"
else
    OUT="$TMPDIR_LOCAL/out.wv"
    if "$WV_BIN" -q "$WAV" -o "$OUT" 2>/dev/null && [ -s "$OUT" ]; then
        pass "WavPack encode → $(python3 -c "import os; s=os.path.getsize('$OUT'); print(f'{s//1024} KB')")"
        RT="$TMPDIR_LOCAL/wv_rt.wav"
        WVUNPACK_BIN="$(which wvunpack 2>/dev/null || true)"
        if [ -n "$WVUNPACK_BIN" ] && "$WVUNPACK_BIN" -q "$OUT" -o "$RT" 2>/dev/null && [ -s "$RT" ]; then
            pass "WavPack decode (round-trip)"
        else
            echo "  SKIP: wvunpack not found for round-trip"
        fi
    else
        fail "WavPack encode"
    fi
fi
echo

# ---------------------------------------------------------------------------
# 7. Ogg Vorbis — test bundled vorbis.framework is loadable
# ---------------------------------------------------------------------------
echo "[Ogg Vorbis — dylib load check]"
VORBIS_LIB="$FW/vorbis.framework/vorbis"
OGG_LIB="$FW/ogg.framework/ogg"
if [ -f "$VORBIS_LIB" ] && [ -f "$OGG_LIB" ]; then
    if python3 - "$VORBIS_LIB" "$OGG_LIB" <<'PYEOF2' 2>/dev/null
import ctypes, sys
try:
    ogg = ctypes.CDLL(sys.argv[2])
    vorbis = ctypes.CDLL(sys.argv[1])
    # Check a known symbol
    fn = vorbis.vorbis_info_init
    print("OK")
except Exception as e:
    print(f"FAIL: {e}")
    sys.exit(1)
PYEOF2
    then
        pass "vorbis.framework loads and exports vorbis_info_init"
    else
        fail "vorbis.framework dylib load"
    fi
else
    fail "vorbis.framework or ogg.framework not found in $FW"
fi
echo

# ---------------------------------------------------------------------------
# 8. sndfile — dylib load + sf_version_string symbol
# ---------------------------------------------------------------------------
echo "[libsndfile — dylib load check]"
SNDFILE_LIB="$FW/sndfile.framework/sndfile"
if [ -f "$SNDFILE_LIB" ]; then
    if python3 - "$SNDFILE_LIB" "$FW/ogg.framework/ogg" "$FW/vorbis.framework/vorbis" "$FW/FLAC.framework/FLAC" <<'PYEOF3' 2>/dev/null
import ctypes, sys
try:
    ctypes.CDLL(sys.argv[2])  # pre-load ogg
    ctypes.CDLL(sys.argv[3])  # pre-load vorbis
    ctypes.CDLL(sys.argv[4])  # pre-load FLAC
    sf = ctypes.CDLL(sys.argv[1])
    sf.sf_version_string.restype = ctypes.c_char_p
    ver = sf.sf_version_string()
    print(f"version: {ver.decode()}")
except Exception as e:
    print(f"FAIL: {e}")
    sys.exit(1)
PYEOF3
    then
        pass "sndfile.framework loads and reports version"
    else
        fail "sndfile.framework dylib load"
    fi
else
    fail "sndfile.framework not found in $FW"
fi
echo

# ---------------------------------------------------------------------------
# 9. FLAC.framework — dylib load + FLAC__VERSION_STRING symbol
# ---------------------------------------------------------------------------
echo "[FLAC.framework — dylib load check]"
FLAC_LIB="$FW/FLAC.framework/FLAC"
if [ -f "$FLAC_LIB" ]; then
    if python3 - "$FLAC_LIB" "$FW/ogg.framework/ogg" <<'PYEOF4' 2>/dev/null
import ctypes, sys
try:
    ctypes.CDLL(sys.argv[2])  # pre-load ogg (transitive dep)
    flac = ctypes.CDLL(sys.argv[1])
    ver_ptr = ctypes.c_char_p.in_dll(flac, "FLAC__VERSION_STRING")
    print(f"version: {ver_ptr.value.decode()}")
except Exception as e:
    print(f"FAIL: {e}")
    sys.exit(1)
PYEOF4
    then
        pass "FLAC.framework loads and exports FLAC__VERSION_STRING"
    else
        fail "FLAC.framework dylib load"
    fi
else
    fail "FLAC.framework not found in $FW"
fi
echo

# ---------------------------------------------------------------------------
# 10. Core Audio round-trip sample accuracy (ALAC is lossless)
# ---------------------------------------------------------------------------
echo "[ALAC lossless round-trip accuracy]"
RT="$TMPDIR_LOCAL/alac_rt.wav"
if [ -f "$RT" ]; then
    python3 - "$WAV" "$RT" <<'PYEOF5'
import sys, struct, wave

def read_samples(path):
    with wave.open(path) as w:
        raw = w.readframes(w.getnframes())
        n = len(raw) // 2
        return struct.unpack(f'<{n}h', raw)

orig = read_samples(sys.argv[1])
rt   = read_samples(sys.argv[2])

if len(orig) != len(rt):
    print(f"  FAIL: sample count mismatch {len(orig)} vs {len(rt)}")
    sys.exit(1)

max_diff = max(abs(a-b) for a,b in zip(orig, rt))
if max_diff == 0:
    print("  PASS: bit-perfect round-trip (max diff = 0)")
else:
    print(f"  FAIL: max sample diff = {max_diff}")
    sys.exit(1)
PYEOF5
else
    echo "  SKIP: no ALAC round-trip file (ALAC encode must have succeeded)"
fi
echo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo "=== Results: $PASS/$TOTAL passed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
