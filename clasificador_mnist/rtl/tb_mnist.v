// tb_mnist.v — banco de verificacion del clasificador contra el golden de Python.
//   Lee una imagen de 28x28 en hex, la mete pixel a pixel y escribe DOS cosas:
//   los 32 contadores del histograma y el digito. Los contadores son lo que importa:
//   si coinciden EXACTAMENTE con los de Python, el front-end en hardware es el mismo
//   modelo con el que se entreno. Es la misma verificacion bit a bit de las Partes 29-35.
`timescale 1ns/1ps
`default_nettype none
module tb_mnist;
    localparam integer H = 28, W = 28, N = H*W, CW = 9;
    reg clk = 0, reset = 1, clr = 0, in_valid = 0;
    reg [7:0] in_pix = 0;
    wire done; wire [3:0] digito;
    wire [32*CW-1:0] cnt;
    wire fdone;

    always #5 clk = ~clk;

    mnist_feat #(.H(H),.W(W),.CW(CW)) FEAT (
        .clk(clk),.reset(reset),.clr(clr),.in_valid(in_valid),.in_pix(in_pix),.thr(8'd60),
        .frame_done(fdone),.cnt_o(cnt));
    mnist_clf #(.CW(CW)) CLF (
        .clk(clk),.reset(reset),.start(fdone),.cnt_i(cnt),
        .done(done),.digito(digito),.score());

    reg [7:0] img [0:N-1];
    integer i, rep, fd, espera;
    reg [1023:0] f_img, f_out;

    initial begin
        if (!$value$plusargs("IMG=%s", f_img)) begin $display("falta +IMG"); $finish; end
        if (!$value$plusargs("OUT=%s", f_out)) begin $display("falta +OUT"); $finish; end
        $readmemh(f_img, img);
        // La imagen se manda DOS veces: los line-buffers arrancan vacios y el primer cuadro
        // sale con basura en las dos primeras filas. Es exactamente lo que hacen los bancos de
        // las Partes 29-35, y por la misma razon. El reset del extractor se suelta recien al
        // empezar la segunda pasada, asi que el histograma solo cuenta datos buenos.
        repeat (4) @(posedge clk); reset = 0; @(posedge clk);
        // TRES pasadas, no dos: la primera ceba los line-buffers, la segunda es la que se
        // cuenta, y la tercera existe solo para DRENAR. El linebuf3x3 emite una salida por
        // cada entrada, asi que las ultimas muestras de un cuadro solo salen cuando entran
        // los primeros pixeles del siguiente. Sin la tercera pasada faltan 2 muestras de 784
        // y el ultimo pixel del raster nunca llega: `ult_pix` no dispara.
        for (rep = 0; rep < 3; rep = rep + 1) begin
            if (rep == 1) begin                     // limpiar contadores, dejar los line-buffers cargados
                clr <= 1'b1; @(posedge clk); clr <= 1'b0;
            end
            for (i = 0; i < N; i = i + 1) begin
                in_valid <= 1'b1; in_pix <= img[i]; @(posedge clk);
                if (done) i = N;                       // ya clasifico: no hace falta seguir
            end
            in_valid <= 1'b0; @(posedge clk);
        end
        espera = 0;
        while (!done && espera < 5000) begin @(posedge clk); espera = espera + 1; end
        fd = $fopen(f_out, "w");
        for (i = 0; i < 32; i = i + 1) $fwrite(fd, "%0d\n", cnt[i*CW +: CW]);
        $fwrite(fd, "digito %0d\n", digito);
        $fclose(fd);
        $display("digito=%0d  (listo en %0d ciclos tras el ultimo pixel)", digito, espera);
        $finish;
    end
endmodule
`default_nettype wire
