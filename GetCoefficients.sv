module GetCoefficients #(
        parameter int num_of_bits_coeff        = 24,
        parameter int num_of_fractional_bits   = 21,
        parameter int num_bits_prefactor       = 10
    )
    (
        input logic                                      clk,
        input logic                                      reset,
        input logic                                      tick,

        input  logic unsigned[15:0]                      w0,

        // Must be in range 1...num_bits_prefactor-1
        input  logic unsigned[4:0]                       k,

        output logic signed [num_of_bits_coeff-1:0]      b0,
        output logic signed [num_of_bits_coeff-1:0]      b1,
        output logic signed [num_of_bits_coeff-1:0]      b2,

        output logic signed [num_of_bits_coeff-1:0]      a1,
        output logic signed [num_of_bits_coeff-1:0]      a2
    );

    localparam int num_bits_raw    = num_of_bits_coeff;
    localparam int num_bits_scaled = num_of_bits_coeff + num_bits_prefactor + 1;

    localparam logic signed [num_of_bits_coeff-1:0] one_q21 =
        24'sd1 <<< num_of_fractional_bits;

    logic signed [15:0] cos_q15;
    logic signed [15:0] sin_q15;

    logic signed [num_of_bits_coeff-1:0] cos_q21;

    CordicFSM cordic (
        .clk(clk),
        .reset(reset),
        .tick(tick),
        .angle(w0),

        .x_i(16'sd32767),
        .x_o(cos_q15),
        .y_o(sin_q15)
    );

    // Convert CORDIC Q1.15 to coefficient Q3.21, with CORDIC gain compensation.
    //
    // The CORDIC rotation algorithm has an inherent magnitude gain
    //     K = prod_{i=0..N-1} sqrt(1 + 2^(-2i)) ~ 1.64676
    // for N = 16 iterations. CordicFSM additionally pre-shifts the input by 1
    // (x_init = x_i << 1) and post-shifts the output by 2 (x_o = result.x >>> 2),
    // giving an effective gain of K/2 ~ 0.8234 from x_i to x_o. With x_i = 32767
    // (+1.0 in Q15), the peak |cos_q15| is therefore ~26988, not 32767, i.e.
    //     cos_q15 ~ (K/2) * cos(angle)   in Q15.
    // Multiplying by 2/K ~ 1.21376 recovers the true cosine.
    //   2/K * 2^14 = 19891 (rounded)  -> Q14 constant
    localparam logic signed [15:0] CORDIC_GAIN_COMP_Q14 = 16'sd19891;

    logic signed [31:0] cos_compensated;
    assign cos_compensated = $signed(cos_q15) * CORDIC_GAIN_COMP_Q14;

    // cos_compensated represents true_cos * 2^(15 + 14) = true_cos * 2^29.
    // For Q21 (true_cos * 2^21) we shift right by 8.
    assign cos_q21 = cos_compensated >>> 8;

    logic [num_bits_prefactor-1:0] prefactor;
    logic [num_bits_prefactor-1:0] a2_numerator;

    always_comb begin
        if (k == 0) begin
            prefactor    = '0;
            a2_numerator = '0;
        end else if (k >= num_bits_prefactor) begin
            prefactor    = '1;
            a2_numerator = '1 - 1'b1;
        end else begin
            prefactor    = (10'd1 << k) - 10'd1;
            a2_numerator = (10'd1 << k) - 10'd2;
        end
    end

    logic signed [num_bits_raw-1:0] b0_raw;
    logic signed [num_bits_raw-1:0] b1_raw;
    logic signed [num_bits_raw-1:0] b2_raw;
    logic signed [num_bits_raw-1:0] a1_raw;

    always_comb begin
        b0_raw = (one_q21 - cos_q21) >>> 1;
        b1_raw =  one_q21 - cos_q21;
        b2_raw = (one_q21 - cos_q21) >>> 1;
        a1_raw = -(cos_q21 <<< 1);
    end

    logic signed [num_bits_scaled-1:0] b0_scaled;
    logic signed [num_bits_scaled-1:0] b1_scaled;
    logic signed [num_bits_scaled-1:0] b2_scaled;
    logic signed [num_bits_scaled-1:0] a1_scaled;
    logic signed [num_bits_scaled-1:0] a2_scaled;
    logic signed [num_bits_scaled-1:0] a2_numerator_extended;

    always_comb begin
        b0_scaled = $signed(b0_raw) * $signed({1'b0, prefactor});
        b1_scaled = $signed(b1_raw) * $signed({1'b0, prefactor});
        b2_scaled = $signed(b2_raw) * $signed({1'b0, prefactor});
        a1_scaled = $signed(a1_raw) * $signed({1'b0, prefactor});

        a2_numerator_extended = {
            {(num_bits_scaled-(num_bits_prefactor+1)){1'b0}},
            1'b0,
            a2_numerator
        };

        a2_scaled = a2_numerator_extended <<< num_of_fractional_bits;

        b0 = $signed(b0_scaled >>> k);
        b1 = $signed(b1_scaled >>> k);
        b2 = $signed(b2_scaled >>> k);
        a1 = $signed(a1_scaled >>> k);
        a2 = $signed(a2_scaled >>> k);
    end

endmodule