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
- [ ] **9. Directed scenarios:** cover K boundaries, invalid K, signed corners, and reset recovery.
- [ ] **10. Coverage and random tests:** add seeded variation and report which cases ran.
- [ ] **11. Checker confidence:** deliberately inject a test-side error and confirm it is detected.

## Current interface assumptions

- Default design: 4 rows × 4 columns, signed INT8 inputs, signed 32-bit accumulated outputs.
- A and B are loaded through the host write ports before `start`.
- The host supplies K as a count from 1 through 64; zero and values above 64 are rejected.
- Results are read in row-major order after `result_valid` becomes high.
- Writes during `busy` are not part of the initial tests until their intended behavior is specified.
