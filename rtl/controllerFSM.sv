module controllerFSM #(
    parameter int K_MAX = 64,
    parameter int K_COUNT_W = (K_MAX <= 1) ? 1 : $clog2(K_MAX + 1),
    parameter int K_IDX_W   = (K_MAX <= 1) ? 1 : $clog2(K_MAX)
) (
    input  logic                 clk,
    input  logic                 rst_n,

    input  logic                 start,
    input  logic [K_COUNT_W-1:0] k_len,
    input  logic                 array_done,

    output logic [K_IDX_W-1:0]   read_k,
    output logic                 in_valid,
    output logic                 in_first,
    output logic                 in_last,

    output logic                 result_capture,
    output logic                 busy,
    output logic                 done,
    output logic                 error
);

    typedef enum logic [2:0] {
        S_IDLE,
        S_FEED,
        S_WAIT_ARRAY,
        S_CAPTURE,
        S_COMPLETE
    } state_t;

    state_t state;

    logic [K_COUNT_W-1:0] active_k;
    logic [K_IDX_W-1:0]   k_idx;
    logic [K_IDX_W-1:0]   last_k_idx;

    localparam logic [K_COUNT_W-1:0] K_MAX_COUNT = K_MAX;

    // K is a count; the last buffer address is K-1.
    // For K=64, last_k_idx is 63.
    assign last_k_idx = active_k - 1'b1;

    // State and counter updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            active_k <= '0;
            k_idx    <= '0;
            error    <= 1'b0;
        end else begin
            error <= 1'b0;

            case (state)
                S_IDLE: begin
                    k_idx <= '0;

                    if (start) begin
                        if ((k_len == 0) || (k_len > K_MAX_COUNT)) begin
                            error <= 1'b1;
                        end else begin
                            active_k <= k_len;
                            state    <= S_FEED;
                        end
                    end
                end

                S_FEED: begin
                    if (k_idx == last_k_idx) begin
                        state <= S_WAIT_ARRAY;
                    end else begin
                        k_idx <= k_idx + 1'b1;
                    end
                end

                S_WAIT_ARRAY: begin
                    if (array_done)
                        state <= S_CAPTURE;
                end

                S_CAPTURE: begin
                    state <= S_COMPLETE;
                end

                S_COMPLETE: begin
                    state <= S_IDLE;
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // Outputs depend on the current state
    always_comb begin
        read_k         = '0;
        in_valid       = 1'b0;
        in_first       = 1'b0;
        in_last        = 1'b0;
        result_capture = 1'b0;
        busy           = 1'b0;
        done           = 1'b0;

        case (state)
            S_FEED: begin
                read_k   = k_idx;
                in_valid = 1'b1;
                in_first = (k_idx == 0);
                in_last  = (k_idx == last_k_idx);
                busy     = 1'b1;
            end

            S_WAIT_ARRAY: begin
                busy = 1'b1;
            end

            S_CAPTURE: begin
                result_capture = 1'b1;
                busy           = 1'b1;
            end

            S_COMPLETE: begin
                done = 1'b1;
            end

            default: begin
                // S_IDLE: outputs remain inactive
            end
        endcase
    end

endmodule