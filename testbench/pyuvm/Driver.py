import cocotb 
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from pyuvm import uvm_driver
from matrix_item import InvalidKOperation


class AcceleratorDriver(uvm_driver):

    def build_phase(self):
        self.dut= cocotb.top


    async def run_phase(self):
        while True : 

            operation =await self.seq_item_port.get_next_item()

            await self.drive_operation(operation)
            self.seq_item_port.item_done()

    async def drive_operation(self , operation): 
        dut = self.dut

        if isinstance(operation, InvalidKOperation):
            await FallingEdge(dut.clk)
            dut.k_len.value = operation.k_len
            dut.start.value = 1
            await RisingEdge(dut.clk)
            await FallingEdge(dut.clk)
            dut.start.value = 0
            await Timer(1, unit="ns")

            if int(dut.error.value) != 1:
                raise AssertionError(
                    f"DUT did not assert error for invalid K={operation.k_len}"
                )
            if int(dut.busy.value) or int(dut.done.value):
                raise AssertionError(
                    f"Invalid K={operation.k_len} changed busy/done status"
                )
            if int(dut.result_valid.value):
                raise AssertionError(
                    f"Invalid K={operation.k_len} produced a valid result"
                )

            await RisingEdge(dut.clk)
            await Timer(1, unit="ns")
            if int(dut.error.value):
                raise AssertionError("DUT error did not clear after invalid request")
            return

        for k in range(operation.k_len):
            for lane in range(4):
                await FallingEdge(dut.clk)

                dut.a_we.value = 1
                dut.a_row.value = lane
                dut.a_k.value = k
                dut.a_wdata.value = operation.matrix_a[lane][k] & 0xFF

                dut.b_we.value = 1
                dut.b_k.value = k
                dut.b_col.value = lane
                dut.b_wdata.value = operation.matrix_b[k][lane] & 0xFF


        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        dut.a_we.value = 0
        dut.b_we.value = 0
        dut.k_len.value = operation.k_len
        dut.start.value = 1

        await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        dut.start.value = 0

        # Deliberately try to alter the last K slice while the DUT is busy.
        # The top-level busy gate must ignore these writes.
        if operation.busy_write_probe:
            if int(dut.busy.value) != 1:
                raise AssertionError("Busy-write probe started while DUT was idle")

            dut.a_we.value = 1
            dut.a_row.value = 0
            dut.a_k.value = 63
            dut.a_wdata.value = 127

            dut.b_we.value = 1
            dut.b_k.value = 63
            dut.b_col.value = 0
            dut.b_wdata.value = 128  # Signed INT8 value -128.

            await RisingEdge(dut.clk)
            await FallingEdge(dut.clk)
            dut.a_we.value = 0
            dut.b_we.value = 0

        for _ in range(100):
            await RisingEdge(dut.clk) 
            await Timer(1 , unit = "ns")


            if int(dut.error.value):
                raise AssertionError(
                    f"DUT rejected operation with K={operation.k_len}"
                )

            if int(dut.done.value):
                for address in range(16) : 
                    await FallingEdge(dut.clk)
                    dut.result_addr.value = address
                    await RisingEdge(dut.clk)
                    await Timer (1 , unit= "ns")
                return

        raise TimeoutError(
            f"Accelerator did not finish operation with K={operation.k_len}"
        )

