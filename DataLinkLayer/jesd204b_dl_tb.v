`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/01/2021 10:15:07 AM
// Design Name: 
// Module Name: jesd204b_dl_tb
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


module jesd204b_dl_tb #(
    parameter LANE_DATA_WIDTH = 32,
    parameter OCTET_PER_SENT = 4,
    parameter LANES = 1,
    parameter OCTETS_PER_FR = 2,
    parameter FRAMES_PER_MF = 10
    );
    
    reg clock, reset, scramble_enable;
    reg [14*8-1:0] in_config;
    reg [LANE_DATA_WIDTH*LANES-1:0] in;
    wire [LANE_DATA_WIDTH*LANES-1:0] out, out_tx;
    wire [OCTET_PER_SENT-1:0] sof, eof, som, eom;
    wire LMFC;
    
    jesd204b_dl #(
    .LANE_DATA_WIDTH (LANE_DATA_WIDTH),
    .OCTET_PER_SENT (OCTET_PER_SENT),
    .LANES (LANES),
    .OCTETS_PER_FR (OCTETS_PER_FR),
    .FRAMES_PER_MF (FRAMES_PER_MF)
    ) dut (
    .clk (clock),
    .reset (reset),
    .scramble_enable (scramble_enable),
    .in_config (in_config),
    .in (in),
    .out_tx (out_tx),
    .out (out),
    .sof (sof),
    .eof (eof),
    .som (som),
    .eom (eom),
    .LMFC (LMFC)
    );
    
    initial begin
        // Set up for the rise of clock every 2 seconds
        clock <= 1'b1;
        #1;
        forever begin
            clock <= 1'b0;
            #1;
            clock <= 1'b1;
            #1;
        end
    end
    
    initial begin
        #110;
        in <= 32'h11111111;
        #50; 
        forever begin 
            in <= in + {4{8'h11}};
            #50;
        end
    end
    
    initial begin 
        reset <= 1;
        scramble_enable <= 0;
        in_config <= 112'h77_77_77_77_88_88_88_88_77_77_77_77_88_88; 
        #120;
        reset <= 0;
        #1500;
        $stop;
    end
endmodule
