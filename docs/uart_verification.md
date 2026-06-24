# UART Verification Suite

The UART protocol controller is thoroughly verified using automated testbenches written in Verilog, simulated with Icarus Verilog (`iverilog`), and verified against waveform dumps in GTKWave.

## Verification Status

| Test Name                  | Status |
|----------------------------|--------|
| `0x00` Edge Case           | ✅ Pass |
| `0x55` Alternating Bits    | ✅ Pass |
| `0xAA` Alternating Bits    | ✅ Pass |
| `0xFF` Edge Case           | ✅ Pass |
| 100-Byte Random Regression | ✅ Pass |
| Loopback Integration       | ✅ Pass |

## Loopback Integration (`uart_loopback_tb.v`)

The Loopback Integration test wires the `uart_tx` module's serial output directly into the `uart_rx` module's serial input. 

This test proves that the Transmitter and Receiver work together seamlessly.

### Test Flow:
1. `TX` receives an 8-bit byte.
2. `TX` serializes the data across the `Serial Line`.
3. `RX` synchronizes the line, samples the bits, and deserializes the byte.
4. The testbench verifies that `Received Byte == Transmitted Byte`.

The final regression test hammers the loopback link with 100 random bytes continuously to ensure sustained stability without framing errors.
