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
 *   y 304..431   Boris (24 x 32 sprite pixels, each 4 x 4 monitor pixels)
 *   y 336..367   "beagleboard.org", coloured like the logo
 *
 * Text comes in two sizes from one font: big letters (each font pixel
 * 2 x 4 machine pixels, letters 16 apart) and small letters (each font
 * pixel 1 x 2, letters 8 apart).
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
  // Boris: 24 x 32 sprite, each sprite pixel 2 x 4 machine pixels
  // ---------------------------------------------------------------------
  wire       in_boris = (x >= 9'd16) && (x < 9'd64) && (y >= 9'd304) && (y < 9'd432);
  wire [7:0] boris_col_wide = x[8:1] - 8'd8;
  wire [6:0] boris_row_wide = y[8:2] - 7'd76;
  wire [2:0] boris_colour;

  boris boris_sprite (
      .row   (boris_row_wide[5:0]),
      .col   (boris_col_wide[4:0]),
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

  localparam [8*4-1:0] TAKE_WORD = "take";
  localparam [8*4-1:0] ADD_WORD  = "add ";

  reg [7:0] listing_char;
  always @(*) begin
    case (listing_col)
      4'd0:    listing_char = running_line ? ">" : " ";
      4'd1:    listing_char = "0" + {4'b0, listing_line};
      4'd2:    listing_char = ":";
      4'd4, 4'd5, 4'd6, 4'd7:
               listing_char = line_is_take ? TAKE_WORD[8*(7 - listing_col) +: 8]
                                           : ADD_WORD[8*(7 - listing_col) +: 8];
      4'd9:    listing_char = "a" + {5'b0, line_box};
      4'd11:   listing_char = "0" + {4'b0, line_next};
      4'd13:   listing_char = line_is_take ? "0" + {4'b0, line_if_empty} : " ";
      default: listing_char = " ";
    endcase
  end

  // ---------------------------------------------------------------------
  // All the text, through one font
  // ---------------------------------------------------------------------
  localparam [8*15-1:0] LOGO    = "beagleboard.org";

  wire [4:0] big_cell   = x[8:4];        // big letters: 16 machine pixels apart

  reg  [7:0] char;
  reg  [2:0] font_row, font_col;
  reg  [5:0] text_colour;
  wire       ink;

  always @(*) begin
    char        = " ";
    font_row    = 3'd0;
    font_col    = x[2:0];                // small letters
    text_colour = LIGHT_GRAY;

    if (in_listing) begin                                   // listing, small
      font_row    = y[3:1];
      char        = listing_char;
      text_colour = running_line ? (listing_col == 4'd0 ? TONGUE_ORANGE : WHITE) : LIGHT_GRAY;
    end else if (y >= 9'd240 && y < 9'd256 && in_cup_cols && across[4:3] == 2'd1) begin
      font_row    = y[3:1];                                          // cup labels a..e
      char        = "a" + {5'b0, cup};
      text_colour = WHITE;
    end else if (y >= 9'd336 && y < 9'd368) begin                    // logo text, big
      font_row    = y[4:2] - 3'd4;
      font_col    = x[3:1];
      text_colour = (big_cell < 5'd11) ? HAIR_BROWN : TONGUE_ORANGE; // "beagle" + "board.org"
      if (big_cell >= 5'd5)
        char = LOGO[8*(14 - (big_cell - 5'd5)) +: 8];
    end
  end

  font letters (
      .char(char),
      .row (font_row),
      .col (font_col),
      .ink (ink)
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
