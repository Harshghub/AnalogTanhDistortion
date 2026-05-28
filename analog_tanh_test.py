"""Cocotb testbench: synthetic ADC samples through CORDIC tanh."""

import math

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

WORD_SZ = 18
FRAC_SZ = 16
TANH_LATENCY = FRAC_SZ + (WORD_SZ - 1)
CLOCK_PERIOD_NS = 20
RUN_CYCLES = 4000
AMPLITUDE = 100


def sample_signed16(value) -> int:
    v = int(value)
    if v >= (1 << 15):
        v -= 1 << 16
    return v


def synth_sample(cycle: int, amplitude: int = 26000) -> int:
    """16-bit signed sine-like stimulus for sample_i."""
    phase = 2.0 * math.pi * cycle / 200.0
    return int(amplitude * math.sin(phase))


@cocotb.test()
async def analog_tanh_distortion(dut):
    """Feed a synthetic waveform; compare bypass vs tanh output."""
    clock = Clock(dut.clk, CLOCK_PERIOD_NS, unit="ns")
    cocotb.start_soon(clock.start())

    dut.reset.value = 1
    dut.distort_en_i.value = 1
    dut.distort_shift_i.value = 0
    dut.sample_i.value = 0
    for _ in range(10):
        await RisingEdge(dut.clk)
    dut.reset.value = 0

    for _ in range(TANH_LATENCY + 100):
        await RisingEdge(dut.clk)

    dut._log.info("=" * 72)
    dut._log.info(
        f"{'cycle':>8}  {'sample_i':>12}  {'in_aligned':>14}  "
        f"{'tanh_sample':>12}  {'distorted':>12}  {'|dist|/|in|':>12}"
    )
    dut._log.info("=" * 72)

    peaks_in = 0
    peaks_dist = 0

    for cycle in range(RUN_CYCLES):
        dut.sample_i.value = synth_sample(cycle)
        await RisingEdge(dut.clk)
        sample_in = sample_signed16(dut.sample_i.value)
        sample_aln = sample_signed16(dut.in_aligned_o.value)
        tanh_sample = sample_signed16(dut.tanh_sample.value)
        dist = sample_signed16(dut.distorted_o.value)
        peaks_in = max(peaks_in, abs(sample_in))
        peaks_dist = max(peaks_dist, abs(dist))
        if cycle % 200 == 0:
            ratio = abs(dist) / max(abs(sample_aln), 1)
            dut._log.info(
                f"{cycle:8d}  {sample_in:12d}  {sample_aln:14d}  "
                f"{tanh_sample:12d}  {dist:12d}  {ratio:12.4f}"
            )

    dut._log.info("=" * 72)
    dut._log.info(f"Peak |input|: {peaks_in}, peak |distorted|: {peaks_dist}")
    if peaks_dist < peaks_in:
        dut._log.info(
            "Tanh soft-clipping reduced peak amplitude "
            f"({peaks_dist}/{peaks_in} ≈ {peaks_dist / max(peaks_in, 1):.3f})"
        )

    for _ in range(40):
        await RisingEdge(dut.clk)
