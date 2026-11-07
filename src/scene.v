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
 *   y 288..455   Boris (16 x 21 sprite pixels, each 8 x 8 monitor pixels)
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
  localparam [5:0] BLACK         = 6'b00_00_00;

  // ---------------------------------------------------------------------
  // Boris: 16 x 21 sprite, each sprite pixel 4 x 8 machine pixels
  // ---------------------------------------------------------------------
  wire       in_boris = (x >= 9'd16) && (x < 9'd80) && (y >= 9'd288) && (y < 9'd456);
  wire [6:0] boris_col_wide = x[8:2] - 7'd4;
  wire [5:0] boris_row_wide = y[8:3] - 6'd36;
  wire [2:0] boris_colour;

  boris boris_sprite (
      .row   (boris_row_wide[4:0]),
      .col   (boris_col_wide[3:0]),
      .colour(boris_colour)
  );

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
  localparam [4:0] COLON = 5'd10, ARROW = 5'd11, LETTER_A = 5'd12, LETTER_D = 5'd15,
                   LETTER_E = 5'd16, LETTER_K = 5'd17, LETTER_T = 5'd18, BLANK = 5'd31;

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
  // All the text, through one font
  // ---------------------------------------------------------------------
  // Letters are 6 x 8 font pixels in an 8-machine-pixel cell; each font
  // pixel is 1 machine pixel wide and 2 lines tall.
  reg  [4:0] letter;
  reg  [5:0] text_colour;
  wire       ink;
  wire       in_cup_label = (y >= 9'd240) && (y < 9'd256) && in_cup_cols && (across[4:3] == 2'd1);

  always @(*) begin
    letter      = BLANK;
    text_colour = LIGHT_GRAY;
    if (in_listing) begin
      letter      = listing_letter;
      text_colour = running_line ? (listing_col == 4'd0 ? TONGUE_ORANGE : WHITE) : LIGHT_GRAY;
    end else if (in_cup_label) begin                   // box names a..e under the cups
      letter      = LETTER_A + {2'b0, cup};
      text_colour = WHITE;
    end
  end

  font letters (
      .letter(letter),
      .row   (y[3:1]),
      .col   (x[2:0]),
      .ink   (ink)
  );

  // ---------------------------------------------------------------------
  // Painting, front to back
  // ---------------------------------------------------------------------
  always @(*) begin
    if (in_boris && boris_colour != 3'd0) begin
      case (boris_colour)
        3'd1:    rgb = BLACK;
        3'd2:    rgb = WHITE;
        3'd3:    rgb = HAIR_BROWN;
        default: rgb = TONGUE_ORANGE;
      endcase
    end else if (ink)
      rgb = text_colour;
    else if (pebble)
      rgb = CHECK_GREEN;
    else if (cup_wall)
      rgb = LIGHT_GRAY;
    else
      rgb = BEAGLE_BLUE;
  end

endmodule
