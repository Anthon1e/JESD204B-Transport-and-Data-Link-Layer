`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/20/2021 08:26:11 AM
// Design Name: 
// Module Name: jesd204b_tpl_rx_tb
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


module jesd204b_tpl_rx_tb #(
	parameter LANES = 4,		// Number of lanes in the link
	parameter CONVERTERS = 8,	// Number of converters
	parameter RESOLUTION = 11,	// Converter resolution
	parameter CONTROL = 2, 		// Number of control bit
	parameter SAMPLE_SIZE = 16,	// Number of bits per sample
	parameter SAMPLES = 1 		// Number of samples per frame
    );
    
    reg clock, reset;
    reg [SAMPLES*SAMPLE_SIZE*(CONVERTERS+(LANES-CONVERTERS%LANES)*|(CONVERTERS%LANES))-1:0] rx_datain;
    wire [(SAMPLES*SAMPLE_SIZE*(CONVERTERS+(LANES-CONVERTERS%LANES)*|(CONVERTERS%LANES)))/LANES-1:0] lane0, lane1, lane2, lane3;
    assign {lane3, lane2, lane1, lane0} = rx_datain;    
    
    wire [SAMPLES*CONVERTERS*RESOLUTION-1:0] rx_dataout;

    jesd204b_tpl_rx #(
        .LANES (LANES), 
        .CONVERTERS (CONVERTERS), 
        .RESOLUTION (RESOLUTION),
        .CONTROL (CONTROL),	
        .SAMPLE_SIZE (SAMPLE_SIZE), 
        .SAMPLES (SAMPLES) 		
    ) DUT (
        .clk(clock),
        .reset(reset),
        .en(1),
        .rx_datain (rx_datain),
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
        #2;
        reset <= 0;
        rx_datain <= 128'he360c360_cb60d360_e760c760_cf60d760;
        #4;
        $stop;
    end
endmodule
