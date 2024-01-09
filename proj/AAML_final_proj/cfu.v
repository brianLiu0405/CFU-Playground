module Cfu (
  input               cmd_valid,
  output              cmd_ready,
  input      [9:0]    cmd_payload_function_id,
  input      [31:0]   cmd_payload_inputs_0,
  input      [31:0]   cmd_payload_inputs_1,
  output reg          rsp_valid,
  input               rsp_ready,
  output reg [31:0]   rsp_payload_outputs_0,
  input               reset,
  input               clk
);
  localparam InputOffset = $signed(9'd128);
  wire [2:0] funct3;
  wire [6:0] funct7;
  assign funct3 = cmd_payload_function_id[2:0];
  assign funct7 = cmd_payload_function_id[9:3];

  /*
  #define cfu_rst()       cfu_op0(0,   0,  0);
  #define cfu_simd()      cfu_op0(1,  v1, v2);
  #define cfu_si8d(f1,f2) cfu_op0(2,  f1, f2);

  #define cfu_set(cnt)    cfu_op1(0, cnt,  0);
  #define cfu_w1(v1,v2)   cfu_op1(1,  v1, v2);
  #define cfu_r1(adr)     cfu_op1(2, adr,  0);
  #define cfu_a1()        cfu_op1(3,   0,  0);

  #define cfu_w2(v1,v2) cfu_op1(4,  v1, v2);
  #define cfu_r2(adr)   cfu_op1(5, adr,  0);
  #define cfu_a2()      cfu_op1(6,   0,  0);

  */

  // | funct3 | funct7 | inputs0 | inputs1 | output |
  // |    0   |   0    |    x    |    x    |    0   | reset 
  // |    0   |   1    |  input  | filter  |sum_prod| simd
  // |    0   |   2    | filter1 | filter2 |sim8_prod| sim8

  // |    1   |   0    |      x  |    x    |    0   | reset input cnt
  // |    1   |   1    |  input  |  input  | cnt    | store
  // |    1   |   2    |  addr   |    x    | buffer | read
  // |    1   |   3    |    x    |    x    |sim8_acc| get acc
  // |    1   |   6    |    x    |    x    |acc 2   | get acc
  // Input Stationary 
  reg [7:0] input_cnt;
  reg [31:0] input_buffer [0:163];
  reg [31:0] input_buffer1[0:163];

  always @(posedge clk) begin
    if(reset)
      input_cnt <= 0;
    else if (cmd_valid &&  funct3 == 0 && funct7 == 2)
      input_cnt <= input_cnt + 2;
    else if (cmd_valid && funct3 == 1) begin
      case (funct7)
        0: input_cnt <= cmd_payload_inputs_0[7:0];
        1: begin
          input_buffer[input_cnt] <= cmd_payload_inputs_0;
          input_buffer[input_cnt+1] <= cmd_payload_inputs_1;
        end
        4: begin
          input_buffer1[input_cnt] <= cmd_payload_inputs_0;
          input_buffer1[input_cnt+1] <= cmd_payload_inputs_1;
        end
      endcase
    end
  end

  // Width 8 SIMD multiply step
  wire signed [15:0] sim8 [0:7];
  wire signed [31:0] sim8_prods;
  assign sim8_prods = sim8[0]+sim8[1]+sim8[2]+sim8[3]+sim8[4]+sim8[5]+sim8[6]+sim8[7];
  assign sim8[0] = ($signed(input_buffer[input_cnt][ 7: 0]) + InputOffset) * $signed(cmd_payload_inputs_0[ 7: 0]);
  assign sim8[1] = ($signed(input_buffer[input_cnt][15: 8]) + InputOffset) * $signed(cmd_payload_inputs_0[15: 8]);
  assign sim8[2] = ($signed(input_buffer[input_cnt][23:16]) + InputOffset) * $signed(cmd_payload_inputs_0[23:16]);
  assign sim8[3] = ($signed(input_buffer[input_cnt][31:24]) + InputOffset) * $signed(cmd_payload_inputs_0[31:24]);
  assign sim8[4] = ($signed(input_buffer[input_cnt + 1][ 7: 0]) + InputOffset) * $signed(cmd_payload_inputs_1[ 7: 0]);
  assign sim8[5] = ($signed(input_buffer[input_cnt + 1][15: 8]) + InputOffset) * $signed(cmd_payload_inputs_1[15: 8]);
  assign sim8[6] = ($signed(input_buffer[input_cnt + 1][23:16]) + InputOffset) * $signed(cmd_payload_inputs_1[23:16]);
  assign sim8[7] = ($signed(input_buffer[input_cnt + 1][31:24]) + InputOffset) * $signed(cmd_payload_inputs_1[31:24]);

  // Width 8 SIMD multiply step
  wire signed [15:0] sim8_1 [0:7];
  wire signed [31:0] sim8_1_prods;
  assign sim8_1_prods = sim8_1[0]+sim8_1[1]+sim8_1[2]+sim8_1[3]+sim8_1[4]+sim8_1[5]+sim8_1[6]+sim8_1[7];
  assign sim8_1[0] = ($signed(input_buffer1[input_cnt][ 7: 0]) + InputOffset) * $signed(cmd_payload_inputs_0[ 7: 0]);
  assign sim8_1[1] = ($signed(input_buffer1[input_cnt][15: 8]) + InputOffset) * $signed(cmd_payload_inputs_0[15: 8]);
  assign sim8_1[2] = ($signed(input_buffer1[input_cnt][23:16]) + InputOffset) * $signed(cmd_payload_inputs_0[23:16]);
  assign sim8_1[3] = ($signed(input_buffer1[input_cnt][31:24]) + InputOffset) * $signed(cmd_payload_inputs_0[31:24]);
  assign sim8_1[4] = ($signed(input_buffer1[input_cnt + 1][ 7: 0]) + InputOffset) * $signed(cmd_payload_inputs_1[ 7: 0]);
  assign sim8_1[5] = ($signed(input_buffer1[input_cnt + 1][15: 8]) + InputOffset) * $signed(cmd_payload_inputs_1[15: 8]);
  assign sim8_1[6] = ($signed(input_buffer1[input_cnt + 1][23:16]) + InputOffset) * $signed(cmd_payload_inputs_1[23:16]);
  assign sim8_1[7] = ($signed(input_buffer1[input_cnt + 1][31:24]) + InputOffset) * $signed(cmd_payload_inputs_1[31:24]);
  

  // SIMD multiply step:
  wire signed [15:0] prod_0, prod_1, prod_2, prod_3;
  wire signed [31:0] sum_prods;
  assign sum_prods = prod_0 +prod_1 +prod_2 +prod_3;
  assign prod_0 =  ($signed(cmd_payload_inputs_0[7 : 0]) + InputOffset) * $signed(cmd_payload_inputs_1[7 : 0]);
  assign prod_1 =  ($signed(cmd_payload_inputs_0[15: 8]) + InputOffset) * $signed(cmd_payload_inputs_1[15: 8]);
  assign prod_2 =  ($signed(cmd_payload_inputs_0[23:16]) + InputOffset) * $signed(cmd_payload_inputs_1[23:16]);
  assign prod_3 =  ($signed(cmd_payload_inputs_0[31:24]) + InputOffset) * $signed(cmd_payload_inputs_1[31:24]);



  // Only not ready for a command when we have a response.
  assign cmd_ready = ~rsp_valid;

  reg [31:0] sim8_acc;
  reg [31:0] sim8_acc_1;

  always @(posedge clk) begin
    if (reset) begin
      rsp_payload_outputs_0 <= 32'b0;
      rsp_valid <= 1'b0;
    end else if (rsp_valid) begin
      // Waiting to hand off response to CPU.
      rsp_valid <= ~rsp_ready;
    end else if (cmd_valid) begin
      rsp_valid <= 1'b1;
      case (funct3)
        0: begin
          case (funct7)
            0: begin
              rsp_payload_outputs_0 <= 0;
              sim8_acc <= 0;
              sim8_acc_1 <= 0;
            end
            1: begin
              rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sum_prods;
            end
            2: begin
              rsp_payload_outputs_0 <= rsp_payload_outputs_0 + sim8_prods; 
              sim8_acc <= sim8_acc + sim8_prods;
              sim8_acc_1 <= sim8_acc_1 + sim8_1_prods;
            end
          endcase
        end
        1: begin
          case (funct7)
            0: rsp_payload_outputs_0 <= 0;
            1: rsp_payload_outputs_0 <= input_cnt;
            2: rsp_payload_outputs_0 <= input_buffer[cmd_payload_inputs_0];
            3: rsp_payload_outputs_0 <= sim8_acc;
            4: rsp_payload_outputs_0 <= input_cnt;
            5: rsp_payload_outputs_0 <= input_buffer1[cmd_payload_inputs_0];
            6: rsp_payload_outputs_0 <= sim8_acc_1;
          endcase
        end
      endcase
    end
  end
endmodule