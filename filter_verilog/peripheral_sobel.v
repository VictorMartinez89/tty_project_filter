// =============================================================================
// peripheral_sobel.v  -- peripheral memory-mapped del FemtoRV32 (slot 0x0045)
//   Envuelve los filtros en STREAMING (sobel_compass_control / canny_control)
//   tras el contrato femto: clk/reset/d_in/cs/addr/rd/wr/d_out.
//   Modelo pixel-a-pixel (polling): el CPU escribe pixeles y lee resultados.
//
//   Mapa de registros (addr = mem_address[4:0]):
//     0x00 CTRL  (W): d_in[0]=mode (0=compass, 1=canny), d_in[1]=frame_reset (pulso)
//     0x04 IMGW  (W): ancho de imagen (line buffers en runtime)
//     0x08 LOW   (W): umbral bajo  (canny)
//     0x0C HIGH  (W): umbral alto  (canny)
//     0x10 PIXEL (W): escribe 1 pixel gris [7:0] -> pulso px_valid a los filtros
//     0x14 STATUS(R): bit0 = result_ready (resultado latcheado disponible)
//     0x18 RESULT(R): compass -> {dir[2:0],mag[7:0]} ; canny -> {class[1:0],edge}
//                     (leer RESULT limpia result_ready)
// =============================================================================
`default_nettype none
module peripheral_sobel #(
    parameter integer PIX=8, parameter integer MAGW=12, parameter integer MAX_IMG_W=1024
)(
    input  wire        clk,
    input  wire        reset,          // activo-alto (femto pasa !resetn)
    input  wire [31:0] d_in,
    input  wire        cs,
    input  wire [4:0]  addr,
    input  wire        rd,
    input  wire        wr,
    output reg  [31:0] d_out
);
    localparam [4:0] A_CTRL=5'h00, A_IMGW=5'h04, A_LOW=5'h08, A_HIGH=5'h0C,
                     A_PIXEL=5'h10, A_STATUS=5'h14, A_RESULT=5'h18;

    // --- registros de configuracion ---
    reg        mode;            // 0=compass, 1=canny
    reg [15:0] img_w;
    reg [MAGW-1:0] low, high;
    reg        frame_rst;       // pulso de reset de frame (limpia line buffers/contadores)
    wire       wr_e = cs & wr;

    always @(posedge clk) begin
        if (reset) begin mode<=0; img_w<=16'd160; low<=12'd40; high<=12'd200; frame_rst<=1'b0; end
        else begin
            frame_rst <= 1'b0;
            if (wr_e) case (addr)
                A_CTRL : begin mode <= d_in[0]; frame_rst <= d_in[1]; end
                A_IMGW : img_w <= d_in[15:0];
                A_LOW  : low   <= d_in[MAGW-1:0];
                A_HIGH : high  <= d_in[MAGW-1:0];
            endcase
        end
    end

    // --- alimentacion de pixeles ---
    wire        px_valid = wr_e & (addr==A_PIXEL);
    wire [PIX-1:0] px    = d_in[PIX-1:0];
    wire        nrst_flt = ~(reset | frame_rst);     // reset comun para los filtros (activo-bajo)

    // --- filtro 1: Sobel compass ---
    wire           scc_ov;  wire [PIX-1:0] scc_mag; wire [2:0] scc_dir;
    sobel_compass_control #(.PIX(PIX), .MAX_IMG_W(MAX_IMG_W)) u_compass (
        .clk_i(clk), .nreset_i(nrst_flt), .img_w_i(img_w),
        .px_valid_i(px_valid), .px_i(px),
        .out_valid_o(scc_ov), .mag_o(scc_mag), .dir_o(scc_dir), .mags8_o());

    // --- filtro 2: Canny (NMS + histeresis streaming) ---
    wire        cc_ov, cc_edge; wire [1:0] cc_class;
    canny_control #(.PIX(PIX), .MAGW(MAGW), .MAX_IMG_W(MAX_IMG_W)) u_canny (
        .clk_i(clk), .nreset_i(nrst_flt), .img_w_i(img_w),
        .px_valid_i(px_valid), .px_i(px), .low_i(low), .high_i(high),
        .out_valid_o(cc_ov), .edge_o(cc_edge), .class_o(cc_class));

    // --- latch del resultado segun el modo ---
    wire        sel_ov   = mode ? cc_ov : scc_ov;
    wire [31:0] sel_data = mode ? {29'b0, cc_class, cc_edge}
                                : {21'b0, scc_dir, scc_mag};
    reg         result_ready;
    reg [31:0]  result_data;
    wire        rd_result = cs & rd & (addr==A_RESULT);
    always @(posedge clk) begin
        if (reset) begin result_ready<=1'b0; result_data<=32'b0; end
        else begin
            if (sel_ov)   begin result_data <= sel_data; result_ready <= 1'b1; end
            if (rd_result) result_ready <= 1'b0;          // leer RESULT limpia el flag
        end
    end

    // --- lectura ---
    always @(*) begin
        d_out = 32'b0;
        if (cs & rd) case (addr)
            A_STATUS : d_out = {31'b0, result_ready};
            A_RESULT : d_out = result_data;
        endcase
    end
endmodule
`default_nettype wire
