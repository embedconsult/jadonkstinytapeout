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

## 2 The pins match the Tiny VGA Pmod

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

## 3 Colour and sync line up (branch vga-timing-fix)

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
