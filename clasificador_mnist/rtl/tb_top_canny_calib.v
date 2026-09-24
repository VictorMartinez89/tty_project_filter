// tb_top_canny_fw.v — la cadena del SoC y de los chips 13/14, en flujo continuo.
//
//   Se copia EXACTAMENTE la forma en que el chip mueve `clr` (vision_canny_mnist.v):
//       always @(posedge pclk) clf_clr <= clf_done;
//   es decir, un pulso un ciclo despues de terminar de clasificar, no en el limite de cuadro.
//   Esa diferencia importa: con `clr` en el limite, el pulso cae en el mismo flanco que el
//   primer `frame_done` y lo borra, porque la rama `if (reset || clr)` tiene prioridad.
//
//   Se encadenan imagenes sin pausa y se anota el veredicto de cada cuadro con los 32
//   contadores que lo produjeron, para poder comparar los dos por separado contra el golden.
`default_nettype none
`timescale 1ns/1ps
module tb_top_canny_calib;
    localparam CW = 9;
    reg clk=0, reset=1, in_valid=0;
    reg [7:0] in_pix=0;
    wire done, valido; wire [3:0] digito;
    reg clr;
    // el `clr` del chip: un ciclo despues de `done`
    always @(posedge clk) if (reset) clr <= 1'b0; else clr <= done;
    mnist_top_canny_calib #(.H(28),.W(28),.CW(CW)) u(
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(8'd90),.thr_lo(8'd32),.done(done),.digito(digito),.valido(valido));
    always #5 clk=~clk;
    integer i,k,fd,NIMG,GAP,nd;
    reg [7:0] img [0:783*64];
    reg [1023:0] fin,fout;
    initial begin
        if(!$value$plusargs("IN=%s",fin))  begin $display("falta +IN");  $finish; end
        if(!$value$plusargs("OUT=%s",fout))begin $display("falta +OUT"); $finish; end
        if(!$value$plusargs("NIMG=%d",NIMG)) NIMG=8;
        if(!$value$plusargs("GAP=%d",GAP))   GAP=0;
        $readmemh(fin,img);
        fd=$fopen(fout,"w"); nd=0;
        repeat(4) @(posedge clk); #1 reset=0;
        fork
          begin
            for(i=0;i<NIMG*784;i=i+1) begin
                @(posedge clk); #1; in_valid=1; in_pix=img[i];
                if (GAP>0) begin @(posedge clk); #1; in_valid=0;
                                 repeat(GAP-1) @(posedge clk); end
            end
            for(i=0;i<16;i=i+1) begin @(posedge clk); #1; in_valid=1; in_pix=8'd0; end
            @(posedge clk); #1; in_valid=0;
            repeat(2000) @(posedge clk);
            $fclose(fd); $finish;
          end
          // en `frame_done` del extractor los 32 contadores estan completos
          forever begin
            @(posedge clk);
            if (u.fdone) begin
                $fwrite(fd,"CNT %0d %0d\n", nd, u.n_bordes);
                for(k=0;k<32;k=k+1) $fwrite(fd,"%0d\n", u.cnt[k*CW +: CW]);
            end
          end
          forever begin
            @(posedge clk);
            if (done) begin
                $fwrite(fd,"VER %0d %0d %0d\n", nd, digito, valido);
                nd = nd + 1;
            end
          end
        join
    end
endmodule
