
// Here we define the inputs / outputs
module Main(
    input  logic         MAX10_CLK1_50,  // 50 MHz clock
    input  logic[1:0]    KEY,            // Buttons
    inout  logic[9:0]    ARDUINO_IO,     // Header pins
    output logic[9:0]    LEDR,           // LEDs
    input  logic[9:0]    SW,             // Switches
    output logic[7:0]    HEX0,           // 7-segment display
    output logic[7:0]    HEX1,           // 7-segment display
    output logic[7:0]    HEX2,           // 7-segment display
    output logic[7:0]    HEX3,           // 7-segment display
    output logic[7:0]    HEX4,           // 7-segment display
    output logic[7:0]    HEX5            // 7-segment display
);
    
   // This project implements the following signal processing chain
   //
   // ADC --> CIC decimator --> FIR --> CIC interpolator --> DAC
   //
   // The ADC (and DAC) are both run at their proper update rate of 1 MHz for which their analog filters (anti-aliasing & reconstruction) were designed.
   // The CIC decimator internally lowers the sampling rate by a factor of 20 from 1 MHz down to 50 kHz
   // The FIR can compensate for the frequency response of the CIC, and additionally also do whatever filtering YOU might want
   // The CIC interpolator increasaes the sampling rate back up to 1 MHz to then feed the DAC
   // The DAC outputs the samples from the interpolator at 1 MHz
   //
   // Using these tricks, we can overcome the shortcoming of our previous design :)

   
   // Internal signals along signal processing chain
   logic signed[15:0] signal_from_adc;
   logic signed[15:0] signal_cic_decimated;
   logic signed[15:0] signal_fir_filtered;
   logic signed[15:0] signal_biquad_filtered;
   logic signed[15:0] signal_to_interpolator;
   logic signed[15:0] signal_cic_interpolated;
   logic signed[15:0] signal_to_dac;
   logic signed[15:0] up_i;
   logic signed[15:0] up_r;
   logic signed[15:0] down_i;
   logic signed[15:0] down_r;
   logic signed[15:0] filtered_i;
   logic signed[15:0] filtered_r;
   logic unsigned[4:0] k;
   logic unsigned[15:0] w0;
   logic unsigned[15:0] w0_lfo;

   logic signed[23:0] b0;
   logic signed[23:0] b1;
   logic signed[23:0] b2;
   logic signed[23:0] a1;
   logic signed[23:0] a2;
   
   // Misc. internal signals
   logic reset;
   logic clk;
   logic tick;         //   1 MHz ticks from tick generator
   logic tick_reduced; // 50 kHz ticks from CIC decimator
    
   // Wire reset & Clk
   assign reset = !KEY[0];      // Pushbutton on FPGA board. Need to push this when switching filter.
   assign clk = MAX10_CLK1_50;
   
   // Internals for ADC/DAC communication
   logic              adc_clk;        // SPI clk
   logic              adc_mosi;       // MOSI: always 1
   logic              adc_cnv;        // Start conversion (SPI CS)
   logic              adc_miso;       // MISO: The DAC data
   
   logic              dac_clk;        // SPI clock
   logic              dac_mosi;       // SPI MOSI
   logic              dac_cs;         // chip select
   logic              dac_reset_n;    // reset of the DAC
   
   
   // FIR Filter 1: CIC compensation
   parameter num_of_stages_f1 = 40; // don't need many stages to compensate for CIC
   parameter logic signed [18-1:0] coeffs_f1[num_of_stages_f1] = '{-1470, 293, 596, -3015, 4029, -5425, 1666, 2570, -12645, 16702, -19881, 6435, 10109, -39622, 52964, -53914, 8434, 64223, -162061, 164102, 164102, -162061, 64223, 8434, -53914, 52964, -39622, 10109, 6435, -19881, 16702, -12645, 2570, 1666, -5425, 4029, -3015, 596, 293, -1470};
   
   //parameter num_of_stages_f1 = 3; // don't need many stages to compensate for CIC
   //parameter logic signed [18-1:0] coeffs_f1[num_of_stages_f1] = '{0, 1000, 0};

   // Tick generator to divide the 50 MHz clock down to 1 MHz used to run the ADC & DAC
   TickGen #(50) tickGen (
      .clk_i(clk),
      .reset_i(reset),
      .tick_o(tick)
   );
   
   // Instantiate the AdcReader for communication with the ADC
   AdcReader reader(
      .clk_i(clk),
      .reset_i(reset),
      .start_i(tick),
      .data_o(signal_from_adc),
      .spi_clk_o(adc_clk),
      .spi_mosi_o(adc_mosi),
      .cnv_o(adc_cnv),
      .spi_miso_i(adc_miso),
      .is_idle_o()
   );
   
   // CIC decimator to reduce the effective sampling rate by a factor of 20, from 1 MHz down to 50 kHz
   CicDecimator decimator(
      .clk_i(clk),
      .reset_i(reset),
      .tick_i(tick),
      .signal_i(signal_from_adc),
      .signal_o(signal_cic_decimated),
      .tick_reduced_o(tick_reduced)
   );
   
   // Instantiate FIR compensation filter 

   FirFSM #(
      .num_of_stages(num_of_stages_f1),
      .coeffs(coeffs_f1)
   ) fir1(
      .clk_i(clk),
      .reset_i(reset),
      .tick_i(tick_reduced),
      .signal_i(signal_cic_decimated),
      .signal_o(signal_fir_filtered)
   );

   ////////////////////////////
   // ADD DISTORTION HERE
   // Module should take signal_fir_filtered as input and output signal_fir_filtered_distorted
   // then signal_fir_filtered_distorted should be passed to biquad filter
   ////////////////////////////

   // Switch assignment:
   // SW[0] = 0: 
   // SW[1] = 1: 
   // SW[2] = 2: 
   // SW[3] = 3: 
   // SW[4] = 4: 
   // SW[5] = 5: cutoff frequency sweep
   // SW[6] = 6: Q gain 3
   // SW[7] = 7: Q gain 2
   // SW[8] = 8: Q gain 1
   // SW[9] = 9: Filter in/out

   // set the Q-factor according to the switches 6, 7, and 8
   always_comb begin
      k = 5'd4 + SW[6] + SW[7] + SW[8];
   end

   // generate LFO for cutoff frequency sweep
   TriangleLFO #(
      .num_of_bits_w0(16),
      .w0_min(16'd328),
      .w0_max(16'd1311),
      .step(16'd1),
      .tick_divider(100)
   )triangle_lfo(
      .clk_i(clk),
      .reset_i(reset),
      .tick_i(tick_reduced),
      .w0_o(w0_lfo)
   );

   // set the cutoff frequency according to switch 5
   always_comb begin
      if (SW[5]) begin
         w0 = w0_lfo;
      end else begin
         w0 = 16'd1311; // 1 kHz
      end
   end

   // get the coefficients for the biquad filter
   GetCoefficients get_coeffs(
      .clk(clk),
      .reset(reset),
      .tick(tick_reduced),
      //.w0(16'd1311),       // 1 kHz: w0 = 1 / 50 * 2^16 = 1311
      .w0(w0),
      .k(k),
      .b0(b0),
      .b1(b1),
      .b2(b2),
      .a1(a1),
      .a2(a2)
   );

   // apply biquad filter
   // 1kHz resonant low pass filter [8139.    16278.     8139.  2097152. -4096211.  2031616.]
   // 1kHz non resonant low pass filter [ 7752.    15503.     7752.  2097152. -3901154.  1835008.]
   BiquadIIR biquad(
      .clk_i(clk),
      .reset_i(reset),
      .tick_i(tick_reduced),
      .signal_i(signal_fir_filtered),
      .signal_o(signal_biquad_filtered),
      //.b0(24'sd8139),
      //.b1(24'sd16278),
      //.b2(24'sd8139),
      //.a1(-24'sd4096211),
      //.a2(24'sd2031616),
      //.b0(24'sd7752),
      //.b1(24'sd15503),
      //.b2(24'sd7752),
      //.a1(-24'sd3901154),
      //.a2(24'sd1835008)
      .b0(b0),
      .b1(b1),
      .b2(b2),
      .a1(a1),
      .a2(a2)
   );

   // use switch 9 to route output
   always_comb begin
      if (SW[9]) begin
         signal_to_interpolator = signal_biquad_filtered;
      end else begin
         signal_to_interpolator = signal_fir_filtered;
      end
   end
   
   // Instantiate the CIC Interpolator to raise the effective sampling rate back from 50 kHz up to 1 MHz
   CicInterpolator interpolator(
      .clk_i(clk),
      .reset_i(reset),
      .tick_reduced_i(tick_reduced),
      .tick_i(tick),
      //.signal_i(down_r),
      .signal_i(signal_to_interpolator),
      .signal_o(signal_cic_interpolated)
   );  
   
   // Instantiate the DacWriter for communication with the DAC at 1 MHz
   DacWriter writer(
      .clk_i(clk),
      .reset_i(reset),
      .start_i(tick),
      //.data_i(signal_cic_interpolated),
      .data_i(signal_cic_interpolated),
      .spi_clk_o(dac_clk),
      .spi_mosi_o(dac_mosi),
      .spi_cs_o(dac_cs),
      .dac_reset_no(dac_reset_n),
      .is_idle_o()
   );

   always_comb begin
      HEX0 = ~8'd113; // F
      HEX1 = ~8'd115; // P
      HEX2 = ~8'd56;  // L
      HEX3 = ~8'd109; // S
      HEX4 = ~8'd121; // E
      HEX5 = ~8'd80;  // R
   end
   
   // Wire the ADC &  DAC to the FPGA via Arduino pins
   assign ARDUINO_IO[0] = dac_cs;
   assign ARDUINO_IO[1] = dac_clk;
   assign ARDUINO_IO[2] = dac_mosi;
   assign ARDUINO_IO[3] = dac_reset_n;
   
   assign ARDUINO_IO[4] = adc_cnv;
   assign ARDUINO_IO[5] = adc_clk;
   assign ARDUINO_IO[6] = adc_mosi;
   assign adc_miso = ARDUINO_IO[7]; // note that the order matters!

endmodule
