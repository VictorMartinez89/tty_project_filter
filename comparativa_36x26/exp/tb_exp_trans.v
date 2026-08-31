// tb_exp_trans.v — banco del experimento 5x6 para los filtros TRANSITIVOS.
// La cadena completa: imagen -> grad_class_top (Gauss -> Sobel -> doble umbral)
// -> mapa de CLASE de 2 bits -> motor de reconstruccion morfologica -> bordes.
// Es la misma cadena que arma trans_completo en el ASIC.
//   vvp a.out +IMG=img/mano.hex +OUT=exp/out/mano_trans.txt
`timescale 1ns/1ps
`default_nettype none
module tb_exp_trans;
    localparam H = 36, W = 26, N = H*W;
    reg clk = 0, reset = 1;
    reg cls_in_valid = 0;
    reg [7:0] cls_in_pix = 0;
    wire cls_v; wire [1:0] cls_p;

    // 1) generador de CLASE (con umbrales altos, los del transitivo)
    // umbrales del generador de clase, ajustables con +THI= / +TLO= (por defecto 110/70)
    integer thi_arg = 110, tlo_arg = 70;
    grad_class_top GC (.clk(clk), .reset(reset), .in_valid(cls_in_valid), .in_pix(cls_in_pix),
                       .thr_hi(thi_arg[7:0]), .thr_lo(tlo_arg[7:0]), .out_valid(cls_v), .class_out(cls_p));

    // 2) el motor
    reg eng_nreset = 0, eng_in_valid = 0;
    reg [1:0] eng_class = 0;
    wire load_ready, out_valid, edge_out, done;
`ifdef CON_CPU
    wire cpu_wrote; wire [7:0] thi, tlo; wire [1:0] modo;
    soc_trans_top DUT (.clk(clk), .resetn(eng_nreset),
                       .in_valid(eng_in_valid), .class_in(eng_class),
                       .load_ready(load_ready), .out_valid(out_valid),
                       .edge_out(edge_out), .done(done), .cpu_wrote_filter(cpu_wrote),
                       .thr_hi_o(thi), .thr_lo_o(tlo), .mode_o(modo));
`else
    trans_engine_top DUT (.clk(clk), .nreset(eng_nreset),
                          .in_valid(eng_in_valid), .class_in(eng_class),
                          .load_ready(load_ready), .out_valid(out_valid),
                          .edge_out(edge_out), .done(done));
`endif

    reg [7:0] img [0:N-1];
    reg [1:0] clases [0:N-1];
    reg       salida [0:N-1];
    integer i, rep, n_cls = 0, n_out = 0, bordes = 0, fuertes = 0, debiles = 0, fd, espera;
    reg [1023:0] f_img, f_out;

    always #5 clk = ~clk;

    // captura de la CLASE: dos pasadas, se guarda la segunda (la primera tiene
    // las dos filas de arriba sucias, como en cualquier line-buffer al arrancar)
    always @(posedge clk) if (cls_v) begin
        if (n_cls >= N && (n_cls - N) < N) begin
            clases[n_cls - N] = cls_p;
            if (cls_p == 2'd2) fuertes = fuertes + 1;
            else if (cls_p == 2'd1) debiles = debiles + 1;
        end
        n_cls = n_cls + 1;
    end

    always @(posedge clk) if (out_valid && n_out < N) begin
        salida[n_out] = edge_out;
        if (edge_out) bordes = bordes + 1;
        n_out = n_out + 1;
    end

    initial begin
        if (!$value$plusargs("IMG=%s", f_img)) begin $display("falta +IMG"); $finish; end
        if (!$value$plusargs("OUT=%s", f_out)) begin $display("falta +OUT"); $finish; end
        void'($value$plusargs("THI=%d", thi_arg));
        void'($value$plusargs("TLO=%d", tlo_arg));
        $readmemh(f_img, img);
        for (i = 0; i < N; i = i + 1) begin clases[i] = 2'd0; salida[i] = 1'b0; end

        // --- fase A: generar el mapa de clase ---
        repeat (6) @(posedge clk); reset = 0; @(posedge clk);
        for (rep = 0; rep < 2; rep = rep + 1)
            for (i = 0; i < N; i = i + 1) begin
                cls_in_valid <= 1'b1; cls_in_pix <= img[i]; @(posedge clk);
            end
        cls_in_valid <= 1'b0;
        repeat (20) @(posedge clk);

        // --- fase B: cargar ese mapa en el motor y dejarlo barrer ---
        eng_nreset = 1;
        espera = 0;
        while (!load_ready && espera < 5000) begin @(posedge clk); espera = espera + 1; end
        for (i = 0; i < N; i = i + 1) begin
            eng_class <= clases[i]; eng_in_valid <= 1'b1; @(posedge clk);
        end
        eng_in_valid <= 1'b0;
        espera = 0;
        while (!done && espera < 300000) begin @(posedge clk); espera = espera + 1; end

        fd = $fopen(f_out, "w");
        for (i = 0; i < N; i = i + 1) $fwrite(fd, "%0d\n", salida[i]);
        $fclose(fd);
        $display("%0d bordes de %0d pixeles | clase: %0d fuertes, %0d debiles | %0d ciclos de barrido",
                 bordes, N, fuertes, debiles, espera);
        $finish;
    end
endmodule
`default_nettype wire
