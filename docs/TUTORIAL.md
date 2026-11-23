# Minsky Machine validation tutorial

One entry per check-in, in the order made, while this design is validated
for its Tiny Tapeout shuttle. Each entry says what now exists, why, what is
not checked yet, and ends with what to run to see it. The check-in comment
carries the full claim and evidence.

To follow along you need Icarus Verilog and Python with cocotb, exactly as
GitHub's `test` action installs them: on Ubuntu, `sudo apt install iverilog`
then `pip install -r test/requirements.txt`. All commands run in `test/`.

## 1 The program, one instruction at a time ([98aea7f2](https://ollama.openbeagle.org/tt-minsky-vga/info/98aea7f2608675f36fc1f9927bcc907f873932a87fc632d3e2dda1085c823fcd?diff=1))

The chip's counting machine (a *Minsky machine*: boxes of pebbles and two
instructions, `add` and `take`) runs a fixed program that multiplies a = 3
by b = 4 into box c. On the chip it runs one instruction every 16 frames,
so simulating the whole chip through one pass of the program would take
hours. `program_trace.v` instead drives the machine's `step` input
directly, so all 99 instructions run in microseconds, and compares every
instruction with a reference model typed in from the table in
`docs/info.md`. It writes the trace to `program_trace.txt`: c reaches 12 at
instruction 77, and after 99 the machine is back at its start and repeats.
The program never stops; it was written to restart. Not checked yet: the
16-frame pacing on the whole chip, and the gate-level netlist.
Run `make program_trace`, then `less program_trace.txt`.

What you'll see (cut with ...):

    instr  line  does          ->  line   a  b  c  d  e
        0                            0   3  4  0  0  0   (start)
        1    0   take b          ->   1   3  3  0  0  0
    ...
       77    0   take b (empty)  ->   7   3  0 12  0  4
            multiplication done: c = 12 (a = 3, b counted down to 0, e = 4)
    ...
       99    9   take c (empty)  ->   0   3  4  0  0  0
            after 99 instructions: back to the start (line 0, a = 3, b = 4)
    ...
    PASS: 3 x 4 = 12 at instruction 77; the program repeats every 99 instructions

## 2 The pins match the Tiny VGA Pmod ([44e861b2](https://ollama.openbeagle.org/tt-minsky-vga/info/44e861b2e0f299d73e00d54190ae5b88444417b85eb02948e5d8cad748367b36?diff=1))

A *Pmod* is a small plug-in board; the Tiny VGA Pmod carries the chip's
eight output pins to a VGA socket. If the chip put a signal on the wrong
pin, the picture would need rewiring. Tiny VGA's README
(https://github.com/mole99/tiny-vga) and Tiny Tapeout's pinout page
(https://tinytapeout.com/specs/pinouts/) both give uo_out[0..7] as R1, G1,
B1, VSYNC, R0, G0, B0, HSYNC, where R1/G1/B1 are each colour's high bit.
`info.yaml` lists the same names, and `src/project.v` drives them in that
order, with each colour's high bit on R1/G1/B1. The cocotb tests read the
pins the same way, so their passing pictures also check the wiring. Run
`grep -n 'uo\[' ../info.yaml`, then `grep -n 'assign uo_out' ../src/project.v`.

What you'll see:

    41:  uo[0]: "R1"
    ...
    48:  uo[7]: "HSYNC"
    103:  assign uo_out  = {hsync_n, blue[0], green[0], red[0], vsync_n, blue[1], green[1], red[1]};

## 3 Colour and sync line up ([6c56d3a1](https://ollama.openbeagle.org/tt-minsky-vga/info/6c56d3a1414995e4cea693d010a7377890a046f1?diff=1), branch vga-timing-fix)

A VGA monitor finds the start of each line from the *hsync* pulse, then
expects 48 clocks of black (the *back porch*) before the 640 picture
pixels. Here the colour came straight from the beam position, while the
sync was registered and so came one clock late. The picture therefore sat
one pixel early: one picture pixel in each back porch, and column 639
black. Nobody would see it on a monitor, but it is not standard timing. The
new cocotb test `test_picture_lines_up_with_sync` measures from the end of
hsync and failed at clock 47. The fix registers the sync for the position
the counters move to next, so sync and colour describe the same pixel. It
adds no flip-flops. `render_frame.v` now also checks that every blanking
clock is black, and `docs/minsky_machine.png` is the new frame 1, which is
the old one moved right by one pixel. Run `make`, then
`iverilog -g2012 -o render.vvp render_frame.v ../src/[a-z]*.v && vvp render.vvp +frames=1 && python3 ppm_to_png.py frame_1.ppm frame_1.png`.

What you'll see (cut with ...):

    ** test.test_picture_lines_up_with_sync   PASS ...
    ** TESTS=4 PASS=4 FAIL=0 SKIP=0 ...
    ...
    wrote frame_1.ppm
    PASS: sync timing and black blanking correct for 2 frames

## 4 The whole chip, at its real pace ([3f225c04](https://ollama.openbeagle.org/tt-minsky-vga/info/3f225c046f8b6365207f35edd572c37a58a3e0cc997547b9c710cc691ba36b36?diff=1))

Entry 1 ran the machine on its own. Here the whole chip runs from reset,
with the VGA scan pacing the machine as it does on silicon: one instruction
every 16 frames, at the start of vertical sync (line 490, clock 0). That
is 1,584 frames for one pass of the program, about 26 seconds on the chip
and about an hour in Icarus. `chip_trace.v` notes the frame, line and
clock of every change of state and fails if one comes at another time. The
Makefile then checks that the states match `program_trace.txt`. The
picture agrees: `docs/frame_1217.png`, rendered by `render_frame.v`, is the
first frame after instruction 77 and shows c = 12. The same testbench runs
on the gate-level netlist (`GATES=yes`), but a full pass there takes most
of a day and was stopped. Run `make chip_trace INSTRUCTIONS=2` for a
two-minute look, or `make chip_trace` for all 99.

What you'll see (cut with ...):

    instr  frame  line  clock  ->  line   a  b  c  d  e
        0                             0   3  4  0  0  0   (after reset)
        1      0   490      0  ->   1   3  3  0  0  0
    ...
       77   1216   490      0  ->   7   3  0 12  0  4
    ...
       99   1568   490      0  ->   0   3  4  0  0  0
    PASS: 99 instructions, one every 16 frames, each at the start of vsync
    SAME: the chip's 99 instructions match program_trace.txt

## 5 A font vga-playground.com can simulate

vga-playground.com runs a design in the browser: an old Verilator, built
for WebAssembly, turns the Verilog into a tree, and a small simulator runs
that tree. It stopped with "non-const expr in initarray (multidimensional
arrays not supported)". Verilator had made the font's `case` into a lookup
table whose entries were whole glyphs, 8 rows of 6 characters, 384 bits
each, and the playground's simulator can't hold entries that wide.
`src/font.v` now looks up one row at a time: a letter and a row give six
bits. The glyphs are still drawn in `#` and `.`, now top to bottom, one
row per line. A check of all 2,048 (letter, row, column) inputs found the
old and new fonts identical, and frame 1 renders byte for byte the same.
`test/vga-playground/minsky.spec.ts` compiles and renders the design with
the playground's own code; it failed with the old font and passes with
this one. Run its header's three steps in a clone of
https://github.com/TinyTapeout/vga-playground.

What you'll see:

     ✓ src/sim/minsky.spec.ts (1 test)
       ✓ Minsky Machine compiles and renders in vga-playground
          Tests  1 passed (1)
