// Real-time tanh soft-clip on a 16-bit signed stream (e.g. from AdcReader).
module AnalogTanhDistort #(
    parameter int AMPLITUDE     = 100,  // 0–100 % output scale
    parameter int DISTORT_SHIFT = 2,    // extra drive into tanh (0 = mild, 2+ = heavy clip)
    parameter int SMALL_THRES   = 200    // identity region for tiny |input| (signed 16-bit LSBs)
) (
    input  logic clk,
    input  logic reset,
    input  logic distort_en_i,                 // 1 = tanh, 0 = bypass
    input  logic signed [15:0] sample_i,

    output logic signed [15:0] in_o,           // input sample (monitor)
    output logic signed [15:0] in_aligned_o,   // input delayed to match tanh latency
    output logic signed [15:0] distorted_o
);

    localparam int WORD_SZ      = 18;
    localparam int FRAC_SZ      = 16;
    localparam int TANH_LATENCY = FRAC_SZ + (WORD_SZ - 1);

    logic signed [WORD_SZ-1:0] angle_in;
    logic signed [WORD_SZ-1:0] tanh_out;

    always_comb begin
        angle_in = {{2{sample_i[15]}}, sample_i};
        if (DISTORT_SHIFT > 0)
            angle_in = angle_in <<< DISTORT_SHIFT;
    end

    cordic #(
        .word_SZ(WORD_SZ),
        .frac_SZ(FRAC_SZ)
    ) tanh_distort (
        .angle(angle_in),
        .clk  (clk),
        .out  (tanh_out)
    );

    localparam logic [WORD_SZ-1:0] OUT_GAIN = WORD_SZ'((65536 * AMPLITUDE) / 100);
    logic signed [2*WORD_SZ-1:0] scaled;
    logic signed [15:0] tanh_sample;
    logic signed [15:0] linear_or_tanh_sample;
    logic [15:0] abs_in_aligned;
    assign scaled      = tanh_out * $signed(OUT_GAIN);
    assign tanh_sample = scaled[2*WORD_SZ-1:WORD_SZ];

    logic signed [15:0] delay_pipe [TANH_LATENCY];

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < TANH_LATENCY; i++)
                delay_pipe[i] <= 16'sd0;
        end else begin
            delay_pipe[0] <= sample_i;
            for (int i = 1; i < TANH_LATENCY; i++)
                delay_pipe[i] <= delay_pipe[i - 1];
        end
    end

    assign abs_in_aligned = in_aligned_o[15] ? $unsigned(-in_aligned_o) : $unsigned(in_aligned_o);
    assign linear_or_tanh_sample = (abs_in_aligned <= SMALL_THRES) ? in_aligned_o : tanh_sample;
    assign distorted_o = distort_en_i ? linear_or_tanh_sample : sample_i;

    assign in_o         = sample_i;
    assign in_aligned_o = delay_pipe[TANH_LATENCY - 1];

endmodule
