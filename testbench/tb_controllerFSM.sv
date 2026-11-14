`timescale 1ns/1ps

module tb_controllerFSM;

    parameter int K_MAX = 64;
    parameter int K_COUNT_W = (K_MAX <= 1) ? 1 : $clog2(K_MAX + 1);
    parameter int K_IDX_W   = (K_MAX <= 1) ? 1 : $clog2(K_MAX);

    logic                 clk = 1'b0;
    logic                 rst_n;
    logic                 start;
    logic [K_COUNT_W-1:0] k_len;
    logic                 array_done;

    logic [K_IDX_W-1:0]   read_k;
    logic                 in_valid;
    logic                 in_first;
    logic                 in_last;

    logic                 result_capture;
    logic                 busy;
    logic                 done;
    logic                 error;

always #5 clk = ~clk;

controllerFSM #(.K_MAX(K_MAX), .K_COUNT_W(K_COUNT_W), .K_IDX_W(K_IDX_W)) dut (
    .clk,
    .rst_n,
    .start,
    .k_len,
    .array_done,
    .read_k,
    .in_valid,
    .in_first,
    .in_last,
    .result_capture,
    .busy,
    .done,
    .error
);



task automatic check_feed(input int expected_k, input int test_k);
        if (in_valid !== 1'b1)
            $fatal(1, "in_valid was not high for K index %0d", expected_k);

        if (read_k !== K_IDX_W'(expected_k))
            $fatal(1, "read_k=%0d, expected %0d", read_k, expected_k);

        if (in_first !== (expected_k == 0))
            $fatal(1, "Incorrect in_first at K index %0d", expected_k);

        if (in_last !== (expected_k == test_k - 1))
            $fatal(1, "Incorrect in_last at K index %0d", expected_k);

        if (busy !== 1'b1)
            $fatal(1, "busy was not high while feeding");
    endtask

    task automatic run_valid_k(input int test_k);
        // Send a one-cycle start pulse while idle.
        @(negedge clk);
        k_len = K_COUNT_W'(test_k);
        start = 1'b1;

        @(posedge clk);
        #1;
        start = 1'b0;

        // Check every K slice, including first and last markers.
        for (int k = 0; k < test_k; k++) begin
            check_feed(k, test_k);
            @(posedge clk);
            #1;
        end

        // The controller should now wait for the systolic array.
        if (in_valid !== 1'b0 || busy !== 1'b1 || done !== 1'b0)
            $fatal(1, "Incorrect outputs while waiting for array_done");

        // Mimic the systolic array's done pulse.
        @(negedge clk);
        array_done = 1'b1;

        @(posedge clk);
        #1;
        array_done = 1'b0;

        if (result_capture !== 1'b1)
            $fatal(1, "result_capture did not assert after array_done");

        // The output memory captures at this edge.
        @(posedge clk);
        #1;

        if (result_capture !== 1'b0 || done !== 1'b1 || busy !== 1'b0)
            $fatal(1, "Incorrect COMPLETE-state outputs");

        // done should last one cycle.
        @(posedge clk);
        #1;

        if (done !== 1'b0 || busy !== 1'b0)
            $fatal(1, "done did not deassert after one cycle");
    endtask

    task automatic check_invalid_k(input logic [K_COUNT_W-1:0] bad_k);
        @(negedge clk);
        k_len = bad_k;
        start = 1'b1;

        @(posedge clk);
        #1;
        start = 1'b0;

        if (error !== 1'b1)
            $fatal(1, "Expected error for invalid K=%0d", bad_k);

        if (in_valid !== 1'b0 || done !== 1'b0 || busy !== 1'b0)
            $fatal(1, "Controller started an invalid K operation");

        @(posedge clk);
        #1;

        if (error !== 1'b0)
            $fatal(1, "error should be a one-cycle pulse");
    endtask

    initial begin
        rst_n      = 1'b0;
        start      = 1'b0;
        k_len      = '0;
        array_done = 1'b0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        run_valid_k(1);
        run_valid_k(3);
        run_valid_k(64);

        check_invalid_k(0);
        check_invalid_k(65);

        $display("PASS: controller FSM (K=1, 3, 64; invalid K=0, 65)");
        $finish;
    end

endmodule

