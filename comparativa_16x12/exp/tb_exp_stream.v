// tb_exp_stream.v — banco del experimento 5x6 para los filtros de STREAMING.
// Lee una imagen de 16x12 en hex, la mete pixel a pixel, y escribe el mapa de
// bordes resultante (una linea por pixel: 1 = borde, 0 = plano).
//   iverilog ... && vvp a.out +IMG=img/mano.hex +OUT=exp/out/mano_sobel.txt
`timescale 1ns/1ps
`default_nettype none
module tb_exp_stream;
    localparam H = 16, W = 12, N = H*W;
    reg clk = 0, in_valid = 0;
    reg [7:0] in_pix = 0;
    wire out_valid; wire [7:0] out_pix;

    reg [7:0] img [0:N-1];
    reg [7:0] salida [0:N-1];
    integer i, rep, n_val = 0, n_out = 0, bordes = 0, fd;
    reg [1023:0] f_img, f_out;
    integer thr_arg = 90;                     // umbral alto, ajustable con +THR=
    integer tlo_arg = -1;                     // umbral bajo, ajustable con +TLO= (por defecto THR/2)
    // OJO: el firmware del SoC escribe 90/40, no 90/45. Sin +TLO= el banco le daria al
    // filtro suelto un umbral bajo distinto al que el CPU le da al del SoC, y la
    // comparacion con/sin CPU dejaria de ser justa.

    wire [31:0] tlo_eff = (tlo_arg < 0) ? (thr_arg >> 1) : tlo_arg;

    always #5 clk = ~clk;

`ifdef CON_CPU
    reg resetn = 0;
    wire cpu_wrote;
    `DISENO DUT (.clk(clk), .resetn(resetn), .in_valid(in_valid), .in_pix(in_pix),
                .out_valid(out_valid), .out_pix(out_pix), .cpu_wrote_filter(cpu_wrote)
`ifdef DOS_UMBRALES
                , .thr_hi_o(), .thr_lo_o());
`else
                , .thr_o());
`endif
`else
    reg reset = 1;
    `DISENO DUT (.clk(clk), .reset(reset), .in_valid(in_valid), .in_pix(in_pix),
`ifdef DOS_UMBRALES
                .thr_hi(thr_arg[7:0]), .thr_lo(tlo_eff[7:0]),
`else
                .thr(thr_arg[7:0]),
`endif
                .out_valid(out_valid), .out_pix(out_pix));
`endif

    // La imagen se manda DOS veces y solo se guarda la segunda pasada: las dos
    // primeras filas del primer cuadro salen con basura porque los line-buffers
    // arrancan vacios (en silicio, con lo que hubiera). Un sistema de video real
    // hace exactamente esto: el primer cuadro tras el reset no sirve.
    always @(posedge clk) if (out_valid) begin
        if (n_val >= N && n_out < N) begin
            salida[n_out] = out_pix;
            if (out_pix == 8'hFF) bordes = bordes + 1;
            n_out = n_out + 1;
        end
        n_val = n_val + 1;
    end

    initial begin
        if (!$value$plusargs("IMG=%s", f_img)) begin $display("falta +IMG"); $finish; end
        if (!$value$plusargs("OUT=%s", f_out)) begin $display("falta +OUT"); $finish; end
        void'($value$plusargs("THR=%d", thr_arg));
        void'($value$plusargs("TLO=%d", tlo_arg));
        $readmemh(f_img, img);
        for (i = 0; i < N; i = i + 1) salida[i] = 8'h00;

`ifdef CON_CPU
        repeat (8) @(posedge clk); resetn = 1;
        repeat (200) @(posedge clk);          // el CPU corre su firmware
`else
        repeat (6) @(posedge clk); reset = 0; @(posedge clk);
`endif
        for (rep = 0; rep < 2; rep = rep + 1)
            for (i = 0; i < N; i = i + 1) begin
                in_valid <= 1'b1; in_pix <= img[i]; @(posedge clk);
            end
        in_valid <= 1'b0;
        repeat (40) @(posedge clk);

        fd = $fopen(f_out, "w");
        for (i = 0; i < N; i = i + 1) $fwrite(fd, "%0d\n", (salida[i] == 8'hFF) ? 1 : 0);
        $fclose(fd);
        $display("%0d bordes de %0d pixeles (%0d emitidos)", bordes, N, n_out);
        $finish;
    end
endmodule
`default_nettype wire
