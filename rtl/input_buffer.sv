module input_buffer #(
    parameter int ROWS  = 4,
    parameter int COLS  = 4,
    parameter int IN_W  = 8,
    parameter int K_MAX = 64
) (
    input  logic                     clk,
    input  logic                     rst_n,

    // Write one A element: A[a_row][a_k]
    input  logic                     a_we,
    input  logic [((ROWS <= 1) ? 1 : $clog2(ROWS))-1:0] a_row,
    input  logic [((K_MAX <= 1) ? 1 : $clog2(K_MAX))-1:0] a_k,
    input  logic [IN_W-1:0]          a_wdata,

    // Write one B element: B[b_k][b_col]
    input  logic                     b_we,
    input  logic [((K_MAX <= 1) ? 1 : $clog2(K_MAX))-1:0] b_k,
    input  logic [((COLS <= 1) ? 1 : $clog2(COLS))-1:0] b_col,
    input  logic [IN_W-1:0]          b_wdata,

    // Controller selects the next K slice
    input  logic [((K_MAX <= 1) ? 1 : $clog2(K_MAX))-1:0] read_k,

    // Packed slices expected by systolic.sv
    output logic [ROWS*IN_W-1:0]     a_col,
    output logic [COLS*IN_W-1:0]     b_row
);

    localparam int ROW_IDX_W = (ROWS  <= 1) ? 1 : $clog2(ROWS);
    localparam int COL_IDX_W = (COLS  <= 1) ? 1 : $clog2(COLS);
    localparam int K_IDX_W   = (K_MAX <= 1) ? 1 : $clog2(K_MAX);

    logic [IN_W-1:0] a_mem [0:ROWS-1][0:K_MAX-1];
    logic [IN_W-1:0] b_mem [0:K_MAX-1][0:COLS-1];

    // Store matrix elements. The data arrays are intentionally not reset:
    // the host/testbench must write every element that will be used.
    always_ff @(posedge clk) begin
        if (rst_n) begin
            if (a_we && (a_row < ROWS) && (a_k < K_MAX))
                a_mem[a_row][a_k] <= a_wdata;

            if (b_we && (b_k < K_MAX) && (b_col < COLS))
                b_mem[b_k][b_col] <= b_wdata;
        end
    end

    // For a selected k:
    // a_col[i] = A[i][k]
    // b_row[j] = B[k][j]
    always_comb begin
        a_col = '0;
        b_row = '0;

        if (read_k < K_MAX) begin
            for (int i = 0; i < ROWS; i++)
                a_col[i*IN_W +: IN_W] = a_mem[i][read_k];

            for (int j = 0; j < COLS; j++)
                b_row[j*IN_W +: IN_W] = b_mem[read_k][j];
        end
    end

endmodule