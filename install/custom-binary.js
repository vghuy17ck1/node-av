#!/usr/bin/env node
// Usage: node install/custom-binary.js
// Downloads the native binary zip for this platform from the fork's GitHub release into binary/.
// Set NODE_AV_BINARY to use a local build, or NODE_AV_SKIP_BINARY=1 to skip.

import { createHash } from 'node:crypto';
import { chmodSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { Open } from 'unzipper';

const TARGETS = new Set(['win32-x64', 'linux-x64', 'linux-arm64']);
const EXECUTABLES = ['ffmpeg', 'ffprobe'];
const ATTEMPTS = 3;

const packageDir = join(dirname(fileURLToPath(import.meta.url)), '..');
const binaryDir = join(packageDir, 'binary');

const fail = (message) => {
  console.error(`node-av: ${message}`);
  process.exit(1);
};

const isMuslLibc = () => {
  if (process.platform !== 'linux') {
    return false;
  }

  try {
    return !process.report?.getReport?.()?.header?.glibcVersionRuntime;
  } catch {
    return false;
  }
};

const download = async (url) => {
  let lastError;
  for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status} ${response.statusText}`);
      }
      return Buffer.from(await response.arrayBuffer());
    } catch (err) {
      lastError = err;
      if (attempt < ATTEMPTS) {
        await new Promise((resolve) => setTimeout(resolve, attempt * 2000));
      }
    }
  }
  throw new Error(`could not download ${url}: ${lastError}`);
};

const checksumFor = (sums, name) => {
  for (const line of sums.split(/\r?\n/)) {
    const match = line.match(/^([0-9a-f]{64})\s+\*?(.+)$/i);
    if (match && match[2] === name) {
      return match[1].toLowerCase();
    }
  }
  return undefined;
};

const main = async () => {
  if (process.env.NODE_AV_BINARY || process.env.NODE_AV_SKIP_BINARY === '1') {
    console.log('node-av: binary download skipped');
    return;
  }

  const target = `${process.platform}-${process.arch}`;
  if (!TARGETS.has(target)) {
    fail(`no binary is available for ${target}. Supported: ${[...TARGETS].join(', ')}.`);
  }
  if (isMuslLibc()) {
    fail('musl based systems such as Alpine are not supported. Use a glibc based distribution.');
  }

  const pkg = JSON.parse(readFileSync(join(packageDir, 'package.json'), 'utf8'));
  const baseUrl = pkg.customBinary?.baseUrl;
  if (!baseUrl) {
    fail('package.json has no customBinary.baseUrl');
  }

  const zipName = `node-av-v${pkg.version}-${target}.zip`;
  const marker = join(binaryDir, '.custom-binary');
  if (existsSync(join(binaryDir, 'node-av.node')) && existsSync(marker) && readFileSync(marker, 'utf8').trim() === zipName) {
    return;
  }

  const releaseUrl = `${baseUrl}/v${pkg.version}`;
  console.log(`node-av: downloading ${zipName}`);
  const sums = (await download(`${releaseUrl}/SHA256SUMS`)).toString('utf8');
  const expected = checksumFor(sums, zipName);
  if (!expected) {
    fail(`SHA256SUMS has no entry for ${zipName}`);
  }

  const zip = await download(`${releaseUrl}/${zipName}`);
  const actual = createHash('sha256').update(zip).digest('hex');
  if (actual !== expected) {
    fail(`checksum mismatch for ${zipName}: expected ${expected}, got ${actual}`);
  }

  rmSync(binaryDir, { recursive: true, force: true });
  mkdirSync(binaryDir, { recursive: true });
  const zipPath = join(binaryDir, zipName);
  writeFileSync(zipPath, zip);
  try {
    const directory = await Open.file(zipPath);
    await directory.extract({ path: binaryDir });
  } finally {
    rmSync(zipPath, { force: true });
  }

  if (!existsSync(join(binaryDir, 'node-av.node'))) {
    fail(`${zipName} does not contain node-av.node`);
  }
  if (process.platform !== 'win32') {
    for (const name of EXECUTABLES) {
      chmodSync(join(binaryDir, name), 0o755);
    }
  }
  writeFileSync(marker, `${zipName}\n`);
  console.log(`node-av: installed ${zipName}`);
};

main().catch((err) => fail(err instanceof Error ? err.message : String(err)));
