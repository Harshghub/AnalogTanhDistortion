module Shifter(
        input  logic clk,
        input  logic reset,
        input  logic tick_reduced,
        input  logic signed[15:0] signal_fir_filtered,
    
        output logic signed[15:0] down_r,
        output logic signed[15:0] down_i
    );

   // FIR Filter 2: High pass filter (from jupyter notebook), cutoff at 13 kHz
   parameter num_of_stages_f2 = 400; // quite a lot of stages needed to get a sharp cutoff
   parameter logic signed [18-1:0] coeffs_f2[num_of_stages_f2] = '{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, -1, 0, -1, 2, -2, 0, 0, 2, -2, 0, 0, 2, -3, 0, 2, 1, -3, -1, 4, -1, -2, -2, 8, -5, -1, -3, 11, -9, 1, -3, 14, -13, 2, -1, 14, -16, 1, 5, 10, -16, -2, 15, 1, -13, -7, 28, -14, -7, -12, 43, -32, 1, -14, 54, -49, 7, -9, 58, -61, 8, 6, 47, -64, 1, 35, 20, -55, -13, 75, -23, -35, -30, 120, -78, -8, -42, 158, -133, 16, -38, 176, -176, 28, -7, 159, -193, 20, 58, 99, -178, -10, 154, -6, -129, -54, 267, -144, -57, -93, 374, -291, 17, -104, 440, -415, 68, -59, 432, -485, 76, 60, 324, -477, 30, 257, 110, -385, -61, 510, -193, -225, -164, 771, -540, -37, -229, 972, -866, 125, -194, 1037, -1097, 206, -6, 897, -1170, 167, 366, 510, -1049, 5, 908, -119, -742, -237, 1553, -935, -306, -465, 2180, -1830, 158, -539, 2621, -2663, 521, -284, 2676, -3275, 646, 500, 2113, -3519, 412, 2064, 637, -3270, -283, 4858, -2340, -2386, -1598, 10322, -8973, -330, -4445, 29385, -44985, 22404, 22404, -44985, 29385, -4445, -330, -8973, 10322, -1598, -2386, -2340, 4858, -283, -3270, 637, 2064, 412, -3519, 2113, 500, 646, -3275, 2676, -284, 521, -2663, 2621, -539, 158, -1830, 2180, -465, -306, -935, 1553, -237, -742, -119, 908, 5, -1049, 510, 366, 167, -1170, 897, -6, 206, -1097, 1037, -194, 125, -866, 972, -229, -37, -540, 771, -164, -225, -193, 510, -61, -385, 110, 257, 30, -477, 324, 60, 76, -485, 432, -59, 68, -415, 440, -104, 17, -291, 374, -93, -57, -144, 267, -54, -129, -6, 154, -10, -178, 99, 58, 20, -193, 159, -7, 28, -176, 176, -38, 16, -133, 158, -42, -8, -78, 120, -30, -35, -23, 75, -13, -55, 20, 35, 1, -64, 47, 6, 8, -61, 58, -9, 7, -49, 54, -14, 1, -32, 43, -12, -7, -14, 28, -7, -13, 1, 15, -2, -16, 10, 5, 1, -16, 14, -1, 2, -13, 14, -3, 1, -9, 11, -3, -1, -5, 8, -2, -2, -1, 4, -1, -3, 1, 2, 0, -3, 2, 0, 0, -2, 2, 0, 0, -2, 2, -1, 0, -1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

   // Cordic to generate the LO signal for up conversion
   // Instantiate the CordicFSM

   logic signed [15:0] lo_up;       // LO cosine component for up conversion
   logic signed [15:0] qlo_up;      // LO sine component for up conversion
   logic unsigned [15:0] angle_up;  // Angle input for the Cordic

   // Generate the angle for the LO signal (incrementing angle)
   always_ff @(posedge clk or posedge reset) begin
      if (reset) begin
         angle_up <= 16'd0;
      end else if (tick_reduced) begin
         angle_up <= angle_up + 16'd17039; // Increment angle (13*2^16/50)
         //angle_up <= angle_up + 16'd1703; // Increment angle (13*2^16/50)
      end
   end

   CordicFSM cordic_up (
      .clk(clk),
      .reset(reset),
      .tick(tick_reduced),
      .angle(angle_up),  // Input angle for LO generation
      .x_i(16'sd32000), // Input magnitude (1.0 in Q1.15 format)
      .x_o(lo_up),       // Output cosine component
      .y_o(qlo_up)       // Output sine component
   );

   // Cordic to generate the LO signal for down conversion
   // Instantiate the CordicFSM

   logic signed [15:0] lo_down;       // LO cosine component for down conversion
   logic signed [15:0] qlo_down;      // LO sine component for down conversion
   logic unsigned [15:0] angle_down;  // Angle input for the Cordic

   // Generate the angle for the LO signal (incrementing angle)
   always_ff @(posedge clk or posedge reset) begin
      if (reset) begin
         angle_down <= 16'd0;
      end else if (tick_reduced) begin
         //angle_down <= angle_down - 16'd17038; // slight up shift
         //angle_down <= angle_down - 16'd18038; // 100 Hz down shift
         //angle_down <= angle_down - 16'd34080; // Inversion of audio band
         angle_down <= angle_down - 16'd16908; // 100 Hz up shift
         //angle_down <= angle_down - 16'd19660; // shift down by 2 kHz
      end
   end

   CordicFSM cordic_down (
      .clk(clk),
      .reset(reset),
      .tick(tick_reduced),
      .angle(angle_down),  // Input angle for LO generation
      .x_i(16'sd32000), // Input magnitude (1.0 in Q1.15 format)
      .x_o(lo_down),       // Output cosine component
      .y_o(qlo_down)       // Output sine component
   );

    logic signed[15:0] up_r;
    logic signed[15:0] up_i;
    logic signed[15:0] filtered_i;
    logic signed[15:0] filtered_r;

   
   Mixer mixerup (
      .lo_i(lo_up),
      .qlo_i(qlo_up),
      .signalr_i(signal_fir_filtered),
      .signali_i('0), // No imaginary part for real input
      .signalr_o(up_r),
      .signali_o(up_i)
   );

   FirFSM #(
      .num_of_stages(num_of_stages_f2),
      .coeffs(coeffs_f2)
   ) fir2r(
      .clk_i(clk),
      .reset_i(reset),
      .tick_i(tick_reduced),
      .signal_i(up_r),
      .signal_o(filtered_r)
   );

   FirFSM #(
      .num_of_stages(num_of_stages_f2),
      .coeffs(coeffs_f2)
   ) fir2i(
      .clk_i(clk),
      .reset_i(reset),
      .tick_i(tick_reduced),
      .signal_i(up_i),
      .signal_o(filtered_i)
   );

   Mixer mixerdown(
      .lo_i(lo_down),
      .qlo_i(qlo_down),
      .signalr_i(filtered_r),
      .signali_i(filtered_i),
      .signalr_o(down_r),
      .signali_o(down_i)
   );

endmodule