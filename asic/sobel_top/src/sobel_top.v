// sobel_top.v — Sobel de bordes AUTOCONTENIDO para ASIC (sky130), datapath de Victor.
//   Stream raster de pixeles (in_valid/in_pix 8-bit) -> ventana 3x3 (linebuf3x3) ->
//   |Gx|+|Gy| (satura a 255) -> umbral -> out_pix (FF=borde / 00=plano).
// Misma matematica que el SoC femto (cam_femto_display.v), sin CPU ni camara: listo para OpenLane.
module sobel_top (
    input  wire       clk,
    input  wire       reset,       // sincrono, activo-alto
    input  wire       in_valid,
    input  wire [7:0] in_pix,
    input  wire [7:0] thr,         // umbral de borde
    output reg        out_valid,
    output reg  [7:0] out_pix      // 8'hFF borde / 8'h00 plano
);
    // ventana 3x3 por line-buffers
    wire [7:0] w00,w01,w02, w10,w11,w12, w20,w21,w22;
    wire       vin;
    linebuf3x3 #(.W(60), .DW(8)) LB (
        .clk(clk), .in_valid(in_valid), .in_pix(in_pix), .valid_o(vin),
        .w00(w00),.w01(w01),.w02(w02), .w10(w10),.w11(w11),.w12(w12),
        .w20(w20),.w21(w21),.w22(w22));

    // Sobel 3x3: Gx/Gy con centro x2, magnitud Manhattan |Gx|+|Gy|
    wire [10:0] gxp = w02 + (w12<<1) + w22;
    wire [10:0] gxn = w00 + (w10<<1) + w20;
    wire [10:0] gyp = w20 + (w21<<1) + w22;
    wire [10:0] gyn = w00 + (w01<<1) + w02;
    wire [10:0] agx = (gxp>=gxn) ? (gxp-gxn) : (gxn-gxp);
    wire [10:0] agy = (gyp>=gyn) ? (gyp-gyn) : (gyn-gyp);
    wire [11:0] mag12 = agx + agy;
    wire [7:0]  mag = (mag12 > 12'd255) ? 8'd255 : mag12[7:0];

    always @(posedge clk) begin
        if (reset) begin out_valid <= 1'b0; out_pix <= 8'd0; end
        else begin
            out_valid <= vin;
            out_pix   <= (mag > thr) ? 8'hFF : 8'h00;
        end
    end
endmodule
