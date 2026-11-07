/*
 * A Minsky register machine.
 *
 * Marvin Minsky showed (Computation: Finite and Infinite Machines, 1967)
 * that a machine with a few counters ("boxes of pebbles") and only two
 * instructions can compute anything a Turing machine can:
 *
 *   ADD  r          put one pebble in box r, then go to `next`
 *   TAKE r          if box r has a pebble, take one out and go to `next`;
 *                   if box r is empty, go to `if_empty` instead
 *
 * This machine has five boxes, a..e, and runs the program in
 * demo_program.v. It executes one instruction each time `step` is high,
 * which the top level arranges once every 16 frames, slowly enough to
 * watch. Its boxes and its program counter are what the screen shows.
 */

`default_nettype none

module minsky_machine (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        step,        // run one instruction on this clock
    output reg  [3:0]  line,        // the program counter: the running instruction
    output wire [19:0] boxes        // pebbles in each box, 4 bits each: {e, d, c, b, a}
);

  // The boxes, with the pebbles they start with.
  localparam [3:0] START_A = 4'd3, START_B = 4'd4;

  reg [3:0] box [0:4];
  assign boxes = {box[4], box[3], box[2], box[1], box[0]};

  // The current instruction.
  wire       is_take;
  wire [2:0] which;
  wire [3:0] next, if_empty;

  demo_program instructions (
      .line    (line),
      .is_take (is_take),
      .box     (which),
      .next    (next),
      .if_empty(if_empty)
  );

  wire [3:0] pebbles = box[which];
  wire       empty   = (pebbles == 4'd0);

  integer i;
  always @(posedge clk) begin
    if (!rst_n) begin
      for (i = 0; i < 5; i = i + 1) box[i] <= 4'd0;
      box[0] <= START_A;
      box[1] <= START_B;
      line   <= 4'd0;
    end else if (step) begin
      if (!is_take) begin                 // ADD: one more pebble, go on
        box[which] <= pebbles + 4'd1;
        line       <= next;
      end else if (!empty) begin          // TAKE from a box with pebbles
        box[which] <= pebbles - 4'd1;
        line       <= next;
      end else begin                      // TAKE from an empty box: jump
        line       <= if_empty;
      end
    end
  end

endmodule
