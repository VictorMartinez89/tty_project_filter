// =============================================================================
// canny_modular_top.sv  -- CADENA MODULAR de Canny (streaming) hasta la CLASE.
//   Encadena las etapas por-pixel que ya estan validadas por separado:
//     gris --> sobel_compass_control --(mag,dir)--> nms_control --(mag_nms)-->
//              canny_grad_threshold_core (doble umbral) --> class (0/1/2)
//
//   Cada etapa de ventana 3x3 pierde 1 px de borde:
//     - compass_control: valido en interior (ancho de su salida = img_w-2)
//     - nms_control:     por eso su img_w = (img_w-2)
//   => la CLASE sale para el interior de interior: (H-4) x (W-4) pixeles.
//   Las etapas NO necesitan handshake de stall: nms solo avanza con in_valid.
// =============================================================================
`default_nettype none
module canny_modular_top #(
    parameter integer PIX = 8,
    parameter integer MAX_IMG_W = 1024
)(
    input  wire           clk_i,
    input  wire           nreset_i,       // activo-bajo
    input  wire [15:0]    img_w_i,        // ancho de la imagen de ENTRADA (gris)
    input  wire           px_valid_i,
    input  wire [PIX-1:0] px_i,
    input  wire [PIX-1:0] low_i, high_i,
    output wire           out_valid_o,
    output wire [PIX-1:0] mag_o,          // magnitud tras NMS (0 si suprimido)
    output wire [2:0]     dir_o,          // direccion del centro
    output wire [1:0]     class_o         // 0 nada / 1 debil / 2 fuerte
);
    // --- etapa 1: gradiente compass + direccion ---
    wire           v1;
    wire [PIX-1:0] mag1;
    wire [2:0]     dir1;
    sobel_compass_control #(.PIX(PIX), .MAX_IMG_W(MAX_IMG_W)) u_cc (
        .clk_i(clk_i), .nreset_i(nreset_i), .img_w_i(img_w_i),
        .px_valid_i(px_valid_i), .px_i(px_i),
        .out_valid_o(v1), .mag_o(mag1), .dir_o(dir1), .mags8_o());

    // --- etapa 2: NMS (su "imagen" es la salida interior del compass -> ancho-2) ---
    wire           v2;
    wire [PIX-1:0] mag2;
    wire [2:0]     dir2;
    nms_control #(.MAGW(PIX), .MAX_IMG_W(MAX_IMG_W)) u_nms (
        .clk_i(clk_i), .nreset_i(nreset_i), .img_w_i(img_w_i - 16'd2),
        .in_valid_i(v1), .mag_i(mag1), .dir_i(dir1),
        .out_valid_o(v2), .mag_o(mag2), .keep_o(), .dir_o(dir2));

    // --- etapa 3: doble umbral (combinacional, por pixel) ---
    canny_grad_threshold_core #(.MAGW(PIX)) u_th (
        .mag_i(mag2), .low_i(low_i), .high_i(high_i),
        .g_low_o(), .g_high_o(), .class_o(class_o), .combo_o());

    assign out_valid_o = v2;
    assign mag_o       = mag2;
    assign dir_o       = dir2;
endmodule
`default_nettype wire
