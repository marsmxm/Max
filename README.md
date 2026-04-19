# Max-Reborn

**Upstream project:** [https://sbooth.org/Max/](https://sbooth.org/Max/) · [GitHub](https://github.com/sbooth/Max)

Max-Reborn is a revival of Max, the open-source macOS application for ripping CDs and converting audio between formats. All bundled third-party frameworks have been recompiled as native ARM64 binaries, several ARM64-specific runtime crashes have been fixed, and the project has been updated to build and run on modern macOS.

## What is Max?

Max is an application for creating high-quality audio files in various formats, from compact discs or files.

When extracting audio from compact discs, Max offers the maximum in flexibility to ensure the true sound of your CD is faithfully extracted. For pristine discs, Max offers a high-speed ripper with no error correction. For damaged discs, Max can either use its built-in comparison ripper (for drives that cache audio) or the error-correcting power of [cdparanoia](https://www.xiph.org/paranoia/).

Once the audio is extracted, Max can generate audio in over 20 compressed and uncompressed formats including MP3, Ogg Vorbis, FLAC, AAC, Apple Lossless, Monkey's Audio, WavPack, Speex, AIFF, and WAVE.

If you would like to convert your audio from one format to another, Max can read and write audio files in over 20 compressed and uncompressed formats at almost all sample rates and in most sample sizes. For many popular formats the artist and album metadata is transferred seamlessly between the old and new files. Max can even split a single audio file into multiple tracks using a cue sheet.

Max leverages open source components and the resources of macOS to provide extremely high-quality output. MP3 encoding is accomplished with [LAME](https://lame.sourceforge.io), Ogg Vorbis encoding with [libVorbis](https://xiph.org/vorbis/), FLAC encoding with [libFLAC](https://xiph.org/flac/), and AAC and Apple Lossless encoding with [Core Audio](https://developer.apple.com/documentation/coreaudio). Many PCM conversions are also possible using Core Audio and [libsndfile](https://libsndfile.github.io/libsndfile/).

Max is integrated with [MusicBrainz](https://musicbrainz.org) to permit automatic retrieval of compact disc information. For MP3, FLAC, Ogg FLAC, Ogg Vorbis, Monkey's Audio, WavPack, AAC, and Apple Lossless files, Max will write this metadata to the output.

Max allows full control over where output files are placed and what they are named.

For advanced users, Max allows control over how many threads are used for encoding, what type of error correction is used for audio extraction, and what parameters are used for each of the various encoders.

Max is free software released under the [GNU General Public License](http://www.gnu.org/licenses/licenses.html#GPL) (GPL).

## Requirements

- Apple Silicon Mac (ARM64)
- macOS 11.0 (Big Sur) or later

## Bundled Library Versions

| Library | Version |
|---------|---------|
| libFLAC | 1.5.0 |
| libsndfile | 1.2.2 |
| LAME | 3.x |
| libvorbis / libogg | current |
| WavPack | current |
| cdparanoia | III |
| Speex | current |
| Monkey's Audio (mac) | current |
| TagLib | current |

## ARM64 Fixes Applied

The following issues were present in the original codebase when running on Apple Silicon and have been fixed in this port:

- **Code signature** — added required entitlements and ad-hoc signing for Gatekeeper on ARM64.
- **libsndfile vorbis ordinal crash** — rebuilt sndfile.framework with correct merged vorbis/vorbisenc/vorbisfile symbols; resolved `NSInvalidArgumentException` on launch.
- **cdtext_get symbol collision** — unexported private `cdtext_get` from cdparanoia.framework to eliminate conflict with the system symbol; relinked the Max binary.
- **CUE sheet last-track frame count** (`0 < frameCount` assertion) — `track_get_length()` returns `-1` as a sentinel for the final track. On ARM64, `fcvtzu` saturates the resulting negative float to `0`, causing `setFrameCount:0` to fire an assertion. Fixed by checking `0 < track_get_length(track)` and falling through to the correct `totalFrames - startingFrame` calculation.

## Building

```bash
cd Max
xcodebuild build -scheme Max -configuration Debug
```

Then copy and sign the result:

```bash
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/Max-*/Build/Products/Debug/Max.app"
DEST="$(pwd)/build/Debug/Max.app"
cp -a $DERIVED "$DEST.new" && rm -rf "$DEST" && mv "$DEST.new" "$DEST"
for fw in "$DEST/Contents/Frameworks/"*.framework; do codesign --force --sign - "$fw" 2>/dev/null; done
codesign --force --deep --sign - "$DEST"
```

Requires Xcode 13 or later on an Apple Silicon Mac.

## Smoke Tests

A shell script is included to verify that all bundled encoding libraries are functional:

```bash
bash smoke_test.sh
```

This generates a synthetic WAV file and exercises ALAC, AAC, FLAC, MP3, WavPack, Ogg Vorbis, libsndfile, and the FLAC framework dylib.

## Support

Bugs in the upstream Max codebase can be reported via the [GitHub issue tracker](https://github.com/sbooth/Max/issues).