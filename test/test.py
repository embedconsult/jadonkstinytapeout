# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
#
# Tests for "Boris and the Minsky Machine": the ADD/TAKE machine must
# produce exact 640x480 VGA timing, and the picture must have Boris, the
# lettering, the program listing and the pebbles in the right places and
# colours, showing the demo program's first instruction taking effect.
#
# To keep the tests fast (they also run on the gate-level netlist), they
# jump ahead with timers instead of waiting for every clock edge.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer

CLOCK_NS = 40                       # 25 MHz test clock
LINE_CLOCKS = 800
FRAME_LINES = 525
VSYNC_LINE = 490                    # vsync goes low at the start of this line


async def start(dut):
    cocotb.start_soon(Clock(dut.clk, CLOCK_NS, unit="ns").start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1


def hsync(dut):
    return (int(dut.uo_out.value) >> 7) & 1


def vsync(dut):
    return (int(dut.uo_out.value) >> 3) & 1


def colour(dut):
    """(red, green, blue), 2 bits each, from the Tiny VGA Pmod pins."""
    v = int(dut.uo_out.value)
    bit = lambda n: (v >> n) & 1
    return (bit(0) << 1 | bit(4), bit(1) << 1 | bit(5), bit(2) << 1 | bit(6))


async def clocks_until(dut, edge):
    """Count clock periods until the trigger fires."""
    start_time = cocotb.utils.get_sim_time(unit="ns")
    await edge
    return round((cocotb.utils.get_sim_time(unit="ns") - start_time) / CLOCK_NS)


@cocotb.test()
async def test_horizontal_timing(dut):
    """Every line is 800 clocks with a 97-clock sync pulse."""
    await start(dut)
    await FallingEdge(dut.hsync_n)
    for _ in range(3):
        low = await clocks_until(dut, RisingEdge(dut.hsync_n))
        high = await clocks_until(dut, FallingEdge(dut.hsync_n))
        assert low == 97, f"hsync pulse is {low} clocks"
        assert low + high == LINE_CLOCKS, f"line is {low + high} clocks"


@cocotb.test()
async def test_vertical_timing(dut):
    """Vsync arrives on line 490 after reset and lasts exactly 2 lines."""
    await start(dut)
    first = await clocks_until(dut, FallingEdge(dut.vsync_n))
    assert abs(first - VSYNC_LINE * LINE_CLOCKS) <= 2, f"vsync after {first} clocks"
    low = await clocks_until(dut, RisingEdge(dut.vsync_n))
    assert low == 2 * LINE_CLOCKS, f"vsync pulse is {low} clocks"


@cocotb.test()
async def test_picture(dut):
    """Spot-check pixels of the second frame against the rendered picture.

    The demo program runs one instruction in the first frame, so the
    second frame must already show its effect: the arrow on line 1 and
    one pebble fewer in box b.
    """
    await start(dut)
    await FallingEdge(dut.vsync_n)           # start of line 490 of frame 0
    frame_start = (FRAME_LINES - VSYNC_LINE) * LINE_CLOCKS
    elapsed = 0

    expected = [  # (x, y, colour, what)
        (136, 16, (3, 3, 3), "white title lettering"),
        (402, 115, (0, 2, 3), "no arrow on line 0 any more"),
        (402, 131, (3, 1, 0), "orange arrow: the demo program is now on line 1"),
        (156, 198, (0, 2, 3), "box b lost a pebble: line 0 was 'take b'"),
        (76, 215, (2, 3, 1), "box a still has its pebbles"),
        (160, 336, (2, 1, 0), "'beagle' in hair brown"),
        (128, 340, (3, 1, 0), "Boris' orange tongue"),
        (500, 336, (3, 1, 0), "'board.org' in tongue orange"),
        (50, 448, (2, 2, 2), "tagline lettering"),
        (600, 470, (0, 2, 3), "BeagleBoard blue background"),
    ]
    for x, y, rgb, what in sorted(expected, key=lambda p: (p[1], p[0])):
        target = frame_start + y * LINE_CLOCKS + x
        # sample in the middle of the clock period
        await Timer((target - elapsed) * CLOCK_NS + (CLOCK_NS // 2 if elapsed == 0 else 0), unit="ns")
        elapsed = target
        assert colour(dut) == rgb, f"{what} at ({x}, {y}): got {colour(dut)}, expected {rgb}"

    # Outside the visible area the colour pins must be black.
    await Timer((frame_start + 470 * LINE_CLOCKS + 700 - elapsed) * CLOCK_NS, unit="ns")
    assert colour(dut) == (0, 0, 0), "colour during horizontal blanking"
