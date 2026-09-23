// tb_canny_lat.v — barre la latencia del extractor de 4 cuadrantes, el que esta en el SoC.
//   Existe porque `mnist_feat16_mem.v` llevaba LAT = 3*(W+2) y la medida dijo 3*(W+1), y este
//   modulo -el del SoC que dio 9/10 con la camara- lleva la misma expresion. Misma cadena de
//   tres linebuf, misma logica de posicion: si alli eran 87, aqui tambien deberian ser 87.
//   Se comprueba contra el golden contador por contador, no por el total.
`default_nettype none
`timescale 1ns/1ps
module tb_canny_lat #(parameter integer LATP = 87) ();
    localparam CW = 9;
    reg clk=0, reset=1, in_valid=0;
    reg [7:0] in_pix=0;
    wire frame_done;
    wire [32*CW-1:0] cnt_o;
    wire [10:0] n_bordes;
    mnist_feat_canny #(.CW(CW),.LATP(LATP)) u(
        .clk(clk),.reset(reset),.clr(1'b0),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(8'd90),.thr_lo(8'd32),.frame_done(frame_done),.cnt_o(cnt_o),
        .n_bordes(n_bordes),.dbg_val(),.dbg_borde(),.dbg_cx(),.dbg_cy(),.dbg_arr(),
        .dbg_mag(),.dbg_cls(),.dbg_vs(),.dbg_vc(),.dbg_win());
    always #5 clk=~clk;
    integer i,fd,EXTRA,visto;
    reg [7:0] img [0:783];
    reg [1023:0] fin,fout;
    initial begin
        if(!$value$plusargs("IN=%s",fin))  begin $display("falta +IN");  $finish; end
        if(!$value$plusargs("OUT=%s",fout))begin $display("falta +OUT"); $finish; end
        if(!$value$plusargs("EXTRA=%d",EXTRA)) EXTRA=6;
        $readmemh(fin,img); visto=0;
        repeat(4) @(posedge clk); #1 reset=0;
        fork
          begin
            for(i=0;i<784;i=i+1)   begin @(posedge clk); #1; in_valid=1; in_pix=img[i]; end
            for(i=0;i<EXTRA;i=i+1) begin @(posedge clk); #1; in_valid=1; in_pix=8'd0; end
            @(posedge clk); #1; in_valid=0;
            repeat(4) @(posedge clk);
            if (!visto) begin
                fd=$fopen(fout,"w"); $fwrite(fd,"# sin frame_done\n"); $fclose(fd);
            end
            $finish;
          end
          forever begin
            @(posedge clk);
            if (frame_done && !visto) begin
                visto=1;
                fd=$fopen(fout,"w");
                $fwrite(fd,"# n_bordes %0d\n", n_bordes);
                for(i=0;i<32;i=i+1) $fwrite(fd,"%0d\n", cnt_o[i*CW +: CW]);
                $fclose(fd);
            end
          end
        join
    end
endmodule
