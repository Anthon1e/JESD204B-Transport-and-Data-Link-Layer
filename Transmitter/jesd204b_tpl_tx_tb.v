`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/19/2021 10:49:19 AM
// Design Name: 
// Module Name: jesd204b_tpl_tb
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


module jesd204b_tpl_tx_tb #(
	parameter LANES = 4,		// Number of lanes in the link
	parameter CONVERTERS = 8,	// Number of converters
	parameter RESOLUTION = 11,	// Converter resolution
	parameter CONTROL = 2, 		// Number of control bit
	parameter SAMPLE_SIZE = 16,	// Number of bits per sample
	parameter SAMPLES = 1 		// Number of samples per frame
    );
    
    reg [SAMPLES*CONVERTERS*RESOLUTION-1:0] tx_datain;
    reg clock;
    
    wire [SAMPLES*SAMPLE_SIZE*(CONVERTERS+(LANES-CONVERTERS%LANES)*|(CONVERTERS%LANES))-1:0] tx_dataout;
    wire [(SAMPLES*SAMPLE_SIZE*(CONVERTERS+(LANES-CONVERTERS%LANES)*|(CONVERTERS%LANES)))/LANES-1:0] lane0, lane1, lane2, lane3;
    assign {lane3, lane2, lane1, lane0} = tx_dataout;

    jesd204b_tpl_tx #(
        .LANES (LANES), 
        .CONVERTERS (CONVERTERS), 
        .RESOLUTION (RESOLUTION),
        .CONTROL (CONTROL),	
        .SAMPLE_SIZE (SAMPLE_SIZE), 
        .SAMPLES (SAMPLES) 		
    ) DUT (
        .clk(clock),
        .tx_datain (tx_datain),
        .tx_dataout (tx_dataout)
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
        #2; 
        tx_datain ={11'h61b, 11'h71b, 11'h69b, 11'h65b,
                    11'h63b, 11'h73b, 11'h6bb, 11'h67b};
        
        #2;
        $stop;
    end
endmodule
