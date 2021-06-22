`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/01/2021 08:12:08 AM
// Design Name: 
// Module Name: jesd204b_dl
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


module jesd204b_dl #(
    parameter LANE_DATA_WIDTH = 32,
    parameter OCTET_PER_SENT = 4,
    parameter LANES = 1,
    parameter OCTETS_PER_FR = 3, 
    parameter FRAMES_PER_MF = 7
    )(
    input clk,
    input reset,
    input scramble_enable,
    input [14*8-1:0] in_config,
    input [LANE_DATA_WIDTH*LANES-1:0] in,
    output [LANE_DATA_WIDTH*LANES-1:0] out_tx,
    output [LANE_DATA_WIDTH*LANES-1:0] out,
    output [3:0] sof,
    output [3:0] eof,
    output [3:0] som,
    output [3:0] eom,
    output reg LMFC
    );
    
    localparam OCTETS_PER_MF = OCTETS_PER_FR * FRAMES_PER_MF;
    
    wire [4*LANES-1:0] sync_request, ctrl_out_tx;
    wire [3:0] eof_h, eom_h;
    wire sync_request_all = |sync_request;
    
    /* LMFC counter based on clock cycles 
        Eqn: LMFC = 10*F*K/SR, with SR = Serial Rate  
        Assumption: SR = 10 Gb/s, 1 clk cycle = 1 ns  
        => LMFC cycles = (10*F*K)/(SR*2e-9)         */
    reg LMFC_about_to_rise, LMFC_about_to_rise_2;
    reg [9:0] LMFC_raise_counter;
    localparam LMFC_CYCLES = 10*OCTETS_PER_MF/10;
    always @(posedge clk) begin
        if (reset) begin
            LMFC <= 0;
            LMFC_raise_counter <= 0;
        end else begin
            if (LMFC_raise_counter == 'h0) begin
                LMFC_raise_counter <= LMFC_raise_counter + 1;
                LMFC <= 1;
                LMFC_about_to_rise <= 0;
            end else if (LMFC_raise_counter == 'h1) begin 
                LMFC_raise_counter <= LMFC_raise_counter + 1;
                LMFC <= 0;
            end else if (LMFC_raise_counter == (LMFC_CYCLES-3)) begin
                LMFC_raise_counter <= LMFC_raise_counter + 1;
                LMFC_about_to_rise_2 <= 1;
            end else if (LMFC_raise_counter == (LMFC_CYCLES-2)) begin
                LMFC_raise_counter <= LMFC_raise_counter + 1;
                LMFC_about_to_rise <= 1;
                LMFC_about_to_rise_2 <= 0;
            end else if (LMFC_raise_counter == (LMFC_CYCLES-1)) begin
                LMFC_raise_counter <= 0;
                LMFC_about_to_rise <= 0;
            end else begin
                LMFC_raise_counter <= LMFC_raise_counter + 1;
            end
        end
    end
    
    generate 
    genvar i;
    for (i = 0; i < LANES; i = i + 1) begin
        jesd204b_dl_tx #(
        .LANE_DATA_WIDTH (LANE_DATA_WIDTH),
        .OCTET_PER_SENT (OCTET_PER_SENT),
        .OCTETS_PER_FR (OCTETS_PER_FR),
        .FRAMES_PER_MF (FRAMES_PER_MF)
        ) dltx (
        .clk (clk),
        .reset (reset),
        .LMFC (LMFC_about_to_rise),
        .sync_request (sync_request_all),
        .scramble_enable (scramble_enable),
        .eof (eof_h),
        .eom (eom_h),
        .in_config (in_config), 
        .in (in[i*LANE_DATA_WIDTH+:LANE_DATA_WIDTH]),
        .out (out_tx[i*LANE_DATA_WIDTH+:LANE_DATA_WIDTH]),
        .ctrl_out (ctrl_out_tx[4*i+:4])
        );
        
        jesd204b_dl_rx #(
        .LANE_DATA_WIDTH (LANE_DATA_WIDTH),
        .OCTET_PER_SENT (OCTET_PER_SENT),
        .OCTETS_PER_FR (OCTETS_PER_FR),
        .FRAMES_PER_MF (FRAMES_PER_MF)
        ) dlrx (
        .clk (clk),
        .reset (reset),
        .LMFC (LMFC_about_to_rise), 
        .scramble_enable (scramble_enable),
        .valid (1'b1),
        .eof (eof),
        .in (out_tx[i*LANE_DATA_WIDTH+:LANE_DATA_WIDTH]),
        .out (out[i*LANE_DATA_WIDTH+:LANE_DATA_WIDTH]),
        .sync_request (sync_request[i])
        );
    end
    endgenerate
    
    jesd204b_dl_framemark #(
    .LANE_DATA_WIDTH (LANE_DATA_WIDTH),
    .OCTET_PER_SENT (OCTET_PER_SENT),
    .OCTETS_PER_FR (OCTETS_PER_FR),
    .FRAMES_PER_MF (FRAMES_PER_MF)
    ) fm (
    .clk (clk),
    .reset (reset),
    .LMFC (LMFC_about_to_rise_2),
    .eof_h (eof_h),
    .eom_h (eom_h),
    .sof (sof),
    .eof (eof),
    .som (som),
    .eom (eom)
    );
    
endmodule
