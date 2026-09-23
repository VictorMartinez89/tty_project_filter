// tb_feat_lat.v — barre la latencia del extractor de DOS etapas (Sobel + umbral simple).
//   Su comentario afirma que 2*(W+2)=60 se calibro contra el golden y que 58 corria dos
//   columnas. El de tres etapas resulto ser 3*(W+1)=87 y no 3*(W+2)=90. Las dos cosas no
//   pueden ser ciertas con la misma regla, asi que se mide esta tambien.
`default_nettype none
`timescale 1ns/1ps
module tb_feat_lat #(parameter integer LATP = 60) ();
    localparam CW = 9;
    reg clk=0, reset=1, in_valid=0;
    reg [7:0] in_pix=0;
    wire frame_done;
    wire [32*CW-1:0] cnt_o;
    wire [10:0] n_bordes;
    mnist_feat #(.CW(CW),.LATP(LATP)) u(
        .clk(clk),.reset(reset),.clr(1'b0),.in_valid(in_valid),.in_pix(in_pix),
        .thr(8'd60),.frame_done(frame_done),.cnt_o(cnt_o),.n_bordes(n_bordes));
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
            @(posedge clk); #1; in_valid=0; repeat(4) @(posedge clk);
            if(!visto) begin fd=$fopen(fout,"w"); $fwrite(fd,"# sin frame_done\n"); $fclose(fd); end
            $finish;
          end
          forever begin
            @(posedge clk);
            if (frame_done && !visto) begin
                visto=1; fd=$fopen(fout,"w");
                $fwrite(fd,"# n_bordes %0d\n", n_bordes);
                for(i=0;i<32;i=i+1) $fwrite(fd,"%0d\n", cnt_o[i*CW +: CW]);
                $fclose(fd);
            end
          end
        join
    end
endmodule
