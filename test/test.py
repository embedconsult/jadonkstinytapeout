# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0
#
# Tests for the beagle clock: a D flip-flop + inverter clock divider on
# segment A, and a lowercase "b" on segments C-G when the switches read 0x62.

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

SEGMENT_A = 0
SEGMENTS_FOR_B = 0b0111_1100  # C, D, E, F, G
SECRET_CODE = 0x62  # ASCII 'b'


async def reset(dut):
    clock = Clock(dut.clk, 10, unit="us")  # 100 kHz
    cocotb.start_soon(clock.start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1


def segment_a(dut):
    return (int(dut.uo_out.value) >> SEGMENT_A) & 1


@cocotb.test()
async def test_clock_divider_toggles_every_edge(dut):
    """Segment A must flip on every rising clock edge: a clock at clk / 2."""
    await reset(dut)
    await ClockCycles(dut.clk, 1)
    previous = segment_a(dut)
    for edge in range(16):
        await ClockCycles(dut.clk, 1)
        current = segment_a(dut)
        assert current != previous, f"segment A did not toggle on edge {edge}"
        previous = current


@cocotb.test()
async def test_reset_starts_clock_low(dut):
    """While reset is held, the divided clock is held low."""
    await reset(dut)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    assert segment_a(dut) == 0


@cocotb.test()
async def test_secret_code_shows_b(dut):
    """Only the code 0x62 lights C-G; B and the decimal point never light."""
    await reset(dut)
    for code in range(256):
        dut.ui_in.value = code
        await Timer(1, unit="us")  # the detector is combinational
        segments = int(dut.uo_out.value)
        expected = SEGMENTS_FOR_B if code == SECRET_CODE else 0
        assert segments & 0b0111_1100 == expected, f"code 0x{code:02x}: segments {segments:08b}"
        assert segments & 0b1000_0010 == 0, f"code 0x{code:02x}: B or DP lit"
    assert int(dut.uio_oe.value) == 0
