/*
 * Run the whole chip from reset, at its real pace, and record each
 * instruction the counting machine runs: when it ran (frame, line and
 * clock of the VGA scan) and the machine's state after it.
 *
 *   RTL:         make chip_trace                      (writes chip_trace.txt)
 *   gate level:  make chip_trace GATES=yes PDK_ROOT=...   (needs gate_level_netlist.v)
 *
 * The machine should run instruction n at the start of the vertical sync
 * of frame 16 (n - 1): line 490, clock 0 of that line. This testbench
 * fails if any instruction comes at another time, or if one is missing.
 * Whether each instruction did the right thing is checked by comparing
 * this trace with program_trace.txt (the Makefile does that).
 *
 * +instructions=N  how many to wait for (default 99, one whole pass:
 *                  1584 frames, about 26 seconds of chip time)
 *
 * The state is read from the nets demo_line and demo_boxes of the top
 * module, which keep those names in the gate-level netlist.
 */

`default_nettype none
`timescale 1ns / 1ps

module chip_trace;

  localparam LINE_CLOCKS = 800, FRAME_LINES = 525, FRAME_CLOCKS = LINE_CLOCKS * FRAME_LINES;

  reg  clk = 0, rst_n = 0;
  wire [7:0] uo_out, uio_out, uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1, VGND = 1'b0;
`endif

  tt_um_jadonk_boris_minsky dut (
`ifdef GL_TEST
      .VPWR(VPWR), .VGND(VGND),
`endif
      .ui_in(8'b0), .uo_out(uo_out), .uio_in(8'b0), .uio_out(uio_out), .uio_oe(uio_oe),
      .ena(1'b1), .clk(clk), .rst_n(rst_n)
  );

  always #20 clk = ~clk;   // 25 MHz, like the cocotb tests

  // The machine's state.
  wire [3:0]  line;
  wire [19:0] boxes;
`ifdef GL_TEST
  assign line  = {dut.\demo_line[3] , dut.\demo_line[2] , dut.\demo_line[1] , dut.\demo_line[0] };
  assign boxes = {dut.\demo_boxes[19] , dut.\demo_boxes[18] , dut.\demo_boxes[17] , dut.\demo_boxes[16] ,
                  dut.\demo_boxes[15] , dut.\demo_boxes[14] , dut.\demo_boxes[13] , dut.\demo_boxes[12] ,
                  dut.\demo_boxes[11] , dut.\demo_boxes[10] , dut.\demo_boxes[9] ,  dut.\demo_boxes[8] ,
                  dut.\demo_boxes[7] ,  dut.\demo_boxes[6] ,  dut.\demo_boxes[5] ,  dut.\demo_boxes[4] ,
                  dut.\demo_boxes[3] ,  dut.\demo_boxes[2] ,  dut.\demo_boxes[1] ,  dut.\demo_boxes[0] };
`else
  assign line  = dut.demo_line;
  assign boxes = dut.demo_boxes;
`endif

  integer wanted, n, errors, clocks, frame, vline, col, expect_at;
  reg [23:0] state, last;

  initial begin
    if (!$value$plusargs("instructions=%d", wanted)) wanted = 99;
    errors = 0;
    repeat (10) @(posedge clk);
    @(negedge clk) rst_n = 1;      // clock 0 of the scan is the first rising edge after this
    @(negedge clk);
    last = {line, boxes};
    $display("instr  frame  line  clock  ->  line   a  b  c  d  e");
    $display("    0                            %2d  %2d %2d %2d %2d %2d   (after reset)",
             line, boxes[3:0], boxes[7:4], boxes[11:8], boxes[15:12], boxes[19:16]);
    clocks = 1;  // the edge seen next ends scan clock 1
    n = 0;
    while (n < wanted) begin
      @(negedge clk);              // look half a clock after each edge
      state = {line, boxes};
      if (state !== last) begin
        n = n + 1;
        // The edge that changed the state ended clock `clocks` of the scan
        // (clock 0 is the one that ends at the first edge after reset).
        frame = clocks / FRAME_CLOCKS;
        vline = (clocks % FRAME_CLOCKS) / LINE_CLOCKS;
        col   = clocks % LINE_CLOCKS;
        $display("  %3d   %4d   %3d    %3d  ->  %2d  %2d %2d %2d %2d %2d", n, frame, vline, col,
                 line, boxes[3:0], boxes[7:4], boxes[11:8], boxes[15:12], boxes[19:16]);
        if (frame != 16 * (n - 1) || vline != 490 || col != 0) begin
          $display("FAIL: instruction %0d ran at frame %0d line %0d clock %0d, expected frame %0d line 490 clock 0",
                   n, frame, vline, col, 16 * (n - 1));
          errors = errors + 1;
        end
        last = state;
      end
      expect_at = (16 * n + 1) * FRAME_CLOCKS;   // by then instruction n + 1 is overdue
      if (clocks > expect_at) begin
        $display("FAIL: instruction %0d did not come by frame %0d", n + 1, 16 * n + 1);
        $fatal(1);
      end
      clocks = clocks + 1;
    end
    if (errors != 0) begin
      $display("FAIL: %0d instructions at the wrong time", errors);
      $fatal(1);
    end
    $display("PASS: %0d instructions, one every 16 frames, each at the start of vsync", wanted);
    $finish;
  end

endmodule
