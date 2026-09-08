// tb_fpga.v — simula el diseno de la FPGA COMPLETO y decodifica el UART.
//   Sirve para ver lo que va a salir por el puerto serie ANTES de grabar la placa: si aca
//   imprime las diez lineas bien, en la iCESugar tambien. Es la version en simulacion del
//   "test de aislamiento" que ya se usa en el proyecto.
`timescale 1ns/1ps
`default_nettype none
module tb_fpga;
    reg clk = 0;
    wire tx, lg, lr, lb;
    always #41.667 clk = ~clk;              // 12 MHz

    top #(.PAUSA(24'd200_000)) DUT (.clk(clk), .uart_tx_pin(tx), .led_g(lg), .led_r(lr), .led_b(lb));

    // --- receptor UART: 115200 8N1 a 12 MHz -> 104 ciclos por bit ---
    localparam integer DIV = 104;
    integer i;
    reg [7:0] b;
    initial begin
        forever begin
            @(negedge tx);                                   // start
            repeat (DIV + DIV/2) @(posedge clk);             // al medio del primer bit
            for (i = 0; i < 8; i = i + 1) begin
                b[i] = tx; repeat (DIV) @(posedge clk);
            end
            $write("%c", b); $fflush;
        end
    end

    initial begin
        $display("--- salida del UART de la iCESugar (simulada) ---");
        #700_000_000;                       // 300 ms simulados: alcanza para los 10 digitos
        $display("\n--- LEDs: verde=%b (termino)  rojo=%b (hubo error) ---", lg, lr);
        $finish;
    end
endmodule
`default_nettype wire
