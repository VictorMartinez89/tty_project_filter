// =============================================================================
// filter_dma_bus.sv -- DMA de PUERTO UNICO (bus compartido del SoC via bus_arbiter).
//   Dos fases sobre un solo puerto: READ (src -> filtro -> buffer) y WRITE (buffer -> dst).
//   Salidas de bus COMBINACIONALES (alineadas con la latencia de lectura de 1 ciclo).
// =============================================================================
`default_nettype none
module filter_dma_bus #(
    parameter integer PIX=8, parameter integer MAGW=12, parameter integer AW=17,
    parameter integer MAX_IMG_W=1024, parameter integer MAXRES=80000
)(
    input  wire           clk, reset,
    input  wire           start, mode,
    input  wire [AW-1:0]  src_addr, dst_addr, npx,
    input  wire [15:0]    img_w,
    input  wire [MAGW-1:0] low, high,
    output reg            done,
    output reg  [AW-1:0]  rescount,
    output reg            req, we,
    output reg  [AW-1:0]  addr,
    output reg  [15:0]    wdata,
    input  wire [15:0]    rdata
);
    localparam [2:0] IDLE=0, RST=1, READ=2, DRAIN=3, WRITE=4, FIN=5;
    reg [2:0]  state;
    reg [AW-1:0] ri, optr, wi;
    reg [3:0]  drain;
    reg [15:0] outbuf [0:MAXRES-1];
    reg        rst_filt, px_valid_r;
    wire       nrst = ~(reset | rst_filt);
    wire [PIX-1:0] px = rdata[PIX-1:0];

    wire           scc_ov; wire [PIX-1:0] scc_mag; wire [2:0] scc_dir;
    sobel_compass_control #(.PIX(PIX), .MAX_IMG_W(MAX_IMG_W)) u_compass (
        .clk_i(clk), .nreset_i(nrst), .img_w_i(img_w),
        .px_valid_i(px_valid_r), .px_i(px),
        .out_valid_o(scc_ov), .mag_o(scc_mag), .dir_o(scc_dir), .mags8_o());
    wire        cc_ov, cc_edge; wire [1:0] cc_class;
    canny_control #(.PIX(PIX), .MAGW(MAGW), .MAX_IMG_W(MAX_IMG_W)) u_canny (
        .clk_i(clk), .nreset_i(nrst), .img_w_i(img_w),
        .px_valid_i(px_valid_r), .px_i(px), .low_i(low), .high_i(high),
        .out_valid_o(cc_ov), .edge_o(cc_edge), .class_o(cc_class));
    wire        sel_ov   = mode ? cc_ov : scc_ov;
    wire [15:0] sel_data = mode ? {13'b0, cc_class, cc_edge} : {5'b0, scc_dir, scc_mag};

    // --- salidas de bus COMBINACIONALES ---
    always @(*) begin
        req=1'b0; we=1'b0; addr={AW{1'b0}}; wdata=16'b0;
        case (state)
            READ : begin req=1'b1; we=1'b0; addr=src_addr + ri; end
            WRITE: begin req=1'b1; we=1'b1; addr=dst_addr + wi; wdata=outbuf[wi]; end
            default: ;
        endcase
    end

    // --- secuencial ---
    always @(posedge clk) begin
        if (reset) begin
            state<=IDLE; done<=0; rescount<=0; ri<=0; optr<=0; wi<=0; drain<=0;
            rst_filt<=0; px_valid_r<=0;
        end else begin
            rst_filt<=1'b0; px_valid_r<=1'b0;
            case (state)
                IDLE:  if (start) begin done<=0; ri<=0; optr<=0; wi<=0; drain<=0; rst_filt<=1; state<=RST; end
                RST:   state<=READ;
                READ:  begin
                          px_valid_r<=1'b1;                         // 1 ciclo despues -> dato listo
                          if (sel_ov) begin outbuf[optr]<=sel_data; optr<=optr+1'b1; end
                          if (ri == npx-1) state<=DRAIN; else ri<=ri+1'b1;
                       end
                DRAIN: begin
                          if (sel_ov) begin outbuf[optr]<=sel_data; optr<=optr+1'b1; end
                          if (drain==4'd10) begin state<=WRITE; rescount<=optr; end
                          else drain<=drain+1'b1;
                       end
                WRITE: if (wi == rescount-1) state<=FIN; else wi<=wi+1'b1;
                FIN:   begin done<=1; state<=IDLE; end
            endcase
        end
    end
endmodule
`default_nettype wire
