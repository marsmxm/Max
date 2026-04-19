#!/bin/bash
# Build ARM64 framework wrappers from Homebrew libraries for Max-Silicon
set -e

FRAMEWORKS_DIR="$(cd "$(dirname "$0")" && pwd)/Frameworks"
BREW_PREFIX="$(brew --prefix)"

rm -rf "$FRAMEWORKS_DIR"
mkdir -p "$FRAMEWORKS_DIR"

create_framework() {
    local FW_NAME="$1"      # Framework name (e.g., FLAC)
    local DYLIB_PATH="$2"   # Path to dylib
    local HEADER_DIR="$3"   # Directory containing headers (will be symlinked as Headers)
    
    echo "Creating $FW_NAME.framework..."
    
    local FW_DIR="$FRAMEWORKS_DIR/$FW_NAME.framework"
    local VERSIONS_DIR="$FW_DIR/Versions/A"
    
    mkdir -p "$VERSIONS_DIR/Headers"
    mkdir -p "$VERSIONS_DIR/Resources"
    
    # Copy dylib as the framework binary
    cp "$DYLIB_PATH" "$VERSIONS_DIR/$FW_NAME"
    
    # Fix install name to use framework path
    install_name_tool -id "@rpath/$FW_NAME.framework/Versions/A/$FW_NAME" "$VERSIONS_DIR/$FW_NAME" 2>/dev/null || true
    
    # Copy headers
    if [ -d "$HEADER_DIR" ]; then
        cp -R "$HEADER_DIR"/* "$VERSIONS_DIR/Headers/" 2>/dev/null || true
    fi
    
    # Create Info.plist
    cat > "$VERSIONS_DIR/Resources/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$FW_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>org.sbooth.$FW_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
</dict>
</plist>
EOF
    
    # Create Current version symlink
    ln -sf A "$FW_DIR/Versions/Current"
    
    # Create top-level symlinks
    ln -sf Versions/Current/$FW_NAME "$FW_DIR/$FW_NAME"
    ln -sf Versions/Current/Headers "$FW_DIR/Headers"
    ln -sf Versions/Current/Resources "$FW_DIR/Resources"
    
    echo "  -> $FW_DIR"
}

# Helper to fix inter-library dependencies
fix_deps() {
    local FW_NAME="$1"
    local BINARY="$FRAMEWORKS_DIR/$FW_NAME.framework/Versions/A/$FW_NAME"
    
    # Fix references to other Homebrew libs to point to our frameworks
    for dep in $(otool -L "$BINARY" | grep "$BREW_PREFIX" | awk '{print $1}'); do
        local dep_basename=$(basename "$dep")
        # Map dylib names to framework names
        local target_fw=""
        case "$dep_basename" in
            libFLAC*) target_fw="FLAC" ;;
            libmp3lame*) target_fw="lame" ;;
            libmad*) target_fw="mad" ;;
            libmp4v2*) target_fw="mp4v2" ;;
            libmpcdec*) target_fw="mpcdec" ;;
            libogg*) target_fw="ogg" ;;
            libsndfile*) target_fw="sndfile" ;;
            libspeex.1*|libspeex.dylib) target_fw="speex" ;;
            libtag.*|libtag_c.*) target_fw="taglib" ;;
            libvorbis.*|libvorbisenc.*|libvorbisfile.*) target_fw="vorbis" ;;
            libwavpack*) target_fw="wavpack" ;;
            libdiscid*) target_fw="discid" ;;
            libcdio_paranoia*|libcdio_cdda*|libcdio.*) target_fw="cdparanoia" ;;
        esac
        
        if [ -n "$target_fw" ] && [ "$target_fw" != "$FW_NAME" ]; then
            install_name_tool -change "$dep" "@rpath/$target_fw.framework/Versions/A/$target_fw" "$BINARY" 2>/dev/null || true
        fi
    done
}

echo "=== Building ARM64 Framework wrappers from Homebrew ==="
echo "Homebrew prefix: $BREW_PREFIX"
echo "Output: $FRAMEWORKS_DIR"
echo ""

# FLAC
create_framework "FLAC" \
    "$BREW_PREFIX/lib/libFLAC.dylib" \
    "$BREW_PREFIX/include/FLAC"

# lame (MP3 encoder)
create_framework "lame" \
    "$BREW_PREFIX/lib/libmp3lame.dylib" \
    "$BREW_PREFIX/include/lame"

# mad (MPEG audio decoder)
create_framework "mad" \
    "$BREW_PREFIX/lib/libmad.dylib" \
    "$BREW_PREFIX/include"
# mad only has mad.h at top level, move it into framework properly
mkdir -p "$FRAMEWORKS_DIR/mad.framework/Versions/A/Headers/mad"
cp "$BREW_PREFIX/include/mad.h" "$FRAMEWORKS_DIR/mad.framework/Versions/A/Headers/mad/" 2>/dev/null || true
# Also keep it at top level for <mad/mad.h> include path
cp "$BREW_PREFIX/include/mad.h" "$FRAMEWORKS_DIR/mad.framework/Versions/A/Headers/" 2>/dev/null || true

# mp4v2
create_framework "mp4v2" \
    "$BREW_PREFIX/lib/libmp4v2.dylib" \
    "$BREW_PREFIX/include/mp4v2"
# The project expects <mp4v2/mp4v2.h>, so nest them
mkdir -p "$FRAMEWORKS_DIR/mp4v2.framework/Versions/A/Headers/mp4v2"
cp "$BREW_PREFIX/include/mp4v2"/*.h "$FRAMEWORKS_DIR/mp4v2.framework/Versions/A/Headers/mp4v2/" 2>/dev/null || true

# mpcdec (Musepack)
create_framework "mpcdec" \
    "$BREW_PREFIX/lib/libmpcdec.dylib" \
    "$BREW_PREFIX/include/mpc"
# The project expects <mpcdec/mpcdec.h>
mkdir -p "$FRAMEWORKS_DIR/mpcdec.framework/Versions/A/Headers/mpcdec"
cp "$BREW_PREFIX/include/mpc"/*.h "$FRAMEWORKS_DIR/mpcdec.framework/Versions/A/Headers/mpcdec/" 2>/dev/null || true
# Also copy as mpcdec.h alias
cp "$BREW_PREFIX/include/mpc/mpcdec.h" "$FRAMEWORKS_DIR/mpcdec.framework/Versions/A/Headers/mpcdec/" 2>/dev/null || true

# ogg
create_framework "ogg" \
    "$BREW_PREFIX/lib/libogg.dylib" \
    "$BREW_PREFIX/include/ogg"
# The project expects <ogg/ogg.h>
mkdir -p "$FRAMEWORKS_DIR/ogg.framework/Versions/A/Headers/ogg"
cp "$BREW_PREFIX/include/ogg"/*.h "$FRAMEWORKS_DIR/ogg.framework/Versions/A/Headers/ogg/" 2>/dev/null || true

# sndfile
create_framework "sndfile" \
    "$BREW_PREFIX/lib/libsndfile.dylib" \
    "$BREW_PREFIX/include"
# sndfile has sndfile.h and sndfile.hh at the top level
mkdir -p "$FRAMEWORKS_DIR/sndfile.framework/Versions/A/Headers"
cp "$BREW_PREFIX/include/sndfile.h" "$FRAMEWORKS_DIR/sndfile.framework/Versions/A/Headers/" 2>/dev/null || true
cp "$BREW_PREFIX/include/sndfile.hh" "$FRAMEWORKS_DIR/sndfile.framework/Versions/A/Headers/" 2>/dev/null || true

# speex
create_framework "speex" \
    "$BREW_PREFIX/lib/libspeex.dylib" \
    "$BREW_PREFIX/include/speex"
# The project expects <speex/speex.h>
mkdir -p "$FRAMEWORKS_DIR/speex.framework/Versions/A/Headers/speex"
cp "$BREW_PREFIX/include/speex"/*.h "$FRAMEWORKS_DIR/speex.framework/Versions/A/Headers/speex/" 2>/dev/null || true

# taglib
# TagLib v2 uses libtag.dylib - need both the C and C++ interfaces
create_framework "taglib" \
    "$BREW_PREFIX/lib/libtag.dylib" \
    "$BREW_PREFIX/include/taglib"
# Also copy the C interface library
cp "$BREW_PREFIX/lib/libtag_c.dylib" "$FRAMEWORKS_DIR/taglib.framework/Versions/A/taglib_c" 2>/dev/null || true
# The project expects <taglib/tag.h> etc.
mkdir -p "$FRAMEWORKS_DIR/taglib.framework/Versions/A/Headers/taglib"
cp "$BREW_PREFIX/include/taglib"/*.h "$FRAMEWORKS_DIR/taglib.framework/Versions/A/Headers/taglib/" 2>/dev/null || true

# vorbis (includes vorbis, vorbisenc, vorbisfile)
# Create a combined framework with all vorbis libs
create_framework "vorbis" \
    "$BREW_PREFIX/lib/libvorbis.dylib" \
    "$BREW_PREFIX/include/vorbis"
# Also merge vorbisenc and vorbisfile into the framework
cp "$BREW_PREFIX/lib/libvorbisenc.dylib" "$FRAMEWORKS_DIR/vorbis.framework/Versions/A/vorbisenc" 2>/dev/null || true
cp "$BREW_PREFIX/lib/libvorbisfile.dylib" "$FRAMEWORKS_DIR/vorbis.framework/Versions/A/vorbisfile" 2>/dev/null || true
# The project expects <vorbis/vorbisenc.h>
mkdir -p "$FRAMEWORKS_DIR/vorbis.framework/Versions/A/Headers/vorbis"
cp "$BREW_PREFIX/include/vorbis"/*.h "$FRAMEWORKS_DIR/vorbis.framework/Versions/A/Headers/vorbis/" 2>/dev/null || true

# wavpack
create_framework "wavpack" \
    "$BREW_PREFIX/lib/libwavpack.dylib" \
    "$BREW_PREFIX/include/wavpack"
# The project expects <wavpack/wavpack.h>
# create_framework already copies include/wavpack/* to Headers/
# We need to nest them under Headers/wavpack/
rm -rf "$FRAMEWORKS_DIR/wavpack.framework/Versions/A/Headers/wavpack" 2>/dev/null || true
mkdir -p "$FRAMEWORKS_DIR/wavpack.framework/Versions/A/Headers/wavpack"
cp "$BREW_PREFIX/include/wavpack"/*.h "$FRAMEWORKS_DIR/wavpack.framework/Versions/A/Headers/wavpack/" 2>/dev/null || true

# discid (MusicBrainz)
create_framework "discid" \
    "$BREW_PREFIX/lib/libdiscid.dylib" \
    "$BREW_PREFIX/include/discid"
# The project expects <discid/discid.h>
mkdir -p "$FRAMEWORKS_DIR/discid.framework/Versions/A/Headers/discid"
cp "$BREW_PREFIX/include/discid"/*.h "$FRAMEWORKS_DIR/discid.framework/Versions/A/Headers/discid/" 2>/dev/null || true

# cdparanoia (using libcdio-paranoia as replacement)
# This is a compatibility wrapper - libcdio-paranoia has a different API
echo "Creating cdparanoia.framework (from libcdio-paranoia)..."
FW_DIR="$FRAMEWORKS_DIR/cdparanoia.framework"
VERSIONS_DIR="$FW_DIR/Versions/A"
mkdir -p "$VERSIONS_DIR/Headers/cdparanoia"
mkdir -p "$VERSIONS_DIR/Resources"

# We need to create a fat library combining cdio_paranoia and cdio_cdda
# For now, use libcdio_paranoia as the main binary
cp "$BREW_PREFIX/lib/libcdio_paranoia.dylib" "$VERSIONS_DIR/cdparanoia"
install_name_tool -id "@rpath/cdparanoia.framework/Versions/A/cdparanoia" "$VERSIONS_DIR/cdparanoia" 2>/dev/null || true

# Copy cdio_cdda as a secondary library
cp "$BREW_PREFIX/lib/libcdio_cdda.dylib" "$VERSIONS_DIR/cdda" 2>/dev/null || true

# Copy headers - the original cdparanoia headers aren't directly compatible
# We'll copy the libcdio-paranoia headers
cp "$BREW_PREFIX/include/cdio/paranoia"/*.h "$VERSIONS_DIR/Headers/cdparanoia/" 2>/dev/null || true
cp "$BREW_PREFIX/include/cdio"/*.h "$VERSIONS_DIR/Headers/" 2>/dev/null || true

# Create symlinks
ln -sf A "$FW_DIR/Versions/Current"
ln -sf Versions/Current/cdparanoia "$FW_DIR/cdparanoia"
ln -sf Versions/Current/Headers "$FW_DIR/Headers"
ln -sf Versions/Current/Resources "$FW_DIR/Resources"

cat > "$VERSIONS_DIR/Resources/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>cdparanoia</string>
    <key>CFBundleIdentifier</key>
    <string>org.sbooth.cdparanoia</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
</dict>
</plist>
EOF

# cuetools (using libcue)
echo "Creating cuetools.framework (from libcue)..."
FW_DIR="$FRAMEWORKS_DIR/cuetools.framework"
VERSIONS_DIR="$FW_DIR/Versions/A"
mkdir -p "$VERSIONS_DIR/Headers/cuetools"
mkdir -p "$VERSIONS_DIR/Resources"

cp "$BREW_PREFIX/lib/libcue.dylib" "$VERSIONS_DIR/cuetools"
install_name_tool -id "@rpath/cuetools.framework/Versions/A/cuetools" "$VERSIONS_DIR/cuetools" 2>/dev/null || true

# Copy libcue headers
cp "$BREW_PREFIX/include/libcue"/*.h "$VERSIONS_DIR/Headers/cuetools/" 2>/dev/null || true
cp "$BREW_PREFIX/include/libcue.h" "$VERSIONS_DIR/Headers/cuetools/" 2>/dev/null || true

ln -sf A "$FW_DIR/Versions/Current"
ln -sf Versions/Current/cuetools "$FW_DIR/cuetools"
ln -sf Versions/Current/Headers "$FW_DIR/Headers"
ln -sf Versions/Current/Resources "$FW_DIR/Resources"

cat > "$VERSIONS_DIR/Resources/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>cuetools</string>
    <key>CFBundleIdentifier</key>
    <string>org.sbooth.cuetools</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
</dict>
</plist>
EOF

echo ""
echo "=== Fixing inter-library dependencies ==="
for fw in FLAC lame mad mp4v2 mpcdec ogg sndfile speex taglib vorbis wavpack discid; do
    fix_deps "$fw"
done

echo ""
echo "=== Verifying architectures ==="
for fw in "$FRAMEWORKS_DIR"/*.framework; do
    FW_NAME=$(basename "$fw" .framework)
    BINARY="$fw/Versions/A/$FW_NAME"
    if [ -f "$BINARY" ]; then
        ARCH=$(lipo -archs "$BINARY" 2>/dev/null || echo "unknown")
        echo "  $FW_NAME: $ARCH"
    fi
done

echo ""
echo "=== Framework creation complete ==="
echo "Frameworks directory: $FRAMEWORKS_DIR"
ls -1 "$FRAMEWORKS_DIR"
