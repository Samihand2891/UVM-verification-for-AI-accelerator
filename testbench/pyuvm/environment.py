from pyuvm import uvm_env

from agent import AcceleratorAgent
from scoreboard import AcceleratorScoreboard


class AcceleratorEnvironment(uvm_env) : 
    def build_phase(self):
        self.agent = AcceleratorAgent.create("agent" , self)
        self.scoreboard = AcceleratorScoreboard ("scoreboard"  ,self)

    def connect_phase(self):
        self.agent.monitor.ap.connect(self.scoreboard.analysis_export)


        