`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/05/2021 10:52:35 AM
// Design Name: 
// Module Name: 8B10B
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Top level module for 8B10B Encoder
//              
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Enc8B10B(
    input BYTECLK, 
    input reset,
    input bit_control,
    input [7:0] in,
    input rd_in,
    output [9:0] out,
    output rd_out
    );
    
    // Variable to hold values 
    wire clk = BYTECLK; 
    wire rd_in_s4, S, COMPLS6, COMPLS4, saved_K;
    wire [4:0] L, saved_L;    
    wire [7:0] saved_data_in;
    wire [5:0] abcdei;
    wire [3:0] fghj; 
    
    reg [7:0] data_in;
    reg K;
    
    fcn5b   f5b(clk, data_in[4:0], L);
    fcn3b   f3b(clk, data_in[4:3], rd_in_s4, L, S); 
    disCtrl dis(clk, reset, K, L, S, data_in, rd_in, saved_data_in, saved_L, saved_K, rd_in_s4, COMPLS6, COMPLS4, rd_out);
    fcn5b6b f56(clk, reset, saved_data_in[4:0], saved_L, saved_K, COMPLS6, abcdei);
    fcn3b4b f34(clk, reset, saved_data_in[7:5], S, saved_K, COMPLS4, fghj);
    
    always @(posedge clk)
    begin
        if (reset) begin 
            K <= 0;
            data_in = 0;
        end
        else begin 
            K <= bit_control;
            data_in = in;
        end
    end
    
    assign out = {abcdei[5:0], fghj[3:0]}; // Encoded messages
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/05/2021 11:00:55 AM
// Design Name: 
// Module Name: fcn5b
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 5B/6B classification or the L function 
//              Figure 3 in Encoder diagram
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fcn5b(
    input clk, 
    input [4:0] data_in,
    output [4:0] L
	);
	// A is the lowest order bit
	wire A,B,C,D,E;
	assign {E,D,C,B,A} = data_in;
	
	// Bit encoding for 5B/6B Classifications
	// It counts the number of 1s and 0s in ABCD
	// L40 means Four 1s and No 0s 
	wire L40, L31, L22, L13, L04; 
	assign L40 = A & B & C & D;                        // A=B=C=D=1
	assign L04 = ~A & ~B & ~C & ~D; 	               // A=B=C=D=0 
	assign L13 = ((A^B) & ~C & ~D) | 
	             (~A & ~B & (C^D));                    // A and B diff, C=D=0 OR A=B=0, C and D diff
	assign L31 = ((A^B) & C & D) | (A & B & (C^D));    // A and B diff, C=D=1 OR A=B=1, C and D diff
	assign L22 = A & B & ~C & ~D |
		         ~A & ~B & C & D |			           // A=B=1,C=D=0 OR A=B=0,C=D=1		
		         (A^B) & (C^D);                        // A,B diff, C,D diff, so 2 1s and 2 0s 
	assign L = {L40, L31, L22, L13, L04}; 
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/05/2021 01:41:36 PM
// Design Name: 
// Module Name: fcn5b6b
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 3B/4B classification or the S function 
//              Figure 4 in Encoder diagram
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fcn3b(
    input clk,
    input [1:0] data_in,  
    input rd_in_s4,
    input [4:0] L,
    output reg S
    );
    wire L13 = L[1];
    wire L31 = L[3];
    wire E, D;
    assign {E, D} = data_in;
    always @(posedge clk)
        S = (rd_in_s4 & L31 & D & ~E) ^ (~rd_in_s4 & L13 & ~D & E);
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/05/2021 11:13:03 AM
// Design Name: 
// Module Name: disCtrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Disparity classifications and control of complementation 
//              Figure 5 and 6 in Encoder diagram
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module disCtrl( 
    input clk,
    input reset,
    input K,
    input [4:0] L,
    input S,
    input [7:0] data_in,
    input rd_in,
    output reg [7:0] saved_data_in,
    output reg [4:0] saved_L,
    output reg saved_K,
    output rd_in_s4,
    output reg COMPLS6,
    output reg COMPLS4,
    output rd_out
    );
    wire L40, L31, L22, L13, L04;
    wire A, B, C, D, E, F, G, H;
    assign {L40, L31, L22, L13, L04} = L;
    assign {H, G, F, E, D, C, B, A} = data_in;
    /* Disparity clarification:
        P,N,S stands for Positive, Negative, Sender
        D1 stands for D-1 (entry running disparity)
        D0 stands for D0  (current running disparity) */
    /* Disparity classification for 5B/6B */
    // If either PD1S6 or ND1S6 is set, then RD6 is changed 
    wire PD1S6, ND0S6, ND1S6, PD0S6, RD6;
    assign PD1S6 = (L13 & D & E) ^ (~L22 & ~L31 & ~E);
    assign ND0S6 = PD1S6;
    assign ND1S6 = (L31 & ~D & ~E) | (E & ~L22 & ~L13) | K;
    assign PD0S6 = (E & ~L22 & ~L13) | K;
    assign RD6 = (PD0S6 | ND0S6);  
    /* Disparity classification for 3B/4B */  
    // If either PD1S5 or ND1S4 is set, then RD4 is changed
    wire ND1S4, ND0S4, PD1S4, PD0S4, RD4; 
    assign ND1S4 = F & G; 
    assign ND0S4 = ~F & ~G; 
    assign PD1S4 = ND0S4 | ((F ^ G) & K);
    assign PD0S4 = F & G & H;
    assign RD4 = (PD0S4 | ND0S4);
    
    /* Control of complementation:
        The complement is set if rd_in's sign does not 
        matched with D1S6 and D1S4 sign                 */
    always @(posedge clk)
    begin 
        if (reset) begin 
           {COMPLS6, COMPLS4} = 3'b100;
           saved_data_in = 8'b0; 
           saved_L = 0;
           saved_K = 0;
        end else begin
            // Disparity of D0S6 is based on the entry running disparity
            // Complement is set when PD1S6 is 1 (expect positive), but rd_in is 0(-) 
            //                     OR ND1S6 is 1 (expect negative), but rd_in is 1(+)
            COMPLS6 <= (PD1S6 & ~rd_in) | (ND1S6 & rd_in);
            // PD1S4 is same, but here, the entry disparity 
            //  will be the out disparity of fcn 5B 
            // Complement is set when PD1S4 is 1 (expect positive), but rd_in is 0(-)
            //                     OR ND1S4 is 1 (expect negative), but rd_in is 1(+)
            COMPLS4 <= ((PD1S4 & ~rd_in_s4) | (ND1S4 & rd_in_s4));
            saved_data_in <= data_in;
            saved_L <= L; 
            saved_K <= K;
        end
    end
    
    /* Assign rd_out for the next input */
    wire rd_cur;
    assign rd_cur = RD6 ^ RD4;         // Running disparity of current input
    assign rd_out = rd_cur ^ rd_in;    // Use running disparity of current input to determine if we
                                //  need to change entry running disparity of the next input.
    assign rd_in_s4 = RD6 ^ rd_in;
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/05/2021 01:41:36 PM
// Design Name: 
// Module Name: fcn5b6b
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Actual transformation of 5 input bits ABCDE into
//                  the 6 abcdei output bits according to given rules
//              Figure 7 in Encoder diagram 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fcn5b6b(
    input clk,  
    input reset,
    input [4:0] data_in,
    input [4:0] L,
    input K,
    input COMPLS6,
    output [5:0] data_out
    );
    wire A, B, C, D, E;
    assign {E, D, C, B, A} = data_in;
    wire L40, L31, L22, L13, L04;
    assign {L40, L31, L22, L13, L04} = L;
    reg a, b, c, d, e, i;
    /* Transformation of 5 input bits ABCDE into the 6 abcdei */
    always @(posedge clk)
    begin    
        if (reset) begin
            a <= 0;
            b <= 0;
            c <= 0;
            d <= 0;
            e <= 0;
            i <= 0;
        end else begin
            a <= A ^ COMPLS6; 
            b <= ((~L40 & B) | L04) ^ COMPLS6;
            c <= (L04 | C) ^ (L13 & D & E) ^ COMPLS6; 
            d <= (D & ~L40) ^ COMPLS6;
            e <= (~(L13 & D & E) & E) ^ (~E & L13) ^ COMPLS6; 
            i <= (~E & L22) ^ (L22 & K) ^ (L04 & E) ^ (E & L40) ^ (E & L13 & ~D) ^ COMPLS6;
        end
    end
    assign data_out = {a, b, c, d, e, i};
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/05/2021 01:41:36 PM
// Design Name: 
// Module Name: fcn5b6b
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Actual transformation of 3 input bits FGH into  
//                  the 4 fghj output bits according to given rules
//              Figure 8 in Encoder diagram 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fcn3b4b(
    input clk, 
    input reset,
    input [2:0] data_in,
    input S,
    input K,
    input COMPLS4,
    output [3:0] data_out
    );
    wire H, G, F;
    assign {H, G, F} = data_in;
    reg f, g, h, j;
    /* Transformation of 3 input bits FGH into the 4 fghj */
    always @(posedge clk)
    begin
        if (reset) begin 
            f <= 0;
            g <= 0;
            h <= 0;
            j <= 0;
        end else begin 
            f <= (F & ~((S & F & G & H) ^ (K & F & G & H))) ^ COMPLS4; 
            g <= (G | (~F & ~G & ~H)) ^ COMPLS4;
            h <= H ^ COMPLS4; 
            j <= (( (S & F & G & H) ^ (F & G & H & K) ) | ((F ^ G) & ~H)) ^ COMPLS4;
        end
    end
    assign data_out = {f, g, h, j};
endmodule
