/*
 * Boris, the BeagleBoard.org beagle, as a 16 x 21 pixel sprite.
 *
 * Drawn by hand from the BeagleBoard.org logo, small enough to fit on a
 * one-tile chip. Each letter is one pixel:
 *
 *   .  transparent         K  black outline, eye, nose
 *   W  white fur           h  hair, brown (and the tongue: see below)
 *
 * The art is stored as text so it can be read (and edited) right here.
 * Synthesis turns the constant strings into a small lookup table.
 *
 * To save space on the chip, the table only stores four kinds of pixel.
 * The tongue is stored as hair ("h"), and painted orange because it is the
 * only hair inside the small rectangle around the mouth (rows 8..9,
 * columns 13..14).
 */

`default_nettype none

module boris (
    input  wire [4:0] row,      // 0..20, top to bottom
    input  wire [3:0] col,      // 0..15, left to right
    output reg  [2:0] colour    // one of the colour codes below
);

  localparam [2:0] CLEAR = 3'd0, BLACK = 3'd1, WHITE = 3'd2,
                   HAIR  = 3'd3, TONGUE = 3'd5;

  reg [8*16-1:0] row_text;  // 16 characters, the leftmost in the top byte
  reg [7:0]      pixel;
  wire           at_mouth = (row >= 5'd8) && (row <= 5'd9) && (col >= 4'd13) && (col <= 4'd14);

  always @(*) begin
    case (row)
      5'd0:  row_text = ".....KKKKK......";
      5'd1:  row_text = "...KKhhhhWK.....";
      5'd2:  row_text = "..KhhhKhhWhK....";
      5'd3:  row_text = ".KhhhhKhhWWKK...";
      5'd4:  row_text = ".KhhhhKhWKWWWK..";
      5'd5:  row_text = "KhhhhhKhWWWWWWK.";
      5'd6:  row_text = "KhhhhhKWWWWWWKKK";
      5'd7:  row_text = "KhhhhhKWWWWWWKKK";
      5'd8:  row_text = "KhhhhhKWWWWKKhhK";
      5'd9:  row_text = "KhhhhhhKWWKKKhK.";
      5'd10: row_text = ".KhhhhhKWWWWKK..";
      5'd11: row_text = ".KKKhhhWWWWWhK..";
      5'd12: row_text = "KhK.KhWWWWWWhhK.";
      5'd13: row_text = ".KhKKhWWWWWWWhK.";
      5'd14: row_text = ".KhhKhWWWWWWWhK.";
      5'd15: row_text = "..KhKhWWWWWWWhK.";
      5'd16: row_text = "..KhKhWWKWWWWhK.";
      5'd17: row_text = "..KhKhWWKWWWWhK.";
      5'd18: row_text = "..KhKKWWKWWKKhK.";
      5'd19: row_text = "..KKKWWWKWWWWKK.";
      5'd20: row_text = "....KKKKKKKKKK..";
      default: row_text = "................";
    endcase

    pixel = row_text[8*(15 - col) +: 8];

    case (pixel)
      "K":     colour = BLACK;
      "W":     colour = WHITE;
      "h":     colour = at_mouth ? TONGUE : HAIR;
      default: colour = CLEAR;
    endcase
  end

endmodule
