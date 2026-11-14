import cocotb 
from dataclasses import dataclass
from pyuvm import uvm_monitor , uvm_analysis_port , uvm_component  
from cocotb.triggers import RisingEdge, FallingEdge, Timer



@dataclass 
class ObservedOperation : 
    k_len : int
    matrix_a : list
    matrix_b:list
    actual_c : list




def signed_value(raw_value , width) : 
    value = int(raw_value)
    sign_bit = 1 << (width -1)

    if sign_bit & value : 
        value -= 1<<width

    return value 



class AcceleratorMonitor(uvm_component) : 
    def build_phase(self):
        self.ap = uvm_analysis_port("ap" , self)

    async def run_phase(self) : 
        dut = cocotb.top

        a_memory = [[0 for _ in range(64)] for _ in range(4)]
        b_memory = [[0 for _ in range(4)] for _ in range(64)]

        active_operation = None
        observed_results = {}


        while True : 
            await RisingEdge(dut.clk)

            await Timer(1 , unit = "ns")


            if int(dut.rst_n.value) == 0:
                active_operation = None
                observed_results = {}
                continue

            
            if int(dut.a_we.value):
                row = int(dut.a_row.value)
                k = int(dut.a_k.value)
                a_memory[row][k] = signed_value(dut.a_wdata.value, 8)

            if int(dut.b_we.value):
                k = int(dut.b_k.value)
                col = int(dut.b_col.value)
                b_memory[k][col] = signed_value(dut.b_wdata.value, 8)


            if int(dut.start.value) : 
                k_len = int(dut.k_len.value)

                if 1 <= k_len <= 64 :
                    active_operation ={"k_len" : k_len , "matrix_a" : [row[:k_len] for row in a_memory] , "matrix_b" : [row[:] for row in b_memory[:k_len]]  }

                    observed_results= {}

            if active_operation is not None and int(dut.result_valid.value) :
                address = int(dut.result_addr.value)


                
                if 0 <= address < 16:
                    observed_results[address] = signed_value(
                        dut.result_data.value, 32
                    )

                # Publish one completed observation after all 16 words were read.
                if len(observed_results) == 16:
                    observed = ObservedOperation(
                        k_len=active_operation["k_len"],
                        matrix_a=active_operation["matrix_a"],
                        matrix_b=active_operation["matrix_b"],
                        actual_c=[
                            observed_results[address]
                            for address in range(16)
                        ],
                    )
                    self.ap.write(observed)
                    active_operation = None

                    self.logger.info(
    f"Captured K={observed.k_len} and {len(observed.actual_c)} result words"
)


