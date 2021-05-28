`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/12/2021 11:01:16 AM
// Design Name: 
// Module Name: Dec8B10B
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


module Dec8B10B(
    input BYTECLK, 
    input reset,
    input [9:0] in,
    output reg rdispout,
    output reg disp_err,
    output reg code_err,
    output reg k_out,
    output reg [7:0] out
    );
    
    // Variable to hold values 
    wire clk = BYTECLK; 
    wire [4:0] EDCBA;
    wire [3:0] KHGF, D;
    wire [2:0] P;
    wire rd_out, rd_error, in_error;
    
    reg [9:0] data_in;
    reg rd_in;
    
    fcn6b   f6b(clk, reset, data_in[9:4], P);
    inCheck err(clk, reset, data_in, P, D, in_error); 
    fcn6b5b f65(clk, reset, data_in[9:4], P, EDCBA);
    fcn4b3b f43(clk, reset, data_in[7:0], P, KHGF);
    disCtr2 dis(clk, reset, data_in, rd_in, P, D, rd_out, rd_error);
    
    always @(posedge clk)
    begin
        if (reset) begin 
            data_in = 0;
            rd_in = 0;
        end else begin
            rd_in = rd_out; 
            data_in = in;
        end
    end
    
    always @(posedge clk)
    begin
        if (reset) begin 
            out <= 8'b0;
            k_out <= 0;
            disp_err <= 0;
            code_err <= 0;
            rdispout <= 0;
        end else begin 
            out <= {KHGF[2:0], EDCBA};
            k_out <= KHGF[3];
            rdispout <= rd_out;
            // If there is error from input, set 1 to code_err, ignore the result
            if (in_error)   code_err <= 1;
            else            code_err <= 0;
            // If there is disparity error, set 1 to disp_err, still give out result
            if (rd_error)   disp_err <= 1;
            else            disp_err <= 0;
        end
    end
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/12/2021 11:24:15 AM
// Design Name: 
// Module Name: fcn6b
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


module fcn6b(
    input clk, 
    input reset,
    input [5:0] data_in,
    output [2:0] P
    );
    
    wire a, b, c, d, e, i, P13, P22, P31;
    assign {a, b, c, d, e, i} = data_in;
    
    assign P13 = ((a^b) & ~c & ~d) | 
                 (~a & ~b & (c^d)) ;                // a and b diff, c=d=0 OR a=b=0, c and d diff
    assign P31 = ((a^b) & c & d) | (a & b & (c^d)); // a and b diff, c=d=1 OR a=b=1, c and d diff 
    assign P22 = (a & b & ~c & ~d) |
                 (c & d & ~a & ~b) |                  // a=b=1, c=d=0 OR a=b=0, c=d=1
                 ((a^b) & (c^d)) ;                    // a,b diff, c,d diff, so 2 1s and 2 0s         
     assign P = {P13, P22, P31};
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/13/2021 09:32:19 AM
// Design Name: 
// Module Name: inCheck
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


module inCheck(
    input clk, 
    input reset,
    input [9:0] data_in,
    input [2:0] P,
    input [3:0] D,
    output in_error
    );
    
    wire a, b, c, d, e, i, f, g, h, j;
    assign {a, b, c, d, e, i, f, g, h, j} = data_in;
    wire P13, P22, P31, PD0S6, ND0S6, PD0S4, ND0S4; 
    assign {P13, P22, P31} = P;
    assign {PD0S6, ND0S6, PD0S4, ND0S4} = D;
    
    // All invalid input cases
    reg case1, case2, case3, case4, case5, case6, case7, case8, case9; 
    always @(posedge clk) 
    begin
        // These cover all +6, +4 disparity cases in 6B/5B
        case1 = (a & b & c & d) | (~a & ~b & ~c & ~d) | (P13 & ~e & ~i) | (P31 & e & i);
        // These cover all +4 disparity cases in 4B/3B
        case2 = (f & g & h & j) | (~f & ~g & ~h & ~j);
        // These cover all cases of run-length 6 (D.7)
        case3 = (a & b & c & ~d & ~e & ~i & ND0S4) | (~a & ~b & ~c & d & e & i & PD0S4);
        // These cover all cases of run-length 6 (D.x.3)
        case4 = (f & g & ~h & ~j & PD0S6) | (~f & ~g & h & j & ND0S6);
        // These cover all cases of run-length 5
        case5 = (e & i & f & g & h) | (~e & ~i & ~f & ~g & ~h) | 
                (d & e & i & f & g) | (~d & ~e & ~i & ~f & ~g) ;
        // These cover all anti-case of run-length 5
        case6 = (i & ~e & ~g & ~h & ~j) | (~i & e & g & h & j);
        // These are the 2 samples that are not covered by equations
        case7 = (~a & ~b & c & d & e & i & ~f & ~g & ~h & j) |
                (a & b & ~c & ~d & ~e & ~i & f & g & h & ~j) ;
        // Do not know why but it is what it is 
        case8 = ((e & i & ~g & ~h & ~j) & ((c ^ d) | (d ^ e))) |
                ((~e & ~i & g & h & j) & ((c ^ d) | (d ^ e))) |
                (~P31 & e & ~i & ~g & ~h & ~j) | (~P13 & ~e & i & g & h & j) ;
        // These cover all cases +4 or -4 total disparity
        case9 = (PD0S6 & PD0S4) | (ND0S6 & ND0S4) ;
    end
    
    assign in_error = case1 | case2 | case3 | case4 | case5 
                    | case6 | case7 | case8 | case9;
endmodule   


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/12/2021 11:14:26 AM
// Design Name: 
// Module Name: fcn6b5b
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


module fcn6b5b(
    input clk, 
    input reset,
    input [5:0] data_in,
    input [2:0] P,
    output [4:0] EDCBA
    );
    
    wire a, b, c, d, e, i;
    assign {a, b, c, d, e, i} = data_in;
    wire P13, P22, P31; 
    assign {P13, P22, P31} = P;
    reg A, B, C, D, E;
    
    always @(posedge clk)
    begin
        A = a ^ ((P22 & ~b & ~c & ~(e^i)) |
                (P31 & i)               |
                (P13 & d & e & i)       |
                (P22 & ~a & ~c & ~(e^i))|
                (P13 & ~e)              |
                (a & b & e & i)         |
                (~c & ~d & ~e & ~i));
        B = b ^ (((a & b & e & i) | ~(c | d | e | i) | (P31 & i))
              ^ ((P22 & a & c & ~(e ^ i)) | (P13 & ~e))
              ^ ((P22 & b & c & ~(e ^ i)) | (P13 & d & e & i)));
        C = c ^ (((P31 & i) | (P22 & b & c & ~(e ^ i)) | (P13 & d & e & i))
              | ((P22 & ~a & ~c & ~(e ^ i)) | (P13 & ~e))
              | ((P13 & ~e) | ~(c | d | e | i) | ~(a | b | e | i)));
        D = d ^ (((a & b & e & i) | ~(c | d | e | i) | (P31 & i))
              ^ ((P22 & a & c & ~(e ^ i)) | (P13 & ~e))
              ^ ((P13 & d & e & i) | (P22 & ~b & ~c & ~(e ^ i))));
        E = e ^ (((P22 & ~a & ~c & ~(e ^ i)) | (P13 & ~i))
              ^ ((P13 & ~e) | ~(c | d | e | i) | ~(a | b | e | i))
              ^ ((P13 & d & e & i) | (P22 & ~b & ~c & ~(e ^ i))));
    end
                 
    assign EDCBA = {E, D, C, B, A};
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/12/2021 11:14:26 AM
// Design Name: 
// Module Name: fcn4b3b
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


module fcn4b3b(
    input clk, 
    input reset,
    input [7:0] data_in,
    input [2:0] P,
    output [3:0] KHGF
    );
    
    wire c, d, e, i, f, g, h, j;
    assign {c, d, e, i, f, g, h, j} = data_in;
    wire P13, P22, P31; 
    assign {P13, P22, P31} = P;
    reg K, F, G, H;
    
    always @(posedge clk)
    begin
        F = f ^ (((g & h & j) | (f & h & j) | ((h ^ j) & ~(c | d | e | i)))
              ^ ((f & g & j) | ~(f | g | h) | (~f & ~g & h & j)));
        G = g ^ (((f & g & j) | ~(f | g | h) | (~f & ~g & h & j))
              ^ ((~f & ~h & ~j) | ((h ^ j) & ~(c | d | e | i)) | (~g & ~h & ~j)));
        H = h ^ (((f & g & j) | ~(f | g | h) | (~f & ~g & h & j))
              ^ ((~g & ~h & ~j) | (f & h & j) | ((h ^ j) & ~(c | d | e | i))));
        K = ((c & d & e & i) | (~c & ~d & ~e & ~i)) ^
            (~e & i & g & h & j & P13) ^ (e & ~i & ~g & ~h & ~j & P31);  
    end
    
    assign KHGF = {K, H, G, F};
endmodule


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/12/2021 03:47:10 PM
// Design Name: 
// Module Name: disCtrl
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


module disCtr2(
    input clk, 
    input reset,
    input [9:0] data_in,
    input rd_in,
    input [2:0] P,
    output [3:0] D,
    output reg rd_out,
    output reg rd_error
    );
    
    wire a, b, c, d, e, i, f, g, h, j;
    assign {a, b, c, d, e, i, f, g, h, j} = data_in;
    wire P13, P22, P31;
    assign {P13, P22, P31} = P;
    
    /* Disparity check for 6B/5B */
    // If either PD1S6 or ND1S6 is set, then RD6 is changed 
    wire PD1S6, ND0S6, ND1S6, PD0S6, RD6;
    assign PD1S6 = (P22 & ~e & ~i) | (P13 & ~i) | (P13 & d & e & i) | (P13 & ~e);
    assign ND1S6 = (P22 & e & i) | (P31 & i) | (P31 & ~d & ~e & ~i) | (P31 & e);
    assign PD0S6 = (P22 & e & i) | (P31 & i) | (P31 & e);
    assign ND0S6 = (P22 & ~e & ~i) | (P13 & ~i) | (P13 & ~e);
    assign RD6 = (PD0S6 | ND0S6);  
    /* Disparity check for 4B/3B */  
    // If either PD1S5 or ND1S4 is set, then RD4 is changed
    wire ND1S4, ND0S4, PD1S4, PD0S4, RD4, rd_in_s4;
    assign rd_in_s4 = RD6 ^ rd_in; 
    assign PD1S4 = (~f & ~h & ~j) | (~f & ~g & h & j) | (~f & ~g & ~j) |
                   (~f & ~g & ~h) | (~g & ~h & ~j) ;
    assign ND1S4 = (f & h & j) | (f & g & ~h & ~j) | (f & g & j) | 
                   (f & g & h) | (g & h & j) ;
    assign PD0S4 = (f & h & j) | (f & g & j) | (f & g & h) | (g & h & j);
    assign ND0S4 = (~f & ~h & ~j) |  (~f & ~g & ~j) | 
                   (~f & ~g & ~h) | (~g & ~h & ~j) ;
    assign RD4 = (PD0S4 | ND0S4);
    /* Disparity checking for error */
    always @(posedge clk) 
    begin
        if (reset) rd_error = 0;
        else
        rd_error <= (rd_in & PD0S6)       |   // rd_in is +, but dis of 6B/5B is +2
                    (~rd_in & ND0S6)      |   // rd_in is -, but dis of 6B/5B is -2
                    (rd_in_s4 & PD0S4)    |   // rd_in_s4 is +, but dis of 4B/3B is +2
                    (~rd_in_s4 & ND0S4)   ;   // rd_in_s4 is -, but dis of 4B/3B is -2   
    end
    /* Running disparity of the end */
    wire rd_cur;
    assign rd_cur = RD6 ^ RD4;          // Running disparity of current input
    always @(posedge clk) 
    begin
        if (reset) rd_out = 0;
        else rd_out <= rd_cur ^ rd_in;  // Use running disparity of current input to determine if we
                                        //  need to change entry running disparity of the next input.
    end
    assign D = {PD0S6, ND0S6, PD0S4, ND0S4};
endmodule
