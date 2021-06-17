`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/01/2021 08:12:08 AM
// Design Name: 
// Module Name: jesd204b_dl_rx
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


module jesd204b_dl_rx #(
    parameter LANE_DATA_WIDTH = 32,
    parameter OCTET_PER_SENT = 4,
    parameter OCTETS_PER_FR = 5,
    parameter FRAMES_PER_MF = 4
    )(
    input clk,
    input reset,
    input LMFC, 
    input scramble_enable,
    // if data is valid based on disparity, characters, etc..
    input valid,
    input [3:0] eof,
    input [LANE_DATA_WIDTH-1:0] in,
    output reg [LANE_DATA_WIDTH-1:0] out,
    // sync flag of EACH lane when 4 Ks are received
    output reg sync_request
    );
    
    localparam OCTETS_PER_MF = OCTETS_PER_FR * FRAMES_PER_MF;
    
    `define RST_T       4'b0000 // Restart state 
    `define CGS_INIT    4'b0001 
    `define CGS_CHECK   4'b0010 
    `define CGS_DATA    4'b0011 
    `define FS_INIT     4'b0100 
    `define FS_DATA     4'b0101 
    `define STATE6      4'b0110 
    `define STATE7      4'b0111 
    `define STATE8      4'b1000 
    `define STATE9      4'b1001 
    
    reg CGS_done;
    
    /* State machine for CGS */
    reg [3:0] cgs_cs;
    reg [2:0] K_counter, I_counter, V_counter;
    always @(posedge clk) begin
        if (reset) begin
            cgs_cs <= `RST_T;
            sync_request <= 0;
            CGS_done <= 0;
        end else begin 
            case (cgs_cs) 
            // State after resetted
            `RST_T: begin 
                cgs_cs <= `CGS_INIT; 
                sync_request <= 0; 
                K_counter <= 0;
                end
            // State for code group synchronization
            `CGS_INIT: begin 
                I_counter <= 0;
                V_counter <= 0;
                sync_request <= 1;
                if (in == {4{8'hBC}} && valid) begin
                    cgs_cs <= `CGS_CHECK;
                    sync_request <= 0;
                    CGS_done <= 1;
                end else begin 
                    cgs_cs <= `CGS_INIT;
                    K_counter <= 0;
                end end     
            // State to check for loss of synchronization
            `CGS_CHECK: begin
                cgs_cs <= `CGS_CHECK;
                K_counter <= 0;
                if (~valid) begin
                    V_counter <= 0; 
                    I_counter <= I_counter + 1;
                    if (I_counter == 'h2) 
                        cgs_cs <= `CGS_INIT;
                end else begin
                    I_counter <= 0; 
                    V_counter <= V_counter + 1;
                    if (I_counter == 'h3)
                        cgs_cs <= `CGS_DATA;
                end end
            // State when all CGS is done, preparing for next request
            `CGS_DATA: begin
                if (~valid)
                    cgs_cs <= `CGS_CHECK;
                else 
                    cgs_cs <= `CGS_DATA;
                end
            endcase 
        end
    end
    
    /* State machine for ILS and IFS */
    reg [3:0] ifs_cs;
    reg [7:0] O_counter;
    reg [LANE_DATA_WIDTH-1:0] ifs_out;
    reg [7:0] last_octet, last_octet_2;
    reg ifs_turn = 0;
    integer i;
    always @(posedge clk) begin
        if (sync_request) begin
            ifs_out <= {4{8'hBC}};
            ifs_cs <= `FS_INIT;
            ifs_turn <= 0;
            O_counter <= 0;
        end else begin
            case (ifs_cs)
            `FS_INIT: begin 
                if (in == {4{8'hBC}} || ~CGS_done) begin
                    ifs_cs <= `FS_INIT;
                end else begin
                    if (O_counter == (4*OCTETS_PER_MF-4)) begin
                        ifs_cs <= `FS_DATA;
                        O_counter <= 0; 
                    end else begin 
                        ifs_cs <= `FS_INIT;
                        O_counter <= O_counter + 4;
                    end
                    ifs_out <= in;
                    ifs_turn <= 1; 
                end end
            `FS_DATA: begin
                ifs_cs <= `FS_DATA;
                // Check alignment code, an A or F is received
                // SCRAMBLING MODE: OFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
                if (~scramble_enable) begin 
                    for (i = 0; i < 4; i = i + 1) begin
                        if ((in[i*8+:8] == 8'h7C) || (in[i*8+:8] == 8'hFC)) begin
                            if ((last_octet == 8'h7C) || (last_octet == 8'hFC))
                                ifs_out[i*8+:8] <= last_octet_2;
                            else 
                                ifs_out[i*8+:8] <= last_octet;
                        end else
                            ifs_out[i*8+:8] <= in[i*8+:8];    
                        // save the octet of previous frame
                        if (eof[i]) begin
                            last_octet <= in[i*8+:8];
                            last_octet_2 <= last_octet;
                        end
                    end
                // SCRAMBLING MODE: ONNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
                end else  
                    ifs_out <= in;
                end 
            endcase
        end
    end 
    
    /* Elastic buffer to hold data, waiting for all lanes to synchronization */
    reg [LANE_DATA_WIDTH-1:0] ebuffer [0:31];
    reg [4:0] eindex_in, eindex_out;
    reg release_buffer;
    always @(posedge clk) begin
        if (reset) begin
            eindex_in <= 'h0;
            release_buffer <= 0;
        end else begin
            if (ifs_turn) begin
                ebuffer[eindex_in] <= ifs_out;
                eindex_in <= eindex_in + 1;
                release_buffer <= 1;
            end else 
                release_buffer <= 0;
        end
    end
    
    /* State machine for User Data and Lane alignment */
    reg [LANE_DATA_WIDTH-1:0] ud_out;
    reg ud_turn;
    always @(posedge clk) begin
        if (~release_buffer) begin
            ud_out <= {4{8'hBC}};
            eindex_out <= 'h0;
            ud_turn <= 0; 
        end else begin
            if (LMFC || ud_turn) begin
                ud_out <= ebuffer[eindex_out];
                eindex_out <= eindex_out + 1;
                ud_turn <= 1; 
            end
        end
    end
    
    /* Output assignment */
    always @(posedge clk) begin
        if (reset) begin
            out <= {4{8'hFF}};
        end else begin
            out <= ud_out;
        end
    end
endmodule
