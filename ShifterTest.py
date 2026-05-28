import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import math


@cocotb.test()
async def shifter_test(dut):
    """Test the ShifterTest module with a 50 MHz clock and 1 kHz sinusoidal input."""

    # Constants
    CLOCK_PERIOD_NS = 20  # 50 MHz clock (20 ns period)
    SIGNAL_FREQ = 1e3  # 1 kHz sine wave
    SAMPLE_RATE = 1 / (CLOCK_PERIOD_NS * 1e-9)  # Sampling rate in Hz
    NUM_CYCLES = 5  # Number of cycles to simulate

    # Set up the clock
    clock = Clock(dut.clk, CLOCK_PERIOD_NS, units="ns")
    cocotb.fork(clock.start())

    # Initialize inputs
    dut.reset <= 1
    dut.signal_fir_filtered <= 0

    # Wait for a few clock cycles to release reset
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.reset <= 0

    # Generate the 1 kHz sine wave input
    for t in range(int(NUM_CYCLES * SAMPLE_RATE / SIGNAL_FREQ)):
        # Time in seconds
        time_s = t / SAMPLE_RATE

        # Generate the sine wave
        sine_val = int((2**15 - 1) * math.sin(2 * math.pi * SIGNAL_FREQ * time_s))
        dut.signal_fir_filtered <= sine_val

        # Wait for one clock cycle
        await Timer(CLOCK_PERIOD_NS, units="ns")
