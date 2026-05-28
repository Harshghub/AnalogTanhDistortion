//verilator lint_off IMPLICIT

module ShifterTest(
        input  logic clk,
        input  logic reset,
        input  logic signed[15:0] signal_fir_filtered,
    
        output logic signed[15:0] down_r,
        output logic signed[15:0] down_i
  );
  
  TickGen #(1000)tickGen (
      .clk_i(clk),
      .reset_i(reset),
      .tick_o(tick_reduced)
   );


   Shifter shifter(
      .clk(clk),
      .reset(reset),
      .tick_reduced(tick_reduced),
      .signal_fir_filtered(signal_fir_filtered),
      .down_r(down_r),
      .down_i(down_i)
   );

endmodule

//verilator lint_on IMPLICIT

