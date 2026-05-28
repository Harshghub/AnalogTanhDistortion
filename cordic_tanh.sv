module cordic #(
    parameter int word_SZ = 18,
    parameter int frac_SZ = 16
) (
    input  logic signed [word_SZ-1:0] angle,
    input  logic                     clk,
    output logic signed [word_SZ-1:0] out
);
    logic signed [word_SZ-1:0] x;
    logic signed [word_SZ-1:0] y;

    Cordic_hyp #(
        .word_SZ(word_SZ),
        .frac_SZ(frac_SZ)
    ) cordic_hyp (
        .z_in (angle),
        .clk  (clk),
        .x_out(x),
        .y_out(y)
    );

    CORDIC_Div #(
        .word_SZ(word_SZ),
        .frac_SZ(frac_SZ)
    ) cordic_div (
        .y_in (y),
        .x_in (x),
        .clk  (clk),
        .z_out(out)
    );
endmodule

module Cordic_hyp #(
    parameter int word_SZ = 18,
    parameter int frac_SZ = 16
) (
    input  logic signed [word_SZ-1:0] z_in,
    input  logic                     clk,
    output logic signed [word_SZ-1:0] x_out,
    output logic signed [word_SZ-1:0] y_out
);
    localparam int num_OfStage = frac_SZ;

    logic signed [word_SZ-1:0] x_stage_Out [num_OfStage];
    logic signed [word_SZ-1:0] y_stage_Out [num_OfStage];
    logic signed [word_SZ-1:0] z_stage_Out [num_OfStage];

    logic signed [word_SZ-1:0] x_in;
    logic signed [word_SZ-1:0] y_in;
    assign y_in = '0;
    assign x_in = word_SZ'(18'b010011010100011111);

    logic signed [word_SZ-1:0] atan_table [0:30];

    assign atan_table[00] = 18'b001000110010011111;
    assign atan_table[01] = 18'b000100000101100011;
    assign atan_table[02] = 18'b000010000000101011;
    assign atan_table[03] = 18'b000001000000000101;
    assign atan_table[04] = 18'b000000100000000001;
    assign atan_table[05] = 18'b000000010000000000;
    assign atan_table[06] = 18'b000000001000000000;
    assign atan_table[07] = 18'b000000000100000000;
    assign atan_table[08] = 18'b000000000010000000;
    assign atan_table[09] = 18'b000000000001000000;
    assign atan_table[10] = 18'b000000000000100000;
    assign atan_table[11] = 18'b000000000000010000;
    assign atan_table[12] = 18'b000000000000001000;
    assign atan_table[13] = 18'b000000000000000100;
    assign atan_table[14] = 18'b000000000000000010;
    assign atan_table[15] = 18'b000000000000000001;
    assign atan_table[16] = 18'b000000000000000001;
    assign atan_table[17] = 18'b000000000000000000;

    Cordic_SubSection #(
        .word_SZ(word_SZ),
        .frac_SZ(frac_SZ),
        .stage  (0)
    ) subCore (
        .x_in  (x_in),
        .y_in  (y_in),
        .z_in  (z_in),
        .arcTan(atan_table[0]),
        .clk   (clk),
        .x_out (x_stage_Out[0]),
        .y_out (y_stage_Out[0]),
        .z_out (z_stage_Out[0])
    );

    genvar i;
    generate
        for (i = 1; i < num_OfStage; i++) begin : XYZ
            Cordic_SubSection #(
                .word_SZ(word_SZ),
                .frac_SZ(frac_SZ),
                .stage  (i)
            ) subCore (
                .x_in  (x_stage_Out[i - 1]),
                .y_in  (y_stage_Out[i - 1]),
                .z_in  (z_stage_Out[i - 1]),
                .arcTan(atan_table[i]),
                .clk   (clk),
                .x_out (x_stage_Out[i]),
                .y_out (y_stage_Out[i]),
                .z_out (z_stage_Out[i])
            );
        end
    endgenerate

    assign x_out = x_stage_Out[num_OfStage - 1];
    assign y_out = y_stage_Out[num_OfStage - 1];
endmodule

module Cordic_SubSection #(
    parameter int word_SZ = 18,
    parameter int frac_SZ = 16,
    parameter int stage   = 0
) (
    input  logic signed [word_SZ-1:0] y_in,
    input  logic signed [word_SZ-1:0] x_in,
    input  logic signed [word_SZ-1:0] z_in,
    input  logic signed [word_SZ-1:0] arcTan,
    input  logic                     clk,
    output logic signed [word_SZ-1:0] x_out,
    output logic signed [word_SZ-1:0] y_out,
    output logic signed [word_SZ-1:0] z_out
);
    logic z_sign;
    assign z_sign = z_in[word_SZ - 1];

    logic signed [word_SZ-1:0] x_shifted;
    logic signed [word_SZ-1:0] y_shifted;
    assign x_shifted = x_in >>> (stage + 1);
    assign y_shifted = y_in >>> (stage + 1);

    always_ff @(posedge clk) begin
        x_out <= z_sign ? x_in - y_shifted : x_in + y_shifted;
        y_out <= z_sign ? y_in - x_shifted : y_in + x_shifted;
        z_out <= z_sign ? z_in + arcTan   : z_in - arcTan;
    end
endmodule

module CORDIC_Div #(
    parameter int word_SZ = 18,
    parameter int frac_SZ = 16
) (
    input  logic signed [word_SZ-1:0] y_in,
    input  logic signed [word_SZ-1:0] x_in,
    input  logic                     clk,
    output logic signed [word_SZ-1:0] z_out
);
    localparam int num_OfStage = word_SZ - 1;

    logic signed [word_SZ-1:0] y_stage_Out [num_OfStage];
    logic signed [word_SZ-1:0] z_stage_Out [num_OfStage];

    logic signed [word_SZ-1:0] z_in;
    assign z_in = '0;

    CorDIC_Div_SubSection #(
        .word_SZ(word_SZ),
        .frac_SZ(frac_SZ),
        .stage  (0)
    ) subDiv (
        .x_in (x_in),
        .y_in (y_in),
        .z_in (z_in),
        .clk  (clk),
        .z_out(z_stage_Out[0]),
        .y_out(y_stage_Out[0])
    );

    genvar i;
    generate
        for (i = 1; i < num_OfStage; i++) begin : XYZ
            CorDIC_Div_SubSection #(
                .word_SZ(word_SZ),
                .frac_SZ(frac_SZ),
                .stage  (i)
            ) subDiv (
                .x_in (x_in),
                .y_in (y_stage_Out[i - 1]),
                .z_in (z_stage_Out[i - 1]),
                .clk  (clk),
                .z_out(z_stage_Out[i]),
                .y_out(y_stage_Out[i])
            );
        end
    endgenerate

    assign z_out = z_stage_Out[num_OfStage - 1];
endmodule

module CorDIC_Div_SubSection #(
    parameter int word_SZ = 18,
    parameter int frac_SZ = 16,
    parameter int stage   = 0
) (
    input  logic signed [word_SZ-1:0] y_in,
    input  logic signed [word_SZ-1:0] x_in,
    input  logic signed [word_SZ-1:0] z_in,
    input  logic                     clk,
    output logic signed [word_SZ-1:0] z_out,
    output logic signed [word_SZ-1:0] y_out
);
    logic y_sign;
    assign y_sign = y_in[word_SZ - 1];

    logic signed [word_SZ-1:0] x_shifted;
    assign x_shifted = x_in >>> stage;

    localparam int firstZero = stage + 1;
    localparam int lastZero  = frac_SZ - stage;
    logic signed [word_SZ-1:0] z_shifted;
    assign z_shifted = {{firstZero{1'b0}}, 1'b1, {lastZero{1'b0}}};

    always_ff @(posedge clk) begin
        y_out <= y_sign ? y_in + x_shifted : y_in - x_shifted;
        z_out <= y_sign ? z_in - z_shifted : z_in + z_shifted;
    end
endmodule
