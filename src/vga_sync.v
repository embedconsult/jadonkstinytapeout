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
 * The sync outputs are registered (they appear one clock after the
 * position they belong to), and both are active low.
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

  always @(posedge clk) begin
    if (!rst_n) begin
      hpos <= 10'd0;
      vpos <= 10'd0;
    end else begin
      hpos <= end_of_line ? 10'd0 : hpos + 10'd1;
      if (end_of_line)
        vpos <= end_of_frame ? 10'd0 : vpos + 10'd1;
    end
  end

  always @(posedge clk) begin
    hsync_n <= !(hpos >= H_SYNC_START && hpos < H_SYNC_END);
    vsync_n <= !(vpos >= V_SYNC_START && vpos < V_SYNC_END);
  end

  assign visible = (hpos < H_VISIBLE) && (vpos < V_VISIBLE);

endmodule
