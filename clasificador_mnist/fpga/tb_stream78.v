// tb_stream78.v — la placa del flujo serie, simulada con la UART DE VERDAD, bit a bit.
//
//   No se le entregan pixeles al top: se le entregan FORMAS DE ONDA en uart_rx_pin, con start,
//   ocho datos y stop, y se decodifica lo que sale por uart_tx_pin igual que lo haria el Mac.
//   El instrumento es un diseno: si el banco se salta la UART, verifica algo que no se graba.
//
//   Se mandan NLOT lotes de NB imagenes, cada uno con su cola de 8 bytes y una pausa mayor
//   que IDLE, que es exactamente lo que hace placa78.py. En el lote PERDER (si >= 0) se omite
//   a proposito UN byte: ese lote debe salir mal, el LED rojo debe encenderse, y los lotes
//   siguientes deben salir BIEN. Eso es lo que prueba el realineo.
//
//   Salida: una linea "R <byte>" por respuesta, y "PERDIDO <0|1>" al final.
`default_nettype none
`timescale 1ns/1ps
module tb_stream78;
    parameter integer DIV  = 8;
    parameter integer IDLE = 4000;
    reg clk = 0; always #5 clk = ~clk;
    reg rx = 1'b1;
    wire tx, lr, lg, lb;
    top #(.DIVISOR(DIV), .IDLE(IDLE)) dut (
        .clk(clk), .uart_rx_pin(rx), .uart_tx_pin(tx), .led_r(lr), .led_g(lg), .led_b(lb));

    reg [7:0] img [0:784*200-1];
    reg [1023:0] fin, fout, fexp;
    integer NB, NLOT, PERDER, fd, l, i, k, n;
    // +EXP=<fichero>: los bytes esperados, uno por imagen, en hex. Con eso el banco se juzga
    // solo y no hace falta python (la VM no tiene conda).
    reg [7:0] esp [0:199];
    integer usa_exp = 0, nresp = 0, nbien = 0, nexcl = 0;
    reg [7:0] exp_b;

    task enviar(input [7:0] b);
        integer j;
        begin
            rx = 1'b0; repeat (DIV) @(posedge clk);            // start
            for (j = 0; j < 8; j = j + 1) begin rx = b[j]; repeat (DIV) @(posedge clk); end
            rx = 1'b1; repeat (DIV) @(posedge clk);            // stop
            // un poco de aire entre bytes, como el USB, que no los manda pegados
            repeat (1 + (b % 3)) @(posedge clk);
        end
    endtask

    // decodificador del lado del Mac
    reg [7:0] rb; integer j2;
    initial forever begin
        @(negedge tx);
        repeat (DIV/2) @(posedge clk);
        for (j2 = 0; j2 < 8; j2 = j2 + 1) begin repeat (DIV) @(posedge clk); rb[j2] = tx; end
        repeat (DIV) @(posedge clk);
        $fwrite(fd, "R %0d\n", rb);
        if (usa_exp) begin
            if (rb == 8'h21) nexcl = nexcl + 1;
            else begin
                exp_b = esp[nresp];
                if (rb == exp_b) nbien = nbien + 1;
                else $display("  imagen %0d: placa %s (%02x), golden %s (%02x)",
                              nresp, rb, rb, exp_b, exp_b);
                nresp = nresp + 1;
            end
        end
    end

    initial begin
        if (!$value$plusargs("IN=%s", fin))   begin $display("falta +IN");  $finish; end
        if (!$value$plusargs("OUT=%s", fout)) begin $display("falta +OUT"); $finish; end
        if (!$value$plusargs("NB=%d", NB))     NB = 4;
        if (!$value$plusargs("NLOT=%d", NLOT)) NLOT = 2;
        if (!$value$plusargs("PERDER=%d", PERDER)) PERDER = -1;
        $readmemh(fin, img);
        if ($value$plusargs("EXP=%s", fexp)) begin $readmemh(fexp, esp); usa_exp = 1; end
        if ($test$plusargs("VCD")) begin
            // solo el top y la frontera de la cadena: el disenio entero pesaria cientos de MB
            $dumpfile("stream78.vcd");
            $dumpvars(1, tb_stream78.dut);
            $dumpvars(1, tb_stream78.dut.CAD);
        end
        fd = $fopen(fout, "w");
        repeat (300) @(posedge clk);                            // el reset de encendido
        n = 0;
        for (l = 0; l < NLOT; l = l + 1) begin
            $fwrite(fd, "LOTE %0d\n", l);
            for (i = 0; i < NB * 784; i = i + 1) begin
                // el byte perdido: a mitad de la segunda imagen del lote
                if (!(l == PERDER && i == 784 + 300)) enviar(img[n * 784 + i]);
            end
            for (k = 0; k < 8; k = k + 1) enviar(8'd0);        // la cola
            n = n + NB;
            repeat (IDLE + 3000) @(posedge clk);                // la pausa entre lotes
        end
        $fwrite(fd, "PERDIDO %0d\n", dut.perdido);
        if (usa_exp) begin
            $display("  %0d/%0d veredictos iguales al golden · '!' recibidos: %0d · LED rojo: %0d",
                     nbien, NB*NLOT, nexcl, dut.perdido);
            if (nbien == NB*NLOT && nresp == NB*NLOT && PERDER < 0 && !dut.perdido)
                $display("ALL TESTS PASSED");
            else if (PERDER < 0) $display("!! HAY FALLOS");
        end
        $fclose(fd); $finish;
    end
endmodule
`default_nettype wire
