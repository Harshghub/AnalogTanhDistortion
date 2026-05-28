/**
  Direct Form I biquad IIR filter

  Implements:

      y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]

  Coefficients are input signals, so they can be changed during runtime.

  Coefficients are signed fixed-point values with num_of_fractional_bits
  fractional bits.

  With the default settings:

      num_of_bits_coeff      = 24
      num_of_fractional_bits = 21

  Therefore:

      1.0  ->  2**21
      0.5  ->  2**20
     -0.5  -> -2**20

  Default coefficient format is effectively signed 24-bit with 21 fractional
  bits, giving a range of approximately -4.0 to +3.9999995.
**/
module BiquadIIR #(
        parameter int num_of_bits_io                    = 16,
        parameter int num_of_bits_coeff                 = 24,
        parameter int num_of_fractional_bits            = 21,
        parameter int num_of_bits_internal              = 28,
        parameter int num_of_fractional_bits_internal   = 8
    )
    (
        input logic                                      clk_i,
        input logic                                      reset_i,
        input logic                                      tick_i,

        input  logic signed [num_of_bits_io-1:0]         signal_i,
        output logic signed [num_of_bits_io-1:0]         signal_o,

        input  logic signed [num_of_bits_coeff-1:0]      b0,
        input  logic signed [num_of_bits_coeff-1:0]      b1,
        input  logic signed [num_of_bits_coeff-1:0]      b2,

        input  logic signed [num_of_bits_coeff-1:0]      a1,
        input  logic signed [num_of_bits_coeff-1:0]      a2
    );

    // CONSTANTS
    localparam int num_of_bits_product = num_of_bits_internal + num_of_bits_coeff;
    localparam int num_of_bits_sum     = num_of_bits_product + 4;

    localparam logic signed [num_of_bits_internal-1:0] max_output_internal =
        {{(num_of_bits_internal-num_of_bits_io){1'b0}},
         1'b0, {(num_of_bits_io-1){1'b1}}};

    localparam logic signed [num_of_bits_internal-1:0] min_output_internal =
        {{(num_of_bits_internal-num_of_bits_io){1'b1}},
         1'b1, {(num_of_bits_io-1){1'b0}}};

    // INTERNAL SIGNALS

    logic signed [num_of_bits_internal-1:0] signal_i_extended;

    // input samples, stored with internal fractional bits:
    logic signed [num_of_bits_internal-1:0] x_curr;
    logic signed [num_of_bits_internal-1:0] x_prev;
    logic signed [num_of_bits_internal-1:0] x_prev_prev;

    // output samples, stored with internal fractional bits:
    logic signed [num_of_bits_internal-1:0] y_curr;
    logic signed [num_of_bits_internal-1:0] y_prev;
    logic signed [num_of_bits_internal-1:0] y_prev_prev;

    // multiplication results:
    logic signed [num_of_bits_product-1:0] prod_b0;
    logic signed [num_of_bits_product-1:0] prod_b1;
    logic signed [num_of_bits_product-1:0] prod_b2;
    logic signed [num_of_bits_product-1:0] prod_a1;
    logic signed [num_of_bits_product-1:0] prod_a2;

    // sum:
    logic signed [num_of_bits_sum-1:0] sum;
    logic signed [num_of_bits_sum-1:0] y_shifted;

    // output conversion:
    logic signed [num_of_bits_internal-1:0] y_output_unscaled;
    logic signed [num_of_bits_io-1:0]       y_curr_clamped;

    // Sign-extend input to internal width first.
    assign signal_i_extended = {
        {(num_of_bits_internal-num_of_bits_io){signal_i[num_of_bits_io-1]}},
        signal_i
    };

    // Convert 16-bit integer input to internal fixed-point format.
    assign x_curr = signal_i_extended <<< num_of_fractional_bits_internal;

    always_comb begin
        prod_b0 = x_curr      * b0;
        prod_b1 = x_prev      * b1;
        prod_b2 = x_prev_prev * b2;

        prod_a1 = y_prev      * a1;
        prod_a2 = y_prev_prev * a2;

        sum = $signed(prod_b0);
        sum = sum + $signed(prod_b1);
        sum = sum + $signed(prod_b2);
        sum = sum - $signed(prod_a1);
        sum = sum - $signed(prod_a2);

        // Remove coefficient fractional bits.
        // Internal fractional bits remain.
        y_shifted = sum >>> num_of_fractional_bits;

        // Store full internal fixed-point value.
        // This assumes num_of_bits_internal has enough headroom.
        y_curr = y_shifted[num_of_bits_internal-1:0];

        // Convert internal fixed-point back to ordinary 16-bit-style scale.
        y_output_unscaled = y_curr >>> num_of_fractional_bits_internal;

        // Saturate only the external output.
        if (y_output_unscaled > max_output_internal) begin
            y_curr_clamped = {1'b0, {(num_of_bits_io-1){1'b1}}};
        end else if (y_output_unscaled < min_output_internal) begin
            y_curr_clamped = {1'b1, {(num_of_bits_io-1){1'b0}}};
        end else begin
            y_curr_clamped = y_output_unscaled[num_of_bits_io-1:0];
        end
    end

    always_ff @(posedge clk_i) begin
        if (reset_i == 1) begin
            x_prev      <= 0;
            x_prev_prev <= 0;

            y_prev      <= 0;
            y_prev_prev <= 0;

            signal_o    <= 0;

        end else if (tick_i == 1) begin
            x_prev_prev <= x_prev;
            x_prev      <= x_curr;

            y_prev_prev <= y_prev;
            y_prev      <= y_curr;

            signal_o    <= y_curr_clamped;
        end
    end
endmodule