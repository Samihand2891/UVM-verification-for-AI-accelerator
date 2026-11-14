import os 
from pathlib import Path

from cocotb_tools.runner import get_runner

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RTL = ROOT / "rtl"

sources = [
    RTL / "mac.sv",
    RTL / "pe.sv",
    RTL / "delay_line.sv",
    RTL / "systolic.sv",
    RTL / "input_buffer.sv",
    RTL / "controllerFSM.sv",
    RTL / "output_memory.sv",
    RTL / "top.sv",
]


runner = get_runner(os.environ.get("SIM", "icarus"))

runner.build(sources = sources , hdl_toplevel="top" , build_dir=HERE/"sim_build" , always = True , build_args=["-g2012"] , timescale=("1ns" , "1ps"))

test_modules = sorted(
    path.stem for path in HERE.glob("test_*.py")
)

if not test_modules:
    raise RuntimeError(f"No test_*.py modules found in {HERE}")

runner.test(
    hdl_toplevel="top",
    test_module=test_modules,
    test_dir=HERE,
    build_dir=HERE / "sim_build",
)