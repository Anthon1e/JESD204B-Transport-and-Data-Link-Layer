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
    parameter LANE_DATA_WIDTH = 8,
    parameter LANES = 2,
    parameter OCTETS_PER_FR = 4,
    parameter FRAMES_PER_MF = 8
    )(
    input clk,
    input reset,
    input scramble_enable,
    input [14*8-1:0] in_config,
    input [LANE_DATA_WIDTH*LANES-1:0] in,
    output [LANE_DATA_WIDTH*LANES-1:0] out
    );
    
    localparam OCTETS_PER_MF = OCTETS_PER_FR * FRAMES_PER_MF;
    
    wire [LANES-1:0] sync_request, ctrl_out_tx;
    wire [LANE_DATA_WIDTH*LANES-1:0] out_tx;
    
    wire sync_request_all = |sync_request;
    
    /* LMFC counter based on clock cycles 
        Eqn: LMFC = 10*F*K/SR, with SR = Serial Rate  
        Assumption: SR = 10 Gb/s, 1 clk cycle = 1 ns  
        => LMFC cycles = (10*F*K)/(SR*2e-9)         */
    reg LMFC, LMFC_about_to_rise;
    reg [4:0] LMFC_raise_counter;
    localparam LMFC_CYCLES = 10*OCTETS_PER_FR*FRAMES_PER_MF/10;
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
            end else if (LMFC_raise_counter == (LMFC_CYCLES-1)) begin
                LMFC_raise_counter <= 0;
                LMFC_about_to_rise <= 1;
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
        .OCTETS_PER_FR (OCTETS_PER_FR),
        .FRAMES_PER_MF (FRAMES_PER_MF)
        ) dltx (
        .clk (clk),
        .reset (reset),
        .LMFC (LMFC_about_to_rise),
        .sync_request (sync_request_all),
        .scramble_enable (scramble_enable),
        .in_config (in_config), 
        .in (in[i*8+:8]),
        .out (out_tx[i*8+:8]),
        .ctrl_out (ctrl_out_tx[i])
        );
        
        jesd204b_dl_rx #(
        .LANE_DATA_WIDTH (LANE_DATA_WIDTH),
        .OCTETS_PER_FR (OCTETS_PER_FR),
        .FRAMES_PER_MF (FRAMES_PER_MF)
        ) dlrx (
        .clk (clk),
        .reset (reset),
        .LMFC (LMFC_about_to_rise), 
        .scramble_enable (scramble_enable),
        .valid (1),
        .in (out_tx[i*8+:8]),
        .out (out[i*8+:8]),
        .sync_request (sync_request[i])
        );
    end
    endgenerate
    
endmodule


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
    parameter LANE_DATA_WIDTH = 8,
    parameter OCTETS_PER_FR = 4,
    parameter FRAMES_PER_MF = 8
    )(
    input clk,
    input reset,
    input LMFC,
    input sync_request, 
    input scramble_enable,
    input [14*8-1:0] in_config,
    input [LANE_DATA_WIDTH-1:0] in,
    output reg [LANE_DATA_WIDTH-1:0] out,
    output reg ctrl_out
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
    reg [3:0] cgs_cs;
    reg [LANE_DATA_WIDTH-1:0] cgs_out;
    reg cgs_ctrl_out;
    always @(posedge clk) begin
        if (reset) begin 
            CGS_done <= 0; 
            cgs_cs <= `RST_T;
            cgs_out <= 0;
            cgs_ctrl_out <= 1;
        end else begin 
            case (cgs_cs) 
            `RST_T: begin 
                if (sync_request) 
                    cgs_cs <= `CGS_INIT; 
                end
            `CGS_INIT: begin 
                if (~sync_request) begin
                    CGS_done <= 1;
                    cgs_cs <= `CGS_INIT; 
                end else begin 
                    cgs_out <= 8'hBC;
                end end
            `CGS_CHECK: begin
                cgs_cs <= `CGS_CHECK;
                end
            endcase 
        end
    end
    
    /* Elastic buffer to hold data from ADC, waiting for CGS & ILAS */
    reg [LANE_DATA_WIDTH-1:0] ebuffer [0:255];
    reg [7:0] eindex_in, eindex_out;
    always @(posedge clk) begin
        if (reset) begin
            eindex_in <= 'h0;
        end else begin
            ebuffer[eindex_in] <= in;
            eindex_in <= eindex_in + 1;
        end
    end
    
    /* State machine for ILAS */
    reg [4:0] octet_count;
    reg [3:0] config_octet, mf_count;
    reg ilas_turn, ilas_ctrl_out;
    reg [LANE_DATA_WIDTH-1:0] ilas_out;
    always @(posedge clk) begin
        if (~CGS_done) begin
            ILAS_done <= 0;
            ilas_turn <= 0;
            octet_count <= 0;
            mf_count <= 1; 
            config_octet <= 0;
            ilas_ctrl_out <= 0;
        end else begin
            if (LMFC || ilas_turn) begin
                ilas_turn <= 1; 
                case (mf_count)
                'h2: begin
                    // Send R, start of frame
                    if (octet_count == 'h0) begin 
                        ilas_out <= 8'h1c; ilas_ctrl_out <= 1; octet_count <= octet_count + 1; 
                    // Send Q, second char of frame
                    end else if (octet_count == 'h1) begin 
                        ilas_out <= 8'h9c; ilas_ctrl_out <= 1; octet_count <= octet_count + 1; 
                    // Send configuration data
                    end else if (('h1 < octet_count) && (octet_count < 'hf)) begin
                        ilas_out <= in_config[config_octet*8+:8];
                        ilas_ctrl_out <= 0;
                        config_octet <= config_octet + 1;
                        octet_count <= octet_count + 1;
                    // Send A, end of frame
                    end else if (octet_count == (OCTETS_PER_MF-1)) begin 
                        ilas_out <= 8'h7c; ilas_ctrl_out <= 1; 
                        mf_count <= mf_count + 1; octet_count <= 0;
                    // Send user data otherwise
                    end else begin 
                        ilas_out <= 8'hAA; ilas_ctrl_out <= 0; octet_count <= octet_count + 1; end
                    end 
                // Rest of frames are the same 
                'h1: begin 
                    // Send R, start of frame
                    if (octet_count == 'h0) begin 
                        ilas_out <= 8'h1c; ilas_ctrl_out <= 1; octet_count <= octet_count + 1; 
                    // Send A, end of frame
                    end else if (octet_count == (OCTETS_PER_MF-1)) begin 
                        ilas_out <= 8'h7c; ilas_ctrl_out <= 1; 
                        mf_count <= mf_count + 1; octet_count <= 0;
                    // Send user data otherwise
                    end else begin 
                        ilas_out <= 8'hAA; ilas_ctrl_out <= 0; octet_count <= octet_count + 1; end
                    end
                'h3: begin 
                    // Send R, start of frame
                    if (octet_count == 'h0) begin 
                        ilas_out <= 8'h1c; ilas_ctrl_out <= 1; octet_count <= octet_count + 1; 
                    // Send A, end of frame
                    end else if (octet_count == (OCTETS_PER_MF-1)) begin 
                        ilas_out <= 8'h7c; ilas_ctrl_out <= 1; 
                        mf_count <= mf_count + 1; octet_count <= 0;
                    // Send user data otherwise
                    end else begin 
                        ilas_out <= 8'hAA; ilas_ctrl_out <= 0; octet_count <= octet_count + 1; end
                    end
                'h4: begin 
                    // Send R, start of frame
                    if (octet_count == 'h0) begin 
                        ilas_out <= 8'h1c; ilas_ctrl_out <= 1; octet_count <= octet_count + 1; 
                    // Send A, end of frame
                    end else if (octet_count == (OCTETS_PER_MF-1)) begin 
                        ilas_out <= 8'h7c; ilas_ctrl_out <= 1; ILAS_done <= 1;
                        mf_count <= mf_count + 1; octet_count <= 0;
                    // Send user data otherwise
                    end else begin 
                        ilas_out <= 8'hAA; ilas_ctrl_out <= 0; octet_count <= octet_count + 1; end
                    end
                endcase
            end
        end
    end
    
    /* State machine for User Data and Frame/Lane Alignment */
    reg [4:0] octet_count_fr;
    reg [LANE_DATA_WIDTH-1:0] data_prev_AF;
    reg [LANE_DATA_WIDTH-1:0] ud_out, next_ud_out;
    reg ud_turn, ud_ctrl_out, last_one_replaced;
    always @(posedge clk) begin
        if (~ILAS_done) begin
            ud_turn <= 0;
            ud_out <= 0;
            ud_ctrl_out <= 0; 
            eindex_out <= 0;
            octet_count_fr <= 0;
            last_one_replaced <= 0;
        end else begin
            ud_turn <= 1;
            // Character replacement for last octet in current frame
            if ((octet_count_fr+1)%OCTETS_PER_FR == 0) begin
                // SCRAMBLING MODE: OFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
                if (~scramble_enable) begin 
                    if (data_prev_AF == next_ud_out) begin
                        // Case when current frame is the end of a multiframe
                        if (octet_count_fr == (OCTETS_PER_MF-1)) begin
                            ud_out <= 'h7C;
                            ud_ctrl_out <= 1;
                            last_one_replaced <= 1;
                        // Case when current frame is not the end of a multiframe
                        end else if (~last_one_replaced) begin
                            ud_out <= 'hFC;
                            ud_ctrl_out <= 1;
                            last_one_replaced <= 1;
                        end else begin 
                            ud_out <= ebuffer[eindex_out];
                            ud_ctrl_out <= 0;
                            last_one_replaced <= 0;
                        end
                    // Case when last octet in current frame not equal that of previous frame
                    end else begin
                        ud_out <= ebuffer[eindex_out];
                        ud_ctrl_out <= 0;
                        last_one_replaced <= 0;
                    end
                    eindex_out <= eindex_out + 1;
                    data_prev_AF <= ebuffer[eindex_out];
                // SCRAMBLING MODE: ONNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
                end else begin
                    ud_out <= ebuffer[eindex_out]; 
                    eindex_out <= eindex_out + 1;
                    if (octet_count_fr == (OCTETS_PER_MF-1)) begin
                        if (ebuffer[eindex_out] == 'h7C)
                            ud_ctrl_out <= 1;
                        else 
                            ud_ctrl_out <= 0;
                    end else if (ebuffer[eindex_out] == 'hFC)
                        ud_ctrl_out <= 1;
                    else
                        ud_ctrl_out <= 0;
                end
            // No character replacement otherwise
            end else begin
                ud_out <= ebuffer[eindex_out];
                ud_ctrl_out <= 0; 
                eindex_out <= eindex_out + 1;
            // Increment the octet counter or reset it
            end 
            next_ud_out <= ebuffer[eindex_out+1];
            if (octet_count_fr == (OCTETS_PER_MF-1))
                octet_count_fr <= 0;
            else 
                octet_count_fr <= octet_count_fr + 1;
        end
    end
    
    /* Output assignment */
    always @(*) begin
        if (reset) begin
            out = 0;
        end else begin
            if (ud_turn) begin          out = ud_out;   ctrl_out = ud_ctrl_out;     end
            else if (ilas_turn) begin   out = ilas_out; ctrl_out = ilas_ctrl_out;   end
            else begin                  out = cgs_out;  ctrl_out = cgs_ctrl_out;    end
        end
    end
endmodule


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
    parameter LANE_DATA_WIDTH = 8,
    parameter OCTETS_PER_FR = 4,
    parameter FRAMES_PER_MF = 8
    )(
    input clk,
    input reset,
    input LMFC, 
    input scramble_enable,
    // if data is valid based on disparity, characters, etc..
    input valid,
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
    
    /* State machine for CGS */
    reg [3:0] cgs_cs;
    reg [2:0] K_counter, I_counter, V_counter;
    always @(posedge clk) begin
        if (reset) begin
            cgs_cs <= `RST_T;
            sync_request <= 0;
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
                if (in == 'hBC && valid) begin
                    K_counter <= K_counter + 1;
                    if (K_counter == 'h3) begin
                        cgs_cs <= `CGS_CHECK;
                        sync_request <= 0;
                    end else
                        cgs_cs <= `CGS_INIT;
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
    reg [5:0] O_counter;
    reg [LANE_DATA_WIDTH-1:0] ifs_out;
    reg [LANE_DATA_WIDTH-1:0] data_prev_AF, data_prev_AF2;
    reg ifs_turn;
    always @(posedge clk) begin
        if (sync_request) begin
            ifs_cs <= `FS_INIT;
            O_counter <= 0;
        end else begin
            case (ifs_cs)
            `FS_INIT: begin 
                if (in == 'hBC) begin
                    ifs_cs <= `FS_INIT;
                end else begin
                    ifs_cs <= `FS_DATA;
                    O_counter <= O_counter + 1;
                    ifs_out <= in;
                    ifs_turn <= 1; 
                end end
            `FS_DATA: begin
                ifs_cs <= `FS_DATA;
                if (O_counter == OCTETS_PER_MF-1)
                    O_counter <= 0;
                else 
                    O_counter <= O_counter + 1;
                // Check alignment code, an A or F is received
                // SCRAMBLING MODE: OFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
                if (~scramble_enable) begin 
                    if ((in == 'h7C) || (in == 'hFC)) begin
                        // Replace alignment character with previous octet
                        if ((data_prev_AF == 'h7C) || (data_prev_AF == 'hFC)) 
                            ifs_out <= data_prev_AF2;  
                        else 
                            ifs_out <= data_prev_AF;
                    end else begin
                        // Keep it as it is
                        ifs_out <= in;
                    // Save the value of the last octet in the previous frame
                    end if (((O_counter+1)%OCTETS_PER_FR) == 0) begin
                        data_prev_AF <= in;
                        data_prev_AF2 <= data_prev_AF;
                    end
                // SCRAMBLING MODE: ONNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN
                end else  
                    ifs_out <= in;
                end 
            endcase
        end
    end 
    
    /* Elastic buffer to hold data, waiting for all lanes to synchronization */
    reg [LANE_DATA_WIDTH-1:0] ebuffer [0:255];
    reg [7:0] eindex_in, eindex_out;
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
    reg ud_turn, ud_start;
    always @(posedge clk) begin
        if (~release_buffer) begin
            ud_out <= 'h0;
            eindex_out <= 'h0;
            ud_turn <= 0;
            ud_start <= 0; 
        end else begin
            if (LMFC) begin
                ud_start = 1; 
            end if (ud_start) begin
                ud_out <= ebuffer[eindex_out];
                eindex_out <= eindex_out + 1;
                ud_turn <= 1; 
            end
        end
    end
    
    always @(*) begin
        if (reset) begin
            out = 0;
        end else begin
            if (~ud_turn)   
                out = 'hBC;                
            else
                out = ud_out;
        end
    end
endmodule


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
    parameter LANE_DATA_WIDTH = 8,
    parameter LANES = 2,
    parameter OCTETS_PER_FR = 4,
    parameter FRAMES_PER_MF = 8
    );
    
    reg clock, reset, scramble_enable;
    reg [14*8-1:0] in_config;
    reg [LANE_DATA_WIDTH*LANES-1:0] in;
    wire [LANE_DATA_WIDTH*LANES-1:0] out;
    
    jesd204b_dl #(
    .LANE_DATA_WIDTH (LANE_DATA_WIDTH),
    .LANES (LANES),
    .OCTETS_PER_FR (OCTETS_PER_FR),
    .FRAMES_PER_MF (FRAMES_PER_MF)
    ) dut (
    .clk (clock),
    .reset (reset),
    .scramble_enable (scramble_enable),
    .in_config (in_config),
    .in (in),
    .out (out)
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
        #120;
        #2;
        in <= 16'h0102;
        #50; 
        forever begin 
            in <= in + {2{8'h01}};
            #50;
        end
    end
    
    initial begin 
        #120;
        reset <= 1;
        scramble_enable <= 0;
        in_config <= 112'h77_77_77_77_88_88_88_88_77_77_77_77_88_88; 
        #2; 
        reset <= 0;
        #1000;
        $stop;
    end
endmodule
