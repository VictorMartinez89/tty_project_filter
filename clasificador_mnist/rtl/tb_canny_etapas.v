// tb_canny_etapas.v — vuelca las etapas INTERMEDIAS del Canny, para ver donde se separa
//   del golden. Comparar solo el resultado final no dice donde esta el problema.
`timescale 1ns/1ps
`default_nettype none
module tb_canny_etapas;
    localparam integer H=28, W=28, N=H*W, CW=9;
    reg clk=0, reset=1, clr=0, in_valid=0; reg [7:0] in_pix=0;
    integer HI, LO;
    wire [32*CW-1:0] cnt; wire [10:0] nb; wire fdone;
    wire dval,dbor,darr,dvs,dvc; wire [4:0] dcx,dcy; wire [7:0] dmag; wire [1:0] dcls;
    always #5 clk=~clk;
    mnist_feat_canny #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(HI[7:0]),.thr_lo(LO[7:0]),.frame_done(fdone),.cnt_o(cnt),.n_bordes(nb),
        .dbg_val(dval),.dbg_borde(dbor),.dbg_cx(dcx),.dbg_cy(dcy),.dbg_arr(darr),
        .dbg_mag(dmag),.dbg_cls(dcls),.dbg_vs(dvs),.dbg_vc(dvc));
    reg [7:0] img [0:N-1];
    integer i, rep, fm, fc;
    reg [1023:0] f_img;
    initial begin
        if (!$value$plusargs("IMG=%s", f_img)) $finish;
        if (!$value$plusargs("HI=%d", HI)) HI=110;
        if (!$value$plusargs("LO=%d", LO)) LO=40;
        $readmemh(f_img, img);
        fm = $fopen("tmp/mag.txt","w"); fc = $fopen("tmp/cls.txt","w");
        repeat (4) @(posedge clk); reset=0; @(posedge clk);
        for (rep=0; rep<4; rep=rep+1) begin
            if (rep==2) begin clr<=1'b1; @(posedge clk); clr<=1'b0; end
            for (i=0;i<N;i=i+1) begin
                in_valid<=1'b1; in_pix<=img[i]; @(posedge clk);
                // DOS pasadas, no una: con 782 muestras una ventana de 24x24 contigua
                // DA LA VUELTA al raster y la comparacion se desalinea sola.
                if (rep>=2) begin
                    if (dvs) $fwrite(fm, "%0d\n", dmag);
                    if (dvc) $fwrite(fc, "%0d\n", dcls);
                end
            end
            in_valid<=1'b0; @(posedge clk);
        end
        $fclose(fm); $fclose(fc); $display("volcado"); $finish;
    end
endmodule
`default_nettype wire
