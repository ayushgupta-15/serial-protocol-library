# UART Protocol Controller Architecture

This document describes the hardware architecture of the UART (Universal Asynchronous Receiver-Transmitter) module.

## High-Level Block Diagram

```text
                +-------------+
                | Baud Gen    |
                +------+------+
                       |
          +------------+------------+
          |                         |
          v                         v

      +--------+               +--------+
      | UART TX|----wire------>| UART RX|
      +--------+               +--------+
                                    |
                             2FF Synchronizer
```

## Module Breakdown

### 1. Baud Generator (`baud_gen.v`)
- **Role:** Generates a single-cycle timing pulse (baud tick) at the specified baud rate (115200 bps from a 50 MHz clock).
- **Function:** Ensures both transmitter and receiver are synchronized to the correct bit-period boundaries.

### 2. UART Transmitter (`uart_tx.v`)
- **Role:** Serializes a parallel 8-bit byte.
- **Components:**
  - Shift register (LSB-first)
  - FSM (`IDLE`, `START_BIT`, `DATA_BITS`, `STOP_BIT`, `DONE`)
  - Baud counter logic

### 3. UART Receiver (`uart_rx.v`)
- **Role:** Deserializes asynchronous serial data back into a parallel byte.
- **Components:**
  - **2FF Synchronizer:** Double flip-flop synchronizer resolving metastability from the asynchronous serial input.
  - **Mid-Bit Sampler:** Edge-detection and counter logic to sample data precisely at the center of the bit-period.
  - FSM (`IDLE`, `START_BIT`, `DATA_BITS`, `STOP_BIT`, `DONE`)
