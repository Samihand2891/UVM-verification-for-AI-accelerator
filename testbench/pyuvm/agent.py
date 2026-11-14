from pyuvm import uvm_agent, uvm_sequencer 
from monitor import AcceleratorMonitor

from Driver import AcceleratorDriver

class AcceleratorAgent(uvm_agent):
    def build_phase(self):


        self.sequencer = uvm_sequencer("sequencer", self)
        self.driver = AcceleratorDriver.create("driver", self)
        self.monitor = AcceleratorMonitor.create("monitor" , self)


    def connect_phase(self):
            self.driver.seq_item_port.connect(self.sequencer.seq_item_export)

        

            

