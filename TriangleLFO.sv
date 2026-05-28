module TriangleLFO #(
        parameter int num_of_bits_w0 = 16,

        parameter logic [num_of_bits_w0-1:0] w0_min = 16'd328,
        parameter logic [num_of_bits_w0-1:0] w0_max = 16'd1311,

        parameter logic [num_of_bits_w0-1:0] step = 16'd1,

        // Update the LFO once every tick_divider input ticks.
        // 100 means 100x slower.
        parameter int tick_divider = 100
    )
    (
        input  logic                         clk_i,
        input  logic                         reset_i,
        input  logic                         tick_i,

        output logic [num_of_bits_w0-1:0]    w0_o
    );

    localparam int num_of_bits_counter = $clog2(tick_divider);

    logic [num_of_bits_counter-1:0] tick_counter;
    logic direction_up;

    logic lfo_tick;

    always_comb begin
        lfo_tick = 1'b0;

        if (tick_i == 1'b1 && tick_counter == tick_divider-1) begin
            lfo_tick = 1'b1;
        end
    end

    always_ff @(posedge clk_i) begin
        if (reset_i == 1'b1) begin
            tick_counter <= '0;
            w0_o         <= w0_min;
            direction_up <= 1'b1;

        end else if (tick_i == 1'b1) begin

            if (tick_counter == tick_divider-1) begin
                tick_counter <= '0;

                if (direction_up == 1'b1) begin
                    if (w0_o + step >= w0_max) begin
                        w0_o         <= w0_max;
                        direction_up <= 1'b0;
                    end else begin
                        w0_o         <= w0_o + step;
                    end
                end else begin
                    if (w0_o <= w0_min + step) begin
                        w0_o         <= w0_min;
                        direction_up <= 1'b1;
                    end else begin
                        w0_o         <= w0_o - step;
                    end
                end

            end else begin
                tick_counter <= tick_counter + 1'b1;
            end
        end
    end

endmodule