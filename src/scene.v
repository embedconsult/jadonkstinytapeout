/*
 * What is on the screen, as a function of the pixel position.
 *
 * Positions are in "machine pixels": x is 0..319 (each one two monitor
 * pixels wide) and y is 0..479. Every region starts on a multiple of a
 * power of two, so finding a sprite or letter pixel needs only shifts and
 * small subtractions, never a divider.
 *
 *   y 112..255   left:  the demo program's five boxes, a..e, with their pebbles
 *                right: the demo program's listing, with ">" at the running line
 *   y 352..383   "bbb.io/minsky" in BeagleBoard.org colours, big letters
 */

`default_nettype none

module scene (
    input  wire [8:0]  x,
    input  wire [8:0]  y,
    input  wire [3:0]  demo_line,    // the demo program's running instruction
    input  wire [19:0] demo_boxes,   // pebbles in boxes a..e, 4 bits each: {e, d, c, b, a}
    output reg  [5:0]  rgb           // {R[1:0], G[1:0], B[1:0]}
);

  // BeagleBoard.org brand colours, as close as 2 bits per channel allow.
  localparam [5:0] BEAGLE_BLUE   = 6'b00_10_11;  // #23B0E6
  localparam [5:0] TONGUE_ORANGE = 6'b11_01_00;  // #F26935
  localparam [5:0] HAIR_BROWN    = 6'b10_01_00;  // #AB833C
  localparam [5:0] CHECK_GREEN   = 6'b10_11_01;  // #8EC969
  localparam [5:0] LIGHT_GRAY    = 6'b10_10_10;  // #CBCCCE
  localparam [5:0] WHITE         = 6'b11_11_11;

  // ---------------------------------------------------------------------
  // The five boxes (drawn as cups), a..e, 32 machine pixels apart from x = 32
  // ---------------------------------------------------------------------
  //   within a cup's 32 columns: 2..3 wall, 4..19 within_cup, 20..21 wall
  //   within_cup: two columns of pebbles, six rows, filled from the bottom
  wire [8:0] from_cups   = x - 9'd32;
  wire [2:0] cup         = from_cups[7:5];          // 0..4 for a..e
  wire [4:0] across      = from_cups[4:0];
  wire       in_cup_cols = (x >= 9'd32) && (x < 9'd192);
  wire       within_cup      = (across >= 5'd4) && (across < 5'd20);
  wire       side_wall   = (across == 5'd2) || (across == 5'd3) || (across == 5'd20) || (across == 5'd21);
  wire       cup_wall    = in_cup_cols &&
                           (((y >= 9'd128) && (y < 9'd228) && side_wall) ||
                            ((y >= 9'd224) && (y < 9'd228) && (across >= 5'd2) && (across < 5'd22)));

  wire [3:0] pebbles_here   = demo_boxes[4*cup +: 4];
  wire [8:0] up_from_bottom = 9'd223 - y;           // 0 on the bottom row of the cup
  wire [2:0] pebble_row     = up_from_bottom[6:4];  // 0..5
  wire [4:0] across_inside  = across - 5'd4;
  wire       pebble_col     = across_inside[3];     // 0 or 1
  wire       pebble_shape   = (across_inside[2:0] < 3'd6) && (y[3:0] >= 4'd2) && (y[3:0] < 4'd14);
  wire       pebble         = in_cup_cols && within_cup && (y >= 9'd128) && (y < 9'd224) && pebble_shape &&
                              ({pebble_row, pebble_col} < pebbles_here);

  // ---------------------------------------------------------------------
  // The listing, generated from the same table the machine runs
  // ---------------------------------------------------------------------
  //   letter: 0 marker, 1 line number, 2 ':', 4..7 "take"/"add ",
  //           9 box, 11 next line, 13 line to go to if the box is empty
  wire [8:0] from_listing      = x - 9'd200;
  wire [3:0] listing_col       = from_listing[6:3];  // letter 0..13
  wire [4:0] listing_line_wide = y[8:4] - 5'd7;      // y 112..271 -> lines 0..9
  wire [3:0] listing_line      = listing_line_wide[3:0];
  wire       in_listing        = (y >= 9'd112) && (y < 9'd272) && (x >= 9'd200) && (x < 9'd312);
  wire       running_line      = (listing_line == demo_line);

  wire       line_is_take;
  wire [2:0] line_box;
  wire [3:0] line_next, line_if_empty;

  demo_program listing (
      .line    (listing_line),
      .is_take (line_is_take),
      .box     (line_box),
      .next    (line_next),
      .if_empty(line_if_empty)
  );

  // Letter numbers in the font (see font.v): digits are themselves.
  localparam [4:0] COLON = 5'd10, ARROW = 5'd11, LETTER_A = 5'd12, LETTER_B = 5'd13,
                   LETTER_D = 5'd15, LETTER_E = 5'd16, LETTER_K = 5'd17, LETTER_T = 5'd18,
                   LETTER_I = 5'd19, LETTER_O = 5'd20, DOT = 5'd21, SLASH = 5'd22,
                   LETTER_M = 5'd23, LETTER_N = 5'd24, LETTER_S = 5'd25, LETTER_Y = 5'd26,
                   BLANK = 5'd31;

  reg [4:0] listing_letter;
  always @(*) begin
    case (listing_col)
      4'd0:    listing_letter = running_line ? ARROW : BLANK;
      4'd1:    listing_letter = {1'b0, listing_line};
      4'd2:    listing_letter = COLON;
      // "take" or "add "
      4'd4:    listing_letter = line_is_take ? LETTER_T : LETTER_A;
      4'd5:    listing_letter = line_is_take ? LETTER_A : LETTER_D;
      4'd6:    listing_letter = line_is_take ? LETTER_K : LETTER_D;
      4'd7:    listing_letter = line_is_take ? LETTER_E : BLANK;
      4'd9:    listing_letter = LETTER_A + {2'b0, line_box};
      4'd11:   listing_letter = {1'b0, line_next};
      4'd13:   listing_letter = line_is_take ? {1'b0, line_if_empty} : BLANK;
      default: listing_letter = BLANK;
    endcase
  end

  // ---------------------------------------------------------------------
  // "bbb.io/minsky", in big letters
  // ---------------------------------------------------------------------
  // 13 letters, 16 machine pixels apart, from x = 48 (letter cells 3..15)
  wire       in_link     = (y >= 9'd352) && (y < 9'd384) && (x >= 9'd48) && (x < 9'd256);
  wire [4:0] link_index  = x[8:4] - 5'd3;           // 0..12

  reg [4:0] link_letter;
  always @(*) begin
    case (link_index)
      5'd0, 5'd1, 5'd2: link_letter = LETTER_B;    // b b b
      5'd3:    link_letter = DOT;                  // .
      5'd4:    link_letter = LETTER_I;             // i
      5'd5:    link_letter = LETTER_O;             // o
      5'd6:    link_letter = SLASH;                // /
      5'd7:    link_letter = LETTER_M;             // m
      5'd8:    link_letter = LETTER_I;             // i
      5'd9:    link_letter = LETTER_N;             // n
      5'd10:   link_letter = LETTER_S;             // s
      5'd11:   link_letter = LETTER_K;             // k
      5'd12:   link_letter = LETTER_Y;             // y
      default: link_letter = BLANK;
    endcase
  end

  // ---------------------------------------------------------------------
  // All the text, through one font
  // ---------------------------------------------------------------------
  // Letters are 6 x 8 font pixels. Small letters: each font pixel is
  // 1 machine pixel wide and 2 lines tall. Big letters: 2 wide, 4 tall.
  reg  [4:0] letter;
  reg  [2:0] font_row, font_col;
  reg  [5:0] text_colour;
  wire       ink;
  wire       in_cup_label = (y >= 9'd240) && (y < 9'd256) && in_cup_cols && (across[4:3] == 2'd1);

  always @(*) begin
    letter      = BLANK;
    font_row    = y[3:1];                          // small letters
    font_col    = x[2:0];
    text_colour = LIGHT_GRAY;
    if (in_link) begin
      letter      = link_letter;
      font_row    = y[4:2];                        // big letters
      font_col    = x[3:1];
      text_colour = (link_index < 5'd6) ? HAIR_BROWN : TONGUE_ORANGE;  // "bbb.io" + "/minsky"
    end else if (in_listing) begin
      letter      = listing_letter;
      text_colour = running_line ? (listing_col == 4'd0 ? TONGUE_ORANGE : WHITE) : LIGHT_GRAY;
    end else if (in_cup_label) begin                   // box names a..e under the cups
      letter      = LETTER_A + {2'b0, cup};
      text_colour = WHITE;
    end
  end

  font letters (
      .letter(letter),
      .row   (font_row),
      .col   (font_col),
      .ink   (ink)
  );

  // ---------------------------------------------------------------------
  // Painting, front to back
  // ---------------------------------------------------------------------
  always @(*) begin
    if (ink)
      rgb = text_colour;
    else if (pebble)
      rgb = CHECK_GREEN;
    else if (cup_wall)
      rgb = LIGHT_GRAY;
    else
      rgb = BEAGLE_BLUE;
  end

endmodule
