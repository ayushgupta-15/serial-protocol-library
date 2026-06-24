# Serial Protocol Library 📡

![RTL Verification](https://github.com/ayushgupta-15/serial-protocol-library/actions/workflows/test.yml/badge.svg)
![Verilog](https://img.shields.io/badge/Language-Verilog_2001-blue.svg)
![Simulator](https://img.shields.io/badge/Simulator-Icarus_Verilog-green.svg)

A professional-grade, synthesizable Serial Protocol Library implemented in Verilog. This repository contains complete RTL implementations and comprehensive verification environments for the three most common embedded serial protocols: **UART**, **SPI**, and **I2C**.

This project was developed with a strict focus on robust Digital Design principles, emphasizing Finite State Machine (FSM) reliability, Clock Domain Crossing (CDC) synchronization, open-drain bus modeling, and scalable verification methodologies.

---

## 🎯 Project Highlights

- **UART**: Parameterized Baud Generator, 2-Stage CDC Synchronizers, Mid-bit Sampling, Full Loopback.
- **SPI**: Master and Slave controllers, Configurable CPOL/CPHA (Modes 0-3 support), Multi-stage Synchronization.
- **I2C**: Open-Drain Bus Control, Multi-Byte Transfers, NACK Abort Handling, **Advanced Clock Stretching**.
- **Verification**: Fully automated `Makefile` pipeline, 14 targeted regression suites, Randomized constraint testing, and Mock Slaves natively built in Verilog.

---

## 📊 Protocol Architecture & Comparison

| Feature | UART | SPI | I2C |
| :--- | :--- | :--- | :--- |
| **Topology** | Point-to-Point | Single Master / Multi-Slave | Multi-Master / Multi-Slave |
| **Clocking** | Asynchronous | Synchronous (SCLK) | Synchronous (SCL) |
| **Pins Required**| 2 (TX, RX) | 4 (MOSI, MISO, SCLK, SS) | 2 (SDA, SCL) - Open Drain |
| **Duplex** | Full-Duplex | Full-Duplex | Half-Duplex |
| **Addressing** | None | Hardware (Slave Select) | Software (7-bit / 10-bit) |
| **ACK/NACK** | Parity (Optional) | None | Yes (Hardware ACK on 9th bit) |
| **RTL Complexity**| Low/Medium | Medium | High (Clock Stretching, Arbitration) |

---

## ⚙️ Supported Parameters & Configurability

The library is designed for seamless integration into larger SoC architectures (e.g., APB bus interconnects). All modules are highly parameterized:

### UART Configuration
```verilog
parameter CLK_FREQ   = 50_000_000;  // System Clock Frequency
parameter BAUD_RATE  = 115200;      // Target Baud Rate
```

### SPI Configuration
```verilog
parameter CLK_FREQ   = 50_000_000;
parameter SPI_FREQ   = 1_000_000;   // Configurable SCLK Speed
parameter CPOL       = 0;           // Clock Polarity (0 or 1)
parameter CPHA       = 0;           // Clock Phase (0 or 1)
```

### I2C Configuration
```verilog
parameter CLK_FREQ   = 50_000_000;
parameter I2C_FREQ   = 100_000;     // Standard Mode (100kHz), Fast Mode (400kHz)
```

---

## 🧪 Verification Methodology

Verification is driven by a comprehensive `Makefile` generating Icarus Verilog (`vvp`) simulations and GTKWave (`.vcd`) outputs. Tests range from unit-level state transitions to randomized sequence regressions.

### Example Test Output
```text
iverilog -o sim/i2c_multi_byte.vvp rtl/i2c/i2c_master.v tb/i2c/i2c_multi_byte_tb.v
vvp sim/i2c_multi_byte.vvp
VCD info: dumpfile sim/waves/i2c_multi_byte.vcd opened for output.
--- Test 1: Address 0x48, 3 Bytes (0x11, 0x22, 0x33) ---
PASS: All bytes ACKed
--- Test 2: Address 0x48, 4 Bytes, NACK on 3rd byte (idx 3) ---
PASS: Transaction aborted correctly due to NACK
--- Test 3: 100 Randomized Multi-Byte Transfers ---
SUCCESS: All Multi-Byte tests passed!
```

### Running the Regression Suite
To run all 14 integration and regression tests natively:
```bash
make all
```

---

## 🌊 Waveform Verification

Visual verification is tracked in the `docs/images` folder. 
*(Please see the `docs` folder for detailed protocol transition diagrams and logic analyzer outputs).*

- **UART Loopback**: Validation of 2FF Synchronizer and mid-bit RX sampling.
- **SPI Mode 0**: Alignment of MOSI/MISO on leading/trailing SCLK edges.
- **I2C Clock Stretching**: Master FSM successfully halting quarter-period timing counters while Slave artificially holds SCL low.

---

## 🛠 Repository Structure

```text
📁 rtl/
 ├── uart/          # TX, RX, Baud Generator, Loopback Top
 ├── spi/           # Master, Slave
 └── i2c/           # Master with Open-Drain and Clock Stretch Logic
📁 tb/              # Advanced Verilog testbenches with Randomization & Mock Slaves
📁 sim/             # Generated VVP binaries and VCD waveforms
📁 docs/            # Architecture markdown and GTKWave screenshots
📄 Makefile         # Verification pipeline
```
