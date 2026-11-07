/*
 * Minsky Machine (bbb.io/minsky)
 *
 * A two-instruction computer (Minsky's ADD and TAKE) runs a program you
 * can watch on a VGA monitor: its boxes of pebbles, and its program with
 * an arrow at the running instruction, with the link bbb.io/minsky in
 * BeagleBoard.org colours.
 *
 *   minsky_machine.v the ADD/TAKE machine: five boxes and a program counter
 *   demo_program.v   the program it runs: multiplication
 *   vga_sync.v       standard 640 x 480 VGA timing
 *   scene.v          what colour each pixel is: the machine's state, drawn
 *   font.v           a small font as ASCII art
 *
 * Output pins follow the Tiny VGA Pmod:
 *   uo_out[0] R1   uo_out[1] G1   uo_out[2] B1   uo_out[3] VSYNC
 *   uo_out[4] R0   uo_out[5] G0   uo_out[6] B0   uo_out[7] HSYNC
 *
 * Clock: 25.175 MHz (640 x 480 at 60 Hz). 25 MHz also works on most monitors.
 *
 * Copyright (c) 2026 jadonk
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_jadonk_boris_minsky (
    input  wire [7:0] ui_in,    // Dedicated inputs (unused)
    output wire [7:0] uo_out,   // Dedicated outputs: Tiny VGA Pmod
    input  wire [7:0] uio_in,   // IOs: Input path (unused)
    output wire [7:0] uio_out,  // IOs: Output path (unused)
    output wire [7:0] uio_oe,   // IOs: Enable path (unused, all inputs)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // ---------------------------------------------------------------------
  // The beam: standard VGA timing
  // ---------------------------------------------------------------------
  wire       hsync_n, vsync_n, video_on;
  wire [9:0] hpos, vpos;

  vga_sync sync (
      .clk    (clk),
      .rst_n  (rst_n),
      .hsync_n(hsync_n),
      .vsync_n(vsync_n),
      .visible(video_on),
      .hpos   (hpos),
      .vpos   (vpos)
  );

  // The picture is drawn in "machine pixels" two monitor pixels wide.
  wire [8:0] x = hpos[9:1];   // 0..319
  wire [8:0] y = vpos[8:0];   // 0..479

  // ---------------------------------------------------------------------
  // The counting machine: one instruction every 16 frames
  // ---------------------------------------------------------------------
  // It steps at the start of the vertical sync, after the picture has been
  // drawn, so each frame shows a settled state.
  reg  [3:0] frames;
  wire       start_of_vsync = (hpos == 10'd0) && (vpos == 10'd490);
  wire       end_of_frame   = (hpos == 10'd799) && (vpos == 10'd524);

  always @(posedge clk) begin
    if (!rst_n)            frames <= 4'd0;
    else if (end_of_frame) frames <= frames + 4'd1;
  end

  wire [3:0]  demo_line;
  wire [19:0] demo_boxes;

  minsky_machine machine (
      .clk  (clk),
      .rst_n(rst_n),
      .step (start_of_vsync && frames == 4'd0),
      .line (demo_line),
      .boxes(demo_boxes)
  );

  // ---------------------------------------------------------------------
  // The picture
  // ---------------------------------------------------------------------
  wire [5:0] scene_rgb;

  scene picture (
      .x    (x),
      .y    (y),
      .demo_line (demo_line),
      .demo_boxes(demo_boxes),
      .rgb       (scene_rgb)
  );

  // The colour comes straight from the beam position; the registered sync
  // signals are one clock behind it, which monitors do not mind.
  wire [5:0] pixel = video_on ? scene_rgb : 6'b0;   // black outside the visible area
  wire [1:0] red   = pixel[5:4];
  wire [1:0] green = pixel[3:2];
  wire [1:0] blue  = pixel[1:0];

  assign uo_out  = {hsync_n, blue[0], green[0], red[0], vsync_n, blue[1], green[1], red[1]};
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in, uio_in, hpos[0], vpos[9], 1'b0};

endmodule
