// tb_canny_map.v — vuelca el MAPA de bordes del RTL, no el histograma.
//   Cuando las sumas coinciden pero la distribucion no, el histograma no alcanza para saber
//   que paso: hay que ver donde cae cada borde.
`timescale 1ns/1ps
`default_nettype none
module tb_canny_map;
    localparam integer H = 28, W = 28, N = H*W, CW = 9;
    reg clk = 0, reset = 1, clr = 0, in_valid = 0;
    reg [7:0] in_pix = 0;
    integer HI, LO;
    wire [32*CW-1:0] cnt; wire [10:0] nb; wire fdone;
    wire dval, dbor, darr; wire [4:0] dcx, dcy;
    always #5 clk = ~clk;
    mnist_feat_canny #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(HI[7:0]),.thr_lo(LO[7:0]),.frame_done(fdone),.cnt_o(cnt),.n_bordes(nb),
        .dbg_val(dval),.dbg_borde(dbor),.dbg_cx(dcx),.dbg_cy(dcy),.dbg_arr(darr));
    reg [7:0] img [0:N-1];
    integer i, rep, fd;
    reg [1023:0] f_img, f_out;
    initial begin
        if (!$value$plusargs("IMG=%s", f_img)) $finish;
        if (!$value$plusargs("OUT=%s", f_out)) $finish;
        if (!$value$plusargs("HI=%d", HI)) HI = 110;
        if (!$value$plusargs("LO=%d", LO)) LO = 40;
        $readmemh(f_img, img);
        fd = $fopen(f_out, "w");
        repeat (4) @(posedge clk); reset = 0; @(posedge clk);
        for (rep = 0; rep < 4; rep = rep + 1) begin
            if (rep == 2) begin clr <= 1'b1; @(posedge clk); clr <= 1'b0; end
            for (i = 0; i < N; i = i + 1) begin
                in_valid <= 1'b1; in_pix <= img[i]; @(posedge clk);
                if (rep == 2 && dval && darr) $fwrite(fd, "%0d %0d %0d\n", dcy, dcx, dbor);
            end
            in_valid <= 1'b0; @(posedge clk);
        end
        $fclose(fd); $display("nb=%0d", nb); $finish;
    end
endmodule
`default_nettype wire
