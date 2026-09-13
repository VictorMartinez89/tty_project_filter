// tb_canny_feat.v — el extractor con Canny 1-salto contra el golden de Python.
//   Mismo procedimiento que tb_mnist.v, con UNA pasada mas: el Canny tiene TRES etapas 3x3
//   encadenadas, asi que los line-buffers tardan mas en cebarse y en drenar.
`timescale 1ns/1ps
`default_nettype none
module tb_canny_feat;
    localparam integer H = 28, W = 28, N = H*W, CW = 9;
    reg clk = 0, reset = 1, clr = 0, in_valid = 0;
    reg [7:0] in_pix = 0;
    integer HI, LO, LATV;
    wire [32*CW-1:0] cnt;
    wire [10:0] n_bordes;
    wire fdone;
    always #5 clk = ~clk;

    mnist_feat_canny #(.H(H),.W(W),.CW(CW),.LATP(LATV)) FEAT (
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(HI[7:0]),.thr_lo(LO[7:0]),
        .frame_done(fdone),.cnt_o(cnt),.n_bordes(n_bordes));

    reg [7:0] img [0:N-1];
    integer i, rep, fd;
    reg [1023:0] f_img, f_out;

    initial begin
        if (!$value$plusargs("IMG=%s", f_img)) begin $display("falta +IMG"); $finish; end
        if (!$value$plusargs("OUT=%s", f_out)) begin $display("falta +OUT"); $finish; end
        if (!$value$plusargs("HI=%d", HI)) HI = 110;
        if (!$value$plusargs("LAT=%d", LATV)) LATV = 0;
        if (!$value$plusargs("LO=%d", LO)) LO = 40;
        $readmemh(f_img, img);
        repeat (4) @(posedge clk); reset = 0; @(posedge clk);
        // CUATRO pasadas: 0 y 1 ceban las tres etapas, 2 es la que se cuenta, 3 drena.
        for (rep = 0; rep < 4; rep = rep + 1) begin
            if (rep == 2) begin clr <= 1'b1; @(posedge clk); clr <= 1'b0; end
            for (i = 0; i < N; i = i + 1) begin
                in_valid <= 1'b1; in_pix <= img[i]; @(posedge clk);
            end
            in_valid <= 1'b0; @(posedge clk);
        end
        fd = $fopen(f_out, "w");
        for (i = 0; i < 32; i = i + 1) $fwrite(fd, "%0d\n", cnt[i*CW +: CW]);
        $fwrite(fd, "bordes %0d\n", n_bordes);
        $fclose(fd);
        $display("bordes=%0d", n_bordes);
        $finish;
    end
endmodule
`default_nettype wire
