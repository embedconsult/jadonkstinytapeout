/*
 * Beagle clock: the Tiny Tapeout workshop design, written out in Verilog.
 *
 * The design has two independent parts:
 *
 *   1. A clock divider: one D flip-flop with an inverter from its output
 *      back to its D input. Every rising clock edge it loads the opposite
 *      of what it holds, so it toggles, giving a clock at half the input
 *      frequency. It drives segment A of the 7-segment display.
 *
 *   2. A secret-code detector: when the input switches spell 0x62, the
 *      ASCII code for 'b', segments C, D, E, F and G light up to draw a
 *      lowercase "b" (for BeagleBoard).
 *
 * The 7-segment display on the Tiny Tapeout demo board is wired as:
 *   uo_out[0] = A   uo_out[1] = B   uo_out[2] = C   uo_out[3] = D
 *   uo_out[4] = E   uo_out[5] = F   uo_out[6] = G   uo_out[7] = decimal point
 *
 *         A
 *       F   B
 *         G
 *       E   C
 *         D
 *
 * Copyright (c) 2026 jadonk
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_jadonk_beagle_clock (
    input  wire [7:0] ui_in,    // Dedicated inputs: the 8 DIP switches
    output wire [7:0] uo_out,   // Dedicated outputs: the 7-segment display
    input  wire [7:0] uio_in,   // IOs: Input path (unused)
    output wire [7:0] uio_out,  // IOs: Output path (unused)
    output wire [7:0] uio_oe,   // IOs: Enable path (unused, all inputs)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // ---------------------------------------------------------------------
  // 1. Clock divider: a D flip-flop with an inverter fed back into D.
  // ---------------------------------------------------------------------
  reg  half_clock;                  // the flip-flop's output, Q
  wire next_half_clock = ~half_clock; // the inverter: D = not Q

  always @(posedge clk) begin
    if (!rst_n)
      half_clock <= 1'b0;           // start from a known state after reset
    else
      half_clock <= next_half_clock;
  end

  // ---------------------------------------------------------------------
  // 2. Secret-code detector: show a lowercase "b" when ui_in == 'b'.
  // ---------------------------------------------------------------------
  localparam [7:0] SECRET_CODE = 8'h62;   // ASCII 'b'

  wire code_matches = (ui_in == SECRET_CODE);

  // ---------------------------------------------------------------------
  // Outputs. All output pins must be assigned.
  // ---------------------------------------------------------------------
  assign uo_out[0]   = half_clock;             // segment A blinks at clk / 2
  assign uo_out[1]   = 1'b0;                   // segment B is not part of "b"
  assign uo_out[6:2] = {5{code_matches}};      // segments C, D, E, F, G draw "b"
  assign uo_out[7]   = 1'b0;                   // decimal point off

  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, uio_in, 1'b0};

endmodule
