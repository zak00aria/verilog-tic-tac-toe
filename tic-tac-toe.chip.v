
module wokwi (
  input wire btn_up,
  input wire btn_right,
  input wire btn_left,
  input wire btn_down,
  input wire btn_select,
  input wire btn_reset,
  input wire CLK_IN,
  output reg OUT,
  output reg CS,
  output reg CLK
);
  assign OUT = 1;

endmodule