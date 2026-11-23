/*
 * Run the counting machine's program one instruction at a time and check
 * every instruction against a reference model written from the table in
 * docs/info.md and src/demo_program.v.
 *
 *   iverilog -g2012 -o program_trace.vvp program_trace.v ../src/minsky_machine.v ../src/demo_program.v
 *   vvp program_trace.vvp > program_trace.txt
 *
 * The machine normally runs one instruction every 16 frames; here `step`
 * is driven directly so the whole program runs in a few hundred clocks.
 * Between instructions `step` is held low for a clock, to check that the
 * machine waits.
 *
 * It prints one line per instruction, then checks that:
 *   - every instruction does what the reference model says;
 *   - when the multiplication is done (the first time it reaches line 7,
 *     "take e"), box c holds 3 x 4 = 12, with a = 3 back as it started;
 *   - after 99 instructions the machine is exactly where it started, so it
 *     repeats forever (it was designed to restart, not to stop);
 *   - a second cycle of 99 is identical to the first.
 * It ends with PASS, or FAIL and exit status 1.
 */

`default_nettype none
`timescale 1ns / 1ps

module program_trace;

  reg        clk = 0, rst_n = 0, step = 0;
  wire [3:0] line;
  wire [19:0] boxes;

  minsky_machine dut (.clk(clk), .rst_n(rst_n), .step(step), .line(line), .boxes(boxes));

  always #5 clk = ~clk;

  // ---- The reference model: the program as the docs give it -----------
  //   line  instruction  next  if empty
  //   0     take b       1     7
  //   1     add  e       2
  //   2     take a       3     5
  //   3     add  c       4
  //   4     add  d       2
  //   5     take d       6     0
  //   6     add  a       5
  //   7     take e       8     9
  //   8     add  b       7
  //   9     take c       9     0
  reg       m_take [0:9];
  integer   m_box  [0:9];
  integer   m_next [0:9];
  integer   m_jump [0:9];
  integer   m_line;
  integer   m_r [0:4];

  task set(input integer l, input t, input integer b, input integer n, input integer j);
    begin m_take[l] = t; m_box[l] = b; m_next[l] = n; m_jump[l] = j; end
  endtask

  function [7:0] letter(input integer b);
    letter = "a" + b;
  endfunction

  // ---- Checking ---------------------------------------------------------
  integer errors = 0, n, i, cycle, done_at;
  reg [3:0] got_r [0:4];
  reg [19:0] start_boxes;
  reg [3:0]  start_line;
  reg [8*3-1:0] was;

  task compare(input integer n);
    begin
      for (i = 0; i < 5; i = i + 1) got_r[i] = boxes[4*i +: 4];
      if (line !== m_line[3:0] || got_r[0] !== m_r[0] || got_r[1] !== m_r[1] ||
          got_r[2] !== m_r[2] || got_r[3] !== m_r[3] || got_r[4] !== m_r[4]) begin
        $display("MISMATCH after instruction %0d: machine line %0d boxes a..e %0d %0d %0d %0d %0d, model line %0d boxes %0d %0d %0d %0d %0d",
                 n, line, got_r[0], got_r[1], got_r[2], got_r[3], got_r[4],
                 m_line, m_r[0], m_r[1], m_r[2], m_r[3], m_r[4]);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    set(0, 1, 1, 1, 7); set(1, 0, 4, 2, 0); set(2, 1, 0, 3, 5); set(3, 0, 2, 4, 0);
    set(4, 0, 3, 2, 0); set(5, 1, 3, 6, 0); set(6, 0, 0, 5, 0); set(7, 1, 4, 8, 9);
    set(8, 0, 1, 7, 0); set(9, 1, 2, 9, 0);
    m_line = 0; m_r[0] = 3; m_r[1] = 4; m_r[2] = 0; m_r[3] = 0; m_r[4] = 0;
    done_at = -1;

    repeat (3) @(posedge clk);
    #1 rst_n = 1;
    @(posedge clk); #1;
    compare(0);
    start_boxes = boxes; start_line = line;
    $display("instr  line  does          ->  line   a  b  c  d  e");
    $display("    0                           %2d  %2d %2d %2d %2d %2d   (start)",
             line, boxes[3:0], boxes[7:4], boxes[11:8], boxes[15:12], boxes[19:16]);

    for (n = 1; n <= 2 * 99; n = n + 1) begin
      // Model one instruction.
      if (!m_take[m_line])          begin was = "add"; m_r[m_box[m_line]] = m_r[m_box[m_line]] + 1; i = m_next[m_line]; end
      else if (m_r[m_box[m_line]]) begin was = "tak"; m_r[m_box[m_line]] = m_r[m_box[m_line]] - 1; i = m_next[m_line]; end
      else                          begin was = "jmp"; i = m_jump[m_line]; end
      $write("  %3d    %1d   %s %s%s  ->", n, m_line,
             m_take[m_line] ? "take" : "add ", letter(m_box[m_line]),
             was == "jmp" ? " (empty)" : "        ");
      m_line = i;

      // Run one instruction on the machine, then a clock with step low.
      step = 1; @(posedge clk); #1;
      step = 0; @(posedge clk); #1;
      compare(n);
      $display("  %2d  %2d %2d %2d %2d %2d", line,
               boxes[3:0], boxes[7:4], boxes[11:8], boxes[15:12], boxes[19:16]);

      if (line == 4'd7 && done_at < 0) begin
        done_at = n;
        $display("        multiplication done: c = %0d (a = %0d, b counted down to %0d, e = %0d)",
                 boxes[11:8], boxes[3:0], boxes[7:4], boxes[19:16]);
        if (boxes[11:8] !== 4'd12 || boxes[3:0] !== 4'd3) begin
          $display("FAIL: expected c = 12 and a = 3 when the multiplication is done");
          errors = errors + 1;
        end
      end
      if (n == 99 || n == 198) begin
        if (boxes !== start_boxes || line !== start_line) begin
          $display("FAIL: after %0d instructions the machine is not back where it started", n);
          errors = errors + 1;
        end else
          $display("        after %0d instructions: back to the start (line 0, a = 3, b = 4)", n);
      end
    end

    if (done_at != 77) begin
      $display("FAIL: multiplication finished at instruction %0d, expected 77", done_at);
      errors = errors + 1;
    end
    if (errors != 0) begin
      $display("FAIL: %0d errors", errors);
      $fatal(1);
    end
    $display("PASS: 3 x 4 = 12 at instruction 77; the program repeats every 99 instructions");
    $finish;
  end

endmodule
