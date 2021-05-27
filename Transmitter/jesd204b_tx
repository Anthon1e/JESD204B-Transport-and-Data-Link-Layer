`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/26/2021 01:45:09 PM
// Design Name: 
// Module Name: jesd204b_tx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module jesd204b_tx #(
    parameter DATA_WIDTH = 64,
    parameter LANES = 4,           // Number of lanes in the link
	parameter CONVERTERS = 4,      // Number of converters
	parameter RESOLUTION = 11,     // Converter resolution
	parameter CONTROL = 2,         // Number of control bit
	parameter SAMPLE_SIZE = 16,    // Number of bits per sample
	parameter SAMPLES = 1          // Number of samples per frame
    ) (
    input clock, 
    input reset, 
    input [SAMPLES*CONVERTERS*RESOLUTION-1:0] tx_datain,
    output [DATA_WIDTH/8*10-1:0] out_enc
    );
    
    // State machine  
    `define STATE0 4'b0000 // Restart state 
    `define STATE1 4'b0001 
    `define STATE2 4'b0010 
    `define STATE3 4'b0011  
    `define STATE4 4'b0100 
    `define STATE5 4'b0101 
    `define STATE6 4'b0110 
    `define STATE7 4'b0111 
    reg [3:0] cs, ns;
    // Transport Layer 
    wire [SAMPLES*SAMPLE_SIZE*(CONVERTERS+(LANES-CONVERTERS%LANES)*|(CONVERTERS%LANES))-1:0] tx_dataout;
    // Scrambler 
    wire [DATA_WIDTH-1:0] out_sc;
    // 8B10B
    reg [DATA_WIDTH-1:0] rd_in;
    wire [DATA_WIDTH-1:0] rd_out;
    
    // State machine for some delay until the first output
    always @(posedge clock) begin
        if (reset) begin
            rd_in <= 0;
            cs <= `STATE0;
            ns <= `STATE0;
        end else begin
            case (cs) 
            `STATE0: begin ns = `STATE1; end
            `STATE1: begin ns = `STATE1; rd_in <= rd_out; end
            endcase 
            cs <= ns;
        end
    end
    
    jesd204b_tpl_tx #(
        .LANES (LANES), 
        .CONVERTERS (CONVERTERS), 
        .RESOLUTION (RESOLUTION),
        .CONTROL (CONTROL),    
        .SAMPLE_SIZE (SAMPLE_SIZE), 
        .SAMPLES (SAMPLES)         
    ) tpltx (
        .clk(clock),
        .reset(reset),
        .en(1),
        .tx_datain (tx_datain),
        .tx_dataout (tx_dataout)
    );
    
    jesd204b_scrambler #(
        .DATA_WIDTH (DATA_WIDTH)
    ) scr (
        .clk (clock), 
        .reset (reset), 
        .en (1), 
        .in (tx_dataout), 
        .out (out_sc)
    );
    
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
    end
    endgenerate 
    
endmodule
