# AnalogTanhDistortion (DE10-Lite)

Read an analog signal on the Arduino ADC/DAC shield, apply hyperbolic CORDIC `tanh` soft-clipping in the FPGA, and play the result on the DAC.


## Files

| File | Role |
|------|------|
| `analog_tanh_distortion.qpf` / `.qsf` | Quartus project |
| `Timing.sdc` | 50 MHz clock constraint |
| `AnalogTanhDacTop.sv` | FPGA top (ADC in, DAC out) |
| `AnalogTanhDistort.sv` | tanh pipeline on ADC samples |
| `AdcReader.sv`, `DacWriter.sv`, `TickGen.sv` | Shield drivers |
| `cordic_tanh.sv` | Hyperbolic CORDIC (`tanh`) |
| `Makefile`, `analog_tanh_test.py` | Cocotb simulation |

## FPGA programming

1. Open **`analog_tanh_distortion.qpf`** in Quartus Prime.
2. Compile and program the DE10-Lite (MAX 10 `10M50DAF484C6GES`).
3. Connect the Arduino ADC/DAC shield.
4. Feed a signal into the shield **analog input**; listen on **analog output**.

| Control | Action |
|---------|--------|
| `KEY[0]` | Push to reset (active-low) |
| `KEY[1]` | Each press **toggles** tanh distortion on/off (starts **on**) |

Signal chain: `AdcReader` → `AnalogTanhDistort` → `DacWriter`.

| `ARDUINO_IO` | Function |
|--------------|----------|
| `[0:3]` | DAC SPI (CS, CLK, MOSI, RESET) |
| `[4:7]` | ADC SPI (CNV, CLK, MOSI, MISO) |

## Simulation

```bash
poetry run make -C Project/AnalogTanhDistortion sim
poetry run make -C Project/AnalogTanhDistortion wave
```

## Parameters

Edit defaults in `AnalogTanhDacTop.sv` or `AnalogTanhDistort.sv`:

| Parameter | Meaning |
|-----------|---------|
| `AMPLITUDE` | Output level 0–100 % after tanh |
| `DISTORT_SHIFT` | Extra drive into `tanh` (higher = stronger clipping) |
| `DAC_TICK_DIV` | Clock divider for 1 MHz ADC/DAC updates (50 → 50 MHz / 50) |
