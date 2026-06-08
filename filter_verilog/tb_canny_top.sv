`default_nettype none
`timescale 1ns/1ps
module tb_canny_top;
  localparam PIX=8;
  reg [25*PIX-1:0] win; reg [PIX+3:0] low, high;
  wire [PIX+3:0] gl, gh; wire [1:0] cl; wire [6:0] cb;
  integer errors=0;
  canny_top_3x3 #(.PIX(PIX), .USE_SQRT(0)) dut
    (.win_i(win), .low_i(low), .high_i(high), .g_low_o(gl), .g_high_o(gh), .class_o(cl), .combo_o(cb));
  task chk(input [127:0] nm, input integer g, input integer e); begin
    if (g!==e) begin $display("  FAIL %0s got=%0d exp=%0d",nm,g,e); errors=errors+1; end
    else $display("  ok %0s=%0d",nm,g); end endtask
  initial begin
    win={8'd184, 8'd71, 8'd87, 8'd77, 8'd209, 8'd119, 8'd30, 8'd204, 8'd33, 8'd210, 8'd127, 8'd1, 8'd233, 8'd223, 8'd72, 8'd76, 8'd14, 8'd57, 8'd213, 8'd198, 8'd148, 8'd229, 8'd175, 8'd160, 8'd241}; low=20; high=60; #1;
    $display("-- test 0 (mag esperada=356) --");
    chk("g_low",gl,356); chk("g_high",gh,356); chk("class",cl,2); chk("combo",cb,26);
    win={8'd9, 8'd113, 8'd11, 8'd29, 8'd156, 8'd219, 8'd41, 8'd216, 8'd55, 8'd119, 8'd253, 8'd87, 8'd159, 8'd179, 8'd202, 8'd206, 8'd254, 8'd130, 8'd141, 8'd149, 8'd129, 8'd122, 8'd113, 8'd253, 8'd65}; low=20; high=60; #1;
    $display("-- test 1 (mag esperada=214) --");
    chk("g_low",gl,214); chk("g_high",gh,214); chk("class",cl,2); chk("combo",cb,20);
    win={8'd125, 8'd94, 8'd184, 8'd51, 8'd225, 8'd177, 8'd248, 8'd49, 8'd24, 8'd3, 8'd254, 8'd63, 8'd97, 8'd127, 8'd68, 8'd131, 8'd112, 8'd161, 8'd210, 8'd234, 8'd206, 8'd119, 8'd248, 8'd131, 8'd36}; low=5; high=15; #1;
    $display("-- test 2 (mag esperada=288) --");
    chk("g_low",gl,288); chk("g_high",gh,288); chk("class",cl,2); chk("combo",cb,24);
    win={8'd223, 8'd156, 8'd129, 8'd186, 8'd138, 8'd62, 8'd23, 8'd121, 8'd189, 8'd10, 8'd163, 8'd181, 8'd216, 8'd240, 8'd130, 8'd47, 8'd225, 8'd247, 8'd68, 8'd136, 8'd39, 8'd169, 8'd212, 8'd158, 8'd0}; low=5; high=15; #1;
    $display("-- test 3 (mag esperada=196) --");
    chk("g_low",gl,196); chk("g_high",gh,196); chk("class",cl,2); chk("combo",cb,19);
    if (errors==0) $display("\nCANNY_TOP_3x3: ALL TESTS PASSED"); else $display("\n%0d FAILURES",errors);
    $finish; end
endmodule
`default_nettype wire
