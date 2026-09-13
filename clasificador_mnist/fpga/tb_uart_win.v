// tb_uart_win.v — comprueba que la placa vuelca bien la ventana de 28x28 por el puerto serie.
//   Emula una camara con un cuadro CHICO (112x112, ventana 56 -> bloques de 2x2) y un patron
//   conocido: una rampa horizontal. Despues DECODIFICA el UART y escribe lo recibido a un
//   archivo, para comprobar el formato y los valores sin mirar una sola forma de onda.
`timescale 1ns/1ps
`default_nettype none
module tb_uart_win;
    localparam integer CW = 112, CH = 112, WIN = 56, DIV = 104;
    reg clk = 0, pclk = 0;
    reg href = 0;
    reg [7:0] cam_d = 0;
    wire tx, scl, sda_w;
    wire led_r, led_g, led_b;
    pullup(sda_w);                       // el bus SCCB es colector abierto

    always #5  clk  = ~clk;              // 100 MHz nominal (el divisor del UART es lo que importa)
    always #5  pclk = ~pclk;

    top #(.CAM_W(CW), .CAM_H(CH), .WIN(WIN), .INVERTIR(0)) DUT (
        .clk(clk), .cam_xclk(), .cam_scl(scl), .cam_sda(sda_w),
        .cam_pclk(pclk), .cam_href(href), .cam_d(cam_d),
        .uart_tx_pin(tx), .led_r(led_r), .led_g(led_g), .led_b(led_b));

    // ---------- camara emulada: rampa horizontal, formato UYVY ----------
    integer f, y, x;
    initial begin
        href = 0; #200;
        for (f = 0; f < 3; f = f + 1)
            for (y = 0; y < CH; y = y + 1) begin
                // href se levanta JUNTO con el primer byte de croma. Levantarlo un flanco
                // ANTES invierte la paridad y el diseno captura croma (0x80 constante) en vez
                // de luma: es la carrera de banco de la Parte 186, y da un sintoma identico al
                // del bug real de la camara. El banco tambien es hardware.
                @(negedge pclk); href = 1; cam_d = 8'h80;    // croma del pixel 0
                for (x = 0; x < CW; x = x + 1) begin
                    @(negedge pclk); cam_d = x[7:0];         // LUMA del pixel x = rampa
                    if (x != CW-1) begin
                        @(negedge pclk); cam_d = 8'h80;      // croma del pixel x+1
                    end
                end
                @(negedge pclk); href = 0;
                repeat (8) @(negedge pclk);
            end
    end

    // ---------- decodificador de UART ----------
    integer fd, n_by;
    reg [7:0] b;
    integer k;
    initial begin
        fd = $fopen("/tmp/win_uart.txt", "w"); n_by = 0;
        forever begin
            @(negedge tx);                       // bit de start
            #(DIV*10*1.5);                       // al medio del bit 0
            for (k = 0; k < 8; k = k + 1) begin
                b[k] = tx; #(DIV*10);
            end
            $fwrite(fd, "%c", b); n_by = n_by + 1;
            if (n_by > 5000) begin $fclose(fd); $display("suficiente"); $finish; end
        end
    end

    initial begin
        #40_000_000;                             // tope duro
        $fclose(fd);
        $display("fin por tiempo · bytes recibidos: %0d", n_by);
        $finish;
    end
endmodule
`default_nettype wire
