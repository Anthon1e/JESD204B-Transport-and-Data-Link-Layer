`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/24/2021 03:55:54 PM
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: The top module joining the code of JESD204B Transport Layer and 
//              part of Data Link Layer, including Scrambler and 8B10B Encoder  
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top #(
  parameter DATA_WIDTH = 8,
  parameter LANES = 4,           // Number of lanes in the link
  parameter CONVERTERS = 8,      // Number of converters
  parameter RESOLUTION = 11,     // Converter resolution
  parameter CONTROL = 2,         // Number of control bit
  parameter SAMPLE_SIZE = 16,    // Number of bits per sample
  parameter SAMPLES = 1          // Number of samples per frame
  ) (
  input clock, 
  input reset, 
  input en,
  input [SAMPLES*CONVERTERS*RESOLUTION-1:0] tx_datain,
  output [SAMPLES*CONVERTERS*RESOLUTION-1:0] rx_dataout
  );
	
  // Transport Layer 
  wire [SAMPLES*SAMPLE_SIZE*(CONVERTERS+(LANES-CONVERTERS%LANES)*|(CONVERTERS%LANES))-1:0] tx_dataout;
  // Scrambler 
  wire [DATA_WIDTH-1:0] out_sc, out_desc;
  // 8B10B
  reg [DATA_WIDTH-1:0] rd_in;
  wire [DATA_WIDTH-1:0] rd_out;
  wire [DATA_WIDTH*10-1:0] out_enc;
  //    wire rdispout, disp_err, code_err, k_out;
  wire [DATA_WIDTH-1:0] out_dec;
	
  jesd204b_tpl_tx #(
    .LANES (LANES), 
    .CONVERTERS (CONVERTERS), 
    .RESOLUTION (RESOLUTION),
    .CONTROL (CONTROL),    
    .SAMPLE_SIZE (SAMPLE_SIZE), 
    .SAMPLES (SAMPLES)         
  ) tpltx (
    .clk(clock),
    .tx_datain (tx_datain),
    .tx_dataout (tx_dataout)
  );

  jesd204b_scrambler #(
    .DATA_WIDTH (DATA_WIDTH)
  ) scr (
    .clk (clock), 
    .reset (reset), 
    .en (en), 
    .in (tx_dataout), 
    .out (out_sc)
  );

  always @(posedge clock) begin
      if (reset)  rd_in <= 0;
      else        rd_in <= rd_out;
  end
    
  generate
  genvar i;
  for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
      Enc8B10B enc (
        .BYTECLK (clock), 
        .reset (reset),
        .bit_control (0),
        .in (out_sc[i*8+:8]),
        .rd_in (rd_in[i]),
        .out (out_enc[i*10+:10]),
        .rd_out (rd_out[i])
      );

      Dec8B10B dec (
        .BYTECLK (clock), 
        .reset (reset),
        .in (out_enc[i*10+:10]),
        .rdispout (),
        .disp_err (),
        .code_err (),
        .k_out (),
        .out (out_dec[i*8+:8])
      );
  end
  endgenerate 
    
  jesd204b_descrambler #(
    .DATA_WIDTH (DATA_WIDTH)
  ) descr (
    .clk (clock), 
    .reset (reset), 
    .en (en), 
    .in (out_dec), 
    .out (out_desc)
  );
    
  jesd204b_tpl_rx #(
    .LANES (LANES), 
    .CONVERTERS (CONVERTERS), 
    .RESOLUTION (RESOLUTION),
    .CONTROL (CONTROL),    
    .SAMPLE_SIZE (SAMPLE_SIZE), 
    .SAMPLES (SAMPLES)         
  ) tplrx (
    .clk(clock),
    .tx_datain (out_desc),
    .tx_dataout (rx_dataout)
  );
endmodule
