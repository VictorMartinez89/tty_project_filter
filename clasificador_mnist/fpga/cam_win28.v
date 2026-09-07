// cam_win28.v — de la camara a las 28x28 que espera el clasificador.
//
//   ESTE MODULO ES LA RESPUESTA AL PROBLEMA DE MNIST. Los digitos de MNIST vienen normalizados
//   en tamano y centrados por centro de masa; lo que ve la OV7670 no. En vez de normalizar en
//   hardware -caro y fragil- se hace lo que hace un lector de QR:
//
//       se define una VENTANA CUADRADA fija en el centro del cuadro, se dibuja en la pantalla,
//       y el centrado lo hace la persona metiendo el digito adentro.
//
//   La ventana es de WINxWIN en el centro del cuadro de la camara, con WIN multiplo de 28: cada
//   pixel de salida es el PROMEDIO de un bloque de (WIN/28)^2. Se promedia y NO se decima: un
//   trazo fino puede caer entre dos muestras de una rejilla y el digito desaparece. Con WIN=448
//   el bloque es 16x16 = 256 y el divisor es un shift de 8.
//
//   INVERSION: MNIST es trazo CLARO sobre fondo OSCURO; tinta sobre papel es al reves.
`default_nettype none
module cam_win28 #(
    parameter integer CAM_W = 640, parameter integer CAM_H = 480,
    parameter integer WIN   = 448,
    parameter integer N     = 28
)(
    input  wire       pclk,
    input  wire       reset,
    input  wire       href,           // alto durante los pixeles activos de la linea
    input  wire [7:0] pix_y,
    input  wire       pix_valid,
    input  wire       invertir,
    output reg        out_valid,
    output reg  [7:0] out_pix,
    output reg        frame_fin       // pulso tras emitir el ultimo pixel de las 28x28
);
    localparam integer BLK = WIN / N;
    localparam integer X0  = (CAM_W - WIN) / 2;
    localparam integer Y0  = (CAM_H - WIN) / 2;

    reg [9:0]  cx, cy;
    reg [15:0] acc  [0:N-1];       // acumuladores en curso
    reg [15:0] fila [0:N-1];       // COPIA de la fila terminada, para emitir en paralelo
    reg [4:0]  ox, ex;
    reg [4:0]  oy;                    // fila de salida ya emitida (0..27)
    reg [4:0]  sub_x;
    reg [4:0]  sub_y;
    reg        emitiendo;
    integer i;

    reg  href_d;
    wire fin_linea = href_d & ~href;                 // flanco de bajada: termino la linea
    wire dentro_x = (cx >= X0) && (cx < X0 + WIN);
    wire dentro_y = (cy >= Y0) && (cy < Y0 + WIN);
    wire fin_blk  = fin_linea && dentro_y && (sub_y == BLK-1);  // se completo una fila de salida

    always @(posedge pclk) begin
        href_d <= href;
        if (reset) begin
            cx <= 0; cy <= 0; ox <= 0; ex <= 0; oy <= 0; href_d <= 1'b0;
            sub_x <= 0; sub_y <= 0; emitiendo <= 1'b0;
            out_valid <= 1'b0; out_pix <= 8'd0; frame_fin <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin acc[i] <= 16'd0; fila[i] <= 16'd0; end
        end else begin
            out_valid <= 1'b0; frame_fin <= 1'b0;

            // ---- la columna se re-sincroniza CON CADA LINEA ----
            //   Contar 640x480 pixeles y confiar en que la cuenta salga justa NO funciona: un
            //   solo pixel de desvio corre la ventana y la imagen se vuelve ruido. La OV7670
            //   marca cada linea activa con `href`, asi que la columna se pone en cero ahi y el
            //   error no se acumula. Es exactamente lo que hace el cam_sobel_display probado.
            if (!href) begin cx <= 0; ox <= 0; sub_x <= 0; end

            // ---- fin de linea: avanzar fila ----
            if (fin_linea) begin
                if (cy == CAM_H-1) begin cy <= 0; sub_y <= 0; end   // auto-sync: envuelve solo
                else begin
                    cy <= cy + 10'd1;
                    if (dentro_y) sub_y <= (sub_y == BLK-1) ? 5'd0 : sub_y + 5'd1;
                end
            end

            // ---- acumulacion: NUNCA se detiene ----
            //   La version anterior paraba de acumular mientras emitia, y los 28 ciclos del
            //   volcado se comian 28 pixeles de la camara: la imagen salia corrida y comprimida.
            //   Ahora la fila terminada se COPIA a `fila` en un ciclo y se emite desde ahi,
            //   mientras `acc` sigue sumando la fila siguiente. Cuesta 28 registros mas.
            if (pix_valid && href) begin
                if (dentro_x && dentro_y) begin
                    acc[ox] <= acc[ox] + {8'd0, pix_y};
                    if (sub_x == BLK-1) begin
                        sub_x <= 0;
                        if (ox != N-1) ox <= ox + 5'd1;
                    end else sub_x <= sub_x + 5'd1;
                end
                if (cx != CAM_W-1) cx <= cx + 10'd1;
            end

            if (1'b1) begin
                if (fin_blk) begin
                    emitiendo <= 1'b1; ex <= 0;
                    for (i = 0; i < N; i = i + 1) begin fila[i] <= acc[i]; acc[i] <= 16'd0; end
                end
            end

            // ---- volcado en PARALELO a la acumulacion, desde la copia ----
            if (emitiendo) begin
                out_valid <= 1'b1;
                out_pix   <= invertir ? (8'd255 - fila[ex][15:8]) : fila[ex][15:8];  // /256 = shift
                if (ex == N-1) begin
                    emitiendo <= 1'b0; ex <= 0;
                    oy <= (oy == N-1) ? 5'd0 : oy + 5'd1;
                    if (oy == N-1) frame_fin <= 1'b1;      // ultimo pixel de las 28x28
                end else ex <= ex + 5'd1;
            end
        end
    end
endmodule
`default_nettype wire
