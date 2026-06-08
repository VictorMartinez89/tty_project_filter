// =============================================================================
// canny_hysteresis_frame.sv  -- HISTERESIS TRANSITIVA (completa) de Canny.
//   A diferencia del 1-salto de canny_control, esta es la histeresis REAL:
//   un borde debil se conserva si esta conectado (por una cadena de debiles)
//   a un borde fuerte. = reconstruccion morfologica de 'strong' bajo la mascara
//   'weak|strong'. Se hace por PROPAGACION ITERATIVA sobre un frame buffer:
//     confirmed = strong;  repetir: confirmed |= (weak & dilata8(confirmed));
//   hasta que no cambie (estable). Converge en <= (cadena mas larga) ciclos.
//   Necesita el frame en memoria (aqui empaquetado; en HW real -> BRAM).
// =============================================================================
`default_nettype none
module canny_hysteresis_frame #(parameter integer H=16, parameter integer W=16)(
    input  wire           clk,
    input  wire           rst,                 // activo-alto
    input  wire           start,               // pulso: carga mascaras y arranca
    input  wire [H*W-1:0] strong_i,
    input  wire [H*W-1:0] weak_i,
    output reg            done,
    output wire [H*W-1:0] edge_o
);
    localparam [1:0] IDLE=0, RUN=1;
    reg [1:0]       state;
    reg [H*W-1:0]   confirmed, weak_r;

    // un paso de dilatacion-8 enmascarada por weak
    reg [H*W-1:0] nxt; reg nb; integer rr, cc, dr, dc;
    always @* begin
        nxt = confirmed;
        for (rr=0; rr<H; rr=rr+1) for (cc=0; cc<W; cc=cc+1) begin
            nb = 1'b0;
            for (dr=-1; dr<=1; dr=dr+1) for (dc=-1; dc<=1; dc=dc+1)
                if (!(dr==0 && dc==0) && rr+dr>=0 && rr+dr<H && cc+dc>=0 && cc+dc<W)
                    nb = nb | confirmed[(rr+dr)*W + (cc+dc)];
            nxt[rr*W+cc] = confirmed[rr*W+cc] | (weak_r[rr*W+cc] & nb);
        end
    end

    always @(posedge clk) begin
        if (rst) begin state<=IDLE; done<=1'b0; end
        else case (state)
            IDLE: if (start) begin
                      confirmed <= strong_i; weak_r <= weak_i; done <= 1'b0; state <= RUN;
                  end
            RUN:  if (nxt == confirmed) begin done <= 1'b1; state <= IDLE; end
                  else confirmed <= nxt;
        endcase
    end
    assign edge_o = confirmed;
endmodule
`default_nettype wire
