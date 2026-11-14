import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer


def signed_32(value):
    value = int(value)
    return value - (1 << 32) if value & (1 << 31) else value

@cocotb.test()
async def test_accelerator(dut):
    rows, cols, k_len = 4, 4, 3
    matrix_a = [
        [1, -2, 3],
        [4, 5, -6],
        [-7, 8, 9],
        [10, -11, 12],
    ]
    matrix_b = [
        [2, -3, 4, 5],
        [-6, 7, -8, 9],
        [10, -11, 12, -13],
    ]
    expected = [
        sum(matrix_a[i][k] * matrix_b[k][j] for k in range(k_len))
        for i in range(rows)
        for j in range(cols)
    ]

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

    await FallingEdge(dut.clk)
    dut.rst_n.value = 1

    # Load one A element and one B element on each active clock edge.
    for k in range(k_len):
        for lane in range(rows):
            await FallingEdge(dut.clk)
            dut.a_we.value = 1
            dut.a_row.value = lane
            dut.a_k.value = k
            dut.a_wdata.value = matrix_a[lane][k] & 0xFF
            dut.b_we.value = 1
            dut.b_k.value = k
            dut.b_col.value = lane
            dut.b_wdata.value = matrix_b[k][lane] & 0xFF
            await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    dut.a_we.value = 0
    dut.b_we.value = 0
    dut.k_len.value = k_len
    dut.start.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.start.value = 0

    for _ in range(100):
        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")
        if int(dut.done.value):
            break
    else:
        raise AssertionError("Timed out waiting for accelerator completion")

    assert int(dut.busy.value) == 0
    assert int(dut.error.value) == 0
    assert int(dut.result_valid.value) == 1

    for address, expected_value in enumerate(expected):
        dut.result_addr.value = address
        await Timer(1, unit="ns")
        actual = signed_32(dut.result_data.value)
        assert actual == expected_value, (
            f"C[{address // cols}][{address % cols}]: "
            f"got {actual}, expected {expected_value}"
        )

    cocotb.log.info("PASS: top-level K=3 signed matrix multiply")
