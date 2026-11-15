# PyUVM accelerator verification — learning checklist

We will build this one component at a time, explain the UVM idea beside the code,
and keep the passing direct-Cocotb test as a baseline.

## Progress

- [x] Confirm the existing Cocotb K=3 test passes with Icarus.
- [x] Set up the separate PyUVM folder and Python runner.
- [x] **1. PyUVM smoke test:** make a `uvm_test` run and check reset-visible status.
- [x] **2. Transaction model:** define one matrix operation (`K`, `A`, and `B`).
- [x] **3. Sequence and sequencer:** create a directed K=3 operation and send it as an item.
- [x] **4. Driver:** load A/B, pulse `start`, and wait for completion.
- [x] **5. Agent connection:** connect the sequencer to the driver and run a K=3 item.
- [x] **6. Monitor:** observe host writes, completion, and result reads.
- [x] **7. Scoreboard:** independently calculate `C = A × B` and compare all 16 words.
- [x] **8. Environment:** assemble the agent, monitor, and scoreboard under a reusable environment.
- [x] **9. Directed scenarios:** cover K boundaries, invalid K, signed corners, and reset recovery.
  - [x] K=1 and K=64 boundaries.
  - [x] Invalid K=0 and K=65 report `error`, remain idle, and produce no valid result.
  - [x] Reset followed by a valid K=2 recovery operation.
  - [x] Signed INT8 corner data includes -128, 127, -1, and 0.
  - [x] Busy-write rejection: probe writes during K=64 and check the result remains unchanged.
- [x] **10. Coverage and random tests:** three seeded operations (seed `20261115`); scoreboard reports tested K values, sign/zero classes, and signed endpoints.
- [x] **11. Checker confidence:** temporarily biased the expected C[0][0] by +1; simulation failed with coordinate, actual, expected, and mismatch count. Removed the probe and reran the passing suite.

## Current interface assumptions

- Default design: 4 rows × 4 columns, signed INT8 inputs, signed 32-bit accumulated outputs.
- A and B are loaded through the host write ports before `start`.
- The host supplies K as a count from 1 through 64; zero and values above 64 are rejected.
- Results are read in row-major order after `result_valid` becomes high.
- A and B writes presented while `busy` is high are ignored; load matrices before `start`.
