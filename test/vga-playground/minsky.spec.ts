// Compile the Minsky Machine sources in $MINSKY_SRC exactly as
// vga-playground.com does (its Verilator, compiled to WebAssembly, and its
// simulator), render one frame, and write it to $MINSKY_OUT as a PNG.
//
// Copy this file into src/sim/ of a clone of
// https://github.com/TinyTapeout/vga-playground, run npm ci there, then:
//   MINSKY_SRC=<this repo>/src MINSKY_OUT=frame.png npx vitest --run src/sim/minsky.spec.ts
import { readFileSync, readdirSync, writeFileSync } from 'fs';
import { dirname, resolve } from 'path';
import { PNG } from 'pngjs';
import { fileURLToPath } from 'url';
import { beforeAll, expect, test, vi } from 'vitest';
import { compileVerilator } from '../verilator/compile';
import { HDLModuleWASM } from './hdlwasm';
import { detectSyncPolarity, renderVGAFrame, resetModule, skipToFrameBoundary, VGA_HEIGHT, VGA_WIDTH } from './vga';

const __dirname = dirname(fileURLToPath(import.meta.url));
const wasmBinary = readFileSync(resolve(__dirname, '../verilator/verilator_bin.wasm'));
beforeAll(() => {
  process.exit = vi.fn() as any;   // the browser does not stop on Verilator exit
});

test('Minsky Machine compiles and renders in vga-playground', async () => {
  const dir = process.env.MINSKY_SRC!;
  const sources: Record<string, string> = {};
  for (const f of readdirSync(dir)) if (f.endsWith('.v')) sources[f] = readFileSync(resolve(dir, f), 'utf8');
  const res = await compileVerilator({ topModule: 'tt_um_jadonk_boris_minsky', sources, wasmBinary });
  expect(res.errors.filter((e: any) => e.type !== 'warning').map((e: any) => e.message)).toEqual([]);
  const constpool = res.output!.modules['@CONST-POOL@'] || res.output!.modules['__Vconst'];
  const mod = new HDLModuleWASM(res.output!.modules['TOP'], constpool);
  await mod.init();
  resetModule(mod);
  const polarity = detectSyncPolarity(mod);
  resetModule(mod);
  skipToFrameBoundary(mod, polarity);
  const pixels = new Uint8Array(VGA_WIDTH * VGA_HEIGHT * 4);
  renderVGAFrame(mod, pixels, { polarity });
  mod.dispose();
  const png = new PNG({ width: VGA_WIDTH, height: VGA_HEIGHT });
  png.data = Buffer.from(pixels);
  writeFileSync(process.env.MINSKY_OUT!, PNG.sync.write(png));
}, 120000);
