`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/21/2021 09:53:13 AM
// Design Name: 
// Module Name: Joint testbench for both scrambler and descrambler
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


module jesd204b_scramble_tb #(
    /* Parameters declaration */
    parameter DATA_WIDTH = 32
    ) ();
    
    reg clock, reset, en;
    reg [DATA_WIDTH-1:0] in;
    wire [DATA_WIDTH-1:0] out, out_sc;
    
    jesd204b_scrambler #(
    .DATA_WIDTH (DATA_WIDTH)
    ) DUTs (
    .clk (clock), 
    .reset (reset), 
    .en (en), 
    .in (in), 
    .out (out_sc)
    );
    
    jesd204b_descrambler #(
    .DATA_WIDTH (DATA_WIDTH)
    ) DUTds (
    .clk (clock), 
    .reset (reset), 
    .en (en), 
    .in (out_sc), 
    .out (out)
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
        reset <= 1;
        en <= 1;
        #2;
        in <= 'hbeefbeef;
        reset <= 0;
        forever begin
            #2;
            in <= in + {4{8'h04}};
        end
    end
endmodule
