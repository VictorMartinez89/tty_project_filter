// =============================================================================
// filter_dma.sv -- DMA REAL: lee la imagen directo de la RAM, la pasa por el
//   filtro (Sobel compass / Canny) a ~1 pixel/ciclo, y ESCRIBE los resultados
//   de vuelta a la RAM. El CPU solo programa src/dst/npx/modo/umbrales y START;
//   no toca ningun pixel (a diferencia de pixel-a-pixel y del framebuffer-load).
//   Interfaz de MAESTRO de memoria: canal de lectura (rd_addr/rd_en -> rd_data
//   1 ciclo despues) y canal de escritura (wr_addr/wr_data/wr_en).
// =============================================================================
`default_nettype none
module filter_dma #(
    parameter integer PIX=8, parameter integer MAGW=12,
    parameter integer AW=17, parameter integer MAX_IMG_W=1024
)(
    input  wire           clk, reset,
    // control / config (las pondria un peripheral memory-mapped)
    input  wire           start,
    input  wire           mode,             // 0=compass, 1=canny
    input  wire [AW-1:0]  src_addr, dst_addr, npx,
    input  wire [15:0]    img_w,
    input  wire [MAGW-1:0] low, high,
    output reg            done,
    output reg  [AW-1:0]  rescount,
    // maestro: canal de lectura (rd_data valido 1 ciclo despues de rd_en)
    output reg            rd_en,
    output reg  [AW-1:0]  rd_addr,
    input  wire [PIX-1:0] rd_data,
    // maestro: canal de escritura
    output reg            wr_en,
    output reg  [AW-1:0]  wr_addr,
    output reg  [15:0]    wr_data
);
    reg running, rst_filt, rd_en_d;
    reg [AW-1:0] rcount, wcount;
    reg [3:0] drain;
    wire nrst = ~(reset | rst_filt);

    // pixel valido = lectura emitida el ciclo anterior ya tiene dato
    wire           px_valid = rd_en_d;
    wire [PIX-1:0] px       = rd_data;

    wire           scc_ov; wire [PIX-1:0] scc_mag; wire [2:0] scc_dir;
    sobel_compass_control #(.PIX(PIX), .MAX_IMG_W(MAX_IMG_W)) u_compass (
        .clk_i(clk), .nreset_i(nrst), .img_w_i(img_w),
        .px_valid_i(px_valid), .px_i(px),
        .out_valid_o(scc_ov), .mag_o(scc_mag), .dir_o(scc_dir), .mags8_o());
    wire        cc_ov, cc_edge; wire [1:0] cc_class;
    canny_control #(.PIX(PIX), .MAGW(MAGW), .MAX_IMG_W(MAX_IMG_W)) u_canny (
        .clk_i(clk), .nreset_i(nrst), .img_w_i(img_w),
        .px_valid_i(px_valid), .px_i(px), .low_i(low), .high_i(high),
        .out_valid_o(cc_ov), .edge_o(cc_edge), .class_o(cc_class));

    wire        sel_ov   = mode ? cc_ov : scc_ov;
    wire [15:0] sel_data = mode ? {13'b0, cc_class, cc_edge} : {5'b0, scc_dir, scc_mag};

    always @(posedge clk) begin
        if (reset) begin
            running<=0; done<=0; rcount<=0; wcount<=0; drain<=0; rst_filt<=0;
            rd_en<=0; rd_en_d<=0; rd_addr<=0; wr_en<=0; wr_addr<=0; wr_data<=0; rescount<=0;
        end else begin
            rd_en<=1'b0; wr_en<=1'b0; rst_filt<=1'b0;
            rd_en_d <= rd_en;                       // retardo de 1 ciclo (latencia de lectura)
            if (start) begin
                running<=1; done<=0; rcount<=0; wcount<=0; drain<=0; rst_filt<=1'b1;
            end else if (running && !rst_filt) begin
                // emitir lecturas secuenciales src_addr..src_addr+npx-1
                if (rcount < npx) begin
                    rd_en<=1'b1; rd_addr<=src_addr + rcount; rcount<=rcount + 1'b1;
                end else begin
                    if (drain==4'd10) begin running<=0; done<=1; rescount<=wcount; end
                    else drain<=drain + 1'b1;
                end
                // capturar salida del filtro -> escribir a dst
                if (sel_ov) begin
                    wr_en<=1'b1; wr_addr<=dst_addr + wcount; wr_data<=sel_data;
                    wcount<=wcount + 1'b1;
                end
            end
        end
    end
endmodule
`default_nettype wire
