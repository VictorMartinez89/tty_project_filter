// tb_espia0.v — espia TODAS las escrituras a la casilla 0 de `cnt`, con su contexto.
//   Sirve para una sola pregunta: de donde salen las tres cuentas de mas que aparecen en
//   cnt[0] a partir de cierta imagen y ya no se van. Se registra cada escritura con el
//   numero de ciclo, la posicion del raster, el dato, y quien la pidio.
`default_nettype none
`timescale 1ns/1ps
module tb_espia0;
    reg clk=0, reset=1, in_valid=0;
    reg [7:0] in_pix=0;
    wire done, valido; wire [3:0] digito;
    mnist_top78 u(.clk(clk),.reset(reset),.in_valid(in_valid),.in_pix(in_pix),
                  .thr_hi(8'd90),.thr_lo(8'd32),.done(done),.digito(digito),.valido(valido));
    always #5 clk=~clk;
    integer i,fd,NIMG,ciclo;
    reg [7:0] img [0:783*16];
    reg [1023:0] fin,fout;
    initial begin
        if(!$value$plusargs("IN=%s",fin))  begin $display("falta +IN");  $finish; end
        if(!$value$plusargs("OUT=%s",fout))begin $display("falta +OUT"); $finish; end
        if(!$value$plusargs("NIMG=%d",NIMG)) NIMG=3;
        $readmemh(fin,img);
        fd=$fopen(fout,"w"); ciclo=0;
        repeat(4) @(posedge clk); #1 reset=0;
        fork
          begin
            for(i=0;i<NIMG*784;i=i+1) begin @(posedge clk); #1; in_valid=1; in_pix=img[i]; end
            for(i=0;i<8;i=i+1) begin @(posedge clk); #1; in_valid=1; in_pix=8'd0; end
            @(posedge clk); #1; in_valid=0;
            repeat(1200) @(posedge clk);
            $fclose(fd); $finish;
          end
          forever begin @(posedge clk); ciclo=ciclo+1; end
          // toda escritura a la casilla 0
          forever begin
            @(posedge clk);
            if (u.ext.cw_en && u.ext.cw_a == 7'd0)
                $fwrite(fd,"W %0d dato=%0d cy=%0d cx=%0d listo=%0d rdclr=%0d borra=%0d inc=%0d qval=%0d\n",
                        ciclo, u.ext.cw_d, u.ext.cy, u.ext.cx, u.ext.listo,
                        u.ext.rd_clr, u.ext.cw_borra, u.ext.cw_inc, u.ext.q_val);
          end
          forever begin
            @(posedge clk);
            if (u.frame_done) $fwrite(fd,"FD %0d cy=%0d cx=%0d nb=%0d\n",
                                      ciclo, u.ext.cy, u.ext.cx, u.ext.n_bordes);
            if (u.reanuda)    $fwrite(fd,"RE %0d cy=%0d cx=%0d\n", ciclo, u.ext.cy, u.ext.cx);
            if (done)         $fwrite(fd,"DN %0d dig=%0d\n", ciclo, digito);
          end
        join
    end
endmodule
