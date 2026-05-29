// Real-time tanh soft-clip on a 16-bit signed stream (e.g. from AdcReader).
module AnalogTanhDistort #(
    parameter int AMPLITUDE     = 100,  // 0–100 % output scale
    parameter int SHIFT_BITS    = 3,    // width of runtime shift control
    parameter int SMALL_THRES   = 0    // identity region for tiny |input| (signed 16-bit LSBs)
) (
    input  logic clk,
    input  logic reset,
    input  logic distort_en_i,                 // 1 = tanh, 0 = bypass
    input  logic signed [15:0] sample_i,
    input  logic [SHIFT_BITS-1:0] distort_shift_i,

    output logic signed [15:0] in_o,           // input sample (monitor)
    output logic signed [15:0] in_aligned_o,   // input delayed to match tanh latency
    output logic signed [15:0] distorted_o
);

    localparam int WORD_SZ           = 18;
    localparam int TANH_LATENCY      = 1;
    localparam int SOFT_KNEE_1       = 16'sd8192;
    localparam int SOFT_KNEE_2       = 16'sd16384;
    localparam int SOFT_KNEE_3       = 16'sd24576;

    logic [SHIFT_BITS-1:0] shift_amt;
    logic signed [WORD_SZ-1:0] driven;
    logic signed [15:0] driven_sat;
    logic signed [15:0] clipped_sample;
    logic signed [15:0] renorm_sample;

    function automatic logic signed [15:0] sat_to_i16(input logic signed [WORD_SZ-1:0] value_i);
        localparam logic signed [WORD_SZ-1:0] MAX_I16 = (WORD_SZ'(1) <<< 15) - 1;
        localparam logic signed [WORD_SZ-1:0] MIN_I16 = -(WORD_SZ'(1) <<< 15);
        begin
            if (value_i > MAX_I16)
                sat_to_i16 = 16'sd32767;
            else if (value_i < MIN_I16)
                sat_to_i16 = -16'sd32768;
            else
                sat_to_i16 = value_i[15:0];
        end
    endfunction

    function automatic logic signed [15:0] soft_clip_i16(input logic signed [15:0] x_i);
        logic sign_i;
        logic [15:0] abs_i;
        logic [16:0] y_abs;
        begin
            sign_i = x_i[15];
            abs_i = sign_i ? $unsigned(-x_i) : $unsigned(x_i);

            if (abs_i <= SOFT_KNEE_1[15:0]) begin
                y_abs = {1'b0, abs_i};
            end else if (abs_i <= SOFT_KNEE_2[15:0]) begin
                y_abs = SOFT_KNEE_1 + (({1'b0, abs_i} - SOFT_KNEE_1) >>> 1);
            end else if (abs_i <= SOFT_KNEE_3[15:0]) begin
                y_abs = 16'sd12288 + (({1'b0, abs_i} - SOFT_KNEE_2) >>> 2);
            end else begin
                y_abs = 16'sd14336 + (({1'b0, abs_i} - SOFT_KNEE_3) >>> 3);
            end

            if (y_abs > 17'd32767)
                soft_clip_i16 = sign_i ? -16'sd32767 : 16'sd32767;
            else
                soft_clip_i16 = sign_i ? -$signed({1'b0, y_abs[15:0]}) : $signed({1'b0, y_abs[15:0]});
        end
    endfunction

    always_comb begin
        shift_amt = distort_shift_i;
        driven    = {{(WORD_SZ-16){sample_i[15]}}, sample_i};
        if (shift_amt > 0)
            driven = driven <<< shift_amt;
    end

    localparam logic [WORD_SZ-1:0] OUT_GAIN = WORD_SZ'((AMPLITUDE * 256) / 100);
    logic signed [2*WORD_SZ-1:0] scaled;
    logic signed [WORD_SZ-1:0] amp_scaled;
    logic signed [15:0] tanh_sample;
    logic signed [15:0] linear_or_tanh_sample;
    logic [15:0] abs_in_aligned;
    assign driven_sat   = sat_to_i16(driven);
    assign clipped_sample = soft_clip_i16(driven_sat);
    // assign renorm_sample  = (shift_amt > 0) ? (clipped_sample >>> shift_amt) : clipped_sample;
    assign renorm_sample  =  clipped_sample;
    assign scaled       = $signed({{(WORD_SZ-16){renorm_sample[15]}}, renorm_sample}) * $signed(OUT_GAIN);
    assign amp_scaled   = scaled >>> 8;
    assign tanh_sample  = sat_to_i16(amp_scaled);

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
