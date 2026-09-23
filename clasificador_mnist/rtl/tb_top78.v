// tb_top78.v — la CADENA COMPLETA en FLUJO CONTINUO, contra el golden.
//
//   Los clasificadores estaban verificados uno por uno, pero alimentados a mano con los 128
//   contadores ya buenos. Nadie habia comprobado que el extractor los PRODUZCA, que el
//   trasvase los ENTREGUE, ni que el conjunto sobreviva al segundo cuadro.
//
//   Se vuelcan los tres sitios por separado -cnt[] del extractor, fmem[] del clasificador y
//   el veredicto- para que una discrepancia diga DONDE esta y no solo que existe.
//
//   Se encadenan varias imagenes sin pausa, que es lo que hace una camara. Un diseno que vive
//   en un flujo de video no se verifica con un cuadro suelto: lo que falla es el segundo.
`default_nettype none
`timescale 1ns/1ps
module tb_top78;
    reg clk=0, reset=1, in_valid=0;
    reg [7:0] in_pix=0;
    wire done, valido; wire [3:0] digito;
    mnist_top78 u(.clk(clk),.reset(reset),.in_valid(in_valid),.in_pix(in_pix),
                  .thr_hi(8'd90),.thr_lo(8'd32),.done(done),.digito(digito),.valido(valido));
    always #5 clk=~clk;
    integer i,k,fd,NIMG,GAP,nd;
    reg [7:0] img [0:783*64];
    reg [1023:0] fin,fout;
    initial begin
        if(!$value$plusargs("IN=%s",fin))  begin $display("falta +IN");  $finish; end
        if(!$value$plusargs("OUT=%s",fout))begin $display("falta +OUT"); $finish; end
        if(!$value$plusargs("NIMG=%d",NIMG)) NIMG=4;
        if(!$value$plusargs("GAP=%d",GAP))   GAP=0;
        $readmemh(fin,img);
        fd=$fopen(fout,"w"); nd=0;
        repeat(4) @(posedge clk); #1 reset=0;
        fork
          begin
            // el flujo entero de corrido, y una cola de 8 muestras para vaciar el cauce
            for(i=0;i<NIMG*784;i=i+1) begin
                @(posedge clk); #1; in_valid=1; in_pix=img[i];
                if (GAP>0) begin @(posedge clk); #1; in_valid=0;
                                 repeat(GAP-1) @(posedge clk); end
            end
            for(i=0;i<8;i=i+1) begin @(posedge clk); #1; in_valid=1; in_pix=8'd0; end
            @(posedge clk); #1; in_valid=0;
            repeat(1200) @(posedge clk);
            $fclose(fd); $finish;
          end
          // DOS ciclos DESPUES de `frame_done`, no en el: la escritura del ultimo pixel
          // util desagua justo despues, asi que volcar en el flanco de `frame_done` pilla el
          // histograma una cuenta corto. El instrumento tambien hay que verificarlo.
          forever begin
            @(posedge clk);
            if (u.frame_done) begin
                // esperar la siguiente MUESTRA VALIDA, no dos flancos: con tiempo muerto
                // entre pixeles el desague ocurre en el proximo `vc`, que puede estar a
                // varios ciclos. Con `@(posedge clk)` a secas el volcado sale corto y el
                // banco denuncia un fallo del diseno que es suyo.
                while (!u.ext.vc) @(posedge clk);
                @(posedge clk);
                $fwrite(fd,"CNT %0d %0d\n", nd, u.ext.n_bordes);
                for(k=0;k<128;k=k+1) $fwrite(fd,"%0d\n", u.ext.cnt[k]);
            end
          end
          // en `arranca` el clasificador ya tiene sus 128 en fmem
          forever begin
            @(posedge clk);
            if (u.arranca) begin
                $fwrite(fd,"FMEM %0d\n", nd);
                for(k=0;k<128;k=k+1) $fwrite(fd,"%0d\n", u.clf.fmem[k]);
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
