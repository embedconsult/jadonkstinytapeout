/*
 * A tiny font: 6 x 8 pixels per letter, and only the letters the screen
 * needs: the digits, ':', '>', the box names a..e, "take" and "add", and
 * "bbb.io/minsky".
 * Each glyph is drawn with '#' for ink and '.' for paper, top row first,
 * so you can read the font right here.
 *
 * Letters are numbered (not ASCII) to keep the lookup table small:
 *   0..9 are the digits themselves, 10 ':', 11 '>',
 *   12..16 'a'..'e', 17 'k', 18 't',
 *   19 'i', 20 'o', 21 '.', 22 '/', 23 'm', 24 'n', 25 's', 26 'y', 31 blank.
 * So a digit n is simply letter n, and box b is letter 12 + b.
 *
 * The table is looked up one row at a time, a letter and a row giving six
 * bits, rather than a whole 8 x 6 glyph at once: some simulators, such as
 * vga-playground.com, cannot hold a table of 384-bit glyphs.
 */

`default_nettype none

module font (
    input  wire [4:0] letter,   // letter number, see above
    input  wire [2:0] row,      // 0..7, top to bottom
    input  wire [2:0] col,      // 0..7, left to right (6 and 7 are spacing)
    output wire       ink
);

  // One row of a glyph, from its picture: '#' is ink, leftmost pixel in bit 5.
  function [5:0] r(input [8*6-1:0] picture);
    integer i;
    for (i = 0; i < 6; i = i + 1) r[i] = (picture[8*i +: 8] == "#");
  endfunction

  reg [5:0] bits;               // the row: bit 5 is column 0

  always @(*) begin
    case ({letter, row})
      // 0
      {5'd0, 3'd0}: bits = r(".####.");
      {5'd0, 3'd1}: bits = r("#....#");
      {5'd0, 3'd2}: bits = r("#...##");
      {5'd0, 3'd3}: bits = r("#..#.#");
      {5'd0, 3'd4}: bits = r("#.#..#");
      {5'd0, 3'd5}: bits = r("##...#");
      {5'd0, 3'd6}: bits = r(".####.");
      {5'd0, 3'd7}: bits = r("......");
      // 1
      {5'd1, 3'd0}: bits = r("..#...");
      {5'd1, 3'd1}: bits = r(".##...");
      {5'd1, 3'd2}: bits = r("..#...");
      {5'd1, 3'd3}: bits = r("..#...");
      {5'd1, 3'd4}: bits = r("..#...");
      {5'd1, 3'd5}: bits = r("..#...");
      {5'd1, 3'd6}: bits = r(".###..");
      {5'd1, 3'd7}: bits = r("......");
      // 2
      {5'd2, 3'd0}: bits = r(".####.");
      {5'd2, 3'd1}: bits = r("#....#");
      {5'd2, 3'd2}: bits = r(".....#");
      {5'd2, 3'd3}: bits = r("...##.");
      {5'd2, 3'd4}: bits = r(".##...");
      {5'd2, 3'd5}: bits = r("#.....");
      {5'd2, 3'd6}: bits = r("######");
      {5'd2, 3'd7}: bits = r("......");
      // 3
      {5'd3, 3'd0}: bits = r(".####.");
      {5'd3, 3'd1}: bits = r("#....#");
      {5'd3, 3'd2}: bits = r(".....#");
      {5'd3, 3'd3}: bits = r("..###.");
      {5'd3, 3'd4}: bits = r(".....#");
      {5'd3, 3'd5}: bits = r("#....#");
      {5'd3, 3'd6}: bits = r(".####.");
      {5'd3, 3'd7}: bits = r("......");
      // 4
      {5'd4, 3'd0}: bits = r("...##.");
      {5'd4, 3'd1}: bits = r("..#.#.");
      {5'd4, 3'd2}: bits = r(".#..#.");
      {5'd4, 3'd3}: bits = r("#...#.");
      {5'd4, 3'd4}: bits = r("######");
      {5'd4, 3'd5}: bits = r("....#.");
      {5'd4, 3'd6}: bits = r("....#.");
      {5'd4, 3'd7}: bits = r("......");
      // 5
      {5'd5, 3'd0}: bits = r("######");
      {5'd5, 3'd1}: bits = r("#.....");
      {5'd5, 3'd2}: bits = r("#####.");
      {5'd5, 3'd3}: bits = r(".....#");
      {5'd5, 3'd4}: bits = r(".....#");
      {5'd5, 3'd5}: bits = r("#....#");
      {5'd5, 3'd6}: bits = r(".####.");
      {5'd5, 3'd7}: bits = r("......");
      // 6
      {5'd6, 3'd0}: bits = r("..###.");
      {5'd6, 3'd1}: bits = r(".#....");
      {5'd6, 3'd2}: bits = r("#.....");
      {5'd6, 3'd3}: bits = r("#####.");
      {5'd6, 3'd4}: bits = r("#....#");
      {5'd6, 3'd5}: bits = r("#....#");
      {5'd6, 3'd6}: bits = r(".####.");
      {5'd6, 3'd7}: bits = r("......");
      // 7
      {5'd7, 3'd0}: bits = r("######");
      {5'd7, 3'd1}: bits = r(".....#");
      {5'd7, 3'd2}: bits = r("....#.");
      {5'd7, 3'd3}: bits = r("...#..");
      {5'd7, 3'd4}: bits = r("..#...");
      {5'd7, 3'd5}: bits = r("..#...");
      {5'd7, 3'd6}: bits = r("..#...");
      {5'd7, 3'd7}: bits = r("......");
      // 8
      {5'd8, 3'd0}: bits = r(".####.");
      {5'd8, 3'd1}: bits = r("#....#");
      {5'd8, 3'd2}: bits = r("#....#");
      {5'd8, 3'd3}: bits = r(".####.");
      {5'd8, 3'd4}: bits = r("#....#");
      {5'd8, 3'd5}: bits = r("#....#");
      {5'd8, 3'd6}: bits = r(".####.");
      {5'd8, 3'd7}: bits = r("......");
      // 9
      {5'd9, 3'd0}: bits = r(".####.");
      {5'd9, 3'd1}: bits = r("#....#");
      {5'd9, 3'd2}: bits = r("#....#");
      {5'd9, 3'd3}: bits = r(".#####");
      {5'd9, 3'd4}: bits = r(".....#");
      {5'd9, 3'd5}: bits = r("....#.");
      {5'd9, 3'd6}: bits = r(".###..");
      {5'd9, 3'd7}: bits = r("......");
      // colon
      {5'd10, 3'd0}: bits = r("......");
      {5'd10, 3'd1}: bits = r("......");
      {5'd10, 3'd2}: bits = r("..##..");
      {5'd10, 3'd3}: bits = r("..##..");
      {5'd10, 3'd4}: bits = r("......");
      {5'd10, 3'd5}: bits = r("..##..");
      {5'd10, 3'd6}: bits = r("..##..");
      {5'd10, 3'd7}: bits = r("......");
      // arrow
      {5'd11, 3'd0}: bits = r("......");
      {5'd11, 3'd1}: bits = r(".#....");
      {5'd11, 3'd2}: bits = r("..#...");
      {5'd11, 3'd3}: bits = r("...#..");
      {5'd11, 3'd4}: bits = r("....#.");
      {5'd11, 3'd5}: bits = r("...#..");
      {5'd11, 3'd6}: bits = r("..#...");
      {5'd11, 3'd7}: bits = r(".#....");
      // a
      {5'd12, 3'd0}: bits = r("......");
      {5'd12, 3'd1}: bits = r("......");
      {5'd12, 3'd2}: bits = r(".####.");
      {5'd12, 3'd3}: bits = r(".....#");
      {5'd12, 3'd4}: bits = r(".#####");
      {5'd12, 3'd5}: bits = r("#....#");
      {5'd12, 3'd6}: bits = r(".#####");
      {5'd12, 3'd7}: bits = r("......");
      // b
      {5'd13, 3'd0}: bits = r("#.....");
      {5'd13, 3'd1}: bits = r("#.....");
      {5'd13, 3'd2}: bits = r("#.###.");
      {5'd13, 3'd3}: bits = r("##...#");
      {5'd13, 3'd4}: bits = r("#....#");
      {5'd13, 3'd5}: bits = r("##...#");
      {5'd13, 3'd6}: bits = r("#.###.");
      {5'd13, 3'd7}: bits = r("......");
      // c
      {5'd14, 3'd0}: bits = r("......");
      {5'd14, 3'd1}: bits = r("......");
      {5'd14, 3'd2}: bits = r(".####.");
      {5'd14, 3'd3}: bits = r("#.....");
      {5'd14, 3'd4}: bits = r("#.....");
      {5'd14, 3'd5}: bits = r("#.....");
      {5'd14, 3'd6}: bits = r(".####.");
      {5'd14, 3'd7}: bits = r("......");
      // d
      {5'd15, 3'd0}: bits = r(".....#");
      {5'd15, 3'd1}: bits = r(".....#");
      {5'd15, 3'd2}: bits = r(".###.#");
      {5'd15, 3'd3}: bits = r("#...##");
      {5'd15, 3'd4}: bits = r("#....#");
      {5'd15, 3'd5}: bits = r("#...##");
      {5'd15, 3'd6}: bits = r(".###.#");
      {5'd15, 3'd7}: bits = r("......");
      // e
      {5'd16, 3'd0}: bits = r("......");
      {5'd16, 3'd1}: bits = r("......");
      {5'd16, 3'd2}: bits = r(".####.");
      {5'd16, 3'd3}: bits = r("#....#");
      {5'd16, 3'd4}: bits = r("######");
      {5'd16, 3'd5}: bits = r("#.....");
      {5'd16, 3'd6}: bits = r(".####.");
      {5'd16, 3'd7}: bits = r("......");
      // k
      {5'd17, 3'd0}: bits = r("#.....");
      {5'd17, 3'd1}: bits = r("#.....");
      {5'd17, 3'd2}: bits = r("#...#.");
      {5'd17, 3'd3}: bits = r("#..#..");
      {5'd17, 3'd4}: bits = r("###...");
      {5'd17, 3'd5}: bits = r("#..#..");
      {5'd17, 3'd6}: bits = r("#...#.");
      {5'd17, 3'd7}: bits = r("......");
      // t
      {5'd18, 3'd0}: bits = r("..#...");
      {5'd18, 3'd1}: bits = r("..#...");
      {5'd18, 3'd2}: bits = r(".####.");
      {5'd18, 3'd3}: bits = r("..#...");
      {5'd18, 3'd4}: bits = r("..#...");
      {5'd18, 3'd5}: bits = r("..#...");
      {5'd18, 3'd6}: bits = r("...##.");
      {5'd18, 3'd7}: bits = r("......");
      // i
      {5'd19, 3'd0}: bits = r("..#...");
      {5'd19, 3'd1}: bits = r("......");
      {5'd19, 3'd2}: bits = r(".##...");
      {5'd19, 3'd3}: bits = r("..#...");
      {5'd19, 3'd4}: bits = r("..#...");
      {5'd19, 3'd5}: bits = r("..#...");
      {5'd19, 3'd6}: bits = r(".###..");
      {5'd19, 3'd7}: bits = r("......");
      // o
      {5'd20, 3'd0}: bits = r("......");
      {5'd20, 3'd1}: bits = r("......");
      {5'd20, 3'd2}: bits = r(".####.");
      {5'd20, 3'd3}: bits = r("#....#");
      {5'd20, 3'd4}: bits = r("#....#");
      {5'd20, 3'd5}: bits = r("#....#");
      {5'd20, 3'd6}: bits = r(".####.");
      {5'd20, 3'd7}: bits = r("......");
      // .
      {5'd21, 3'd0}: bits = r("......");
      {5'd21, 3'd1}: bits = r("......");
      {5'd21, 3'd2}: bits = r("......");
      {5'd21, 3'd3}: bits = r("......");
      {5'd21, 3'd4}: bits = r("......");
      {5'd21, 3'd5}: bits = r(".##...");
      {5'd21, 3'd6}: bits = r(".##...");
      {5'd21, 3'd7}: bits = r("......");
      // /
      {5'd22, 3'd0}: bits = r(".....#");
      {5'd22, 3'd1}: bits = r("....#.");
      {5'd22, 3'd2}: bits = r("....#.");
      {5'd22, 3'd3}: bits = r("...#..");
      {5'd22, 3'd4}: bits = r("..#...");
      {5'd22, 3'd5}: bits = r(".#....");
      {5'd22, 3'd6}: bits = r(".#....");
      {5'd22, 3'd7}: bits = r("#.....");
      // m
      {5'd23, 3'd0}: bits = r("......");
      {5'd23, 3'd1}: bits = r("......");
      {5'd23, 3'd2}: bits = r("##.##.");
      {5'd23, 3'd3}: bits = r("#.#..#");
      {5'd23, 3'd4}: bits = r("#.#..#");
      {5'd23, 3'd5}: bits = r("#.#..#");
      {5'd23, 3'd6}: bits = r("#.#..#");
      {5'd23, 3'd7}: bits = r("......");
      // n
      {5'd24, 3'd0}: bits = r("......");
      {5'd24, 3'd1}: bits = r("......");
      {5'd24, 3'd2}: bits = r("#.###.");
      {5'd24, 3'd3}: bits = r("##...#");
      {5'd24, 3'd4}: bits = r("#....#");
      {5'd24, 3'd5}: bits = r("#....#");
      {5'd24, 3'd6}: bits = r("#....#");
      {5'd24, 3'd7}: bits = r("......");
      // s
      {5'd25, 3'd0}: bits = r("......");
      {5'd25, 3'd1}: bits = r("......");
      {5'd25, 3'd2}: bits = r(".#####");
      {5'd25, 3'd3}: bits = r("#.....");
      {5'd25, 3'd4}: bits = r(".####.");
      {5'd25, 3'd5}: bits = r(".....#");
      {5'd25, 3'd6}: bits = r("#####.");
      {5'd25, 3'd7}: bits = r("......");
      // y
      {5'd26, 3'd0}: bits = r("......");
      {5'd26, 3'd1}: bits = r("......");
      {5'd26, 3'd2}: bits = r("#....#");
      {5'd26, 3'd3}: bits = r("#....#");
      {5'd26, 3'd4}: bits = r("#....#");
      {5'd26, 3'd5}: bits = r(".#####");
      {5'd26, 3'd6}: bits = r(".....#");
      {5'd26, 3'd7}: bits = r(".####.");
      default: bits = 6'b000000;  // blank
    endcase
  end

  assign ink = (col < 3'd6) && bits[3'd5 - col];

endmodule
