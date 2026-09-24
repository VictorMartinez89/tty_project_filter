// cam78_cadena.v — de la ventana de 28x28 de la camara al veredicto, con la cadena del 97,22 %.
//
//   Es la pieza que cambia respecto de mnist_cam_canny.v, y vive en un modulo aparte por una
//   razon: el banco de pruebas y la placa instancian ESTE MISMO modulo. Asi lo que se simula
//   es lo que se graba, no una copia que se le parece.
//
//   cam_win28 -> [realineo] -> mnist_top78 -> digito (0..9, o 10 = NADA)
//
//   El realineo. mnist_top78 cuenta el raster por su cuenta desde el reset: si un cuadro de la
//   camara llegara con un pixel de mas o de menos, todos los siguientes quedarian corridos y el
//   circuito clasificaria basura con total seguridad (la §36.14 midio lo que cuesta un
//   corrimiento: a 3 px, del 97 al 63 %). Por eso se cuentan los pixeles modulo 784 y, si al
//   llegar frame_fin la cuenta no cierra en cero, la cadena se resetea. Un cuadro malo cuesta
//   un veredicto, no el resto de la sesion.
//
//   La latencia: el veredicto de un cuadro sale cuando llegan las primeras muestras del
//   SIGUIENTE (el cauce necesita desaguar) mas 777 ciclos de clasificacion. A 30 cuadros por
//   segundo es un cuadro de retraso, invisible en la pantalla.
`default_nettype none
module cam78_cadena (
    input  wire       pclk,
    input  wire       reset,
    input  wire       w_valid,
    input  wire [7:0] w_pix,
    input  wire       w_fin,
    output reg  [3:0] digito,       // 0..9, o 10 = NADA
    output reg        hubo,         // ya clasifico al menos una vez
    output reg        realineo      // hubo que realinear alguna vez (diagnostico)
);
    reg [9:0] cuenta;               // pixeles del cuadro en curso, modulo 784
    reg [2:0] rst_n;                // pulso de reset de la cadena
    wire [9:0] sig = (cuenta == 10'd783) ? 10'd0 : cuenta + 10'd1;

    always @(posedge pclk) begin
        if (reset) begin cuenta <= 10'd0; rst_n <= 3'd0; realineo <= 1'b0; end
        else begin
            if (rst_n != 3'd0) rst_n <= rst_n - 3'd1;
            if (w_valid) cuenta <= sig;
            // frame_fin llega en el MISMO ciclo que el ultimo pixel: la cuenta que vale es `sig`
            if (w_fin && (w_valid ? sig : cuenta) != 10'd0) begin
                cuenta <= 10'd0; rst_n <= 3'd4; realineo <= 1'b1;
            end
        end
    end
    wire reset_cad = reset | (rst_n != 3'd0);

    wire       done, valido;
    wire [3:0] dig;
    mnist_top78 CAD (
        .clk(pclk), .reset(reset_cad),
        .in_valid(w_valid & ~reset_cad), .in_pix(w_pix),
        .thr_hi(8'd90), .thr_lo(8'd32),         // los del entrenamiento del 97,22 %
        .done(done), .digito(dig), .valido(valido));

    // Si el clasificador dice NADA se muestra el codigo 10, que el glifo dibuja como una raya.
    always @(posedge pclk) begin
        if (reset) begin digito <= 4'd10; hubo <= 1'b0; end
        else if (done) begin digito <= valido ? dig : 4'd10; hubo <= 1'b1; end
    end
endmodule
`default_nettype wire
