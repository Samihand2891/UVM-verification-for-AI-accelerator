from pyuvm import uvm_subscriber


class AcceleratorScoreboard(uvm_subscriber) :
    def build_phase(self):
        self.checked_operations =0
        self.errors = []
        self.k_values = set()
        self.value_classes = set()
        self.corner_values = set()

    def write(self , observed):
        self.k_values.add(observed.k_len)
        values = [value for row in observed.matrix_a for value in row]
        values.extend(value for row in observed.matrix_b for value in row)
        if any(value > 0 for value in values):
            self.value_classes.add("positive")
        if any(value < 0 for value in values):
            self.value_classes.add("negative")
        if any(value == 0 for value in values):
            self.value_classes.add("zero")
        self.corner_values.update(value for value in values if value in (-128, 127))
        expected_c = []


        for row in range(4) : 
            for col in range(4) : 
                total =0
                for k in range(observed.k_len) :
                    total +=(observed.matrix_a[row][k]*observed.matrix_b[k][col])
                expected_c.append(total)

        self.checked_operations +=1
        operation_errors =[]


        for address , expected in enumerate(expected_c) :
            actual= observed.actual_c[address]

            if actual != expected:
                operation_errors.append(
                    f"C[{address // 4}][{address % 4}]: "
                    f"got {actual}, expected {expected}"
                )

        if operation_errors:
            self.errors.extend(operation_errors)
            for error in operation_errors:
                self.logger.error(error)
        else:
            self.logger.info(
                f"PASS: K={observed.k_len}, all 16 results matched"
            )

    def check_phase(self):
        if self.checked_operations == 0:
            raise AssertionError(
                "Scoreboard received no completed operations from the monitor"
            )

        if self.errors:
            raise AssertionError(
                f"Scoreboard found {len(self.errors)} result mismatch(es)"
            )

        self.logger.info(
            "Coverage: K values=%s, data classes=%s, signed corners=%s",
            sorted(self.k_values),
            sorted(self.value_classes),
            sorted(self.corner_values),
        )


