`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/27/2021 09:11:52 AM
// Design Name: 
// Module Name: jesd204b_rx
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


module jesd204b_rx #(
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
    input [DATA_WIDTH/8*10-1:0] in_dec,
    output [SAMPLES*CONVERTERS*RESOLUTION-1:0] rx_dataout
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
    reg en_tplrx;
    // Scrambler 
    wire [DATA_WIDTH-1:0] out_desc;
    // 8B10B
    wire [DATA_WIDTH-1:0] out_dec;
    
    // State machine for some delay until the first output
    always @(posedge clock) begin
        if (reset) begin
            en_tplrx <= 0;
            cs <= `STATE0;
            ns <= `STATE0;
        end else begin
            case (cs) 
            `STATE0: begin ns = `STATE1; end
            `STATE1: begin ns = `STATE2; end
            `STATE2: begin ns = `STATE3; en_tplrx <= 1; end
            `STATE3: begin ns = `STATE3; end
            endcase 
            cs <= ns;
        end
    end
    
    generate
    genvar i;
    for (i = 0; i < DATA_WIDTH/8; i = i + 1) begin
        Dec8B10B dec (
            .BYTECLK (clock), 
            .reset (reset),
            .in (in_dec[i*10+:10]),
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
        .en (1), 
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
        .reset(reset),
        .en(en_tplrx),
        .rx_datain (out_desc),
        .rx_dataout (rx_dataout)
    );
endmodule
