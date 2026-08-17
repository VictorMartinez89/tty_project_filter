`timescale 1ns/1ps
`define SIMULATION
module tb_flash;
    reg clk=0, resetn=0; reg in_valid=0; reg [7:0] in_pix=0;
    wire out_valid; wire [7:0] out_pix; wire cpu_wrote_filter;
    wire flash_clk, flash_cs_n, flash_mosi, flash_miso;

    soc_sobel_flash_top DUT (
        .clk(clk), .resetn(resetn), .in_valid(in_valid), .in_pix(in_pix),
        .out_valid(out_valid), .out_pix(out_pix), .cpu_wrote_filter(cpu_wrote_filter),
        .flash_clk(flash_clk), .flash_cs_n(flash_cs_n), .flash_mosi(flash_mosi), .flash_miso(flash_miso));

    // modelo de flash SPI (Claire Wolf) con el firmware Sobel
    spiflash flash0(.csb(flash_cs_n), .clk(flash_clk), .io0(flash_mosi), .io1(flash_miso), .io2(), .io3());

    always #5 clk = ~clk;             // 100 MHz
    integer i; reg done=0;
    initial begin
        $dumpfile("tb_flash.vcd"); $dumpvars(0, tb_flash);
        resetn=0; repeat(10) @(posedge clk); resetn=1;
        // esperar a que el CPU arranque de flash y escriba el periferico
        for (i=0; i<200000 && !done; i=i+1) begin
            @(posedge clk);
            if (cpu_wrote_filter && !done) begin
                done=1;
                $display("=== BOOT OK: el CPU arranco de FLASH y escribio el filtro (cpu_wrote_filter=1) en ~%0d ciclos ===", i);
            end
        end
        if (!done) $display("=== FALLO: cpu_wrote_filter nunca subio (revisar boot de flash) ===");
        // meter unos pixeles para ver el datapath
        repeat(50) begin @(posedge clk); in_valid<=1; in_pix<=$random; end
        in_valid<=0; repeat(20) @(posedge clk);
        $finish;
    end
endmodule
