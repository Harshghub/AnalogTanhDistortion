

/**
 Module to control the DAC on the ADC/DAC board.
*/    
module DacWriter
    (
    input logic         clk_i,            // clock
    input logic         reset_i,          // sync. reset
    input signed [15:0] data_i,           // DAC value to send
    input logic         start_i,          // 1 to start transmission
    output logic        is_idle_o,        // 1 if in IDLE state
    output logic        spi_clk_o,        // SPI clock
    output logic        spi_mosi_o,       // SPI MOSI
    output logic        spi_cs_o,         // chip select
    output logic        dac_reset_no     // reset of the DAC
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
    // TASK 2: WRITE YOUR NEXT STATE LOGIC HERE
    always_comb begin
	//Set default values if not covered in state
	state_d = state_q;
	bit_counter_d = bit_counter_q;
        data_reg_d = data_reg_q;
        // FSM transition logic
		case(state_q)
			IDLE: begin
				if(start_i) begin
					// start at 15 as MSB comes first
					bit_counter_d = 15;
					state_d = CS_DOWN;
					//Transform 16-bit signed to unsigned
					data_reg_d = 16'($unsigned(17'sh8000 + data_i));
				end
			end
			CS_DOWN: state_d = SET_CLK;
			SET_CLK: state_d = SEL_BIT;
			SEL_BIT: begin
				// We decrease the counter for the next bit until all 16 bits are transfered
				if(bit_counter_q > 0) begin
					bit_counter_d = bit_counter_q - 4'd1;
					state_d = SET_CLK;
				end
				else begin
					state_d  = DONE;
				end
			end
			DONE: begin
			//wait until start goes back to zero
				if(!start_i) begin
					state_d = IDLE;
				end
			end
			
			default:
				state_d = state_q;
		endcase
		
    
    end
    
    
    
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
