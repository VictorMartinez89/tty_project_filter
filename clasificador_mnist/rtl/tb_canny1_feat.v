// tb_canny1_feat.v — verifica el Canny 1-salto del RTL contra el golden de Python.
//   Mete una imagen de 28x28 tres veces (cebar / medir / drenar, igual que tb_mnist.v)
//   y vuelca el mapa de bordes de la pasada del medio: 1 por linea, 0 o 1.
`timescale 1ns/1ps
module tb_canny1_feat;
    localparam integer H = 28, W = 28, N = H*W;
    reg clk = 0, reset = 1, in_valid = 0;
    reg [7:0] in_pix = 0;
    integer HI, LO;          // DECLARADOS ANTES DE USARSE (leccion del bug #8)
    wire out_valid; wire [7:0] out_pix;
    always #5 clk = ~clk;

    canny1_top #(.W(W)) DUT (
        .clk(clk), .reset(reset), .in_valid(in_valid), .in_pix(in_pix),
        .thr_hi(HI[7:0]), .thr_lo(LO[7:0]),
        .out_valid(out_valid), .out_pix(out_pix));

    reg [7:0] img [0:N-1];
    integer i, rep, fd, n_out;
    reg [1023:0] f_img, f_out;

    initial begin
        if (!$value$plusargs("IMG=%s", f_img)) begin $display("falta +IMG"); $finish; end
        if (!$value$plusargs("OUT=%s", f_out)) begin $display("falta +OUT"); $finish; end
        if (!$value$plusargs("HI=%d", HI)) HI = 110;
        if (!$value$plusargs("LO=%d", LO)) LO = 40;
        $readmemh(f_img, img);
        fd = $fopen(f_out, "w"); n_out = 0;
        repeat (4) @(posedge clk); reset = 0; @(posedge clk);
        // CUATRO pasadas: la 1a ceba, la 2a todavia arrastra el borde inferior del cebado,
        // la 3a ya esta completamente asentada y es la que se compara, la 4a drena.
        for (rep = 0; rep < 4; rep = rep + 1) begin
            for (i = 0; i < N; i = i + 1) begin
                in_valid <= 1'b1; in_pix <= img[i]; @(posedge clk);
                // la pasada del MEDIO es la buena: los line-buffers ya estan cebados
                // se vuelca desde la pasada 1 EN ADELANTE: asi la ventana de 22x22 cae
                // entera dentro del flujo y no hace falta dar la vuelta al raster.
                if (rep >= 1 && out_valid) begin
                    $fwrite(fd, "%0d\n", out_pix[0]); n_out = n_out + 1;
                end
            end
            in_valid <= 1'b0; @(posedge clk);
        end
        // drenar lo que quede de la pasada 1 durante la 2
        $fclose(fd);
        $display("muestras escritas: %0d", n_out);
        $finish;
    end
endmodule
