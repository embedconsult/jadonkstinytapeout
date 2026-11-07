/*
 * Boris, the BeagleBoard.org beagle, as a 24 x 32 pixel sprite.
 *
 * Pixelated from the BeagleBoard.org logo. Each letter is one pixel:
 *
 *   .  transparent         K  black outline, eye, nose
 *   W  white fur           h  hair, brown (and the tongue: see below)
 *
 * The art is stored as text so it can be read (and edited) right here.
 * Synthesis turns the constant strings into a small lookup table.
 *
 * To save space on the chip, the table only stores four kinds of pixel.
 * The tongue is stored as hair ("h"), and painted orange because it is the
 * only hair inside the small rectangle around the mouth (rows 14..16,
 * columns 20..22).
 */

`default_nettype none

module boris (
    input  wire [5:0] row,      // 0..31, top to bottom
    input  wire [4:0] col,      // 0..23, left to right
    output reg  [2:0] colour    // one of the colour codes below
);

  localparam [2:0] CLEAR = 3'd0, BLACK = 3'd1, WHITE = 3'd2,
                   HAIR  = 3'd3, TONGUE = 3'd5;

  reg [8*24-1:0] row_text;  // 24 characters, the leftmost in the top byte
  reg [7:0]      pixel;
  wire           at_mouth = (row >= 6'd14) && (row <= 6'd16) && (col >= 5'd20) && (col <= 5'd22);

  always @(*) begin
    case (row)
      6'd0:  row_text = "........KKKKKK..........";
      6'd1:  row_text = "......KhhhhhhhK.........";
      6'd2:  row_text = "....KKKKhhhhWhhK........";
      6'd3:  row_text = "...KhhhhKhhhhhhhK.......";
      6'd4:  row_text = "...KhhhhKhhhhWhhK.......";
      6'd5:  row_text = "..KhhhhhhhKKhhWWKK......";
      6'd6:  row_text = "..KhhhhhhKhKhhWWWWK.....";
      6'd7:  row_text = "..KhhhhhhKhhhWWWWWWWK...";
      6'd8:  row_text = ".KhhhhhhhKhhWWWWWWWWKKK.";
      6'd9:  row_text = ".KhhhhhhhhhhWWWWWWWKWWKK";
      6'd10: row_text = "KhhhhhhhhhKWWWWWWWWKKKKK";
      6'd11: row_text = "KhhhhhhhhhKWWWWWWWWWKKKK";
      6'd12: row_text = "KhhhhhhhhhhhWWWWWWWWWWK.";
      6'd13: row_text = "KhhhhhhhhhKhWWWWWWWWWKK.";
      6'd14: row_text = ".KhhhhhhhhKhWWWWWWKKKhh.";
      6'd15: row_text = ".KKhhhhhhKhhWWWKKKKKhhhK";
      6'd16: row_text = ".K.KKKKKhhhhWWWWWKKKKhK.";
      6'd17: row_text = "KWK.KhhhWWWWWWKKhK......";
      6'd18: row_text = "KWK.KhhWWWWWWWWhhh......";
      6'd19: row_text = ".KhKKhWWWWWWWWWWhh......";
      6'd20: row_text = ".KhKhhWWWWWWWWWWhhK.....";
      6'd21: row_text = ".KKhhhKWWWWWWWWWhhK.....";
      6'd22: row_text = "..KhhhKWWWWWWWWWhhK.....";
      6'd23: row_text = "...KhhKWWWWWWWWWhhK.....";
      6'd24: row_text = "...KKhKWWKWWWWWWhh......";
      6'd25: row_text = "....KhKWWWWWWWWWhh......";
      6'd26: row_text = "....KhWWWKWWWWWWhhK.....";
      6'd27: row_text = "...KhhWWWKWWWWWWKhhK....";
      6'd28: row_text = "..KhhKWWWKKKKWWWKhhK....";
      6'd29: row_text = "...KKKWWWKWWKWWWWKKK....";
      6'd30: row_text = "....KKWWKKWWKKWWWK......";
      6'd31: row_text = ".....KKKKWWWWKKKK.......";
      default: row_text = "........................";
    endcase

    pixel = (col < 5'd24) ? row_text[8*(23 - col) +: 8] : ".";

    case (pixel)
      "K":      colour = BLACK;
      "W":      colour = WHITE;
      "h":      colour = at_mouth ? TONGUE : HAIR;
      default:  colour = CLEAR;
    endcase
  end

endmodule
