module counter_task1 (
    input  logic clk_i,
    input  logic rstn_i,
    (* MARK_DEBUG = "TRUE" *) input  logic en_i,
    (* MARK_DEBUG = "TRUE" *) output logic [7:0] cnt_o
);
    logic [7:0] cnt_ff;

    always_ff @(posedge clk_i) begin
        if(!rstn_i) begin
            cnt_ff <= '0;
        end else if (en_i) begin
            cnt_ff <= cnt_ff + 1'b1;
        end
    end

    assign cnt_o = cnt_ff;
endmodule