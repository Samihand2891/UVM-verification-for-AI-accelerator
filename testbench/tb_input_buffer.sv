`timescale 1ns/1ps

module tb_input_buffer;
    localparam int ROWS  = 4;
    localparam int COLS  = 4;
    localparam int IN_W  = 8;
    localparam int K_MAX = 6;

    localparam int ROW_IDX_W = (ROWS  <= 1) ? 1 : $clog2(ROWS);
    localparam int COL_IDX_W = (COLS  <= 1) ? 1 : $clog2(COLS);
    localparam int K_IDX_W   = (K_MAX <= 1) ? 1 : $clog2(K_MAX);

    logic clk = 0;
    logic rst_n;

    logic a_we;
    logic [ROW_IDX_W-1:0] a_row;
    logic [K_IDX_W-1:0]   a_k;
    logic [IN_W-1:0]      a_wdata;

    logic b_we;
    logic [K_IDX_W-1:0]   b_k;
    logic [COL_IDX_W-1:0] b_col;
    logic [IN_W-1:0]      b_wdata;

    logic [K_IDX_W-1:0] read_k;
    logic [ROWS*IN_W-1:0] a_col;
    logic [COLS*IN_W-1:0] b_row;

    logic [IN_W-1:0] expected_a [0:ROWS-1][0:K_MAX-1];
    logic [IN_W-1:0] expected_b [0:K_MAX-1][0:COLS-1];

    int checks = 0;

    always #5 clk = ~clk;

    input_buffer #(
        .ROWS(ROWS),
        .COLS(COLS),
        .IN_W(IN_W),
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
        .read_k,
        .a_col,
        .b_row
    );

    task automatic write_a(
        input int row_idx,
        input int k_idx,
        input logic [IN_W-1:0] value
    );
        @(negedge clk);
        a_we    = 1;
        a_row   = row_idx;
        a_k     = k_idx;
        a_wdata = value;
        @(posedge clk);
        #1;
        a_we = 0;
    endtask

    task automatic write_b(
        input int k_idx,
        input int col_idx,
        input logic [IN_W-1:0] value
    );
        @(negedge clk);
        b_we    = 1;
        b_k     = k_idx;
        b_col   = col_idx;
        b_wdata = value;
        @(posedge clk);
        #1;
        b_we = 0;
    endtask

    initial begin
        rst_n  = 0;
        a_we   = 0;
        b_we   = 0;
        a_row  = 0;
        a_k    = 0;
        b_k    = 0;
        b_col  = 0;
        a_wdata = 0;
        b_wdata = 0;
        read_k = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1;

        // Load every element of A and B with predictable values.
        for (int i = 0; i < ROWS; i++) begin
            for (int k = 0; k < K_MAX; k++) begin
                expected_a[i][k] = IN_W'(i*10 + k + 1);
                write_a(i, k, expected_a[i][k]);
            end
        end

        for (int k = 0; k < K_MAX; k++) begin
            for (int j = 0; j < COLS; j++) begin
                expected_b[k][j] = IN_W'(k*10 + j + 50);
                write_b(k, j, expected_b[k][j]);
            end
        end

        // Check that each selected K produces the correct A column and B row.
        for (int k = 0; k < K_MAX; k++) begin
            read_k = K_IDX_W'(k);
            #1;

            for (int i = 0; i < ROWS; i++) begin
                if (a_col[i*IN_W +: IN_W] !== expected_a[i][k])
                    $fatal(1, "A mismatch at row=%0d k=%0d", i, k);
                checks++;
            end

            for (int j = 0; j < COLS; j++) begin
                if (b_row[j*IN_W +: IN_W] !== expected_b[k][j])
                    $fatal(1, "B mismatch at k=%0d col=%0d", k, j);
                checks++;
            end
        end

        // K_MAX=6 uses a 3-bit read address, so 6 and 7 are out of range.
        read_k = K_IDX_W'(K_MAX);
        #1;
        if (a_col !== '0) $fatal(1, "A output should be zero for invalid read_k");
        if (b_row !== '0) $fatal(1, "B output should be zero for invalid read_k");
        checks += 2;

        read_k = K_IDX_W'(K_MAX + 1);
        #1;
        if (a_col !== '0) $fatal(1, "A output should be zero for invalid read_k");
        if (b_row !== '0) $fatal(1, "B output should be zero for invalid read_k");
        checks += 2;

        $display("PASS: input buffer (%0d checks)", checks);
        $finish;
    end
endmodule


