/*
 * A Minsky register machine that generates VGA timing.
 *
 * Marvin Minsky showed (Computation: Finite and Infinite Machines, 1967)
 * that a machine with a few counters ("boxes of pebbles") and only two
 * instructions can compute anything a Turing machine can:
 *
 *   ADD  r          put one pebble in box r, then go to `next`
 *   TAKE r          if box r has a pebble, take one out and go to `next`;
 *                   if box r is empty, go to `if_empty` instead
 *
 * This module is such a machine. It executes one instruction per clock,
 * and its program is the VGA scan itself: every pixel is one trip around
 * a TAKE/ADD loop, so the machine draws 640x480 at 60 Hz from a 25.175 MHz
 * clock with each pixel two clocks wide (320 x 480 distinct pixels).
 *
 * Each instruction also carries three output bits -- horizontal sync,
 * vertical sync and "video on" -- which go straight to the monitor.
 *
 * The same machine also runs a second program, slowly, so you can watch
 * it: the multiplication in demo_program.v. Once every 16 frames, the
 * spare instruction slot at the end of the vertical front porch runs one
 * instruction of it. Its five boxes (a..e) and its program counter are
 * outputs, and the screen shows them.
 *
 * Why pairs of boxes? Minsky's machine has no "load a constant"
 * instruction. To count 320 pixels it TAKEs from box A while ADDing to
 * box B. At the end of the line A is empty and B holds 320, so the next
 * line counts the other way, from B back into A. Every count on the screen
 * uses such a pair, and the program comes in two mirror-image copies for
 * odd and even lines (and again for odd and even frames).
 */

`default_nettype none

module minsky_vga (
    input  wire       clk,
    input  wire       rst_n,
    output reg        hsync_n,    // horizontal sync, active low
    output reg        vsync_n,    // vertical sync, active low
    output reg        video_on,   // high while the beam is in the visible area
    output wire [8:0] x,          // pixel column, 0..319 (each pixel is 2 clocks wide)
    output wire [8:0] y,          // pixel row, 0..479
    output wire [8:0] frame,      // counts frames, for animation
    output reg  [3:0] demo_line,  // the demo program's current instruction
    output wire [19:0] demo_boxes // the demo program's boxes, 4 bits each: {e, d, c, b, a}
);

  // ---------------------------------------------------------------------
  // The boxes of pebbles (counters)
  // ---------------------------------------------------------------------
  // Box numbers. Each count uses a pair of boxes, 2n and 2n+1.
  localparam [4:0] H_VISIBLE = 5'd0;   // boxes 0, 1: pixels in a line
  localparam [4:0] H_FRONT   = 5'd2;   // boxes 2, 3: front porch
  localparam [4:0] H_SYNC    = 5'd4;   // boxes 4, 5: sync pulse
  localparam [4:0] H_BACK    = 5'd6;   // boxes 6, 7: back porch
  localparam [4:0] V_REGION  = 5'd8;   // boxes 8..15: lines in each vertical region
  localparam [4:0] FRAMES    = 5'd16;  // box 16: frame counter (only ever ADDed to)
  localparam [4:0] DEMO      = 5'd17;  // boxes 17..21: the demo program's a, b, c, d, e

  localparam NUM_BOXES = 22;

  // How many pebbles each count starts with. A TAKE/ADD loop that starts
  // with n pebbles runs 2n + 1 clocks (n round trips plus the final TAKE
  // that finds the box empty), so a line is
  //   (2*320+1) + (2*6+1) + (2*48+1) + (2*23+1) + 2 = 800 clocks:
  //   641 visible, 13 front porch, 97 sync, 49 back porch.
  // A vertical region that starts with n pebbles lasts n + 1 lines:
  //   480 visible, 10 front porch, 2 sync, 33 back porch = 525 lines.
  function [8:0] initial_pebbles(input integer box);
    case (box)
      0:  initial_pebbles = 9'd320;  // visible pixels per line
      2:  initial_pebbles = 9'd6;    // horizontal front porch
      4:  initial_pebbles = 9'd48;   // horizontal sync
      6:  initial_pebbles = 9'd23;   // horizontal back porch
      8:  initial_pebbles = 9'd479;  // visible lines
      10: initial_pebbles = 9'd9;    // vertical front porch
      12: initial_pebbles = 9'd1;    // vertical sync
      14: initial_pebbles = 9'd32;   // vertical back porch
      17: initial_pebbles = 9'd3;    // demo box a
      18: initial_pebbles = 9'd4;    // demo box b
      default: initial_pebbles = 9'd0;  // the other box of each pair starts empty
    endcase
  endfunction

  // A box only needs enough bits for the most pebbles it ever holds.
  function integer box_bits(input integer box);
    case (box)
      0, 1, 8, 9:     box_bits = 9;   // up to 320 or 479 pebbles
      16:             box_bits = 4;   // frame count: only "every 16th frame" matters
      2, 3:           box_bits = 3;   // up to 6
      4, 5:           box_bits = 6;   // up to 48
      6, 7:           box_bits = 5;   // up to 23
      10, 11:         box_bits = 4;   // up to 9
      12, 13:         box_bits = 1;   // up to 1
      14, 15:         box_bits = 6;   // up to 32
      19:             box_bits = 4;   // demo box c: up to 12
      default:        box_bits = 3;   // demo boxes a, b, d, e: up to 4
    endcase
  endfunction

  wire [8:0] box [0:NUM_BOXES-1];   // every box's count, widened to 9 bits for reading

  // ---------------------------------------------------------------------
  // The program counter
  // ---------------------------------------------------------------------
  // The program is written as one short routine, "draw a line", in 16
  // copies. The program counter says which copy we are in:
  reg       frame_odd;   // which box of each vertical pair holds the pebbles
  reg [1:0] region;      // 0 visible, 1 front porch, 2 sync, 3 back porch
  reg       line_odd;    // which box of each horizontal pair holds the pebbles
  reg [3:0] step;        // where we are in the "draw a line" routine

  // The box we TAKE from and the box we ADD to, for each kind of count.
  wire [4:0] h_from_offset = {4'b0, line_odd};
  wire [4:0] h_to_offset   = {4'b0, ~line_odd};
  wire [4:0] v_box_pair    = V_REGION + {2'b0, region, 1'b0};
  wire [4:0] v_from        = v_box_pair + {4'b0, frame_odd};
  wire [4:0] v_to          = v_box_pair + {4'b0, ~frame_odd};

  // ---------------------------------------------------------------------
  // The "draw a line" routine
  // ---------------------------------------------------------------------
  //   step  instruction                     next     if empty
  //   0     TAKE visible.from                1        2        (video on)
  //   1     ADD  visible.to                  0                 (video on)
  //   2     TAKE front.from                  3        4
  //   3     ADD  front.to                    2
  //   4     TAKE sync.from                   5        6        (hsync)
  //   5     ADD  sync.to                     4                 (hsync)
  //   6     TAKE back.from                   7        8
  //   7     ADD  back.to                     6
  //   8     TAKE region.from                 9        10
  //   9     ADD  region.to                   next line, same region
  //   10    (region over) one instruction that does not affect the picture:
  //           after the back porch:  ADD frames
  //           after the front porch: every 16th frame, one demo instruction
  //           otherwise:             TAKE back.from, which is empty, so it
  //                                  does nothing
  //                                          first line of the next region
  //
  // Both ways out of step 8 take two clocks, so every line is 800 clocks.
  reg        is_take;
  reg [4:0]  which_box;
  reg [3:0]  next_step;
  reg [3:0]  empty_step;
  reg        end_of_line;      // step 9 or 10: the next instruction starts a new line
  reg        end_of_region;    // step 10
  reg        demo_turn;        // step 10 is running the demo program

  wire       demo_is_take;
  wire [2:0] demo_box;
  wire [3:0] demo_next, demo_if_empty;

  demo_program demo (
      .line    (demo_line),
      .is_take (demo_is_take),
      .box     (demo_box),
      .next    (demo_next),
      .if_empty(demo_if_empty)
  );

  always @(*) begin
    end_of_line   = 1'b0;
    end_of_region = 1'b0;
    demo_turn     = 1'b0;
    empty_step    = 4'd0;
    case (step)
      4'd0:    begin is_take = 1; which_box = H_VISIBLE + h_from_offset; next_step = 4'd1; empty_step = 4'd2;  end
      4'd1:    begin is_take = 0; which_box = H_VISIBLE + h_to_offset;   next_step = 4'd0;                     end
      4'd2:    begin is_take = 1; which_box = H_FRONT + h_from_offset;   next_step = 4'd3; empty_step = 4'd4;  end
      4'd3:    begin is_take = 0; which_box = H_FRONT + h_to_offset;     next_step = 4'd2;                     end
      4'd4:    begin is_take = 1; which_box = H_SYNC + h_from_offset;    next_step = 4'd5; empty_step = 4'd6;  end
      4'd5:    begin is_take = 0; which_box = H_SYNC + h_to_offset;      next_step = 4'd4;                     end
      4'd6:    begin is_take = 1; which_box = H_BACK + h_from_offset;    next_step = 4'd7; empty_step = 4'd8;  end
      4'd7:    begin is_take = 0; which_box = H_BACK + h_to_offset;      next_step = 4'd6;                     end
      4'd8:    begin is_take = 1; which_box = v_from;                    next_step = 4'd9; empty_step = 4'd10; end
      4'd9:    begin is_take = 0; which_box = v_to;                      next_step = 4'd0; end_of_line = 1;    end
      default: begin  // step 10
        if (region == 2'd3) begin
          is_take = 0; which_box = FRAMES;
        end else if (region == 2'd1 && frame[3:0] == 4'd0) begin
          is_take = demo_is_take; which_box = DEMO + {2'b0, demo_box}; demo_turn = 1;
        end else begin
          is_take = 1; which_box = H_BACK + h_from_offset;
        end
        next_step = 4'd0; end_of_line = 1; end_of_region = 1;
      end
    endcase
  end

  // ---------------------------------------------------------------------
  // Executing one instruction per clock
  // ---------------------------------------------------------------------
  wire [8:0] pebbles   = box[which_box];
  wire       box_empty = (pebbles == 9'd0);

  wire       write_box = !is_take || !box_empty;   // ADD always; TAKE only if not empty
  wire [8:0] new_count = is_take ? pebbles - 9'd1 : pebbles + 9'd1;

  genvar b;
  generate
    for (b = 0; b < NUM_BOXES; b = b + 1) begin : boxes
      localparam integer BITS = box_bits(b);
      reg [BITS-1:0] count;
      always @(posedge clk) begin
        if (!rst_n)
          count <= initial_pebbles(b);
        else if (write_box && which_box == b)
          count <= new_count[BITS-1:0];
      end
      assign box[b] = {{(9 - BITS){1'b0}}, count};
    end
  endgenerate

  always @(posedge clk) begin
    if (!rst_n) begin
      frame_odd <= 1'b0;
      region    <= 2'd0;
      line_odd  <= 1'b0;
      step      <= 4'd0;
      demo_line <= 4'd0;
    end else begin
      // Choose the next instruction.
      if (is_take && box_empty) step <= empty_step;
      else                      step <= next_step;

      if (demo_turn) begin
        if (is_take && box_empty) demo_line <= demo_if_empty;
        else                      demo_line <= demo_next;
      end

      if (end_of_line) line_odd <= ~line_odd;
      if (end_of_region) begin
        region <= region + 2'd1;
        if (region == 2'd3) frame_odd <= ~frame_odd;
      end
    end
  end

  // ---------------------------------------------------------------------
  // What the monitor sees
  // ---------------------------------------------------------------------
  // The sync and video bits belong to each instruction. They are
  // registered so they line up with the pixel colour, which is computed
  // from this clock's box contents and registered in the top module.
  always @(posedge clk) begin
    hsync_n  <= !(step == 4'd4 || step == 4'd5);
    vsync_n  <= !(region == 2'd2);
    video_on <= (region == 2'd0) && (step == 4'd0 || step == 4'd1);
  end

  // The pixel being drawn is the count in the box being filled.
  assign x     = box[H_VISIBLE + h_to_offset];
  assign y     = box[V_REGION + {4'b0, ~frame_odd}];
  assign frame = box[FRAMES];
  assign demo_boxes = {box[DEMO + 4][3:0], box[DEMO + 3][3:0], box[DEMO + 2][3:0],
                       box[DEMO + 1][3:0], box[DEMO][3:0]};

endmodule
