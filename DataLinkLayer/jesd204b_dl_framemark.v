`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/14/2021 01:58:38 PM
// Design Name: 
// Module Name: jesd204b_dl_framemark
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


module jesd204b_dl_framemark #(
    parameter LANE_DATA_WIDTH = 32,
    parameter OCTET_PER_SENT = 4,
    parameter OCTETS_PER_FR = 5,
    parameter FRAMES_PER_MF = 5
    )(
    input clk,
    input reset,
    input LMFC,
    output reg [OCTET_PER_SENT-1:0] eof_h2,
    output reg [OCTET_PER_SENT-1:0] eom_h2,
    output reg [OCTET_PER_SENT-1:0] sof,
    output reg [OCTET_PER_SENT-1:0] eof,
    output reg [OCTET_PER_SENT-1:0] som,
    output reg [OCTET_PER_SENT-1:0] eom
    );
    
	localparam OCTETS_PER_MF = OCTETS_PER_FR * FRAMES_PER_MF;
	
    reg [9:0] octet_counter, octet_counter_fr;
    reg start_marking;
    
    reg [OCTET_PER_SENT-1:0] sof_h;
    reg [OCTET_PER_SENT-1:0] eof_h;
    reg [OCTET_PER_SENT-1:0] som_h;
    reg [OCTET_PER_SENT-1:0] eom_h;
	reg [OCTET_PER_SENT-1:0] sof_h2;
	//reg [OCTET_PER_SENT-1:0] eof_h2;
	reg [OCTET_PER_SENT-1:0] som_h2;
	//reg [OCTET_PER_SENT-1:0] eom_h2;
	
	wire [OCTETS_PER_FR-1:0] sof_t = {{(OCTETS_PER_FR-2){1'b0}}, 1'b1};
	wire [OCTETS_PER_FR-1:0] eof_t = {1'b1, {(OCTETS_PER_FR-1){1'b0}}};
	wire [OCTETS_PER_MF-1:0] som_t = {{(OCTETS_PER_MF-2){1'b0}}, 1'b1};
    wire [OCTETS_PER_MF-1:0] eom_t = {1'b1, {(OCTETS_PER_MF-1){1'b0}}};
	
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            {sof_h, eof_h, som_h, eom_h} <= {4{4'b0}};
            start_marking <= 0;
            octet_counter <= 0; 
            octet_counter_fr <= 0;
        end else begin
            if (LMFC || start_marking) begin
                start_marking <= 1;
                // Checking eof and sof
                if ((octet_counter+4) < OCTETS_PER_FR) begin 
                    octet_counter <= octet_counter + 4;
                    sof_h <= sof_t[octet_counter+:4];
                    eof_h <= eof_t[octet_counter+:4];
                end else if ((octet_counter+4) == OCTETS_PER_FR) begin 
                    octet_counter <= 0;
                    sof_h <= sof_t[octet_counter+:4];
                    eof_h <= eof_t[octet_counter+:4];
                end else if ((octet_counter+3) == OCTETS_PER_FR) begin
                    octet_counter <= 1;
                    sof_h <= {sof_t[0], sof_t[octet_counter+:3]};
                    eof_h <= {eof_t[0], eof_t[octet_counter+:3]};
                end else if ((octet_counter+2) == OCTETS_PER_FR) begin
                    octet_counter <= 2;
                    sof_h <= {sof_t[1:0], sof_t[octet_counter+:2]};
                    eof_h <= {eof_t[1:0], eof_t[octet_counter+:2]};
                end else if ((octet_counter+1) == OCTETS_PER_FR) begin
                    octet_counter <= 3;
                    sof_h <= {sof_t[2:0], sof_t[octet_counter+:1]};
                    eof_h <= {eof_t[2:0], eof_t[octet_counter+:1]};
                end
                // Checking eom and som
                if ((octet_counter_fr+4) < OCTETS_PER_MF) begin 
                    octet_counter_fr <= octet_counter_fr + 4;
                    som_h <= som_t[octet_counter_fr+:4];
                    eom_h <= eom_t[octet_counter_fr+:4];
                end else if ((octet_counter_fr+4) == OCTETS_PER_MF) begin 
                    octet_counter_fr <= 0;
                    som_h <= som_t[octet_counter_fr+:4];
                    eom_h <= eom_t[octet_counter_fr+:4];
                end else if ((octet_counter_fr+3) == OCTETS_PER_MF) begin
                    octet_counter_fr <= 1;
                    som_h <= {som_t[0], som_t[octet_counter_fr+:3]};
                    eom_h <= {eom_t[0], eom_t[octet_counter_fr+:3]};
                end else if ((octet_counter_fr+2) == OCTETS_PER_MF) begin
                    octet_counter_fr <= 2;
                    som_h <= {som_t[1:0], som_t[octet_counter_fr+:2]};
                    eom_h <= {eom_t[1:0], eom_t[octet_counter_fr+:2]};
                end else if ((octet_counter_fr+1) == OCTETS_PER_MF) begin
                    octet_counter_fr <= 3;
                    som_h <= {som_t[2:0], som_t[octet_counter_fr+:1]};
                    eom_h <= {eom_t[2:0], eom_t[octet_counter_fr+:1]};
                end
			end
		end
    end
    
    always @(posedge clk) begin
        sof_h2 <= sof_h;
        eof_h2 <= eof_h;
        som_h2 <= som_h;
        eom_h2 <= eom_h;
    end
    
    always @(posedge clk) begin
        sof <= sof_h2;
        eof <= eof_h2;
        som <= som_h2;
        eom <= eom_h2;
    end
endmodule
