/*
 * The program you can watch: Minsky-machine multiplication.
 *
 * Five boxes, a..e. It multiplies a by b, leaving the product in c, puts a
 * and b back the way they were, empties c, and starts again, forever.
 *
 *   line  instruction   next  if empty   what it is doing
 *   0     take b        1     7          one more pebble of b to process?
 *   1     add  e        2                remember it in e (to restore b)
 *   2     take a        3     5          copy a into c, and into d ...
 *   3     add  c        4
 *   4     add  d        2
 *   5     take d        6     0          ... then move d back into a
 *   6     add  a        5
 *   7     take e        8     9          all of b done: move e back into b
 *   8     add  b        7
 *   9     take c        9     0          empty c and start again
 *
 * The same table is read twice: by the machine, to run it, and by the
 * screen, to print it. So the listing on the screen is always exactly the
 * program that is running.
 */

`default_nettype none

module demo_program (
    input  wire [3:0] line,
    output reg        is_take,
    output reg  [2:0] box,        // 0 = a, 1 = b, ... 4 = e
    output reg  [3:0] next,
    output reg  [3:0] if_empty    // only used by take
);

  localparam ADD = 1'b0, TAKE = 1'b1;
  localparam [2:0] A = 3'd0, B = 3'd1, C = 3'd2, D = 3'd3, E = 3'd4;

  always @(*) begin
    if_empty = 4'd0;
    case (line)
      4'd0:    begin is_take = TAKE; box = B; next = 4'd1; if_empty = 4'd7; end
      4'd1:    begin is_take = ADD;  box = E; next = 4'd2;                  end
      4'd2:    begin is_take = TAKE; box = A; next = 4'd3; if_empty = 4'd5; end
      4'd3:    begin is_take = ADD;  box = C; next = 4'd4;                  end
      4'd4:    begin is_take = ADD;  box = D; next = 4'd2;                  end
      4'd5:    begin is_take = TAKE; box = D; next = 4'd6; if_empty = 4'd0; end
      4'd6:    begin is_take = ADD;  box = A; next = 4'd5;                  end
      4'd7:    begin is_take = TAKE; box = E; next = 4'd8; if_empty = 4'd9; end
      4'd8:    begin is_take = ADD;  box = B; next = 4'd7;                  end
      default: begin is_take = TAKE; box = C; next = 4'd9; if_empty = 4'd0; end
    endcase
  end

endmodule
