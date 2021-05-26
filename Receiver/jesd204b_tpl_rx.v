`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/20/2021 08:10:42 AM
// Design Name: 
// Module Name: jesd204b_tpl_rx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Implementation of the transport layer in a jesd204b design 
//              Receiver (rx) side
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module jesd204b_tpl_rx #(
	/* Parameters declaration */
	parameter LANES = 4,		// Number of lanes in the link
	parameter CONVERTERS = 8,	// Number of converters
	parameter RESOLUTION = 11,	// Converter resolution
	parameter CONTROL = 2, 		// Number of control bit
	parameter SAMPLE_SIZE = 16,	// Number of bits per sample
	parameter SAMPLES = 1 		// Number of samples per frame
	) (
	/* Input, output declaration 
		Input: Lane 0 with 4 octets will be rx_dataout[31:0]
		        starting at Octet 0 [31:24] -> Octet 4 [7:0]          
        Output: Converter 0 with resolution 11 will be rx_datain[10:0] */
    input clk,
    input reset,
    input en,
	input [SAMPLES*SAMPLE_SIZE*(CONVERTERS+(LANES-CONVERTERS%LANES)*|(CONVERTERS%LANES))-1:0] rx_datain,
    output reg [SAMPLES*CONVERTERS*RESOLUTION-1:0] rx_dataout
	);
	
	/* Parameters calculation */
    localparam TAILS = SAMPLE_SIZE - RESOLUTION - CONTROL;                          // Number of tail bits
    localparam OCTETS = (SAMPLES*SAMPLE_SIZE*(CONVERTERS+
                        (LANES-CONVERTERS%LANES)*|(CONVERTERS%LANES)))/(8*LANES) ;  // Number of octets per frame per lane
    
    /* Actual mapping of the transport layer */ 
    integer i, j;
    (* KEEP = "TRUE" *) reg [3:0] k;   // represent lane index, octet index, converter index
    always @(posedge clk) begin 
        if (reset) begin 
            rx_dataout = 0;
        end else if (en) begin 
            k = 0;
            // Looping for each lane
            for (i = 0; i < LANES; i = i+1) begin
                // Looping for every 2 octets 
                for (j = OCTETS; j > 0; j = j-2) begin
                    if (k < CONVERTERS) begin
                        rx_dataout[k*RESOLUTION +: RESOLUTION] = rx_datain[i*8*OCTETS+(j-2)*8+CONTROL+TAILS +: RESOLUTION];
                        // Next converter index
                        k = k + 1;    
                    end 
                end
            end
        end
    end
endmodule
