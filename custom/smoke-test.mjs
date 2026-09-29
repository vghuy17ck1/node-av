// Usage: NODE_AV_BINARY=<path to node-av.node> node custom/smoke-test.mjs
// Checks that the built binary loads, reports FFmpeg 8.1 and can transcode.
import assert from 'node:assert/strict';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

assert.ok(process.env.NODE_AV_BINARY, 'NODE_AV_BINARY must point to the built node-av.node');

const dist = pathToFileURL(resolve('dist/index.js')).href;
const { Codec, Decoder, Demuxer, Encoder, FF_ENCODER_LIBX264, getFFmpegInfo, avGetCodecString } = await import(dist);

const info = getFFmpegInfo();
console.log(`FFmpeg ${info.version}, libavcodec ${info.libraries.avcodec}`);
assert.match(info.version, /8\.1/);
assert.match(String(info.libraries.avcodec), /^62/);

// CI has no GPU, so h264_nvenc is only checked for registration
for (const name of ['h264_nvenc', 'libx264', 'libopus']) {
  assert.ok(Codec.findEncoderByName(name), `encoder ${name} is missing`);
}

await using input = await Demuxer.open('testdata/demux.mp4');
const stream = input.video(0);
assert.ok(stream, 'no video stream in testdata/demux.mp4');

const codecString = avGetCodecString(stream.codecpar);
console.log(`codec string: ${codecString}`);
assert.ok(codecString && codecString.length > 0, 'avGetCodecString returned nothing');

using decoder = await Decoder.create(stream);
using encoder = await Encoder.create(FF_ENCODER_LIBX264, { decoder, bitrate: '1M', options: { preset: 'ultrafast' } });

let packets = 0;
for await (using packet of input.packets()) {
  if (packet && packet.streamIndex !== stream.index) continue;
  for await (using frame of decoder.frames(packet)) {
    for await (using _encoded of encoder.packets(frame)) packets++;
  }
  if (packets >= 30) break;
}
console.log(`encoded ${packets} packets with libx264`);
assert.ok(packets > 0, 'no packets were encoded');
