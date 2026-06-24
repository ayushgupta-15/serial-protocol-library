# Protocol Verification & Waveforms

To ensure the RTL is professional-grade and interview-ready, visual verification of the bus states is crucial. Please use GTKWave to view the generated `.vcd` files in the `sim/waves/` directory.

## Required Screenshots

To complete the repository's presentation, please capture the following screenshots in GTKWave, save them to the `docs/images/` directory, and link them below or in the README.

### 1. UART Loopback
**File**: `sim/waves/uart_loopback.vcd`
**What to show**: 
- The `i_tx_byte` value entering the TX module.
- The `serial_tx` wire toggling (Start bit, 8 data bits, Stop bit).
- The RX module sampling the bits at the mid-point.
- The `o_rx_byte` output matching the input.
- Highlight the 2-stage CDC synchronizer delay if visible.

*(Add screenshot here: `![UART Loopback](images/uart_loopback.png)`)*

### 2. SPI Mode 0 Transfer
**File**: `sim/waves/spi_modes.vcd`
**What to show**: 
- `sclk` resting low (CPOL=0).
- `mosi` and `miso` toggling on the trailing edge.
- Data being sampled on the leading (rising) edge of `sclk`.
- Ensure `ss` (Slave Select) encapsulates the entire transaction.

*(Add screenshot here: `![SPI Mode 0](images/spi_mode0.png)`)*

### 3. I2C Clock Stretching & Acknowledgement
**File**: `sim/waves/i2c_clock_stretch.vcd` or `sim/waves/i2c_multi_byte.vcd`
**What to show**: 
- **START Condition**: `sda` falling while `scl` is high.
- **Address Phase**: 7-bit address followed by R/W bit.
- **ACK Phase**: The slave pulling `sda` low on the 9th clock cycle.
- **Clock Stretching**: The slave holding `scl` low, and the master's FSM (`clk_count` and `step_count`) freezing until `scl` is released.
- **STOP Condition**: `sda` rising while `scl` is high.

*(Add screenshot here: `![I2C Verification](images/i2c_verification.png)`)*
