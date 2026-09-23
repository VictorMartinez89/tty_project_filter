// tb_ext_lat.v — MIDE la latencia del cauce en vez de deducirla.
//   Protocolo de verdad: pasada 1 calienta los line-buffers, pulso de `clr`, pasada 2 cuenta.
//   Se vuelca el mapa de bordes por posicion y en Python se busca que LATP lo hace coincidir
//   EXACTAMENTE con el golden. El total no sirve: un corrimiento no cambia la suma.
`default_nettype none
`timescale 1ns/1ps
module tb_ext_lat #(parameter integer LATP = 90) ();
    reg clk=0, reset=1, clr=0, in_valid=0;
    reg [7:0] in_pix=0;
    wire dbg_val, dbg_borde, dbg_arr;
    wire [4:0] dbg_cx, dbg_cy;
    wire [10:0] n_bordes;
    mnist_feat16_mem #(.LATP(LATP)) u(.clk(clk),.reset(reset),.clr(clr),
        .in_valid(in_valid),.in_pix(in_pix),.thr_hi(8'd90),.thr_lo(8'd32),
        .frame_done(),.rd_a(7'd0),.rd_d(),.rd_clr(1'b0),.reanuda(1'b0),.n_bordes(n_bordes),
        .dbg_val(dbg_val),.dbg_borde(dbg_borde),.dbg_cx(dbg_cx),.dbg_cy(dbg_cy),
        .dbg_arr(dbg_arr),.dbg_mag(),.dbg_cls(),.dbg_vs(),.dbg_vc(),.dbg_win());
    always #5 clk=~clk;
    integer i,fd,EXTRA;
    reg [7:0] img [0:783];
    reg [1023:0] fin,fout;
    initial begin
        if(!$value$plusargs("IN=%s",fin))  begin $display("falta +IN");  $finish; end
        if(!$value$plusargs("OUT=%s",fout))begin $display("falta +OUT"); $finish; end
        if(!$value$plusargs("EXTRA=%d",EXTRA)) EXTRA=8;
        $readmemh(fin,img);
        fd=$fopen(fout,"w");
        repeat(4) @(posedge clk); #1 reset=0;
        fork
          begin
            // pasada 1: calentar. No se cuenta nada util.
            for(i=0;i<784;i=i+1) begin @(posedge clk); #1; in_valid=1; in_pix=img[i]; end
            // el pulso de clr cae EN el limite de cuadro: pone contadores y posicion a cero
            // y deja los line-buffers cargados, que es justo para lo que existe.
            @(posedge clk); #1; clr=1; in_valid=1; in_pix=img[0];
            @(posedge clk); #1; clr=0; in_pix=img[1];
            for(i=2;i<784;i=i+1) begin @(posedge clk); #1; in_pix=img[i]; end
            // unas pocas de mas: hacen falta para que la ultima posicion salga del cauce
            for(i=0;i<EXTRA;i=i+1) begin @(posedge clk); #1; in_pix=img[i]; end
            @(posedge clk); #1; in_valid=0;
            repeat(4) @(posedge clk);
            $fwrite(fd,"# n_bordes %0d\n", n_bordes);
            $fclose(fd); $finish;
          end
          forever begin
            @(posedge clk);
            if (dbg_val && dbg_arr) $fwrite(fd,"%0d %0d %0d\n", dbg_cy, dbg_cx, dbg_borde);
          end
        join
    end
endmodule
