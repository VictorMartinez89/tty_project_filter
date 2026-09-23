// tb_ext_una.v — UNA sola pasada desde reset, y la cola la dan muestras de OTRA imagen.
//   Contesta dos preguntas: cuantas muestras de mas hacen falta para que la ultima posicion
//   salga del cauce, y si el CONTENIDO de esa cola afecta al resultado (no deberia: las
//   ventanas de la ultima fila util solo miran filas que ya entraron).
`default_nettype none
`timescale 1ns/1ps
module tb_ext_una #(parameter integer LATP = 87) ();
    reg clk=0, reset=1, in_valid=0;
    reg [7:0] in_pix=0;
    wire dbg_val, dbg_borde, dbg_arr;
    wire [4:0] dbg_cx, dbg_cy;
    wire [10:0] n_bordes;
    wire frame_done;
    mnist_feat16_mem #(.LATP(LATP)) u(.clk(clk),.reset(reset),.clr(1'b0),
        .in_valid(in_valid),.in_pix(in_pix),.thr_hi(8'd90),.thr_lo(8'd32),
        .frame_done(frame_done),.rd_a(7'd0),.rd_d(),.rd_clr(1'b0),.reanuda(1'b0),.n_bordes(n_bordes),
        .dbg_val(dbg_val),.dbg_borde(dbg_borde),.dbg_cx(dbg_cx),.dbg_cy(dbg_cy),
        .dbg_arr(dbg_arr),.dbg_mag(),.dbg_cls(),.dbg_vs(),.dbg_vc(),.dbg_win());
    always #5 clk=~clk;
    integer i,fd,EXTRA,nfd;
    reg [7:0] img [0:783];
    reg [7:0] cola [0:783];
    reg [1023:0] fin,fin2,fout;
    initial begin
        if(!$value$plusargs("IN=%s",fin))   begin $display("falta +IN");  $finish; end
        if(!$value$plusargs("IN2=%s",fin2)) begin $display("falta +IN2"); $finish; end
        if(!$value$plusargs("OUT=%s",fout)) begin $display("falta +OUT"); $finish; end
        if(!$value$plusargs("EXTRA=%d",EXTRA)) EXTRA=4;
        $readmemh(fin,img); $readmemh(fin2,cola);
        fd=$fopen(fout,"w"); nfd=0;
        repeat(4) @(posedge clk); #1 reset=0;
        fork
          begin
            for(i=0;i<784;i=i+1)   begin @(posedge clk); #1; in_valid=1; in_pix=img[i];  end
            for(i=0;i<EXTRA;i=i+1) begin @(posedge clk); #1; in_valid=1; in_pix=cola[i]; end
            @(posedge clk); #1; in_valid=0;
            repeat(4) @(posedge clk);
            $fwrite(fd,"# n_bordes %0d frame_done %0d\n", n_bordes, nfd);
            $fclose(fd); $finish;
          end
          forever begin
            @(posedge clk);
            if (frame_done) nfd=nfd+1;
            if (dbg_val && dbg_arr) $fwrite(fd,"%0d %0d %0d\n", dbg_cy, dbg_cx, dbg_borde);
          end
        join
    end
endmodule
