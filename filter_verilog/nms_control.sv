// =============================================================================
// nms_control.sv
//   Controlador de VENTANA DESLIZANTE 3x3 (line buffers) para la etapa de NMS.
//   Toma el STREAM (mag, dir) que sale de sobel_compass_control y arma la ventana
//   3x3 de MAGNITUDES para alimentar nms_core.
//
//   Truco: empaca {dir,mag} en cada celda de la ventana, asi la direccion viaja
//   junto a su pixel. El NMS usa la MAGNITUD de los 8 vecinos y la DIRECCION del
//   CENTRO (w4). Mismo patron que sobel_compass_control (2 line buffers; salida
//   valida solo en pixeles interiores).
//
//   Pipeline modular:
//     sobel_compass_control --(mag,dir)--> nms_control --(mag_nms)--> doble umbral
// =============================================================================
`default_nettype none
module nms_control #(
    parameter integer MAGW = 8,
    parameter integer MAX_IMG_W = 1024
)(
    input  wire            clk_i,
    input  wire            nreset_i,      // activo-bajo (estilo Diana)
    input  wire [15:0]     img_w_i,       // ancho de imagen en runtime
    input  wire            in_valid_i,
    input  wire [MAGW-1:0] mag_i,         // magnitud del pixel (de compass_control)
    input  wire [2:0]      dir_i,         // su direccion (0=N..7=NW)
    output reg             out_valid_o,
    output wire [MAGW-1:0] mag_o,         // magnitud tras NMS (0 si suprimido)
    output wire            keep_o,        // 1 = el centro sobrevive
    output wire [2:0]      dir_o          // direccion del centro (passthrough)
);
    localparam integer DW = MAGW + 3;              // celda = {dir[2:0], mag}

    // line buffers: line1 = fila (row-1), line2 = fila (row-2)
    reg [DW-1:0] line1 [0:MAX_IMG_W-1];
    reg [DW-1:0] line2 [0:MAX_IMG_W-1];
    // ventana 3x3 (row-major): w0 w1 w2 / w3 w4 w5 / w6 w7 w8  (w4 = centro)
    reg [DW-1:0] w0,w1,w2,w3,w4,w5,w6,w7,w8;

    reg [$clog2(MAX_IMG_W)-1:0] col;
    reg [15:0]                  row;

    wire [DW-1:0] top = line2[col];                // vecino fila-2 (arriba)
    wire [DW-1:0] mid = line1[col];                // vecino fila-1
    wire [DW-1:0] bot = {dir_i, mag_i};            // celda entrante (fila actual)

    // ventana de MAGNITUDES empacada para nms_core (row-major); descarta el dir
    // de los vecinos y se queda solo con la magnitud de cada celda.
    wire [9*MAGW-1:0] mag9;
    assign mag9[MAGW*0 +: MAGW] = w0[MAGW-1:0];
    assign mag9[MAGW*1 +: MAGW] = w1[MAGW-1:0];
    assign mag9[MAGW*2 +: MAGW] = w2[MAGW-1:0];
    assign mag9[MAGW*3 +: MAGW] = w3[MAGW-1:0];
    assign mag9[MAGW*4 +: MAGW] = w4[MAGW-1:0];
    assign mag9[MAGW*5 +: MAGW] = w5[MAGW-1:0];
    assign mag9[MAGW*6 +: MAGW] = w6[MAGW-1:0];
    assign mag9[MAGW*7 +: MAGW] = w7[MAGW-1:0];
    assign mag9[MAGW*8 +: MAGW] = w8[MAGW-1:0];

    wire [2:0] cdir = w4[MAGW +: 3];               // direccion del CENTRO
    assign dir_o = cdir;

    nms_core #(.MAGW(MAGW)) u_nms (
        .mag9_i(mag9), .dir_i(cdir), .mag_o(mag_o), .keep_o(keep_o)
    );

    always @(posedge clk_i or negedge nreset_i) begin
        if (!nreset_i) begin
            col <= 0; row <= 0; out_valid_o <= 1'b0;
            w0<=0;w1<=0;w2<=0;w3<=0;w4<=0;w5<=0;w6<=0;w7<=0;w8<=0;
        end else begin
            out_valid_o <= 1'b0;
            if (in_valid_i) begin
                // desplazar columnas e insertar columna derecha (top,mid,bot)
                w0<=w1; w1<=w2; w2<=top;
                w3<=w4; w4<=w5; w5<=mid;
                w6<=w7; w7<=w8; w8<=bot;
                // actualizar line buffers en esta columna
                line2[col] <= line1[col];
                line1[col] <= bot;
                // salida valida solo en interior (ventana 3x3 completa)
                if (row >= 2 && col >= 2) out_valid_o <= 1'b1;
                // contadores raster
                if (col == img_w_i-1) begin col <= 0; row <= row + 1; end
                else col <= col + 1;
            end
        end
    end
endmodule
`default_nettype wire
