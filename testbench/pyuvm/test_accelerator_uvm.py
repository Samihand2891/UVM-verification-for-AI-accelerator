import cocotb
import pyuvm
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer
from pyuvm import uvm_test

from environment import AcceleratorEnvironment
from Sequencer import MatrixOperationSequence


@pyuvm.test()
class AcceleratorK3Test(uvm_test):
    def build_phase(self):
        # The agent creates the sequencer and driver and connects them.
        self.env = AcceleratorEnvironment.create("env", self)

    async def run_phase(self):
        self.raise_objection("Run the K=3 matrix operation")

        dut = cocotb.top
        dut.clk.value = 0
        dut.rst_n.value = 0
        dut.a_we.value = 0
        dut.a_row.value = 0
        dut.a_k.value = 0
        dut.a_wdata.value = 0
        dut.b_we.value = 0
        dut.b_k.value = 0
        dut.b_col.value = 0
        dut.b_wdata.value = 0
        dut.start.value = 0
        dut.k_len.value = 0
        dut.result_addr.value = 0

        cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
        await Timer(1, unit="ns")

        assert int(dut.busy.value) == 0
        assert int(dut.done.value) == 0
        assert int(dut.result_valid.value) == 0

        # Release reset on a falling edge so inputs are stable before the next rising edge.
        await FallingEdge(dut.clk)
        dut.rst_n.value = 1

        # The sequence sends a MatrixOperation through the sequencer to the driver.
        sequence = MatrixOperationSequence("k3_sequence")
        await sequence.start(self.env.agent.sequencer)

        # The driver returns the item only after the accelerator completes.
        assert int(dut.error.value) == 0
        assert int(dut.busy.value) == 0
        assert int(dut.result_valid.value) == 1

        self.logger.info("PASS: K=3 operation completed through the PyUVM agent")
        self.drop_objection("K=3 operation completed")