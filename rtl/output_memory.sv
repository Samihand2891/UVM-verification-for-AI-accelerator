module output_memory #(
    parameter int ROWS   = 4,
    parameter int COLS   = 4,
    parameter int ACC_W  = 32,
    parameter int DEPTH  = ROWS * COLS,
    parameter int ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  logic                        clk,
    input  logic                        rst_n,
    input  logic                        capture,
    input  logic                        busy,
    input  logic [DEPTH*ACC_W-1:0]      c_flat,
    input  logic [ADDR_W-1:0]           read_addr,
    output logic signed [ACC_W-1:0]     read_data,
    output logic                        result_valid
);

    logic signed [ACC_W-1:0] mem [0:DEPTH-1];
    logic result_stored;

    // Hide old results during a new operation. A captured result becomes
    // visible when the controller deasserts busy.
    assign result_valid = result_stored && !busy;

    // Capture all result words in parallel. c_flat is row-major:
    // word (i*COLS+j) contains C[i][j].
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_stored <= 1'b0;
        end else if (capture) begin
            for (int word_idx = 0; word_idx < DEPTH; word_idx++) begin
                mem[word_idx] <= c_flat[word_idx*ACC_W +: ACC_W];
            end
            result_stored <= 1'b1;
        end
    end

    // Combinational read port. Data is zero until a result is valid.
    always_comb begin
        read_data = '0;
        if (result_valid && (read_addr < DEPTH))
            read_data = mem[read_addr];
    end

endmodule
