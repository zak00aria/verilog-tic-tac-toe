parameter CLK_SPEED = 20*1000;// Hz
parameter O_SPRITE = 1, 
          X_SPRITE = 2, 
          SELECTED_CELL_SPRITE = 3;
parameter BOARD_STATE_CELL_SIZE = 2, 
          BOARD_STATE_ROWS_COUNT = 3,
          BOARD_STATE_COLS_COUNT = 3,
          BOARD_STATE_CELL_EMPTY = 0,
          BOARD_STATE_CELL_O = 0,
          BOARD_STATE_CELL_X = 0;

module sprites(
  input wire [1:0] shape_id,
  output wire [8*8-1:0] shape_data
);
reg [8*8-1:0] selected_shape_data = 0;

assign shape_data = selected_shape_data;

always @* begin
    case(shape_id)
      O_SPRITE:begin
        selected_shape_data <= {
          {8'b00000000},
          {8'b00000000},
          {8'b00011000},
          {8'b00100100},
          {8'b00100100},
          {8'b00011000},
          {8'b00000000},
          {8'b00000000}
        };
      end
      X_SPRITE:begin
        selected_shape_data <= {
          {8'b00000000},
          {8'b00000000},
          {8'b00100100},
          {8'b00011000},
          {8'b00011000},
          {8'b00100100},
          {8'b00000000},
          {8'b00000000}
        };
      end
      SELECTED_CELL_SPRITE:begin
        selected_shape_data <= {
          {8'b11111111},
          {8'b10000001},
          {8'b10000001},
          {8'b10000001},
          {8'b10000001},
          {8'b10000001},
          {8'b10000001},
          {8'b11111111}
        };
      end
      default:begin
        selected_shape_data <= {16{1'b0}};
      end
    endcase
end

endmodule

module btn_handler(
  input wire btn,
  input wire clk,
  output wire state
);
  reg [15:0] timer = 0;
  reg btn_state = 0;

  assign state = btn_state;

  always @(negedge clk)begin
    if(timer == 0)begin
      if(btn)begin
        timer <= CLK_SPEED/10*2;// we need a delay of about 200ms 
        btn_state <= 1;
      end
      else begin
        btn_state <= 0;
      end
    end
    else if(timer > 0) begin
      timer <= timer - 1;
      btn_state <= 0;
    end
  end
endmodule

parameter winning_line_length = 3;
parameter possible_winning_lines_count = 8;
module win_checker(
  input wire [3*3*2-1:0] board_state,
  output wire [1:0] winner,
  output wire [(winning_line_length*2*2)-1:0] winning_line
);
  parameter size_t = 2;

  reg [possible_winning_lines_count*(winning_line_length*size_t*2)-1:0] possible_winning_lines = {
          // x       // y         // x       // y         // x       // y
    {{size_t'd0, size_t'd0}, {size_t'd1, size_t'd0}, {size_t'd2, size_t'd0}},
    {{size_t'd0, size_t'd0}, {size_t'd1, size_t'd1}, {size_t'd2, size_t'd2}},
    {{size_t'd0, size_t'd0}, {size_t'd0, size_t'd1}, {size_t'd0, size_t'd2}},
    {{size_t'd2, size_t'd0}, {size_t'd2, size_t'd1}, {size_t'd2, size_t'd2}},
    {{size_t'd0, size_t'd2}, {size_t'd1, size_t'd2}, {size_t'd2, size_t'd2}},
    {{size_t'd0, size_t'd2}, {size_t'd1, size_t'd1}, {size_t'd2, size_t'd0}},
    {{size_t'd1, size_t'd0}, {size_t'd1, size_t'd1}, {size_t'd1, size_t'd2}},
    {{size_t'd0, size_t'd1}, {size_t'd1, size_t'd1}, {size_t'd2, size_t'd1}}
  };

  reg [1:0] result = 0;
  reg [(winning_line_length*size_t*2)-1:0] winning_line_cells = 0;
  
  assign winner = result;
  assign winning_line = winning_line_cells;

  function three_in_row_check;
    input [(winning_line_length*size_t*2)-1:0] line_cells_xy;
    begin
      // cell_index = (y*BOARD_STATE_COLS_COUNT+x)*BOARD_STATE_CELL_SIZE;
      if(board_state[(line_cells_xy[0*size_t+:size_t]*BOARD_STATE_COLS_COUNT+line_cells_xy[1*size_t+:size_t])*BOARD_STATE_CELL_SIZE+:BOARD_STATE_CELL_SIZE])begin
        three_in_row_check =  board_state[(line_cells_xy[0*size_t+:size_t]*BOARD_STATE_COLS_COUNT+line_cells_xy[1*size_t+:size_t])*BOARD_STATE_CELL_SIZE+:BOARD_STATE_CELL_SIZE] == board_state[(line_cells_xy[2*size_t+:size_t]*BOARD_STATE_COLS_COUNT+line_cells_xy[3*size_t+:size_t])*BOARD_STATE_CELL_SIZE+:BOARD_STATE_CELL_SIZE]
                              && board_state[(line_cells_xy[2*size_t+:size_t]*BOARD_STATE_COLS_COUNT+line_cells_xy[3*size_t+:size_t])*BOARD_STATE_CELL_SIZE+:BOARD_STATE_CELL_SIZE] == board_state[(line_cells_xy[4*size_t+:size_t]*BOARD_STATE_COLS_COUNT+line_cells_xy[5*size_t+:size_t])*BOARD_STATE_CELL_SIZE+:BOARD_STATE_CELL_SIZE];
      end
      else begin
        three_in_row_check = 0;
      end
    end 
  endfunction

  always @(*)begin:check_winner_block
    integer i;
    integer line_start_index;
    result <= 0;
    for(i=0;i<possible_winning_lines_count;i=i+1)begin
      line_start_index = i * winning_line_length*(size_t*2);
      if(three_in_row_check(possible_winning_lines[line_start_index+:winning_line_length*(size_t*2)]))begin
        result <= board_state[(possible_winning_lines[line_start_index+0*size_t+:size_t]*BOARD_STATE_COLS_COUNT+possible_winning_lines[line_start_index+1*size_t+:size_t])*BOARD_STATE_CELL_SIZE+:BOARD_STATE_CELL_SIZE];
        winning_line_cells <= possible_winning_lines[line_start_index +:winning_line_length*(size_t*2)];
      end
    end
  end
endmodule

function does_cell_belong_to_winning_line;
  input [2*2-1:0] cell_xy;
  input [winning_line_length*2*2-1:0] winning_line;
  begin
    does_cell_belong_to_winning_line = cell_xy==winning_line[0*2*2 +:2*2]
                                        || cell_xy==winning_line[1*2*2 +:2*2]
                                        || cell_xy==winning_line[2*2*2 +:2*2];
  end
endfunction

module wokwi (
  input wire btn_up,
  input wire btn_right,
  input wire btn_left,
  input wire btn_down,
  input wire btn_select,
  input wire btn_restart,
  input wire CLK_IN,
  output reg OUT,
  output reg CS,
  output wire o_won,
  output wire x_won,
  output reg CLK
);

  parameter MATRIX_ROWS_COUNT = 8;
  parameter MATRIX_COLS_COUNT = 8;
  parameter CHAINED_MATRICES_COUNT = 9;
  parameter CHAINED_MATRICES_X_COUNT = 3;
  parameter CHAINED_MATRICES_Y_COUNT = 3;
  parameter BLINK_TIMER_SIZE = 14; // in bits

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
            UPDATE_DISPLAY = 2, 
            HANDLE_USER_INPUT = 3, 
            REFRESH_DISPLAY = 4;
  reg [2:0] MAIN_STATE = START;
  reg [2:0] MAIN_NEXT_STATE = START;

  parameter CLEAR_DISPLAY = 0,
            DRAW_GRID = 1,
            DRAW_XO = 2,
            DRAW_SELECTED_CELL = 3;
  reg [1:0] UPDATE_DISPLAY_CURRENT_STEP = CLEAR_DISPLAY;

  parameter ACTION_MOVE_UP = 1,
            ACTION_MOVE_RIGHT = 2,
            ACTION_MOVE_DOWN = 3,
            ACTION_MOVE_LEFT = 4,
            ACTION_RESTART = 5,
            ACTION_SELECT = 6;
  reg [2:0] NEXT_ACTION = 0;

  reg current_turn = 0;
  reg [1:0] selected_cell_x = 0;
  reg [1:0] selected_cell_y = 0;
  reg [BLINK_TIMER_SIZE-1:0] blink_timer = 0;
  reg [1:0] draw_xo_selected_cell_x = 0;
  reg [1:0] draw_xo_selected_cell_y = 0;

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
    {8'h00, 8'h00}  // nothing, just to have a small delay
  };

  reg [7:0] matrix_data_read_index = 8'd0;
  reg [7:0] matrix_selected_row_address = 8'd0;
  reg [7:0] selected_matrix_x = 0;
  reg [7:0] selected_matrix_y = CHAINED_MATRICES_Y_COUNT - 1;

  wire [winning_line_length*2*2-1:0] winning_line;
  wire end_game;
  assign end_game = o_won || x_won;
  
  reg [MATRIX_DATA_LENGTH*CHAINED_MATRICES_COUNT-1 :0] matrix_data = 0;
  reg [BOARD_STATE_ROWS_COUNT*BOARD_STATE_COLS_COUNT*BOARD_STATE_CELL_SIZE-1:0] board_state = {
    2'b00, 2'b00, 2'b00,
    2'b00, 2'b00, 2'b00,
    2'b00, 2'b00, 2'b00
  };

  wire [8*8-1:0] selected_shape_data;
  reg [1:0] selected_shape;
  sprites u_sprites(
    .shape_id(selected_shape),
    .shape_data(selected_shape_data)
    );
  
  wire btn_up_state;
  btn_handler up_btn_handler(
    .clk(CLK_IN),
    .btn(btn_up),
    .state(btn_up_state)
  );
  wire btn_right_state;
  btn_handler right_btn_handler(
    .clk(CLK_IN),
    .btn(btn_right),
    .state(btn_right_state)
  );
  wire btn_down_state;
  btn_handler down_btn_handler(
    .clk(CLK_IN),
    .btn(btn_down),
    .state(btn_down_state)
  );
  wire btn_left_state;
  btn_handler left_btn_handler(
    .clk(CLK_IN),
    .btn(btn_left),
    .state(btn_left_state)
  );
  wire btn_select_state;
  btn_handler select_btn_handler(
    .clk(CLK_IN),
    .btn(btn_select),
    .state(btn_select_state)
  );
  wire btn_restart_state;
  btn_handler restart_btn_handler(
    .clk(CLK_IN),
    .btn(btn_restart),
    .state(btn_restart_state)
  );

  win_checker u_win_checker(
    .board_state(board_state),
    .winner({x_won, o_won}),
    .winning_line(winning_line)
  );

  always @(posedge CLK_IN) 
  begin
    MAIN_STATE <= MAIN_NEXT_STATE;
    DATA_LINE_STATE <= DATA_LINE_NEXT_STATE;
    if(CLK_STATE==CLK_GO_HIGH)begin
      CLK <= 1;
      CLK_STATE <= CLK_GO_LOW;
    end
    
    if(NEXT_ACTION==0)begin
      if(!end_game)begin
        if(btn_up_state)begin
          NEXT_ACTION <= ACTION_MOVE_UP;
        end
        else if(btn_right_state)begin
          NEXT_ACTION <= ACTION_MOVE_RIGHT;
        end
        else if(btn_down_state)begin
          NEXT_ACTION <= ACTION_MOVE_DOWN;
        end
        else if(btn_left_state)begin
          NEXT_ACTION <= ACTION_MOVE_LEFT;
        end
        else if(btn_select_state)begin
          NEXT_ACTION <= ACTION_SELECT;
        end
      end
      if(btn_restart_state)begin
        NEXT_ACTION <= ACTION_RESTART;
      end
    end

  end

  always @(negedge CLK_IN) begin
    blink_timer <= blink_timer+1;
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
      HANDLE_USER_INPUT:begin:handle_user_inputs_block
        integer cell_index, cell_value;
        case(NEXT_ACTION)
          ACTION_MOVE_UP:begin
            if(selected_cell_y>0)begin
              selected_cell_y <= selected_cell_y - 1;
            end
          end
          ACTION_MOVE_RIGHT:begin
            if(selected_cell_x<CHAINED_MATRICES_X_COUNT-1)begin
              selected_cell_x <= selected_cell_x + 1;
            end
          end
          ACTION_MOVE_DOWN:begin
            if(selected_cell_y<CHAINED_MATRICES_Y_COUNT-1)begin
              selected_cell_y <= selected_cell_y + 1;
            end
          end
          ACTION_MOVE_LEFT:begin
            if(selected_cell_x>0)begin
              selected_cell_x <= selected_cell_x - 1;
            end
          end
          ACTION_SELECT:begin
            cell_index = selected_cell_y*3*2
                          +2*selected_cell_x;
            cell_value = board_state[cell_index +: 2];
            if(cell_value==0)begin
              case(current_turn)
                0:begin
                  board_state[cell_index +: 2] = X_SPRITE;
                end
                1:begin
                  board_state[cell_index +: 2] = O_SPRITE;
                end
              endcase
              current_turn <= current_turn ^ 1;
            end
          end
          ACTION_RESTART:begin
            // reset current turn to X
            current_turn <= 0;
            // clear screen
            matrix_data <= 0;
            // clear board cells
            board_state <= 0;
            // reset selected cell
            selected_cell_x <= 0;
            selected_cell_y <= 0;
          end
        endcase
        NEXT_ACTION<=0;
        MAIN_NEXT_STATE<=UPDATE_DISPLAY;
        UPDATE_DISPLAY_CURRENT_STEP<=CLEAR_DISPLAY;
      end
      UPDATE_DISPLAY:begin
        case(UPDATE_DISPLAY_CURRENT_STEP)
          CLEAR_DISPLAY:begin
            UPDATE_DISPLAY_CURRENT_STEP<=DRAW_GRID;
            matrix_data<=0;
          end
          DRAW_GRID:begin:draw_grid_block
            UPDATE_DISPLAY_CURRENT_STEP<=DRAW_XO;
            /*integer row_index;
            for(row_index=0;row_index<CHAINED_MATRICES_Y_COUNT*MATRIX_ROWS_COUNT;row_index=row_index+1)begin
              if(row_index==((row_index>>3)<<3) && row_index>0 && row_index<CHAINED_MATRICES_Y_COUNT*MATRIX_ROWS_COUNT-1)begin
                matrix_data[(row_index-1)*CHAINED_MATRICES_X_COUNT*MATRIX_COLS_COUNT +: CHAINED_MATRICES_X_COUNT*MATRIX_COLS_COUNT] <= {(CHAINED_MATRICES_X_COUNT*MATRIX_COLS_COUNT){1'b1}};
                matrix_data[row_index*CHAINED_MATRICES_X_COUNT*MATRIX_COLS_COUNT +: CHAINED_MATRICES_X_COUNT*MATRIX_COLS_COUNT] <= {(CHAINED_MATRICES_X_COUNT*MATRIX_COLS_COUNT){1'b1}};
              end
              else begin
                matrix_data[MATRIX_COLS_COUNT-1+row_index*CHAINED_MATRICES_X_COUNT*MATRIX_COLS_COUNT +: 2] <= {2{1'b1}};
                matrix_data[MATRIX_COLS_COUNT*2-1+row_index*CHAINED_MATRICES_X_COUNT*MATRIX_COLS_COUNT +: 2] <= {2{1'b1}};
              end
            end*/
          end
          DRAW_XO:begin:draw_x_o_block
            integer cell_value;
            integer row_offset;
            integer row_index;
            if(draw_xo_selected_cell_y<=2)begin
              cell_value = board_state[draw_xo_selected_cell_y*3*2
                                      +2*draw_xo_selected_cell_x +: 2];
              selected_shape <= cell_value;
              if(cell_value==selected_shape)begin
                for(row_index=0; row_index<MATRIX_ROWS_COUNT; row_index=row_index+1)begin
                  row_offset = (MATRIX_DATA_LENGTH*(CHAINED_MATRICES_X_COUNT*draw_xo_selected_cell_y)) /*screen rows to skip*/
                              + (MATRIX_COLS_COUNT*draw_xo_selected_cell_x) /*columns to skip (in current row)*/
                              + (row_index*CHAINED_MATRICES_X_COUNT*MATRIX_COLS_COUNT);
                  if(end_game
                     && does_cell_belong_to_winning_line({draw_xo_selected_cell_x, draw_xo_selected_cell_y}, winning_line) 
                     && blink_timer < (1<<(BLINK_TIMER_SIZE-2))
                  )begin
                    matrix_data[row_offset +: MATRIX_COLS_COUNT] <= matrix_data[row_offset +: MATRIX_COLS_COUNT] 
                                                                    & ~(selected_shape_data[row_index*MATRIX_COLS_COUNT +: MATRIX_COLS_COUNT]);
                  end
                  else begin
                    matrix_data[row_offset +: MATRIX_COLS_COUNT] <= matrix_data[row_offset +: MATRIX_COLS_COUNT] 
                                                                    | (selected_shape_data[row_index*MATRIX_COLS_COUNT +: MATRIX_COLS_COUNT]);
                  end
                end
                if(draw_xo_selected_cell_x<2)begin
                  draw_xo_selected_cell_x <= draw_xo_selected_cell_x+1;
                end
                else begin
                  draw_xo_selected_cell_x <= 0;
                  draw_xo_selected_cell_y <= draw_xo_selected_cell_y+1;
                end
              end
            end
            else begin
              draw_xo_selected_cell_x <= 0;
              draw_xo_selected_cell_y <= 0;
              UPDATE_DISPLAY_CURRENT_STEP<=DRAW_SELECTED_CELL;
            end
          end
          DRAW_SELECTED_CELL:begin:draw_selected_cell_block
            integer row_offset;
            integer row_index;
            selected_shape <= SELECTED_CELL_SPRITE;
            if(selected_shape == SELECTED_CELL_SPRITE)begin
              MAIN_NEXT_STATE <= REFRESH_DISPLAY;
              DATA_LINE_NEXT_STATE <= START_SENDING;
              UPDATE_DISPLAY_CURRENT_STEP <= CLEAR_DISPLAY;
              if(!end_game)begin
                for(row_index=0; row_index<MATRIX_ROWS_COUNT; row_index=row_index+1)begin
                  row_offset = (MATRIX_DATA_LENGTH*(CHAINED_MATRICES_X_COUNT*selected_cell_y)) /*screen rows to skip*/
                              + (MATRIX_COLS_COUNT*selected_cell_x) /*columns to skip (in current row)*/
                              + (row_index*CHAINED_MATRICES_X_COUNT*MATRIX_COLS_COUNT);
                  if(blink_timer < (1<<(BLINK_TIMER_SIZE-2)))begin
                    matrix_data[row_offset +: MATRIX_COLS_COUNT] <= matrix_data[row_offset +: MATRIX_COLS_COUNT] 
                                                                              & (~selected_shape_data[row_index*MATRIX_COLS_COUNT +: MATRIX_COLS_COUNT]);
                  end
                  else begin
                    matrix_data[row_offset +: MATRIX_COLS_COUNT] <= matrix_data[row_offset +: MATRIX_COLS_COUNT] 
                                                                              | (selected_shape_data[row_index*MATRIX_COLS_COUNT +: MATRIX_COLS_COUNT]);
                  end
                end
              end
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
              MAIN_NEXT_STATE <= HANDLE_USER_INPUT;
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
