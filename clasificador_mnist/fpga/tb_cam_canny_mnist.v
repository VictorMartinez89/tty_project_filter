// tb_cam_canny_mnist.v — LA CADENA ENTERA con front-end CANNY, en simulacion:
//   camara emulada (OV7670, YUV422 con href y blanking reales)
//        -> cam_win28   (recorte 448x448 del centro + promediado a 28x28 + inversion)
//        -> mnist_feat_canny  (Gauss -> Sobel -> doble umbral -> histeresis 1 salto -> 32 contadores)
//        -> mnist_clf_canny   (40 rasgos -> 400 MAC -> argmax -> veredicto NADA)
//   y sale una de ONCE clases: 0..9 o NADA.
//
//   La escena se genera con gen_escena.py a partir de una imagen de MNIST ampliada al centro
//   del cuadro de 640x480, asi se sabe que digito DEBERIA salir.
//   No se simula el TFT (son 76 800 pixeles por SPI, eterno): se observan directamente la
//   ventana de 28x28, el digito reconocido y lo que se dibujaria. Es el test que dice si vale
//   la pena grabar la placa.
`timescale 1ns/1ps
`default_nettype none
module tb_cam_canny_mnist;
    localparam integer CAM_W = 640, CAM_H = 480;
    reg pclk = 0, reset = 1;
    reg [7:0] mem [0:CAM_W*CAM_H-1];

    // --- camara emulada: YUV422, un byte de luma y uno de croma por pixel ---
    // href y BLANKING modelados de verdad: la version anterior alimentaba pixeles seguidos y
    // por eso no podia cazar el bug de sincronia. Una linea real tiene 640 pixeles activos con
    // href alto y despues un tramo de blanking con href bajo.
    reg        href = 0, py_valid = 0;
    reg [7:0]  curY = 0;
    always #5 pclk = ~pclk;

    wire       w_valid; wire [7:0] w_pix; wire w_fin;
    cam_win28 #(.CAM_W(CAM_W),.CAM_H(CAM_H),.WIN(448),.N(28)) WIN (
        .pclk(pclk), .sync(1'b0), .reset(reset), .href(href),
        .pix_y(curY), .pix_valid(py_valid), .invertir(1'b1),
        .out_valid(w_valid), .out_pix(w_pix), .frame_fin(w_fin));

    wire done; wire [3:0] digito; wire valido;
    integer HI, LO;                       // declarados ANTES de usarse
    // clr cuando el clasificador TERMINA, no en cada cuadro: el video es continuo y el
    // raster se encadena solo. Con clr por cuadro la latencia se reinicia y nunca se
    // completa el barrido (784 muestras no alcanzan para 60 de latencia + 784 de raster).
    reg clr = 0;
    always @(posedge pclk) clr <= done;
    mnist_top_canny #(.H(28),.W(28),.CW(9)) CLF (
        .clk(pclk), .reset(reset), .clr(clr),
        .in_valid(w_valid), .in_pix(w_pix),
        .thr_hi(HI[7:0]), .thr_lo(LO[7:0]),
        .done(done), .digito(digito), .valido(valido));

    // capturar las 28x28 que salen de la ventana, para compararlas con Python
    reg [7:0] vista [0:783];
    integer nv = 0;
    always @(posedge pclk) if (w_valid && nv < 784) begin vista[nv] = w_pix; nv = nv + 1; end

    integer i, f, r, fd;
    reg [1023:0] f_esc;
    initial begin
        if (!$value$plusargs("HI=%d", HI)) HI = 110;
        if (!$value$plusargs("LO=%d", LO)) LO = 40;
        if (!$value$plusargs("ESC=%s", f_esc)) f_esc = "escena.hex";
        $readmemh(f_esc, mem);
        repeat (4) @(posedge pclk); reset = 0; @(posedge pclk);
        // TRES cuadros: ceba line-buffers, cuenta, drena — igual que en el banco del RTL
        for (f = 0; f < 3; f = f + 1) begin
            nv = (f == 1) ? 0 : nv;
            for (r = 0; r < CAM_H; r = r + 1) begin
                href <= 1'b1;
                for (i = 0; i < CAM_W; i = i + 1) begin
                    curY <= mem[r*CAM_W + i]; py_valid <= 1'b1; @(posedge pclk);
                    py_valid <= 1'b0; @(posedge pclk);      // el byte de croma
                end
                href <= 1'b0;                                // BLANKING horizontal
                repeat (40) @(posedge pclk);
            end
            repeat (200) @(posedge pclk);                    // blanking vertical
        end
        repeat (600) @(posedge pclk);
        fd = $fopen("vista28.txt", "w");
        for (i = 0; i < 784; i = i + 1) $fwrite(fd, "%0d\n", vista[i]);
        $fclose(fd);
        $display("pixeles emitidos por la ventana: %0d", nv);
        if (valido) $display(">>> RESULTADO: %0d", digito);
        else        $display(">>> RESULTADO: NADA");
        $display("    bordes=%0d  done=%b", CLF.FEAT.n_bordes, done);
        $finish;
    end
endmodule
`default_nettype wire
