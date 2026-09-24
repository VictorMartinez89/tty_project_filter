// tb_cam78.v — la camara emulada mostrando los DIEZ digitos seguidos a la cadena del 97,22 %.
//
//   OV7670 emulada (YUV422: luma y croma alternadas, href y blanking horizontal y vertical)
//   -> cam_win28 -> cam78_cadena (el MISMO modulo que va en la placa) -> un veredicto por cuadro.
//   Cada digito se muestra DOS cuadros, como alguien que sostiene el papel, y se cambia de
//   digito sin reset: lo que falla en video no es el primer cuadro sino el cambio de escena.
//   Escribe una linea "V <cuadro> <digito>" por veredicto; verificar_cam78.py la compara.
`timescale 1ns/1ps
`default_nettype none
module tb_cam78;
    localparam integer CAM_W = 640, CAM_H = 480;
    parameter integer NESC = 10, REP = 2;
    reg pclk = 0, reset = 1;
    always #5 pclk = ~pclk;
    reg [7:0] mem [0:NESC*CAM_W*CAM_H-1];
    reg href = 0, py_valid = 0;
    reg [7:0] curY = 0;

    wire w_valid; wire [7:0] w_pix; wire w_fin;
    cam_win28 #(.CAM_W(CAM_W),.CAM_H(CAM_H),.WIN(448),.N(28)) WIN (
        .pclk(pclk), .sync(1'b0), .reset(reset), .href(href),
        .pix_y(curY), .pix_valid(py_valid), .invertir(1'b1),
        .out_valid(w_valid), .out_pix(w_pix), .frame_fin(w_fin));

    wire [3:0] digito; wire hubo, realineo;
    cam78_cadena DUT (.pclk(pclk), .reset(reset), .w_valid(w_valid), .w_pix(w_pix),
                      .w_fin(w_fin), .digito(digito), .hubo(hubo), .realineo(realineo));

    integer f, r, i, fd, nver = 0, base, nbien = 0, usa_exp = 0;
    reg [1023:0] fesc, fout, fexp;
    // +EXP=<fichero>: el veredicto esperado por cuadro (0..9, 10=NADA), en hex. Con eso el
    // banco se juzga solo y corre en la VM, que no tiene python cientifico.
    reg [3:0] esp [0:NESC*REP-1];
    wire [3:0] v_ahora = DUT.valido ? DUT.dig : 4'd10;
    // un veredicto cada vez que la cadena termina de clasificar
    always @(posedge pclk) if (DUT.done) begin
        $fwrite(fd, "V %0d %0d %0d\n", nver, v_ahora, DUT.CAD.n_bordes);
        if (usa_exp && nver < NESC*REP) begin
            if (v_ahora == esp[nver]) nbien = nbien + 1;
            else $display("  cuadro %0d: sale %0d, golden %0d", nver, v_ahora, esp[nver]);
        end
        nver = nver + 1;
    end
    initial begin
        if (!$value$plusargs("ESC=%s", fesc)) begin $display("falta +ESC"); $finish; end
        if (!$value$plusargs("OUT=%s", fout)) begin $display("falta +OUT"); $finish; end
        $readmemh(fesc, mem);
        if ($value$plusargs("EXP=%s", fexp)) begin $readmemh(fexp, esp); usa_exp = 1; end
        fd = $fopen(fout, "w");
        repeat (4) @(posedge pclk); reset = 0; @(posedge pclk);
        // NESC*REP cuadros con escena, y UNO mas de papel en blanco para desaguar el ultimo
        for (f = 0; f <= NESC*REP; f = f + 1) begin
            base = (f < NESC*REP) ? (f / REP) * CAM_W * CAM_H : 0;
            for (r = 0; r < CAM_H; r = r + 1) begin
                href <= 1'b1;
                for (i = 0; i < CAM_W; i = i + 1) begin
                    curY <= (f < NESC*REP) ? mem[base + r*CAM_W + i] : 8'd235;
                    py_valid <= 1'b1; @(posedge pclk);
                    py_valid <= 1'b0; @(posedge pclk);          // el byte de croma
                end
                href <= 1'b0; repeat (40) @(posedge pclk);      // blanking horizontal
            end
            repeat (200) @(posedge pclk);                       // blanking vertical
        end
        repeat (2000) @(posedge pclk);
        $fwrite(fd, "REALINEO %0d\n", realineo);
        if (usa_exp) begin
            $display("  %0d/%0d veredictos iguales al golden · realineos: %0d", nbien, NESC*REP, realineo);
            if (nbien == NESC*REP && !realineo) $display("ALL TESTS PASSED");
            else $display("!! HAY FALLOS");
        end
        $fclose(fd); $finish;
    end
endmodule
`default_nettype wire
