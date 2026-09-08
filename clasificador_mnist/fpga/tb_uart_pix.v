`timescale 1ns/1ps
module tb_pix;
    reg clk=0, cam_pclk=0, cam_href=0; reg [7:0] cam_d=0;
    wire tx, sck,mosi,cs,dc, lr,lg,lb;
    wire sda; pullup(sda);            // el SCCB lo necesita, si no cfg_done nunca sube
    always #41.667 clk=~clk;
    always #41.667 cam_pclk=~cam_pclk;
    top DUT(.clk(clk), .uart_tx_pin(tx), .cam_xclk(), .cam_scl(), .cam_sda(sda),
            .cam_pclk(cam_pclk), .cam_href(cam_href), .cam_d(cam_d),
            .tft_sck(sck), .tft_mosi(mosi), .tft_cs(cs), .tft_dc(dc),
            .led_r(lr), .led_g(lg), .led_b(lb));
    localparam DIV=104; integer i; reg [7:0] b;
    initial forever begin
        @(negedge tx);
        repeat(DIV+DIV/2) @(posedge clk);
        for(i=0;i<8;i=i+1) begin b[i]=tx; repeat(DIV) @(posedge clk); end
        $write("%c", b); $fflush;
    end
    // El bloque combinacional que calcula coptype depende de cpc, que se inicializa en su
    // declaracion y NUNCA cambia: en iverilog un always @(*) sin evento inicial no se ejecuta y
    // coptype se queda en x para siempre, trabando el SCCB. En hardware es logica pura y anda.
    // Se le da un empujon al arrancar para generar el evento. Es un arreglo del BANCO, no del diseno.
    initial begin #1 DUT.cpc = 3'd1; #1 DUT.cpc = 3'd0; end   // hay que CAMBIAR el valor

    integer r,c,esperas;
    initial begin
        // cboot son 2^20 ciclos = 87 ms antes de que el SCCB arranque. Hay que esperar
        // cfg_done de verdad, no un tiempo fijo: eso fue lo que fallo la primera vez.
        esperas=0;
        while (DUT.cfg_done !== 1'b1 && esperas < 150) begin #1_000_000; esperas=esperas+1; end
        $display("cfg_done=%b tras %0d ms", DUT.cfg_done, esperas);
        $display("  cboot_ok=%b  cpc=%0d  idx=%0d  cbi=%0d  cph=%0d  coptype=%0d",
                 DUT.cboot_ok, DUT.cpc, DUT.idx, DUT.cbi, DUT.cph, DUT.coptype);
        $display("  sda=%b scl=%b sda_oe=%b  rom=%04x tbl_end=%b",
                 sda, DUT.scl, DUT.sda_oe, DUT.rom, DUT.tbl_end);
        $display("--- lo que manda el UART ---");
        // El dato se cambia en el flanco de BAJADA, que es lo que hace una camara real: asi
        // esta estable cuando el DUT lo captura en el de subida. Cambiarlo justo en el posedge
        // -como hacia la version anterior- es una carrera del banco, y el DUT terminaba leyendo
        // el byte siguiente: por eso rep_and daba 80, el valor de la CROMA.
        for (r=0; r<400; r=r+1) begin
            for (c=0; c<640; c=c+1) begin
                // href y el primer byte de luma se ponen EN EL MISMO flanco: si href sube antes,
                // queda un posedge de mas y la paridad arranca corrida -el DUT captura la croma-.
                @(negedge cam_pclk); cam_href = 1; cam_d = 8'h20 + c[6:0];   // luma, rampa suave
                @(negedge cam_pclk);              cam_d = 8'h80;            // croma
            end
            @(negedge cam_pclk); cam_href = 0;
            repeat(20) @(posedge cam_pclk);
        end
        #3_000_000;
        $display("\n  hay_reporte=%b nuevo=%b h2=%b h3=%b mandando=%b mi=%0d u_listo=%b u_env=%b",
                 DUT.hay_reporte, DUT.nuevo, DUT.h2, DUT.h3, DUT.mandando, DUT.mi, DUT.u_listo, DUT.u_env);
        $display("--- interno: npix=%0d rep_and=%02x rep_or=%02x  muestra %02x %02x %02x %02x",
                 DUT.npix, DUT.rep_and, DUT.rep_or, DUT.muestra[0],DUT.muestra[1],DUT.muestra[2],DUT.muestra[3]);
        $finish;
    end
endmodule
