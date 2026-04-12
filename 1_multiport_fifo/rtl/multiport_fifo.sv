`timescale 1ns / 1ps

module multiport_fifo#(
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 8
    )(
    // write
    input  logic clk_i,
    input  logic rstn_i,
 
    input  logic                          w_valid_i,
    input  logic [2 * DATA_WIDTH - 1 : 0] w_data_i,
    output logic                          w_ready_o,
  

    // read 0
    input  logic                      r1_ready_i,
    output logic                      r1_valid_o,
    output logic                      r1_user_o,
    output logic [DATA_WIDTH - 1 : 0] r1_data_o,
    
    // read 1
    input  logic                      r2_ready_i,
    output logic                      r2_valid_o,
    output logic                      r2_user_o,
    output logic [DATA_WIDTH - 1 : 0] r2_data_o
);


    logic [DATA_WIDTH - 1 : 0] ram_0 [FIFO_DEPTH];
    logic [DATA_WIDTH - 1 : 0] ram_1 [FIFO_DEPTH];

    logic [$clog2(FIFO_DEPTH) : 0] w_ptr;
    logic [$clog2(FIFO_DEPTH) : 0] r1_ptr;
    logic [$clog2(FIFO_DEPTH) : 0] r2_ptr;

    logic [$clog2(FIFO_DEPTH) - 1 : 0] w_ptr_true;
    logic [$clog2(FIFO_DEPTH) - 1 : 0] r1_ptr_true;
    logic [$clog2(FIFO_DEPTH) - 1 : 0] r2_ptr_true;

    logic w_hs;
    logic r1_hs;
    logic r2_hs;
    logic r12_hs;
    logic fifo1_full;
    logic fifo2_full;
    logic fifo_full;
    logic fifo1_empty;
    logic fifo2_empty;
    logic [1:0] ball;


    assign w_hs  = w_valid_i  && w_ready_o;
    assign r1_hs = r1_ready_i && r1_valid_o;
    assign r2_hs = r2_ready_i && r2_valid_o;
    assign r12_hs = r1_hs && r2_hs;

    assign w_ptr_true  = w_ptr [$clog2(FIFO_DEPTH)-1:0];
    assign r1_ptr_true = r1_ptr[$clog2(FIFO_DEPTH)-1:0];
    assign r2_ptr_true = r2_ptr[$clog2(FIFO_DEPTH)-1:0];


    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            w_ptr <= '0;
        end 
        else if (w_hs && !fifo_full) begin
            ram_0[w_ptr_true] <= w_data_i[DATA_WIDTH - 1 : 0];
            ram_1[w_ptr_true] <= w_data_i[2*DATA_WIDTH - 1 : DATA_WIDTH];
            w_ptr <= w_ptr + 1'b1;
        end
    end


    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            r1_ptr <= '0;
        end 
        else if (r1_hs && !fifo1_empty && (ball[0] || r12_hs)) begin
            r1_ptr <= r1_ptr + 1'b1;
        end
        
    end


    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            r2_ptr <= '0;
        end 
        else if (r2_hs && !fifo2_empty && (ball[1] || r12_hs)) begin
            r2_ptr <= r2_ptr + 1'b1;
        end
    end


    always_ff @(posedge clk_i) begin
        if (!rstn_i) begin
            ball <= 2'b01;
        end 
        else if ( r1_hs && !r12_hs && (ball == 2'b01)) begin
            ball <= 2'b10;
        end
        else if ( r2_hs && !r12_hs && (ball == 2'b10) ) begin
            ball <= 2'b01;
        end
    end

    assign {r2_user_o, r1_user_o} = ball;


    assign fifo1_full  = (w_ptr[$clog2(FIFO_DEPTH) - 1] != r1_ptr[$clog2(FIFO_DEPTH) - 1]) && (w_ptr_true == r1_ptr_true);
    assign fifo2_full  = (w_ptr[$clog2(FIFO_DEPTH) - 1] != r2_ptr[$clog2(FIFO_DEPTH) - 1]) && (w_ptr_true == r2_ptr_true);
    assign fifo_full  = fifo1_full || fifo2_full;

    assign fifo1_empty = (w_ptr == r1_ptr);
    assign fifo2_empty = (w_ptr == r2_ptr);

    assign w_ready_o = !fifo_full || ( r12_hs && (ball == 2'b01));


    assign r1_valid_o = !fifo1_empty;
    assign r2_valid_o = !fifo2_empty;


    assign r1_data_o = ram_0[r1_ptr_true];
    assign r2_data_o = ram_1[r2_ptr_true];

endmodule
