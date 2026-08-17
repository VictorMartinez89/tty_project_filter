// tt_um_soc_sobel_flash_vic.v — SoC Femto + Sobel con BOOT DE FLASH SPI EXTERNA (estilo Johan) para TT.
`default_nettype none
module tt_um_soc_sobel_flash_vic (
    input  wire [7:0] ui_in,    // in_pix[7:0]
    output wire [7:0] uo_out,   // out_pix[7:0]
    input  wire [7:0] uio_in,   // [0]=in_valid, [6]=flash_miso
    output wire [7:0] uio_out,  // [1]=out_valid, [2]=cpu_wrote_filter, [3]=flash_clk, [4]=flash_cs_n, [5]=flash_mosi
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire out_valid, cpu_wrote_filter, flash_clk, flash_cs_n, flash_mosi;
    soc_sobel_flash_top u_soc (
        .clk(clk), .resetn(rst_n),
        .in_valid(uio_in[0]), .in_pix(ui_in),
        .out_valid(out_valid), .out_pix(uo_out),
        .cpu_wrote_filter(cpu_wrote_filter),
        .flash_clk(flash_clk), .flash_cs_n(flash_cs_n), .flash_mosi(flash_mosi), .flash_miso(uio_in[6]));
    assign uio_out = {2'b0, flash_mosi, flash_cs_n, flash_clk, cpu_wrote_filter, out_valid, 1'b0};
    assign uio_oe  = 8'b0011_1110;   // salidas: [1..5]; entradas: [0]=in_valid, [6]=flash_miso
    wire _unused = &{ena, uio_in[7], uio_in[5:1], 1'b0};
endmodule
`default_nettype wire
