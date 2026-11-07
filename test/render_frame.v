/*
 * Render frames from the design to PPM images, as a VGA monitor would see them.
 *
 *   iverilog -g2012 -o render.vvp render_frame.v ../src/[a-z]*.v
 *   vvp render.vvp +frames=1,200
 *
 * Writes frame_<n>.ppm for each frame listed (frames counted from reset).
 * The picture is 640 x 480; each colour channel is 2 bits, scaled to 0..255.
 * It also checks the sync timing and stops with an error if it is wrong.
 */

`default_nettype none
`timescale 1ns / 1ps

module render_frame;

  localparam LINE_CLOCKS  = 800;
  localparam FRAME_LINES  = 525;
  localparam FRAME_CLOCKS = LINE_CLOCKS * FRAME_LINES;

  reg        clk = 0;
  reg        rst_n = 0;
  wire [7:0] uo_out;
  wire [7:0] uio_out, uio_oe;

  tt_um_jadonk_boris_minsky dut (
      .ui_in(8'b0), .uo_out(uo_out), .uio_in(8'b0), .uio_out(uio_out), .uio_oe(uio_oe),
      .ena(1'b1), .clk(clk), .rst_n(rst_n)
  );

  always #19.86 clk = ~clk;   // 25.175 MHz

  wire       hsync_n = uo_out[7];
  wire       vsync_n = uo_out[3];
  wire [1:0] red     = {uo_out[0], uo_out[4]};
  wire [1:0] green   = {uo_out[1], uo_out[5]};
  wire [1:0] blue    = {uo_out[2], uo_out[6]};

  integer frames_wanted [0:7];
  integer num_wanted, i, frame, line, col, clocks, fd, last_frame;
  reg [8*64-1:0] frames_arg;
  reg [8*32-1:0] name;
  integer errors = 0;

  initial begin
    // Which frames to save, e.g. +frames=1,200
    num_wanted = 1; frames_wanted[0] = 1;
    if ($value$plusargs("frames=%s", frames_arg)) begin
      num_wanted = $sscanf(frames_arg, "%d,%d,%d,%d,%d,%d,%d,%d",
                           frames_wanted[0], frames_wanted[1], frames_wanted[2], frames_wanted[3],
                           frames_wanted[4], frames_wanted[5], frames_wanted[6], frames_wanted[7]);
    end
    last_frame = 0;
    for (i = 0; i < num_wanted; i = i + 1)
      if (frames_wanted[i] > last_frame) last_frame = frames_wanted[i];

    repeat (4) @(posedge clk);
    rst_n = 1;
    @(posedge clk);   // outputs are registered: the picture starts one clock after reset

    for (frame = 0; frame <= last_frame; frame = frame + 1) begin
      fd = 0;
      for (i = 0; i < num_wanted; i = i + 1)
        if (frames_wanted[i] == frame) begin
          $sformat(name, "frame_%0d.ppm", frame);
          fd = $fopen(name, "w");
          $fwrite(fd, "P3\n640 480\n3\n");
        end
      for (line = 0; line < FRAME_LINES; line = line + 1) begin
        for (col = 0; col < LINE_CLOCKS; col = col + 1) begin
          #1;  // sample just after the clock edge
          // Expected timing: hsync low for clocks 654..750, vsync low on lines 490..491.
          if (hsync_n !== !(col >= 654 && col < 751)) begin
            if (errors < 5) $display("hsync wrong: frame %0d line %0d clock %0d", frame, line, col);
            errors = errors + 1;
          end
          if (vsync_n !== !(line >= 490 && line < 492)) begin
            if (errors < 5) $display("vsync wrong: frame %0d line %0d clock %0d", frame, line, col);
            errors = errors + 1;
          end
          if (fd != 0 && line < 480 && col < 640)
            $fwrite(fd, "%0d %0d %0d\n", red, green, blue);
          @(posedge clk);
        end
      end
      if (fd != 0) begin
        $fclose(fd);
        $display("wrote frame_%0d.ppm", frame);
      end
    end
    if (errors != 0) begin
      $display("FAIL: %0d timing errors", errors);
      $fatal(1);
    end
    $display("PASS: sync timing correct for %0d frames", last_frame + 1);
    $finish;
  end

endmodule
