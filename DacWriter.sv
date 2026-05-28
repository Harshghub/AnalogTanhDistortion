

/**
 Module to control the DAC on the ADC/DAC board.
*/    
module DacWriter
    (
    input               clk_i,            // clock
    input               reset_i,          // sync. reset
    input signed [15:0] data_i,           // DAC value to send
    input               start_i,          // 1 to start transmission
    output              is_idle_o,        // 1 if in IDLE state
    output              spi_clk_o,        // SPI clock
    output              spi_mosi_o,       // SPI MOSI
    output              spi_cs_o,         // chip select
    output              dac_reset_no     // reset of the DAC
    );
    
    typedef enum logic [4:0] {
        IDLE,       // wait for start
        CS_DOWN,    // start transmission by selecting the DAC
        SET_CLK,    // set the spi clk
        SEL_BIT,    // select the bit
        DONE        // wait for start to go to 0
    } state_t;
    
    // signals holding the state
    state_t state_q, state_d;
    // the bit counter
    logic [3:0] bit_counter_q, bit_counter_d;
    // signal holding the stored setpoint
    logic [15:0] data_reg_q, data_reg_d;
	 
    
    always_ff @(posedge clk_i) begin
        if (reset_i) begin
            state_q <= IDLE;
            bit_counter_q <= 0;
            data_reg_q <= 16'h8000;
        end else begin
            state_q <= state_d;
            bit_counter_q <= bit_counter_d;
            data_reg_q <= data_reg_d;
        end // if not reset
    end // always_ff
    
    
    
    // next-state logic
    always_comb begin
        // default: stay where you are
        state_d = state_q;
        bit_counter_d = bit_counter_q;
        data_reg_d = data_reg_q;
        
        // if in idle: wait for the start_i to go '1'
        if (state_q == IDLE) begin
            bit_counter_d = 15;
            // here we need to convert the input signal to unsigned with offset
            data_reg_d = 16'($unsigned(17'sh8000 + data_i));
            if (start_i) state_d = CS_DOWN;
        end
        
        
        // lower the CS signal
        if (state_q == CS_DOWN) begin
            state_d = SET_CLK;
        end
        
        
        // set the clock
        if (state_q == SET_CLK) state_d = SEL_BIT;
        
        // if we are not yet done: increment the bit counter and repeat
        // otherwise: go to DONE
        if (state_q == SEL_BIT) begin
            if (bit_counter_q > 0) begin
                bit_counter_d = bit_counter_q - 4'd1;
                state_d = SET_CLK;
            end else state_d = DONE;
        end
        
        
        // wait for the start signal to clear
        if (state_q == DONE) begin
            if (!start_i) state_d = IDLE;
        end
    end // next state logic
    
    
    
    
    
    // Output signals:
    //================
    // set the correct bit; the bit MUST be set when ENTERING the SEL_BIT state! Therefore, we need to use the 
    // next_bit_counter here! (otherwise, the bit gets set one clock cycle too late!)
    assign spi_mosi_o = data_reg_q[bit_counter_d];
    
    // clk is 1 for SET_CLK only!
    assign spi_clk_o = (state_q == SET_CLK);
    
    // the CS is 1 for IDLE and DONE, otherwise it is 0
    assign spi_cs_o = ((state_q == IDLE) | (state_q == DONE));
    
    // is_idle_o is 1 only in IDLE:
    assign is_idle_o = (state_q == IDLE);
    
    // the reset to the DAC is directly connected to the reset_i signal:
    assign dac_reset_no = !reset_i;
    
endmodule
