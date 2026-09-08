// stub del primitivo del LED, solo para simular
module SB_RGBA_DRV #(parameter CURRENT_MODE="0b0", parameter RGB0_CURRENT="0b000000",
                     parameter RGB1_CURRENT="0b000000", parameter RGB2_CURRENT="0b000000")
  (input CURREN, RGBLEDEN, RGB0PWM, RGB1PWM, RGB2PWM, output RGB0, RGB1, RGB2);
  assign RGB0=RGB0PWM; assign RGB1=RGB1PWM; assign RGB2=RGB2PWM;
endmodule
