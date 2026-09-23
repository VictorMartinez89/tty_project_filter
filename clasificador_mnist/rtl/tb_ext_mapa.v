// tb_ext_mapa.v — vuelca el MAPA de bordes tal como lo ve el extractor, posicion por posicion.
//   Comparar sumas no sirve: un corrimiento no cambia el total. Hay que ver donde cae cada borde.
`default_nettype none
`timescale 1ns/1ps
module tb_ext_mapa;
    reg clk=0, reset=1, in_valid=0;
    reg [7:0] in_pix=0;
    wire frame_done, dbg_val, dbg_borde, dbg_arr;
    wire [4:0] dbg_cx, dbg_cy;
    wire [10:0] n_bordes;
    mnist_feat16_mem u(.clk(clk),.reset(reset),.clr(1'b0),.in_valid(in_valid),.in_pix(in_pix),
        .thr_hi(8'd90),.thr_lo(8'd32),.frame_done(frame_done),.rd_a(7'd0),.rd_d(),.rd_clr(1'b0),.reanuda(1'b0),
        .n_bordes(n_bordes),.dbg_val(dbg_val),.dbg_borde(dbg_borde),.dbg_cx(dbg_cx),
        .dbg_cy(dbg_cy),.dbg_arr(dbg_arr),.dbg_mag(),.dbg_cls(),.dbg_vs(),.dbg_vc(),.dbg_win());
    always #5 clk=~clk;
    integer i,fd,pas,PAS;
    reg [7:0] img [0:783];
    reg [1023:0] fin,fout;
    initial begin
        if(!$value$plusargs("IN=%s",fin))  begin $display("falta +IN");  $finish; end
        if(!$value$plusargs("OUT=%s",fout))begin $display("falta +OUT"); $finish; end
        if(!$value$plusargs("PAS=%d",PAS)) PAS=2;
        $readmemh(fin,img);
        fd=$fopen(fout,"w");
        repeat(4) @(posedge clk); #1 reset=0;
        fork
          begin
            for(pas=0;pas<PAS;pas=pas+1)
              for(i=0;i<784;i=i+1) begin @(posedge clk); #1; in_valid=1; in_pix=img[i]; end
            @(posedge clk); #1; in_valid=0;
            repeat(20) @(posedge clk);
            $fclose(fd); $finish;
          end
          // una linea por muestra CONTADA: posicion, si es borde, y si el borrado sigue activo
          forever begin
            @(posedge clk);
            if (dbg_val && dbg_arr)
                $fwrite(fd,"%0d %0d %0d %0d\n", dbg_cy, dbg_cx, dbg_borde, u.borrando);
          end
        join
    end
endmodule
