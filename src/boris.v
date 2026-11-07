/*
 * Boris, the BeagleBoard.org beagle, as a 32 x 43 pixel sprite.
 *
 * Pixelated from the BeagleBoard.org logo. Each letter is one pixel:
 *
 *   .  transparent         K  black outline, eye, nose
 *   W  white fur           h  hair, light brown
 *   d  hair, dark brown    O  tongue, orange
 *
 * The art is stored as text so it can be read (and edited) right here.
 * Synthesis turns the constant strings into a small lookup table.
 */

`default_nettype none

module boris (
    input  wire [5:0] row,      // 0..42, top to bottom
    input  wire [4:0] col,      // 0..31, left to right
    output reg  [2:0] colour    // one of the colour codes below
);

  localparam [2:0] CLEAR = 3'd0, BLACK = 3'd1, WHITE = 3'd2,
                   HAIR  = 3'd3, DARK  = 3'd4, TONGUE = 3'd5;

  reg [8*32-1:0] row_text;  // 32 characters, the leftmost in the top byte
  reg [7:0]      pixel;

  always @(*) begin
    case (row)
      6'd0: row_text = "...........KKKKKKK..............";
      6'd1: row_text = ".........KKhhhhWhhKK............";
      6'd2: row_text = "........KhhhhhhhhhhhK...........";
      6'd3: row_text = "......KKhKKhhhhhWhhhhK..........";
      6'd4: row_text = ".....KhhhhKhhhhhhWhhhK..........";
      6'd5: row_text = "....KhhhhhhKhhhhhWhhhKK.........";
      6'd6: row_text = "....KhhhhhhKhhKKhhWhKKK.........";
      6'd7: row_text = "...KKhhhhhhhhKKKKhWWWKKK........";
      6'd8: row_text = "...KhhhhhhhhKhKKhhWWWWWWKK......";
      6'd9: row_text = "..KKhhhhhhhhKhhhhhWWWWWWWWKK....";
      6'd10: row_text = "..KhhhhhhhhhKhhhhhWWWWWWWWWWK...";
      6'd11: row_text = "..KhhhhhhhhhhKhhhWWWWWWWWWWKKWK.";
      6'd12: row_text = ".KhhhhhhhhhhhKhhWWWWWWWWWWKWWKK.";
      6'd13: row_text = ".KhhhhhhhhhhhKhWWWWWWWWWWKKKKKKK";
      6'd14: row_text = "KKhhhhhhhhhhhhKWWWWWWWWWWKKKKKK.";
      6'd15: row_text = "KhhhhhhhhhhhhhKWWWWWWWWWWWKKKKK.";
      6'd16: row_text = "KhhhhhhhhhhhdhKWWWWWWWWWWWWWWWK.";
      6'd17: row_text = "KhhhhhhhhhhddhKhWWWWWWWWWWWWWKK.";
      6'd18: row_text = "KKhhhhhhhhdddhKhWWWWWWWWWWWKKKK.";
      6'd19: row_text = ".KhhhhhhhdddhKhhWWWWWWWWKKKKOOK.";
      6'd20: row_text = ".KKhhhhddddhhKhhhWWWKKKKKKKOOOK.";
      6'd21: row_text = "..KKKhhhhhhKKhhhhWWWKKKKKKKKOOK.";
      6'd22: row_text = ".KK.KKKKKKKhhhhhWWWWWWWKKKKKKKK.";
      6'd23: row_text = "KKK...KhhhhWWWWWWWWKKKhK........";
      6'd24: row_text = "KKWK.KhhhWWWWWWWWWWWhhhK........";
      6'd25: row_text = ".KhK.KhhhWWWWWWWWWWWWhhhK.......";
      6'd26: row_text = ".KhhKKhhWWWWWWWWWWWWWhhhK.......";
      6'd27: row_text = ".KKhKKhhWWWWWWWWWWWWWhhhK.......";
      6'd28: row_text = "..KhhKhhKWWWWWWWWWWWWKhhK.......";
      6'd29: row_text = "..KKhhhhKWWWWWWWWWWWWKhhK.......";
      6'd30: row_text = "...KhhhhKWWWWWWWWWWWWKhhK.......";
      6'd31: row_text = "...KKhhhKWWWKWWWWKWWWKhhK.......";
      6'd32: row_text = "....KKhhKWWWKWWWWKWWWKhhK.......";
      6'd33: row_text = ".....KhhKWWWKWWWWKWWWKhh........";
      6'd34: row_text = ".....KKhKWWWKWWWWKWWWKhK........";
      6'd35: row_text = ".....KhhKWWWKWWWWKWWWKhhK.......";
      6'd36: row_text = "....KhhhKWWWKWWWWKWWWKhhhK......";
      6'd37: row_text = "...KKhhhWWWWKWWWWKWWWKhhhK......";
      6'd38: row_text = "...KhhhKWWWWKKKKKKWWWWKhhh......";
      6'd39: row_text = "...KKhhKWWWWKKWWKKWWWWKhhK......";
      6'd40: row_text = "....KKKWWWWWKWWWKKWWWWWKK.......";
      6'd41: row_text = "......KKKKKKKWWWWKKKKKKK........";
      6'd42: row_text = "......KKKKKWWWWWWWKKKKK.........";
      default: row_text = "................................";
    endcase

    pixel = row_text[8*(31 - col) +: 8];

    case (pixel)
      "K":     colour = BLACK;
      "W":     colour = WHITE;
      "h":     colour = HAIR;
      "d":     colour = DARK;
      "O":     colour = TONGUE;
      default: colour = CLEAR;
    endcase
  end

endmodule
