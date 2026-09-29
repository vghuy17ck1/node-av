# Custom build

This fork of [seydx/node-av](https://github.com/seydx/node-av) builds the native binding against shared FFmpeg 8.1 libraries instead of upstream's static build. The FFmpeg builds come from `vghuy17ck1/FFmpeg-Builds-SVT-AV1-Tritium`, pinned in `custom/ffmpeg.env`.

## Install

Install the tarball from a release. The install script downloads the binary for your platform and checks its SHA-256.

```
npm install https://github.com/vghuy17ck1/node-av/releases/download/v<version>/node-av-<version>.tgz
```

With pnpm 10 or newer, allow the install script by adding `node-av: true` to `allowBuilds`.

## Supported targets

- `win32-x64`
- `linux-x64` (glibc 2.34 or newer, no Alpine)
- `linux-arm64` (glibc 2.34 or newer, no Alpine)

## NVENC

- Windows uses NVENC SDK 12.2 headers. It is tested on driver 566.36.
- Linux uses NVENC SDK 13.0 headers and needs driver 570 or newer.

## Environment variables

- `NODE_AV_BINARY`: path to a `node-av.node` to load instead of the installed one. The install script does nothing when it is set.
- `NODE_AV_SKIP_BINARY=1`: skip the binary download.
- Node's `fetch` ignores `HTTPS_PROXY` unless `NODE_USE_ENV_PROXY=1` is set.

## Known gaps

These need FFmpeg internals that shared libraries do not export.

- `CodecParameters.parseExtradata()` does not parse H.264 and HEVC SPS.
- The avcC and hvcC fallbacks return nothing. This affects `getDecoderConfigurationRecord()`, the fMP4 helpers and the codec string fallback.
- Raw packet writes to RTSP are not supported.
- On Linux, device listing returns no devices. FFmpeg's `v4l2`, `alsa` and `x11grab` inputs still work by name.

## Building

`bash custom/build.sh <target>` builds the binary zip into `artifacts/`. `bash custom/test.sh <target>` tests it. The `Build` workflow does this for all targets on every push to `custom`. Run it manually with `release` enabled to publish `v<version>`.
