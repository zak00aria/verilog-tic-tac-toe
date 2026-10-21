
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

  parameter MATRIX_ROWS_COUNT = 8;
  parameter MATRIX_COLS_COUNT = 8;
  parameter CHAINED_MATRICES_COUNT = 9;
  parameter CHAINED_MATRICES_X_COUNT = 3;
  parameter CHAINED_MATRICES_Y_COUNT = 3;

  parameter MATRIX_CONFIG_DATA_LENGTH = 8*16;
  parameter MATRIX_DATA_LENGTH = 8*8;

  parameter CLK_GO_LOW = 0, CLK_GO_HIGH = 1;
  reg CLK_STATE = CLK_GO_LOW;

  parameter LINE_IDLE = 0, 
            START_SENDING = 1, 
            SENDING = 2, 
            DONE_SENDING = 3;
  reg [1:0] DATA_LINE_STATE = LINE_IDLE;
  reg [1:0] DATA_LINE_NEXT_STATE = LINE_IDLE;

  parameter START = 0, 
            CONFIG_DISPLAY = 1, 
            REFRESH_DISPLAY = 2;
  reg [2:0] MAIN_STATE = START;
  reg [2:0] MAIN_NEXT_STATE = START;

  reg [4:0] data_sent_bits_counter = 5'd0;
  reg [4:0] max_data_sent_bits = 5'd16;
  reg [4:0] selected_matrix = 5'd0;

  reg [7:0] matrix_config_data_read_index = 8'd0;
  reg is_matrix_configured = 1'b0;
  reg [MATRIX_CONFIG_DATA_LENGTH-1:0] matrix_config_data = {
    {8'h0c, 8'h00}, // shutdown while configuring
    {8'h09, 8'h00}, // disable 7-segment decoding
    {8'h0b, 8'h07}, // scan all 8 rows
    {8'h0a, 8'h03}, // set a low brightness
    {8'h0f, 8'h00}, // disable display test
    {8'h0c, 8'h01}, // normal operation
    {8'h00, 8'h00}, // nothing, just to have a small delay
    {8'h00, 8'h00} // nothing, just to have a small delay
  };

  reg [7:0] matrix_data_read_index = 8'd0;
  reg [7:0] matrix_selected_row_address = 8'd0;
  reg [7:0] selected_matrix_x = 0;
  reg [7:0] selected_matrix_y = CHAINED_MATRICES_Y_COUNT - 1;

  
  reg [MATRIX_DATA_LENGTH*CHAINED_MATRICES_COUNT-1 :0] matrix_data = {

    {8'b00111100, 8'b00111100, 8'b00000110},
    {8'b01100110, 8'b01100110, 8'b00000110},
    {8'b01100000, 8'b01100110, 8'b00000110},
    {8'b11111110, 8'b00111100, 8'b00001100},
    {8'b11100110, 8'b01100110, 8'b00011000},
    {8'b01100110, 8'b01100110, 8'b00110000},
    {8'b01100110, 8'b01100110, 8'b01100000},
    {8'b00111100, 8'b00111100, 8'b01111110},

    {8'b00111100, 8'b00111100, 8'b00110000},
    {8'b01100110, 8'b01100110, 8'b01111110},
    {8'b01100110, 8'b01100000, 8'b00110001},
    {8'b01100110, 8'b01100000, 8'b00110010},
    {8'b00111110, 8'b00111110, 8'b00110100},
    {8'b00000110, 8'b00000110, 8'b00111000},
    {8'b01100110, 8'b00000110, 8'b00110000},
    {8'b00111100, 8'b01111110, 8'b00110000},

    {8'b00111100, 8'b01111110, 8'b01111110},
    {8'b01100110, 8'b00000110, 8'b00011000},
    {8'b01100000, 8'b00001100, 8'b00011000},
    {8'b01100000, 8'b00011000, 8'b00011000},
    {8'b00111000, 8'b00110000, 8'b00011000},
    {8'b01100000, 8'b01100000, 8'b00011000},
    {8'b01100110, 8'b01100110, 8'b00011100},
    {8'b00111100, 8'b00111100, 8'b00011000}

};

  always @(posedge CLK_IN) begin
    MAIN_STATE <= MAIN_NEXT_STATE;
    DATA_LINE_STATE <= DATA_LINE_NEXT_STATE;
    if(CLK_STATE==CLK_GO_HIGH)begin
      CLK <= 1;
      CLK_STATE <= CLK_GO_LOW;
    end
  end

  always @(negedge CLK_IN) begin
    if(CLK_STATE==CLK_GO_LOW)begin
      CLK <= 0;
    end
    OUT <= 0;
    case(MAIN_STATE)
      START:begin
        MAIN_NEXT_STATE <= CONFIG_DISPLAY;
        DATA_LINE_NEXT_STATE <= START_SENDING;
        CS <= 1;
      end
      CONFIG_DISPLAY:begin
        case(DATA_LINE_STATE)
          LINE_IDLE:begin
          end
          START_SENDING:begin
            data_sent_bits_counter <= 0;
            matrix_config_data_read_index <= 0;
            DATA_LINE_NEXT_STATE <= SENDING;
          end
          SENDING:begin
            if(data_sent_bits_counter < max_data_sent_bits)begin
              data_sent_bits_counter <= data_sent_bits_counter + 1'b1;
              if(selected_matrix==0)begin
                matrix_config_data_read_index <= matrix_config_data_read_index + 1'b1;
                OUT <= matrix_config_data[MATRIX_CONFIG_DATA_LENGTH - 1 - matrix_config_data_read_index];
              end
              else begin
                OUT <= matrix_config_data[MATRIX_CONFIG_DATA_LENGTH - matrix_config_data_read_index - 1 +(max_data_sent_bits-data_sent_bits_counter)];
              end
              CS <= 0;
              CLK_STATE <= CLK_GO_HIGH;
            end
            else begin
              selected_matrix <= selected_matrix + 1;
              if(selected_matrix>=CHAINED_MATRICES_COUNT-1)begin
                DATA_LINE_NEXT_STATE <= DONE_SENDING;
              end
              else begin
                data_sent_bits_counter <= 0;
              end
            end
          end
          DONE_SENDING:begin
            CS <= 1;
            data_sent_bits_counter <= 0;
            selected_matrix <= 0;
            if(matrix_config_data_read_index >= MATRIX_CONFIG_DATA_LENGTH-1)begin
              MAIN_NEXT_STATE <= REFRESH_DISPLAY;
              DATA_LINE_NEXT_STATE <=  START_SENDING;
            end
            else begin
              DATA_LINE_NEXT_STATE <= SENDING;
            end
          end
        endcase
      end
      REFRESH_DISPLAY:begin
        case(DATA_LINE_STATE)
          LINE_IDLE:begin
          end
          START_SENDING:begin
            data_sent_bits_counter <= 0;
            matrix_data_read_index <= 0;
            DATA_LINE_NEXT_STATE <= SENDING;
          end
          SENDING:begin
            if(data_sent_bits_counter < max_data_sent_bits)begin
              data_sent_bits_counter <= data_sent_bits_counter + 1'b1;
              if(data_sent_bits_counter<8)begin
                // send row address
                if(selected_matrix==0)begin
                  matrix_selected_row_address <= ((matrix_data_read_index) >> 3) + 1; 
                end
                OUT <= matrix_selected_row_address[8 - data_sent_bits_counter - 1];
              end
              else begin
                // send row data
                if(selected_matrix==0)begin
                  matrix_data_read_index <= matrix_data_read_index + 1'b1;
                end
                OUT <= matrix_data[
                                  (MATRIX_DATA_LENGTH*(CHAINED_MATRICES_X_COUNT*selected_matrix_y)) /*screen rows to skip*/
                                  +(MATRIX_COLS_COUNT*selected_matrix_x) /*columns to skip (in current row)*/
                                  +((matrix_selected_row_address-1)*(MATRIX_COLS_COUNT*CHAINED_MATRICES_X_COUNT)) /*matrix rows to skip*/
                                  +(max_data_sent_bits-data_sent_bits_counter-1)
                                ];
              end
              CS <= 0;
              CLK_STATE <= CLK_GO_HIGH;
            end
            else begin
              selected_matrix <= selected_matrix + 1;
              if(selected_matrix_x < CHAINED_MATRICES_X_COUNT-1)begin
                selected_matrix_x <= selected_matrix_x + 1;
              end
              else begin
                selected_matrix_x <= 0;
                if(selected_matrix_y > 0)begin
                  selected_matrix_y <= selected_matrix_y -1;
                end
                else begin
                  selected_matrix_y <= CHAINED_MATRICES_Y_COUNT - 1;
                end
              end
              if(selected_matrix >= CHAINED_MATRICES_COUNT-1)begin
                DATA_LINE_NEXT_STATE <= DONE_SENDING;
              end
              else begin
                data_sent_bits_counter <= 0;
              end
            end
          end
          DONE_SENDING:begin
            CS <= 1;
            data_sent_bits_counter <= 0;
            selected_matrix <= 0;
            if(matrix_data_read_index >= MATRIX_DATA_LENGTH-1)begin
              MAIN_NEXT_STATE <= REFRESH_DISPLAY;
              DATA_LINE_NEXT_STATE <= LINE_IDLE;
            end
            else begin
              DATA_LINE_NEXT_STATE <= SENDING;
            end
          end
        endcase
      end
    endcase
  end

endmodule