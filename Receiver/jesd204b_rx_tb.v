`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/27/2021 10:02:32 AM
// Design Name: 
// Module Name: jesd204b_rx_tb
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


module jesd204b_rx_tb #(
    parameter DATA_WIDTH = 64,
    parameter LANES = 4,           // Number of lanes in the link
	parameter CONVERTERS = 4,      // Number of converters
	parameter RESOLUTION = 11,     // Converter resolution
	parameter CONTROL = 2,         // Number of control bit
	parameter SAMPLE_SIZE = 16,    // Number of bits per sample
	parameter SAMPLES = 1          // Number of samples per frame
	);
	
	reg clock, reset;
	reg [DATA_WIDTH/8*10-1:0] in_dec;
    wire [SAMPLES*CONVERTERS*RESOLUTION-1:0] rx_dataout;
    
    jesd204b_rx #(
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
    .in_dec (in_dec),
    .rx_dataout (rx_dataout)
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
        in_dec <= 'h0;
        #2; 
        in_dec <= 'h4ee7_971a_d3da_4dc3_595e;
        reset <= 0;
        #2;
        in_dec <= 'hc658_59c5_2a8a_97a3_aa25;
        #2;
        in_dec <= 'h2e67_556e_75d9_1897_5ad4;
        #2;
        in_dec <= 'ha558_cc6b_149e_a5e5_33a2;
        #2;
        forever begin 
            in_dec <= in_dec + 'h11111111_111;
            #2;
        end
    end
endmodule
