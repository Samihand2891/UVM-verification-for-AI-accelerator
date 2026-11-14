`timescale 1ns/1ps

module tb_top;

    localparam int ROWS       = 4;
    localparam int COLS       = 4;
    localparam int IN_W       = 8;
    localparam int ACC_W      = 32;
    localparam int K_MAX      = 64;
    localparam int K_COUNT_W  = $clog2(K_MAX + 1);
    localparam int K_IDX_W    = $clog2(K_MAX);
    localparam int ROW_IDX_W  = $clog2(ROWS);
    localparam int COL_IDX_W  = $clog2(COLS);
    localparam int OUT_DEPTH  = ROWS * COLS;
    localparam int OUT_ADDR_W = $clog2(OUT_DEPTH);
    localparam int LANES      = (ROWS > COLS) ? ROWS : COLS;

    logic clk = 1'b0;
    logic rst_n;

    logic a_we;
    logic [ROW_IDX_W-1:0] a_row;
    logic [K_IDX_W-1:0] a_k;
    logic [IN_W-1:0] a_wdata;

    logic b_we;
    logic [K_IDX_W-1:0] b_k;
    logic [COL_IDX_W-1:0] b_col;
    logic [IN_W-1:0] b_wdata;

    logic start;
    logic [K_COUNT_W-1:0] k_len;
    logic busy;
    logic done;
    logic error;

    logic [OUT_ADDR_W-1:0] result_addr;
    logic signed [ACC_W-1:0] result_data;
    logic result_valid;

    logic signed [IN_W-1:0] a_matrix [0:ROWS-1][0:K_MAX-1];
    logic signed [IN_W-1:0] b_matrix [0:K_MAX-1][0:COLS-1];
    logic signed [ACC_W-1:0] expected [0:OUT_DEPTH-1];

    always #5 clk = ~clk;

    top #(
        .ROWS(ROWS),
        .COLS(COLS),
        .IN_W(IN_W),
        .ACC_W(ACC_W),
        .K_MAX(K_MAX)
    ) dut (
        .clk,
        .rst_n,
        .a_we,
        .a_row,
        .a_k,
        .a_wdata,
        .b_we,
        .b_k,
        .b_col,
        .b_wdata,
        .start,
        .k_len,
        .busy,
        .done,
        .error,
        .result_addr,
        .result_data,
        .result_valid
    );

    task automatic prepare_matrices(input int test_k, input bit use_corners);
        for (int i = 0; i < ROWS; i++) begin
            for (int k = 0; k < test_k; k++) begin
                if (use_corners)
                    a_matrix[i][k] = (((i + k) % 2) == 0) ? 8'sd127 : -8'sd128;
                else
                    a_matrix[i][k] = ((i*7 + k*3) % 17) - 8;
            end
        end

        for (int k = 0; k < test_k; k++) begin
            for (int j = 0; j < COLS; j++) begin
                if (use_corners)
                    b_matrix[k][j] = (((k + j) % 2) == 0) ? -8'sd128 : 8'sd127;
                else
                    b_matrix[k][j] = ((k*5 + j*3) % 19) - 9;
            end
        end
    endtask

    task automatic write_matrices(input int test_k);
        // The input buffer has independent A and B write ports. Use both
        // simultaneously to load one A element and one B element per cycle.
        for (int k = 0; k < test_k; k++) begin
            for (int lane = 0; lane < LANES; lane++) begin
                @(negedge clk);

                a_we = (lane < ROWS);
                if (lane < ROWS) begin
                    a_row   = ROW_IDX_W'(lane);
                    a_k     = K_IDX_W'(k);
                    a_wdata = a_matrix[lane][k];
                end

                b_we = (lane < COLS);
                if (lane < COLS) begin
                    b_k     = K_IDX_W'(k);
                    b_col   = COL_IDX_W'(lane);
                    b_wdata = b_matrix[k][lane];
                end

                @(posedge clk);
                #1;
                a_we = 1'b0;
                b_we = 1'b0;
            end
        end
    endtask

    task automatic calculate_expected(input int test_k);
        longint signed sum;

        for (int i = 0; i < ROWS; i++) begin
            for (int j = 0; j < COLS; j++) begin
                sum = 0;
                for (int k = 0; k < test_k; k++)
                    sum += longint'(a_matrix[i][k]) * longint'(b_matrix[k][j]);

                expected[i*COLS + j] = ACC_W'(sum);
            end
        end
    endtask

    task automatic run_matrix(input int test_k, input bit use_corners);
        int timeout_cycles;

        prepare_matrices(test_k, use_corners);
        write_matrices(test_k);
        calculate_expected(test_k);

        // Start only after all required matrix elements are loaded.
        @(negedge clk);
        k_len = K_COUNT_W'(test_k);
        start = 1'b1;

        @(posedge clk);
        #1;
        start = 1'b0;

        if (busy !== 1'b1)
            $fatal(1, "Controller did not enter busy for K=%0d", test_k);
        if (result_valid !== 1'b0)
            $fatal(1, "Old result remained valid while a new job was running");
        if (error !== 1'b0)
            $fatal(1, "Unexpected controller error for K=%0d", test_k);

        timeout_cycles = 0;
        while ((done !== 1'b1) && (timeout_cycles < 200)) begin
            @(posedge clk);
            #1;
            timeout_cycles++;
        end

        if (done !== 1'b1)
            $fatal(1, "Timed out waiting for completion at K=%0d", test_k);
        if (busy !== 1'b0)
            $fatal(1, "busy should be low when done is asserted");
        if (result_valid !== 1'b1)
            $fatal(1, "Result memory did not become valid at completion");

        for (int word_idx = 0; word_idx < OUT_DEPTH; word_idx++) begin
            result_addr = OUT_ADDR_W'(word_idx);
            #1;

            if (result_data !== expected[word_idx]) begin
                $fatal(1,
                    "K=%0d result[%0d][%0d] got %0d expected %0d",
                    test_k, word_idx/COLS, word_idx%COLS,
                    result_data, expected[word_idx]);
            end
        end

        // Let the one-cycle done pulse return the controller to idle.
        @(posedge clk);
        #1;
        if ((done !== 1'b0) || (busy !== 1'b0))
            $fatal(1, "Controller did not return to idle after completion");
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
        if ((busy !== 1'b0) || (done !== 1'b0))
            $fatal(1, "Invalid K request should not start an operation");

        @(posedge clk);
        #1;
        if (error !== 1'b0)
            $fatal(1, "error should be a one-cycle pulse");
    endtask

    task automatic check_reset_during_operation;
        prepare_matrices(3, 1'b0);
        write_matrices(3);

        @(negedge clk);
        k_len = K_COUNT_W'(3);
        start = 1'b1;

        @(posedge clk);
        #1;
        start = 1'b0;
        if (busy !== 1'b1)
            $fatal(1, "Expected busy before interrupting the operation");

        @(posedge clk);
        #1;
        @(negedge clk);
        rst_n = 1'b0;
        #1;

        if ((busy !== 1'b0) || (done !== 1'b0) || (result_valid !== 1'b0))
            $fatal(1, "Reset did not abort the operation and invalidate results");

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
    endtask

    initial begin
        rst_n          = 1'b0;
        a_we           = 1'b0;
        a_row          = '0;
        a_k            = '0;
        a_wdata        = '0;
        b_we           = 1'b0;
        b_k            = '0;
        b_col          = '0;
        b_wdata        = '0;
        start          = 1'b0;
        k_len          = '0;
        result_addr    = '0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        check_invalid_k(0);
        check_invalid_k(65);

        run_matrix(1, 1'b1);
        run_matrix(3, 1'b0);
        run_matrix(64, 1'b1);

        check_reset_during_operation();
        run_matrix(3, 1'b0);

        $display("PASS: integrated accelerator (K=1, 3, 64; invalid K; reset recovery)");
        $finish;
    end

endmodule
