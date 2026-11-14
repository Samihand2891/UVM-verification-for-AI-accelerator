import cocotb 
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from pyuvm import uvm_driver


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

