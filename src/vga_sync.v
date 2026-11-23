/*
 * Standard 640 x 480 @ 60 Hz VGA timing from a 25.175 MHz clock.
 *
 * Two ordinary counters: hpos counts clocks along a line (0..799) and
 * vpos counts lines (0..524).
 *
 *              visible   front porch   sync    back porch   total
 *   clocks     0..639    640..655      656..751  752..799   800
 *   lines      0..479    480..489      490..491  492..524   525
 *
 * The sync outputs are registered, and both are active low. Each is
 * computed from the position the counters move to on the same clock edge,
 * so it always belongs to the current hpos and vpos, like the colour the
 * top level makes from them. (Computed from the current position instead,
 * it would come one clock late, and the picture would sit one pixel early:
 * a picture pixel in the back porch, and column 639 black.)
 */

`default_nettype none

module vga_sync (
    input  wire       clk,
    input  wire       rst_n,
    output reg        hsync_n,
    output reg        vsync_n,
    output wire       visible,    // the beam is in the 640 x 480 picture
    output reg  [9:0] hpos,       // 0..799
    output reg  [9:0] vpos        // 0..524
);

  localparam H_VISIBLE = 640, H_SYNC_START = 656, H_SYNC_END = 752, H_TOTAL = 800;
  localparam V_VISIBLE = 480, V_SYNC_START = 490, V_SYNC_END = 492, V_TOTAL = 525;

  wire end_of_line  = (hpos == H_TOTAL - 1);
  wire end_of_frame = (vpos == V_TOTAL - 1);

  // Where the beam is on the next clock.
  wire [9:0] next_h = end_of_line ? 10'd0 : hpos + 10'd1;
  wire [9:0] next_v = !end_of_line ? vpos : end_of_frame ? 10'd0 : vpos + 10'd1;

  always @(posedge clk) begin
    if (!rst_n) begin
      hpos <= 10'd0;
      vpos <= 10'd0;
    end else begin
      hpos <= next_h;
      vpos <= next_v;
    end
  end

  always @(posedge clk) begin
    hsync_n <= !(next_h >= H_SYNC_START && next_h < H_SYNC_END);
    vsync_n <= !(next_v >= V_SYNC_START && next_v < V_SYNC_END);
  end

  assign visible = (hpos < H_VISIBLE) && (vpos < V_VISIBLE);

endmodule
