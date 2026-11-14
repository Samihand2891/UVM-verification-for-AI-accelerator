// Top-level integration for the buffered systolic matrix multiplier.
// The host loads all required A/B elements before pulsing start.
module top #(
    parameter int ROWS   = 4,
    parameter int COLS   = 4,
    parameter int IN_W   = 8,
    parameter int ACC_W  = 32,
    parameter int K_MAX  = 64,
    parameter bit SAT    = 0,
    parameter int K_COUNT_W = (K_MAX <= 1) ? 1 : $clog2(K_MAX + 1),
    parameter int K_IDX_W   = (K_MAX <= 1) ? 1 : $clog2(K_MAX),
    parameter int ROW_IDX_W = (ROWS <= 1) ? 1 : $clog2(ROWS),
    parameter int COL_IDX_W = (COLS <= 1) ? 1 : $clog2(COLS),
    parameter int OUT_DEPTH = ROWS * COLS,
    parameter int OUT_ADDR_W = (OUT_DEPTH <= 1) ? 1 : $clog2(OUT_DEPTH)
) (
    input  logic                         clk,
    input  logic                         rst_n,

    // Host writes one A and one B element per clock at most.
    input  logic                         a_we,
    input  logic [ROW_IDX_W-1:0]         a_row,
    input  logic [K_IDX_W-1:0]           a_k,
    input  logic [IN_W-1:0]              a_wdata,

    input  logic                         b_we,
    input  logic [K_IDX_W-1:0]           b_k,
    input  logic [COL_IDX_W-1:0]         b_col,
    input  logic [IN_W-1:0]              b_wdata,

    // Operation request and status.
    input  logic                         start,
    input  logic [K_COUNT_W-1:0]         k_len,
    output logic                         busy,
    output logic                         done,
    output logic                         error,

    // Host reads the result matrix in row-major order.
    input  logic [OUT_ADDR_W-1:0]        result_addr,
    output logic signed [ACC_W-1:0]      result_data,
    output logic                         result_valid
);

    logic [K_IDX_W-1:0] read_k;
    logic [ROWS*IN_W-1:0] a_col;
    logic [COLS*IN_W-1:0] b_row;
    logic in_valid;
    logic in_first;
    logic in_last;
    logic array_done;
    logic result_capture;
    logic [OUT_DEPTH*ACC_W-1:0] c_flat;

    input_buffer #(
        .ROWS(ROWS),
        .COLS(COLS),
        .IN_W(IN_W),
        .K_MAX(K_MAX)
    ) u_input_buffer (
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

    controllerFSM #(
        .K_MAX(K_MAX),
        .K_COUNT_W(K_COUNT_W),
        .K_IDX_W(K_IDX_W)
    ) u_controller (
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

    systolic #(
        .ROWS(ROWS),
        .COLS(COLS),
        .IN_W(IN_W),
        .ACC_W(ACC_W),
        .SAT(SAT)
    ) u_systolic (
        .clk,
        .rst_n,
        .in_valid,
        .in_first,
        .in_last,
        .a_col,
        .b_row,
        .c(c_flat),
        .done(array_done)
    );

    output_memory #(
        .ROWS(ROWS),
        .COLS(COLS),
        .ACC_W(ACC_W),
        .DEPTH(OUT_DEPTH),
        .ADDR_W(OUT_ADDR_W)
    ) u_output_memory (
        .clk,
        .rst_n,
        .capture(result_capture),
        .busy,
        .c_flat,
        .read_addr(result_addr),
        .read_data(result_data),
        .result_valid
    );

endmodule
