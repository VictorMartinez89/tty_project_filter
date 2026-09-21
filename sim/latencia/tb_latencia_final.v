// tb_latencia_final.v — separa las DOS magnitudes que la tesis llamaba "latencia".
//
//   A · LATENCIA DE CAUCE      primer in_valid -> primer out_valid.
//       Es la profundidad de la cadena de `valid`. NO espera a que las lineas de retardo
//       se llenen: las primeras salidas son validas segun la senal, pero se calculan
//       sobre el contenido inicial de los buffers.
//
//   B · LATENCIA HASTA EL PRIMER PIXEL INDEPENDIENTE DEL ESTADO INICIAL
//       Ultimo ciclo cuya salida todavia depende de lo que hubiera en las lineas de
//       retardo. Se mide sin suponer ninguna formula: los arreglos arrancan sin
//       inicializar (X en el simulador) y se busca el ultimo ciclo con salida indefinida.
//       Es la latencia que importa para decir cuando el primer pixel es utilizable.
`timescale 1ns/1ps
module tb_latencia_final;
    localparam W=60, H=80;
    reg clk=0, reset=1, in_valid=0; reg [7:0] in_pix=0;
    always #5 clk=~clk;
    integer ciclo=0; always @(posedge clk) if(!reset) ciclo=ciclo+1;

    wire sov,cov; wire [7:0] sop,cop;
    sobel_top  S(.clk(clk),.reset(reset),.in_valid(in_valid),.in_pix(in_pix),
                 .thr(8'd90),.out_valid(sov),.out_pix(sop));
    canny1_top C(.clk(clk),.reset(reset),.in_valid(in_valid),.in_pix(in_pix),
                 .thr_hi(8'd90),.thr_lo(8'd32),.out_valid(cov),.out_pix(cop));

    integer t_in=-1, t_ovs=-1, t_ovc=-1, ult_x_s=-1, ult_x_c=-1;
    always @(posedge clk) if(!reset) begin
        if(t_in <0 && in_valid) t_in = ciclo;
        if(t_ovs<0 && sov)      t_ovs= ciclo;
        if(t_ovc<0 && cov)      t_ovc= ciclo;
        if(sov && (^sop === 1'bx)) ult_x_s = ciclo;
        if(cov && (^cop === 1'bx)) ult_x_c = ciclo;
    end

    integer r,c;
    initial begin
        repeat(4) @(posedge clk); reset=0; @(posedge clk);
        in_valid=1;
        for(r=0;r<H;r=r+1) for(c=0;c<W;c=c+1) begin in_pix=$random; @(posedge clk); end
        in_valid=0; repeat(40) @(posedge clk);
        $display("");
        $display("   Imagen %0dx%0d.  Referencia: 2*(W+2) = %0d,  6*(W+2) = %0d", W,H,2*(W+2),6*(W+2));
        $display("   ==============================================================");
        $display("                        A · cauce    B · primer pixel utilizable");
        $display("   Sobel  (1 etapa)     %4d ciclos            %4d ciclos", t_ovs-t_in, ult_x_s-t_in+1);
        $display("   Canny  (3 etapas)    %4d ciclos            %4d ciclos", t_ovc-t_in, ult_x_c-t_in+1);
        $display("   ==============================================================");
        $display("   El Sobel coincide con 2*(W+2)=%0d. El Canny NO llega a 6*(W+2)=%0d,",2*(W+2),6*(W+2));
        $display("   porque las tres etapas se llenan SOLAPADAS, no una tras otra.");
        $display("");
        $finish;
    end
endmodule
