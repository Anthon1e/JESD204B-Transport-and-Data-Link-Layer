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
    parameter DATA_WIDTH = 64
    ) (
    input clk,
    input reset,
    input en,
    input [DATA_WIDTH-1:0] in,
    output reg [DATA_WIDTH-1:0] out
    );
    
    // 1 for 8 highest-storage elements, rest are 0
    reg [14:0] storage;
    
    /* Looping through the input data bit, starting from MSB */
    integer i, j;
    always @(*) begin
        if (reset) begin 
            out = 0;
        end else begin
            j = 0;
            if (en) begin
                for (i = DATA_WIDTH; i > 0; i = i - 1) begin 
                    if (j < 16) out[i-1] = in[i-1];
                    else out[i-1] = in[i-1] ^ storage[14] ^ storage[13];
                    // Replace LSB of storage with in, push the
                    //  remaining to the right. Value of bit 0 is gone
                    storage = {storage[13:0], in[i-1]}; 
                    j = j + 1;
                end
            end
            else out = in;
        end
    end
endmodule
