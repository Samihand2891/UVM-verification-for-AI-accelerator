from pyuvm import uvm_sequence_item

class MatrixOperation(uvm_sequence_item):

    ROWS=4
    COLS=4
    K_MAX=64
    INPUT_MIN =-128
    INPUT_MAX =127

    def __init__(
        self,
        name="matrix_operation",
        k_len=1,
        matrix_a=None,
        matrix_b=None,
        busy_write_probe=False,
    ):
        super().__init__(name)
        self.k_len = k_len
        self.busy_write_probe = busy_write_probe

        if matrix_a is None:
            self.matrix_a = [
                [0 for _ in range(self.k_len)]
                for _ in range(self.ROWS)
            ]
        else:
            self.matrix_a = [list(row) for row in matrix_a]

        if matrix_b is None:
            self.matrix_b = [
                [0 for _ in range(self.COLS)]
                for _ in range(self.k_len)
            ]
        else:
            self.matrix_b = [list(row) for row in matrix_b]

        self.validate()

    def validate(self) : 
        if not isinstance(self.k_len, int):
            raise TypeError("k_len must be an integer")

        if not 1 <= self.k_len <= self.K_MAX:
            raise ValueError(
                f"k_len must be between 1 and {self.K_MAX}, got {self.k_len}"
            )

        if len(self.matrix_a) != self.ROWS:
            raise ValueError(
                f"A must have {self.ROWS} rows, got {len(self.matrix_a)}"
            )

        for row_index, row in enumerate(self.matrix_a):
            if len(row) != self.k_len:
                raise ValueError(
                    f"A row {row_index} must have {self.k_len} values, "
                    f"got {len(row)}"
                )

        if len(self.matrix_b) != self.k_len:
            raise ValueError(
                f"B must have {self.k_len} rows, got {len(self.matrix_b)}"
            )

        for row_index, row in enumerate(self.matrix_b):
            if len(row) != self.COLS:
                raise ValueError(
                    f"B row {row_index} must have {self.COLS} values, "
                    f"got {len(row)}"
                )

        for matrix_name, matrix in (
            ("A", self.matrix_a),
            ("B", self.matrix_b),
        ):
            for row_index, row in enumerate(matrix):
                for col_index, value in enumerate(row):
                    if not isinstance(value, int):
                        raise TypeError(
                            f"{matrix_name}[{row_index}][{col_index}] "
                            "must be an integer"
                        )

                    if not self.INPUT_MIN <= value <= self.INPUT_MAX:
                        raise ValueError(
                            f"{matrix_name}[{row_index}][{col_index}] "
                            f"must be between {self.INPUT_MIN} and "
                            f"{self.INPUT_MAX}, got {value}"
                        )

    def __str__(self):
        return (
            f"{self.get_name()}: K={self.k_len}, "
            f"A={self.ROWS}x{self.k_len}, "
            f"B={self.k_len}x{self.COLS}"
        )


class InvalidKOperation(uvm_sequence_item):
    """A start request used to verify the DUT's K-range rejection."""

    def __init__(self, name="invalid_k_operation", k_len=0):
        super().__init__(name)
        self.k_len = k_len

    def __str__(self):
        return f"{self.get_name()}: invalid K={self.k_len}"
