// =============================================================================
// peripheral_sobel_fb.v  -- version FRAMEBUFFER (rapida) del peripheral 0x0045.
//   El CPU carga la imagen a un buffer interno y dispara START; un SECUENCIADOR
//   (DMA-lite) la pasa por el filtro a ~1 pixel/CICLO sin que el CPU toque cada
//   pixel, y guarda los resultados en un buffer de salida. El CPU lee STATUS.done
//   y luego los resultados. Mucho mas rapido que pixel-a-pixel por polling.
//
//   Mapa de registros (addr = mem_address[4:0]):
//     0x00 CTRL (W): bit0=mode (0=compass,1=canny), bit1=clear (reset punteros/estado)
//     0x04 IMGW (W): ancho (line buffers del filtro, runtime)
//     0x08 NPX  (W): numero total de pixeles a procesar (= W*H)
//     0x0C LOW  (W): umbral bajo (canny)
//     0x10 HIGH (W): umbral alto (canny)
//     0x14 WRPIX(W): inbuf[wptr++] = d_in[7:0]   (carga de la imagen)
//     0x18 START(W) / STATUS(R): R -> {rescount[30:1], done[0]}
//     0x1C RDRES(R): outbuf[rptr++]  (lectura de resultados)
// =============================================================================
`default_nettype none
module peripheral_sobel_fb #(
    parameter integer PIX=8, parameter integer MAGW=12,
    parameter integer MAX_IMG_W=1024, parameter integer MAXPX=70000   // 160x120<70000
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] d_in,
    input  wire        cs,
    input  wire [4:0]  addr,
    input  wire        rd,
    input  wire        wr,
    output reg  [31:0] d_out
);
    localparam [4:0] A_CTRL=5'h00,A_IMGW=5'h04,A_NPX=5'h08,A_LOW=5'h0C,
                     A_HIGH=5'h10,A_WRPIX=5'h14,A_START=5'h18,A_RDRES=5'h1C;
    localparam integer AW = $clog2(MAXPX);

    // buffers (en HW real -> BRAM; aqui memorias inferibles)
    reg [PIX-1:0]  inbuf  [0:MAXPX-1];
    reg [15:0]     outbuf [0:MAXPX-1];

    reg        mode; reg [15:0] img_w; reg [31:0] npx; reg [MAGW-1:0] low, high;
    reg [AW-1:0] wptr, rptr, idx, optr;
    reg        running, done; reg [3:0] drain;
    wire       wr_e = cs & wr;

    // --- escrituras de config / carga ---
    always @(posedge clk) begin
        if (reset) begin
            mode<=0; img_w<=160; npx<=0; low<=40; high<=200; wptr<=0;
        end else begin
            if (wr_e) case (addr)
                A_CTRL : begin mode<=d_in[0]; if (d_in[1]) wptr<=0; end
                A_IMGW : img_w <= d_in[15:0];
                A_NPX  : npx   <= d_in;
                A_LOW  : low   <= d_in[MAGW-1:0];
                A_HIGH : high  <= d_in[MAGW-1:0];
                A_WRPIX: begin inbuf[wptr] <= d_in[PIX-1:0]; wptr <= wptr + 1'b1; end
            endcase
        end
    end

    // --- secuenciador (DMA): alimenta inbuf -> filtro a 1 px/ciclo ---
    wire start_pulse = wr_e & (addr==A_START);
    reg  rst_filt;
    wire nrst_flt = ~(reset | rst_filt);
    wire feeding  = running & (idx < npx) & ~rst_filt;
    wire px_valid = feeding;
    wire [PIX-1:0] px = inbuf[idx[AW-1:0]];

    // filtros (comparten el stream)
    wire           scc_ov; wire [PIX-1:0] scc_mag; wire [2:0] scc_dir;
    sobel_compass_control #(.PIX(PIX), .MAX_IMG_W(MAX_IMG_W)) u_compass (
        .clk_i(clk), .nreset_i(nrst_flt), .img_w_i(img_w),
        .px_valid_i(px_valid), .px_i(px),
        .out_valid_o(scc_ov), .mag_o(scc_mag), .dir_o(scc_dir), .mags8_o());
    wire        cc_ov, cc_edge; wire [1:0] cc_class;
    canny_control #(.PIX(PIX), .MAGW(MAGW), .MAX_IMG_W(MAX_IMG_W)) u_canny (
        .clk_i(clk), .nreset_i(nrst_flt), .img_w_i(img_w),
        .px_valid_i(px_valid), .px_i(px), .low_i(low), .high_i(high),
        .out_valid_o(cc_ov), .edge_o(cc_edge), .class_o(cc_class));

    wire        sel_ov   = mode ? cc_ov : scc_ov;
    wire [15:0] sel_data = mode ? {13'b0, cc_class, cc_edge} : {5'b0, scc_dir, scc_mag};

    always @(posedge clk) begin
        if (reset) begin running<=0; done<=0; idx<=0; optr<=0; drain<=0; rst_filt<=0; end
        else begin
            rst_filt <= 1'b0;
            if (start_pulse) begin                 // arrancar frame
                running<=1; done<=0; idx<=0; optr<=0; drain<=0; rst_filt<=1'b1;
            end else if (running && !rst_filt) begin
                if (sel_ov) begin outbuf[optr] <= sel_data; optr <= optr + 1'b1; end
                if (idx < npx) idx <= idx + 1'b1;  // alimentar siguiente pixel
                else begin                          // ya alimentados todos -> drenar pipeline
                    if (drain == 4'd10) begin running<=0; done<=1; end
                    else drain <= drain + 1'b1;
                end
            end
        end
    end

    // --- puntero de lectura de resultados (un solo driver) ---
    always @(posedge clk) begin
        if (reset)                                  rptr <= 0;
        else if (wr_e && addr==A_CTRL && d_in[1])   rptr <= 0;   // clear
        else if (start_pulse)                       rptr <= 0;   // nuevo frame
        else if (cs && rd && addr==A_RDRES)         rptr <= rptr + 1'b1;  // auto-incremento
    end
    always @(*) begin
        d_out = 32'b0;
        if (cs & rd) case (addr)
            A_START: d_out = {optr, done};              // STATUS: bit0=done, [AW:1]=rescount
            A_RDRES: d_out = {16'b0, outbuf[rptr]};
            default: d_out = 32'b0;
        endcase
    end
endmodule
`default_nettype wire
