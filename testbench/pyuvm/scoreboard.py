from pyuvm import uvm_subscriber


class AcceleratorScoreboard(uvm_subscriber) :
    def build_phase(self):
        self.checked_operations =0
        self.errors = []

    def write(self , observed):
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


