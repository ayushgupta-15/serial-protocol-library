# UART RX Timing & Mid-Bit Sampling

The most critical aspect of the UART receiver is **Mid-Bit Sampling**. Because the UART input is asynchronous to the FPGA clock domain, we cannot sample exactly at the bit boundaries.

## RX Timing Diagram

```text
Idle  Start     D0      D1
 1      0       1       0

 ──────┐
       └───────────────
```

## Mid-Bit Sampling Flow

1. **Detect falling edge**: Transition from Idle (`1`) to Start (`0`).
2. **Wait half bit period**: Wait `CLKS_PER_BIT / 2` cycles.
3. **Verify Start Bit**: Ensure the signal is still `0` (filters out noise/glitches).
4. **Sample center**: The timing is now perfectly aligned to the center of the start bit.
5. **Sample every `CLKS_PER_BIT`**: Subsequent reads are guaranteed to land directly in the middle of each data bit, which is the most stable region of the asynchronous signal.

## Clock Domain Crossing (CDC)
To safely process the incoming asynchronous serial line, a 2-stage Flip-Flop (2FF) synchronizer is used:

```verilog
rx_sync_1 <= i_rx_serial;
rx_sync_2 <= rx_sync_1;
```

**Interview Value:** Sampling directly causes metastability. The two-stage synchronization dramatically reduces metastability propagation into the FSM logic, ensuring stable operation across asynchronous clock domains.
