<!---
This file is used to generate your project datasheet.
-->

## How it works

This is the Tiny Tapeout workshop design, extended in two small ways.

**Clock divider.** A single D flip-flop has an inverter connected from its
output Q back to its D input. On every rising edge of the clock it loads the
opposite of what it holds, so its output toggles: a clean square wave at half
the input clock frequency. It drives segment A of the 7-segment display.
Reset (`rst_n` low) holds it low.

**Secret code.** The eight input switches are compared with `0x62`, the ASCII
code for the letter `b`. When they match, segments C, D, E, F and G light up
to draw a lowercase **b** (for BeagleBoard). For any other code those
segments stay off.

## How to test

1. Select the design and reset it with all switches off.
2. Clock it slowly (a few Hz, or with the manual clock button). Segment A
   turns on and off on alternate clock edges.
3. Set the switches to `0x62`: `ui[1]`, `ui[5]` and `ui[6]` on, all others
   off. A lowercase **b** appears. Change any switch and it disappears.

## External hardware

None. It uses the DIP switches and 7-segment display on the Tiny Tapeout
demo board.
