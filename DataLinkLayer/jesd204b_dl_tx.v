`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/01/2021 08:11:22 AM
// Design Name: 
// Module Name: jesd204b_dl_tx
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


module jesd204b_dl_tx #(
    parameter LANE_DATA_WIDTH = 32,
    parameter OCTET_PER_SENT = 4,
    parameter OCTETS_PER_FR = 5,
    parameter FRAMES_PER_MF = 4
    )(
    input clk,
    input reset,
    input LMFC,
    input sync_request, 
    input scramble_enable,
    input [3:0] eof,
    input [3:0] eom,
    input [14*8-1:0] in_config,
    input [LANE_DATA_WIDTH-1:0] in,
    output reg [LANE_DATA_WIDTH-1:0] out,
    output reg [LANE_DATA_WIDTH/8-1:0] ctrl_out
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
    
    reg CGS_done = 0;
    reg ILAS_done = 0;
    
    /* State machine for CGS */
    reg [3:0] cgs_cs, cgs_ctrl_out;
    reg [LANE_DATA_WIDTH-1:0] cgs_out;
    always @(posedge clk) begin
        if (reset) begin
            CGS_done <= 0;
            cgs_cs <= `RST_T;
            cgs_out <= {4{8'hff}};
            cgs_ctrl_out <= 4'b0;
        end else begin
            case (cgs_cs)
            `RST_T: begin
                if (sync_request)
                    cgs_cs <= `CGS_INIT;
                    cgs_out <= {4{8'hBC}};
                    cgs_ctrl_out <= 4'b1111;
                end
            `CGS_INIT: begin
                if (~sync_request) begin
                    CGS_done <= 1;
                    cgs_cs <= `CGS_INIT;
                end end
            `CGS_CHECK: begin
                cgs_cs <= `CGS_CHECK;
                end
            endcase
        end
    end
    
    /* Elastic buffer to hold data from ADC, waiting for CGS & ILAS */
    reg [LANE_DATA_WIDTH-1:0] ebuffer [0:15];
    reg [3:0] eindex_in, eindex_out;
    always @(posedge clk) begin
        if (reset) begin
            eindex_in <= 'h0;
        end else begin
            ebuffer[eindex_in] <= in;
            eindex_in <= eindex_in + 1;
        end
    end
    
    /* State machine for ILAS */
    reg [6:0] octet_count;
    reg [3:0] ilas_ctrl_out;
    reg [1:0] mf_count;
    reg ilas_turn;
    reg [LANE_DATA_WIDTH-1:0] ilas_out;
    wire [OCTETS_PER_MF*8-1:0] mf1 = {8'h7c, {(OCTETS_PER_MF-17){8'h00}}, in_config, 8'h9c, 8'h1c};
    wire [OCTETS_PER_MF*8-1:0] mf0 = {8'h7c, {(OCTETS_PER_MF-2){8'h00}}, 8'h1c};
    always @(posedge clk) begin
        if (~CGS_done) begin
            ILAS_done <= 0;
            ilas_turn <= 0;
            octet_count <= 0;
            mf_count <= 0;
            ilas_ctrl_out <= 0;
        end else begin
            if (LMFC || ilas_turn) begin
                ilas_turn <= 1;
                if ((octet_count+4) < OCTETS_PER_MF) begin
                    octet_count <= octet_count+4;
                    if (mf_count == 1)  ilas_out <= mf1[octet_count*8+:32];
                    else                ilas_out <= mf0[octet_count*8+:32];
                end else if ((octet_count+4) == OCTETS_PER_MF) begin
                    octet_count <= 0;
                    if (mf_count == 1)
                        ilas_out <= mf1[octet_count*8+:32];
                    else
                        ilas_out <= mf0[octet_count*8+:32];
                    if (mf_count == 3)
                        ILAS_done <= 1;
                    else
                        mf_count <= mf_count+1;
                end else if ((octet_count+3) == OCTETS_PER_MF) begin
                    octet_count <= 1;
                    if (mf_count == 0)
                        ilas_out <= {mf1[0+:8], mf0[octet_count*8+:24]};
                    else if (mf_count == 1)
                        ilas_out <= {mf0[0+:8], mf1[octet_count*8+:24]};
                    else
                        ilas_out <= {mf0[0+:8], mf0[octet_count*8+:24]};
                    if (mf_count == 3)
                        ILAS_done <= 1;
                    else
                        mf_count <= mf_count+1;
                end else if ((octet_count+2) == OCTETS_PER_MF) begin
                    octet_count <= 2;
                    if (mf_count == 0)
                        ilas_out <= {mf1[0+:16], mf0[octet_count*8+:16]};
                    else if (mf_count == 1)
                        ilas_out <= {mf0[0+:16], mf1[octet_count*8+:16]};
                    else
                        ilas_out <= {mf0[0+:16], mf0[octet_count*8+:16]};
                    if (mf_count == 3)
                        ILAS_done <= 1;
                    else
                        mf_count <= mf_count+1;
                end else if ((octet_count+1) == OCTETS_PER_MF) begin
                    octet_count <= 3;
                    if (mf_count == 0)
                        ilas_out <= {mf1[0+:24], mf0[octet_count*8+:8]};
                    else if (mf_count == 1)                
                        ilas_out <= {mf0[0+:24], mf1[octet_count*8+:8]};
                    else
                        ilas_out <= {mf0[0+:24], mf0[octet_count*8+:8]};
                    if (mf_count == 3)
                        ILAS_done <= 1;
                    else
                        mf_count <= mf_count+1;
                end
            end
        end
    end
    
    /* State machine for User Data and Frame/Lane Alignment */
    reg [7:0] data_prev_AF;
    reg [4:0] octet_count_fr;
    reg [3:0] ud_ctrl_out, last_one_replaced;
    reg [LANE_DATA_WIDTH-1:0] ud_out, next_ud_out;
    reg ud_turn, two_rp, four_rp;
    integer i;
    always @(posedge clk) begin
        if (~ILAS_done) begin
            ud_turn <= 0;
            ud_out <= 0;
            ud_ctrl_out <= 0;
            eindex_out <= 0;
            octet_count_fr <= 0;
            last_one_replaced <= 0;
            two_rp <= 0;
            four_rp <= 1;
            next_ud_out <= ebuffer[eindex_out];
        end else begin
            ud_turn <= 1;
            // SCRAMBLING MODE: OFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            case (scramble_enable)
            'b0: begin
                if (OCTETS_PER_FR == 2) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        if (eom[i] && (data_prev_AF == next_ud_out[i*8+:8])) begin
                            ud_out[i*8+:8] <= 8'h7C;
                            ud_ctrl_out[i] <= 1;
                            if (i == 1) begin
                                {two_rp, four_rp} <= 2'b10;
                            end else begin
                                {two_rp, four_rp} <= 2'b01;
                            end
                        end else if (eof[i] && ~(eom[1] && (data_prev_AF == next_ud_out[15:8]))) begin
                            if (two_rp) begin
                                if (data_prev_AF == next_ud_out[15:8]) begin
                                    if (i == 1) begin
                                        ud_out[i*8+:8] <= 8'hFC;
                                        ud_ctrl_out[i] <= 1;
                                        {two_rp, four_rp} <= 2'b10;
                                    end else begin
                                        ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                                        ud_ctrl_out[i] <= 0;
                                    end
                                end else if (data_prev_AF != next_ud_out[15:8]) begin
                                    if (i == 1) begin
                                        ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                                        ud_ctrl_out[i] <= 0;
                                    end else begin
                                        if (next_ud_out[31:24] == next_ud_out[15:8]) begin
                                            ud_out[i*8+:8] <= 8'hFC;
                                            ud_ctrl_out[i] <= 1;
                                            {two_rp, four_rp} <= 2'b01;
                                        end else begin
                                            ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                                            ud_ctrl_out[i] <= 0;
                                        end
                                    end
                                end
                            end else if (four_rp) begin
                                if (i == 1) begin
                                    ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                                    ud_ctrl_out[i] <= 0;
                                end else if (next_ud_out[31:24] == next_ud_out[15:8]) begin
                                    ud_out[i*8+:8] <= 8'hFC;
                                    ud_ctrl_out[i] <= 1;
                                end else begin
                                    ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                                    ud_ctrl_out[i] <= 0;
                                end
                            end
                        end else begin
                            ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                            ud_ctrl_out[i] <= 0;
                        end
                        // save the octet of previous frame
                        data_prev_AF <= next_ud_out[31:24];
                    end
                end else if (OCTETS_PER_FR == 3) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        if (eom[i]) begin
                            if ((i !== 3) && (data_prev_AF == next_ud_out[i*8+:8])) begin
                                ud_out[i*8+:8] <= 8'h7C;
                                ud_ctrl_out[i] <= 1;
                                last_one_replaced[i] <= 1;
                            end else if ((i == 3) && (next_ud_out[31:24] == next_ud_out[7:0])) begin
                                ud_out[i*8+:8] <= 8'h7C;
                                ud_ctrl_out[i] <= 1;
                                last_one_replaced[i] <= 1;
                            end else begin
                                ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                                ud_ctrl_out[i] <= 0;
                                last_one_replaced[i] <= 1'b0;
                            end
                        end else if (eof[i] && ~(eom[0] && (data_prev_AF == next_ud_out[7:0]))) begin
                            if ((i == 3) && (next_ud_out[31:24] == next_ud_out[7:0])) begin
                                if ((next_ud_out[7:0] == data_prev_AF) && ~(|last_one_replaced)) begin
                                    ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                                    ud_ctrl_out[i] <= 0;
                                    last_one_replaced[i] <= 1'b0;
                                end else begin
                                    ud_out[i*8+:8] <= 8'hFC;
                                    ud_ctrl_out[i] <= 1;
                                    last_one_replaced[i] <= 1'b1;
                                end
                            end else if ((i !== 3) && ~(|last_one_replaced[3:1]) && (data_prev_AF == next_ud_out[i*8+:8])) begin
                                ud_out[i*8+:8] <= 8'hFC;
                                ud_ctrl_out[i] <= 1;
                                last_one_replaced[i] <= 1'b1;
                            end else begin
                                ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                                ud_ctrl_out[i] <= 0;
                                last_one_replaced[i] <= 1'b0;
                            end
                        end else begin
                            ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                            ud_ctrl_out[i] <= 0;
                            last_one_replaced[i] <= 1'b0;
                        end
                        // save the octet of previous frame
                        if (eof[i] && (i !== 0))
                            data_prev_AF <= next_ud_out[i*8+:8];
                    end
                end else if (OCTETS_PER_FR >= 4) begin
                    for (i = 0; i < 4; i = i + 1) begin
                        if (eom[i] && (data_prev_AF == next_ud_out[i*8+:8])) begin
                            ud_out[i*8+:8] <= 8'h7C;
                            ud_ctrl_out[i] <= 1;
                            last_one_replaced[i] <= 1'b1;
                        end else if (eof[i] && ~(|last_one_replaced) && (data_prev_AF == next_ud_out[i*8+:8])) begin
                            ud_out[i*8+:8] <= 8'hFC;
                            ud_ctrl_out[i] <= 1;
                            last_one_replaced[i] <= 1'b1;
                        end else if (~(|eof)) begin
                            ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                            ud_ctrl_out[i] <= 0;
                            last_one_replaced[i] <= last_one_replaced[i];
                        end else begin
                            ud_out[i*8+:8] <= next_ud_out[i*8+:8];
                            ud_ctrl_out[i] <= 0;
                            last_one_replaced[i] <= 1'b0;
                        end
                        // save the octet of previous frame
                        if (eof[i])
                            data_prev_AF <= next_ud_out[i*8+:8];
                    end
                end
            end
            // SCRAMBLING MODE: ONNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
            'b1: begin
                ud_out <= next_ud_out;
                for (i = 0; i < 4; i = i + 1) begin
                    if (eom[i] && (next_ud_out[i*8+:8] == 'h7C))
                        ud_ctrl_out[i] <= 1;
                    else if (eof[i] && (next_ud_out[i*8+:8] == 'hFC))
                        ud_ctrl_out[i] <= 1;
                    else
                        ud_ctrl_out[i] <= 0;
                end
            end
            endcase
            // Do this no matter the mode or case
            eindex_out <= eindex_out + 1;
            next_ud_out <= ebuffer[eindex_out+1];
            // Increment the octet counter or reset it
            if (octet_count_fr == (OCTETS_PER_MF-4))
                octet_count_fr <= 0;
            else 
                octet_count_fr <= octet_count_fr + 4;
        end
    end
    
    /* Output assignment */
    always @(posedge clk) begin
        if (reset) begin
            out <= {4{8'hFF}};
        end else begin
            if (ud_turn) begin          out <= ud_out;   ctrl_out <= ud_ctrl_out;    end
            else if (ilas_turn) begin   out <= ilas_out; ctrl_out <= ilas_ctrl_out;  end
            else begin                  out <= cgs_out;  ctrl_out <= cgs_ctrl_out;   end
        end
    end
endmodule
