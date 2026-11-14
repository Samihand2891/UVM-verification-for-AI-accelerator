`timescale 1ns/1ps

module tb_output_memory;

    localparam int ROWS   = 4;
    localparam int COLS   = 4;
    localparam int ACC_W  = 32;
    localparam int DEPTH  = ROWS * COLS;
    localparam int ADDR_W = $clog2(DEPTH);

    logic clk = 1'b0;
    logic rst_n;
    logic controller_busy;
    logic capture;
    logic [DEPTH*ACC_W-1:0] c_flat;
    logic [ADDR_W-1:0] host_read_addr;
    logic signed [ACC_W-1:0] host_read_data;
    logic host_result_valid;

    logic signed [ACC_W-1:0] expected [0:DEPTH-1];

    always #5 clk = ~clk;

    output_memory #(
        .ROWS(ROWS),
        .COLS(COLS),
        .ACC_W(ACC_W)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .capture      (capture),
        .busy         (controller_busy),
        .c_flat       (c_flat),
        .read_addr    (host_read_addr),
        .read_data    (host_read_data),
        .result_valid (host_result_valid)
    );

    task automatic load_and_check(input int base_value);
        // Present a new matrix and request capture while the controller is busy.
        @(negedge clk);
        controller_busy = 1'b1;

        for (int word_idx = 0; word_idx < DEPTH; word_idx++) begin
            if ((word_idx % 2) == 0)
                expected[word_idx] = base_value + word_idx * 3;
            else
                expected[word_idx] = -(base_value + word_idx * 2);

            c_flat[word_idx*ACC_W +: ACC_W] = expected[word_idx];
        end

        capture = 1'b1;
        @(posedge clk);
        #1;
        capture = 1'b0;

        if (host_result_valid !== 1'b0)
            $fatal(1, "result_valid must stay low while controller is busy");

        // The captured matrix becomes readable when busy deasserts.
        @(negedge clk);
        controller_busy = 1'b0;
        #1;

        if (host_result_valid !== 1'b1)
            $fatal(1, "result_valid did not assert after capture and busy deassertion");

        for (int word_idx = 0; word_idx < DEPTH; word_idx++) begin
            host_read_addr = ADDR_W'(word_idx);
            #1;

            if (host_read_data !== expected[word_idx]) begin
                $fatal(1,
                    "Read mismatch at address %0d: got %0d expected %0d",
                    word_idx, host_read_data, expected[word_idx]);
            end
        end
    endtask

    initial begin
        rst_n           = 1'b0;
        controller_busy = 1'b0;
        capture         = 1'b0;
        c_flat          = '0;
        host_read_addr  = '0;

        repeat (2) @(posedge clk);
        #1;

        if (host_result_valid !== 1'b0 || host_read_data !== '0)
            $fatal(1, "Outputs should be invalid/zero during reset");

        @(negedge clk);
        rst_n = 1'b1;

        // Check signed values, row-major indexing, and overwriting old results.
        load_and_check(20);
        load_and_check(100);

        // Reset invalidates stored results; stale data must not be presented.
        @(negedge clk);
        rst_n = 1'b0;
        #1;

        if (host_result_valid !== 1'b0 || host_read_data !== '0)
            $fatal(1, "Reset did not invalidate the stored result");

        $display("PASS: output memory (two full matrices, signed reads, busy gating, reset)");
        $finish;
    end

endmodule
