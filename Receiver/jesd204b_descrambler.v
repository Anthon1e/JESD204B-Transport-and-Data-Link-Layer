`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/20/2021 01:47:28 PM
// Design Name: 
// Module Name: descrambler
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


module jesd204b_descrambler #(
	/* Parameters declaration */
    parameter DATA_WIDTH = 128
    ) (
    input clk,
    input reset,
    input en,
    input [DATA_WIDTH-1:0] in,
    output reg [DATA_WIDTH-1:0] out
    );
    
    // In descrambler, no need for preset
    reg [14:0] storage;
    
    /* Looping through the input data bit, starting from MSB */
    integer i;
    always @(*) begin
        if (reset) begin 
            out <= 0;
        end else begin
            if (en) begin
                for (i = DATA_WIDTH; i > 0; i = i - 1) begin 
                    out[i-1] = in[i-1] ^ storage[14] ^ storage[13];
                    // Replace LSB of storage with in, push the
                    //  remaining to the right. Value of bit 0 is gone
                    storage = {storage[13:0], in[i-1]}; 
                end
            end
            else out <= in;
        end
    end
endmodule
