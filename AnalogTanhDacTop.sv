// FPGA top: AdcReader -> AnalogTanhDistort -> DacWriter (Arduino ADC/DAC shield).
// Pin wiring matches AdcDac.sv.
module AnalogTanhDacTop #(
    parameter int AMPLITUDE     = 100,
    parameter int DAC_TICK_DIV  = 50    // 50 MHz / 50 = 1 MHz sample rate
) (
    input         MAX10_CLK1_50,
    input  [1:0]  KEY,
    input  [9:0]  SW,
    inout  [9:0]  ARDUINO_IO
);

    logic              clk;
    logic              reset;
    logic              sample_tick;
    logic              distort_en_i;
    logic              key1_sync;
    logic              key1_prev;

    logic signed [15:0] adc_data;
    logic signed [15:0] in_o;
    logic signed [15:0] in_aligned_o;
    logic signed [15:0] distorted_o;
    logic signed [15:0] amplified_o;
    logic signed [15:0] dac_data;

    logic adc_clk;
    logic adc_mosi;
    logic adc_cnv;
    logic adc_miso;

    logic dac_clk;
    logic dac_mosi;
    logic dac_cs;
    logic dac_reset_n;

    assign clk   = MAX10_CLK1_50;
    assign reset = !KEY[0];

    // KEY[1] (active-low): each press toggles tanh distortion on/off
    always_ff @(posedge clk) begin
        if (reset) begin
            distort_en_i <= 1'b1;
            key1_sync    <= 1'b1;
            key1_prev    <= 1'b1;
        end else begin
            key1_sync <= KEY[1];
            key1_prev <= key1_sync;
            if (key1_sync == 1'b0 && key1_prev == 1'b1)
                distort_en_i <= ~distort_en_i;
        end
    end

    TickGen #(
        .DIVIDER(DAC_TICK_DIV)
    ) sample_tick_gen (
        .clk_i   (clk),
        .reset_i (reset),
        .tick_o  (sample_tick)
    );

    AdcReader adc_reader (
        .clk_i       (clk),
        .reset_i     (reset),
        .start_i     (sample_tick),
        .data_o      (adc_data),
        .spi_clk_o   (adc_clk),
        .spi_mosi_o  (adc_mosi),
        .cnv_o       (adc_cnv),
        .spi_miso_i  (adc_miso),
        .is_idle_o   ()
    );

    AnalogTanhDistort #(
        .AMPLITUDE     (AMPLITUDE)
    ) tanh_path (
        .clk           (clk),
        .reset         (reset),
        .distort_en_i  (distort_en_i),
        .sample_i      (adc_data),
        .distort_shift_i(SW[2:0]),
        .in_o          (in_o),
        .in_aligned_o  (in_aligned_o),
        .distorted_o   (distorted_o)
    );

    // SW[4:3] applies post-distortion output gain as a left shift (0..3 bits).
    // Overflow is intentionally not clamped (wraparound/truncation is allowed).
    assign amplified_o = distorted_o <<< SW[4:3];
    assign dac_data    = amplified_o;

    DacWriter dac_writer (
        .clk_i         (clk),
        .reset_i       (reset),
        .start_i       (sample_tick),
        .data_i        (dac_data),
        .spi_clk_o     (dac_clk),
        .spi_mosi_o    (dac_mosi),
        .spi_cs_o      (dac_cs),
        .dac_reset_no  (dac_reset_n),
        .is_idle_o     ()
    );

    assign ARDUINO_IO[0] = dac_cs;
    assign ARDUINO_IO[1] = dac_clk;
    assign ARDUINO_IO[2] = dac_mosi;
    assign ARDUINO_IO[3] = dac_reset_n;

    assign ARDUINO_IO[4] = adc_cnv;
    assign ARDUINO_IO[5] = adc_clk;
    assign ARDUINO_IO[6] = adc_mosi;
    assign adc_miso      = ARDUINO_IO[7];

endmodule
