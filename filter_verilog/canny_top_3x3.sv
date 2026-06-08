// AUTO-GENERADO. Canny 3x3 combinacional: ventana (K+2)x(K+2)=5x5 ->
//   suaviza la vecindad 3x3 del centro con gaussian3x3 -> gradiente -> doble umbral.
//   pixel (r,c) en win_i[PIX*(r*5+c) +: PIX].  NMS+histeresis = futuro (no por-pixel).
`default_nettype none
module canny_top_3x3 #(parameter integer PIX=8, parameter integer USE_SQRT=0)(
    input  wire [5*5*PIX-1:0] win_i,
    input  wire [PIX+3:0] low_i, high_i,
    output wire [PIX+3:0] g_low_o, g_high_o,
    output wire [1:0]     class_o,
    output wire [(PIX+4+1)/2:0] combo_o);
    wire [PIX-1:0] sm [0:8];   // 3x3 suavizado
    // posicion gradiente g=0  centro suavizado (1,1)
    wire [9*PIX-1:0] sub0;
    assign sub0[PIX*0 +: PIX] = win_i[PIX*0 +: PIX];
    assign sub0[PIX*1 +: PIX] = win_i[PIX*1 +: PIX];
    assign sub0[PIX*2 +: PIX] = win_i[PIX*2 +: PIX];
    assign sub0[PIX*3 +: PIX] = win_i[PIX*5 +: PIX];
    assign sub0[PIX*4 +: PIX] = win_i[PIX*6 +: PIX];
    assign sub0[PIX*5 +: PIX] = win_i[PIX*7 +: PIX];
    assign sub0[PIX*6 +: PIX] = win_i[PIX*10 +: PIX];
    assign sub0[PIX*7 +: PIX] = win_i[PIX*11 +: PIX];
    assign sub0[PIX*8 +: PIX] = win_i[PIX*12 +: PIX];
    gaussian3x3 #(.PIX(PIX)) ug0 (.win_i(sub0), .gray_o(sm[0]));
    // posicion gradiente g=1  centro suavizado (1,2)
    wire [9*PIX-1:0] sub1;
    assign sub1[PIX*0 +: PIX] = win_i[PIX*1 +: PIX];
    assign sub1[PIX*1 +: PIX] = win_i[PIX*2 +: PIX];
    assign sub1[PIX*2 +: PIX] = win_i[PIX*3 +: PIX];
    assign sub1[PIX*3 +: PIX] = win_i[PIX*6 +: PIX];
    assign sub1[PIX*4 +: PIX] = win_i[PIX*7 +: PIX];
    assign sub1[PIX*5 +: PIX] = win_i[PIX*8 +: PIX];
    assign sub1[PIX*6 +: PIX] = win_i[PIX*11 +: PIX];
    assign sub1[PIX*7 +: PIX] = win_i[PIX*12 +: PIX];
    assign sub1[PIX*8 +: PIX] = win_i[PIX*13 +: PIX];
    gaussian3x3 #(.PIX(PIX)) ug1 (.win_i(sub1), .gray_o(sm[1]));
    // posicion gradiente g=2  centro suavizado (1,3)
    wire [9*PIX-1:0] sub2;
    assign sub2[PIX*0 +: PIX] = win_i[PIX*2 +: PIX];
    assign sub2[PIX*1 +: PIX] = win_i[PIX*3 +: PIX];
    assign sub2[PIX*2 +: PIX] = win_i[PIX*4 +: PIX];
    assign sub2[PIX*3 +: PIX] = win_i[PIX*7 +: PIX];
    assign sub2[PIX*4 +: PIX] = win_i[PIX*8 +: PIX];
    assign sub2[PIX*5 +: PIX] = win_i[PIX*9 +: PIX];
    assign sub2[PIX*6 +: PIX] = win_i[PIX*12 +: PIX];
    assign sub2[PIX*7 +: PIX] = win_i[PIX*13 +: PIX];
    assign sub2[PIX*8 +: PIX] = win_i[PIX*14 +: PIX];
    gaussian3x3 #(.PIX(PIX)) ug2 (.win_i(sub2), .gray_o(sm[2]));
    // posicion gradiente g=3  centro suavizado (2,1)
    wire [9*PIX-1:0] sub3;
    assign sub3[PIX*0 +: PIX] = win_i[PIX*5 +: PIX];
    assign sub3[PIX*1 +: PIX] = win_i[PIX*6 +: PIX];
    assign sub3[PIX*2 +: PIX] = win_i[PIX*7 +: PIX];
    assign sub3[PIX*3 +: PIX] = win_i[PIX*10 +: PIX];
    assign sub3[PIX*4 +: PIX] = win_i[PIX*11 +: PIX];
    assign sub3[PIX*5 +: PIX] = win_i[PIX*12 +: PIX];
    assign sub3[PIX*6 +: PIX] = win_i[PIX*15 +: PIX];
    assign sub3[PIX*7 +: PIX] = win_i[PIX*16 +: PIX];
    assign sub3[PIX*8 +: PIX] = win_i[PIX*17 +: PIX];
    gaussian3x3 #(.PIX(PIX)) ug3 (.win_i(sub3), .gray_o(sm[3]));
    // posicion gradiente g=4  centro suavizado (2,2)
    wire [9*PIX-1:0] sub4;
    assign sub4[PIX*0 +: PIX] = win_i[PIX*6 +: PIX];
    assign sub4[PIX*1 +: PIX] = win_i[PIX*7 +: PIX];
    assign sub4[PIX*2 +: PIX] = win_i[PIX*8 +: PIX];
    assign sub4[PIX*3 +: PIX] = win_i[PIX*11 +: PIX];
    assign sub4[PIX*4 +: PIX] = win_i[PIX*12 +: PIX];
    assign sub4[PIX*5 +: PIX] = win_i[PIX*13 +: PIX];
    assign sub4[PIX*6 +: PIX] = win_i[PIX*16 +: PIX];
    assign sub4[PIX*7 +: PIX] = win_i[PIX*17 +: PIX];
    assign sub4[PIX*8 +: PIX] = win_i[PIX*18 +: PIX];
    gaussian3x3 #(.PIX(PIX)) ug4 (.win_i(sub4), .gray_o(sm[4]));
    // posicion gradiente g=5  centro suavizado (2,3)
    wire [9*PIX-1:0] sub5;
    assign sub5[PIX*0 +: PIX] = win_i[PIX*7 +: PIX];
    assign sub5[PIX*1 +: PIX] = win_i[PIX*8 +: PIX];
    assign sub5[PIX*2 +: PIX] = win_i[PIX*9 +: PIX];
    assign sub5[PIX*3 +: PIX] = win_i[PIX*12 +: PIX];
    assign sub5[PIX*4 +: PIX] = win_i[PIX*13 +: PIX];
    assign sub5[PIX*5 +: PIX] = win_i[PIX*14 +: PIX];
    assign sub5[PIX*6 +: PIX] = win_i[PIX*17 +: PIX];
    assign sub5[PIX*7 +: PIX] = win_i[PIX*18 +: PIX];
    assign sub5[PIX*8 +: PIX] = win_i[PIX*19 +: PIX];
    gaussian3x3 #(.PIX(PIX)) ug5 (.win_i(sub5), .gray_o(sm[5]));
    // posicion gradiente g=6  centro suavizado (3,1)
    wire [9*PIX-1:0] sub6;
    assign sub6[PIX*0 +: PIX] = win_i[PIX*10 +: PIX];
    assign sub6[PIX*1 +: PIX] = win_i[PIX*11 +: PIX];
    assign sub6[PIX*2 +: PIX] = win_i[PIX*12 +: PIX];
    assign sub6[PIX*3 +: PIX] = win_i[PIX*15 +: PIX];
    assign sub6[PIX*4 +: PIX] = win_i[PIX*16 +: PIX];
    assign sub6[PIX*5 +: PIX] = win_i[PIX*17 +: PIX];
    assign sub6[PIX*6 +: PIX] = win_i[PIX*20 +: PIX];
    assign sub6[PIX*7 +: PIX] = win_i[PIX*21 +: PIX];
    assign sub6[PIX*8 +: PIX] = win_i[PIX*22 +: PIX];
    gaussian3x3 #(.PIX(PIX)) ug6 (.win_i(sub6), .gray_o(sm[6]));
    // posicion gradiente g=7  centro suavizado (3,2)
    wire [9*PIX-1:0] sub7;
    assign sub7[PIX*0 +: PIX] = win_i[PIX*11 +: PIX];
    assign sub7[PIX*1 +: PIX] = win_i[PIX*12 +: PIX];
    assign sub7[PIX*2 +: PIX] = win_i[PIX*13 +: PIX];
    assign sub7[PIX*3 +: PIX] = win_i[PIX*16 +: PIX];
    assign sub7[PIX*4 +: PIX] = win_i[PIX*17 +: PIX];
    assign sub7[PIX*5 +: PIX] = win_i[PIX*18 +: PIX];
    assign sub7[PIX*6 +: PIX] = win_i[PIX*21 +: PIX];
    assign sub7[PIX*7 +: PIX] = win_i[PIX*22 +: PIX];
    assign sub7[PIX*8 +: PIX] = win_i[PIX*23 +: PIX];
    gaussian3x3 #(.PIX(PIX)) ug7 (.win_i(sub7), .gray_o(sm[7]));
    // posicion gradiente g=8  centro suavizado (3,3)
    wire [9*PIX-1:0] sub8;
    assign sub8[PIX*0 +: PIX] = win_i[PIX*12 +: PIX];
    assign sub8[PIX*1 +: PIX] = win_i[PIX*13 +: PIX];
    assign sub8[PIX*2 +: PIX] = win_i[PIX*14 +: PIX];
    assign sub8[PIX*3 +: PIX] = win_i[PIX*17 +: PIX];
    assign sub8[PIX*4 +: PIX] = win_i[PIX*18 +: PIX];
    assign sub8[PIX*5 +: PIX] = win_i[PIX*19 +: PIX];
    assign sub8[PIX*6 +: PIX] = win_i[PIX*22 +: PIX];
    assign sub8[PIX*7 +: PIX] = win_i[PIX*23 +: PIX];
    assign sub8[PIX*8 +: PIX] = win_i[PIX*24 +: PIX];
    gaussian3x3 #(.PIX(PIX)) ug8 (.win_i(sub8), .gray_o(sm[8]));
    wire [9*PIX-1:0] smwin = {sm[8],sm[7],sm[6],sm[5],sm[4],sm[3],sm[2],sm[1],sm[0]};
    canny_datapath #(.PIX(PIX), .USE_SQRT(USE_SQRT)) u_dp (
        .sm_window_i(smwin), .low_i(low_i), .high_i(high_i),
        .g_low_o(g_low_o), .g_high_o(g_high_o), .class_o(class_o), .combo_o(combo_o));
endmodule
`default_nettype wire
