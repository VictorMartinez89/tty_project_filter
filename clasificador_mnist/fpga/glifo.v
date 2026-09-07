// glifo.v — el digito reconocido, grande, en la pantalla. Siete segmentos dibujados a mano.
//   Entra una coordenada (gx,gy) dentro de una caja de ANCHO x ALTO y el digito; sale 1 si ese
//   punto cae sobre un segmento encendido. Es puramente combinacional: no hay memoria de fuente,
//   solo comparaciones. Una fuente de mapa de bits para 10 digitos costaria BRAM; esto cuesta
//   unas pocas LUT, que es la diferencia entre que entre y que no.
`default_nettype none
module glifo #(
    parameter integer ANCHO = 60, parameter integer ALTO = 96, parameter integer GRUESO = 10
)(
    input  wire [3:0] digito,
    input  wire [7:0] gx, gy,
    output wire       encendido
);
    // segmentos:   a
    //            f   b
    //              g
    //            e   c
    //              d
    reg [6:0] seg;                       // {g,f,e,d,c,b,a}
    always @(*) case (digito)
        4'd0: seg = 7'b0111111;
        4'd1: seg = 7'b0000110;
        4'd2: seg = 7'b1011011;
        4'd3: seg = 7'b1001111;
        4'd4: seg = 7'b1100110;
        4'd5: seg = 7'b1101101;
        4'd6: seg = 7'b1111101;
        4'd7: seg = 7'b0000111;
        4'd8: seg = 7'b1111111;
        4'd9: seg = 7'b1101111;
        default: seg = 7'b0000000;
    endcase

    localparam integer MED = ALTO/2;
    wire hx = (gx >= GRUESO) && (gx < ANCHO-GRUESO);      // tramo horizontal (sin las esquinas)
    wire vy_a = (gy >= GRUESO) && (gy < MED-GRUESO/2);    // mitad de arriba
    wire vy_b = (gy >= MED+GRUESO/2) && (gy < ALTO-GRUESO);

    wire s_a = seg[0] && hx && (gy < GRUESO);
    wire s_b = seg[1] && vy_a && (gx >= ANCHO-GRUESO);
    wire s_c = seg[2] && vy_b && (gx >= ANCHO-GRUESO);
    wire s_d = seg[3] && hx && (gy >= ALTO-GRUESO);
    wire s_e = seg[4] && vy_b && (gx < GRUESO);
    wire s_f = seg[5] && vy_a && (gx < GRUESO);
    wire s_g = seg[6] && hx && (gy >= MED-GRUESO/2) && (gy < MED+GRUESO/2);

    assign encendido = s_a | s_b | s_c | s_d | s_e | s_f | s_g;
endmodule
`default_nettype wire
