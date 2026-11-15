from pyuvm import uvm_sequence

from matrix_item import InvalidKOperation, MatrixOperation


class SingleOperationSequence(uvm_sequence):
    def __init__(self, name="single_operation_sequence", operation=None):
        super().__init__(name)
        self.operation = operation

    async def body(self):
        if self.operation is None:
            raise ValueError("SingleOperationSequence needs an operation")
        await self.start_item(self.operation)
        await self.finish_item(self.operation)


class BusyWriteIgnoredSequence(uvm_sequence):
    async def body(self):
        operation = MatrixOperation(
            name="busy_write_probe_k64",
            k_len=64,
            matrix_a=[[0 for _ in range(64)] for _ in range(4)],
            matrix_b=[[0 for _ in range(4)] for _ in range(64)],
            busy_write_probe=True,
        )
        await self.start_item(operation)
        await self.finish_item(operation)


class InvalidKSequence(uvm_sequence):
    def __init__(self, name="invalid_k_sequence", k_len=0):
        super().__init__(name)
        self.k_len = k_len

    async def body(self):
        operation = InvalidKOperation(name=f"invalid_k{self.k_len}", k_len=self.k_len)
        await self.start_item(operation)
        await self.finish_item(operation)
