`timescale 1ns/1ps
// ov7670_model.v — modelo (emulador) de la camara OV7670 para simulacion.
// Genera VSYNC / HREF / PCLK y transmite una imagen por D0..D7 en formato
// YUV422: por cada pixel salen 2 bytes -> byte PAR = luma (Y), byte IMPAR =
// croma (0x80, ignorado por el filtro).  Reusable para Sobel y Canny.
//
// La imagen (600x480) la carga el testbench en 'mem' por referencia jerarquica
// ANTES de subir 'start' (asi no dependemos de un parametro string).
//   SW = columnas de luma (600) -> submuestreo /10 del RTL => 60 col
//   SH = filas            (480) -> submuestreo /6  del RTL => 80 filas
module ov7670_model #(parameter SW = 600, SH = 480, parameter NFRAMES = 2) (
    input  wire       start,
    output reg        pclk,
    output reg        href,
    output reg        vsync,
    output reg  [7:0] d,
    output reg        done
);
    reg [7:0] mem [0:SW*SH-1];
    integer r, c, idx;

    task pclk_tick(input [7:0] val);
        begin
            d = val; #5;     // dato estable antes del flanco
            pclk = 1'b1; #5; // el DUT muestrea en posedge cam_pclk
            pclk = 1'b0; #5;
        end
    endtask

    integer bp, fr;
    initial begin
        pclk = 0; href = 0; vsync = 0; d = 0; done = 0;
        @(posedge start);
        for (fr = 0; fr < NFRAMES; fr = fr + 1) begin   // varios frames (video real refresca)
            vsync = 1; #200; vsync = 0; #200;           // pulso de inicio de frame
            for (r = 0; r < SH; r = r + 1) begin
                href = 0; for (bp=0; bp<8; bp=bp+1) pclk_tick(8'h00);   // back-porch
                href = 1;
                for (c = 0; c < SW; c = c + 1) begin
                    idx = r*SW + c;
                    pclk_tick(mem[idx]);    // byte par  = luma Y  <- imagen
                    pclk_tick(8'h80);       // byte impar = croma  (ignorado)
                end
                href = 0; for (bp=0; bp<8; bp=bp+1) pclk_tick(8'h00); // front-porch
            end
        end
        #200; done = 1;
    end
endmodule
