`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/26/2021 02:19:25 PM
// Design Name: 
// Module Name: jesd204b_tx_tb
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


module jesd204b_tx_tb #(
    parameter DATA_WIDTH = 64,
    parameter LANES = 4,           // Number of lanes in the link
	parameter CONVERTERS = 4,      // Number of converters
	parameter RESOLUTION = 11,     // Converter resolution
	parameter CONTROL = 2,         // Number of control bit
	parameter SAMPLE_SIZE = 16,    // Number of bits per sample
	parameter SAMPLES = 1          // Number of samples per frame
	);
    
    reg clock, reset;
    reg [SAMPLES*CONVERTERS*RESOLUTION-1:0] tx_datain;
    wire [DATA_WIDTH/8*10-1:0] out_enc;
    
    jesd204b_tx #(
    .DATA_WIDTH (DATA_WIDTH),
    .LANES (LANES), 
    .CONVERTERS (CONVERTERS), 
    .RESOLUTION (RESOLUTION),
    .CONTROL (CONTROL),    
    .SAMPLE_SIZE (SAMPLE_SIZE), 
    .SAMPLES (SAMPLES) 
    ) dut (
    .clock (clock), 
    .reset (reset), 
    .tx_datain (tx_datain),
    .out_enc (out_enc)
    );
    
    initial begin
        // Set up for the rise of clock every 2 seconds
        clock = 1'b1;
        #1;
        forever begin
            clock = 1'b0;
            #1;
            clock = 1'b1;
            #1;
        end
    end
    
    initial begin
        #120;
        reset <= 1;
        tx_datain <= 'h0;
        #2; 
        tx_datain <= 'h12345678_abc;
        reset <= 0;
        #2;
        forever begin 
            tx_datain <= tx_datain + 'h11111111_111;
            #2;
        end
    end
endmodule
