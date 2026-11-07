/*
 * Boris and the Minsky Machine
 *
 * A two-instruction computer (Minsky's ADD and TAKE) draws a VGA picture
 * of Boris, the BeagleBoard.org beagle, together with a live demonstration
 * of Minsky's "boxes of pebbles".
 *
 *   minsky_vga.v     the ADD/TAKE machine; its main program generates the VGA timing
 *   demo_program.v   the second program it runs, slowly, for you to watch: multiplication
 *   scene.v          what colour each pixel is
 *   boris.v          Boris as ASCII art
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

  wire       hsync_n, vsync_n, video_on;
  wire [8:0] x, y, frame;
  wire [3:0] demo_line;
  wire [19:0] demo_boxes;

  minsky_vga machine (
      .clk     (clk),
      .rst_n   (rst_n),
      .hsync_n (hsync_n),
      .vsync_n (vsync_n),
      .video_on(video_on),
      .x       (x),
      .y       (y),
      .frame   (frame),
      .demo_line (demo_line),
      .demo_boxes(demo_boxes)
  );

  wire [5:0] scene_rgb;

  scene picture (
      .x    (x),
      .y    (y),
      .demo_line (demo_line),
      .demo_boxes(demo_boxes),
      .rgb       (scene_rgb)
  );

  // Register the colour so it lines up with the (registered) sync signals.
  reg [5:0] rgb;
  always @(posedge clk) rgb <= scene_rgb;

  wire [5:0] pixel = video_on ? rgb : 6'b0;   // black outside the visible area
  wire [1:0] red   = pixel[5:4];
  wire [1:0] green = pixel[3:2];
  wire [1:0] blue  = pixel[1:0];

  assign uo_out  = {hsync_n, blue[0], green[0], red[0], vsync_n, blue[1], green[1], red[1]};
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in, uio_in, frame, 1'b0};

endmodule
