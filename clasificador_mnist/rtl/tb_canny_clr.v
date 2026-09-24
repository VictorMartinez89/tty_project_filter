// tb_canny_clr.v — la latencia del camino de `clr`, que NO es la del camino de `reset`.
//
//   Importa porque asi es como funcionan el SoC de camara y los chips 13/14: pulsan `clr` al
//   terminar de clasificar, cada cuadro. Solo el PRIMER cuadro pasa por el camino de reset.
//
//   Y las dos latencias no pueden ser iguales: desde reset, las muestras que tarda el
//   encadenado en llenarse NO las cuenta `lat_cnt`, porque `vc` esta baja y la guarda es esa
//   misma senal. Tras `clr` los buffers ya estan calientes, `vc` ya esta alta, y el contador
//   arranca a contar desde el primer ciclo. Sobran las que el reset se tragaba gratis.
//
//   Protocolo: pasada 1 -> pulso de clr en el limite -> pasada 2 -> se lee en el frame_done
//   de la SEGUNDA. Se compara contador por contador, no por el total.
`default_nettype none
`timescale 1ns/1ps
module tb_canny_clr #(parameter integer LATP = 87) ();
    localparam CW = 9;
    reg clk=0, reset=1, clr=0, in_valid=0;
    reg [7:0] in_pix=0;
    wire frame_done;
    wire [32*CW-1:0] cnt_o;
    wire [10:0] n_bordes;
    mnist_feat_canny #(.CW(CW),.LATP(LATP)) u(
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(8'd90),.thr_lo(8'd32),.frame_done(frame_done),.cnt_o(cnt_o),
        .n_bordes(n_bordes),.dbg_val(),.dbg_borde(),.dbg_cx(),.dbg_cy(),.dbg_arr(),
        .dbg_mag(),.dbg_cls(),.dbg_vs(),.dbg_vc(),.dbg_win());
    always #5 clk=~clk;
    integer i,fd,EXTRA,nfd;
    reg [7:0] img [0:783];
    reg [1023:0] fin,fout;
    initial begin
        if(!$value$plusargs("IN=%s",fin))  begin $display("falta +IN");  $finish; end
        if(!$value$plusargs("OUT=%s",fout))begin $display("falta +OUT"); $finish; end
        if(!$value$plusargs("EXTRA=%d",EXTRA)) EXTRA=8;
        $readmemh(fin,img); nfd=0;
        fd=$fopen(fout,"w");
        repeat(4) @(posedge clk); #1 reset=0;
        fork
          begin
            // pasada 1: calienta y da el primer frame_done (camino de reset)
            for(i=0;i<784;i=i+1) begin @(posedge clk); #1; in_valid=1; in_pix=img[i]; end
            // el pulso de clr cae en el limite de cuadro, como lo hace el chip
            @(posedge clk); #1; clr=1; in_pix=img[0];
            @(posedge clk); #1; clr=0; in_pix=img[1];
            for(i=2;i<784;i=i+1)   begin @(posedge clk); #1; in_pix=img[i]; end
            for(i=0;i<EXTRA;i=i+1) begin @(posedge clk); #1; in_pix=img[i]; end
            @(posedge clk); #1; in_valid=0; repeat(4) @(posedge clk);
            if (nfd<2) $fwrite(fd,"# solo %0d frame_done\n", nfd);
            $fclose(fd); $finish;
          end
          forever begin
            @(posedge clk);
            if (frame_done) begin
                nfd = nfd + 1;
                // se vuelca el de la SEGUNDA pasada: ese es el camino de clr
                if (nfd == 2) begin
                    $fwrite(fd,"# n_bordes %0d\n", n_bordes);
                    for(i=0;i<32;i=i+1) $fwrite(fd,"%0d\n", cnt_o[i*CW +: CW]);
                end
            end
          end
        join
    end
endmodule
