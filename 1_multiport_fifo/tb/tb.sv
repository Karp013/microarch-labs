`timescale 1ns / 1ps

module tb();
    parameter DATA_WIDTH = 32;
    parameter FIFO_DEPTH = 4;

    bit clk = 1;
    bit rst;

    bit                        w_valid;
    bit [2*DATA_WIDTH - 1 : 0] w_data;
    bit                        w_ready;
    bit                        r1_ready;
    bit                        r1_valid;
    bit                        r1_user;
    bit [DATA_WIDTH - 1 : 0]   r1_data;
    bit                        r2_ready;
    bit                        r2_valid;
    bit                        r2_user;
    bit [DATA_WIDTH - 1 : 0]   r2_data;
    
    bit [DATA_WIDTH - 1 : 0] w1_data;
    bit [DATA_WIDTH - 1 : 0] w2_data;

    initial begin
        clk <= '0;
        forever #(10/2) clk = ~clk;    
    end

    initial begin
        rst <= 0;
        repeat(2) @(posedge clk);
        rst <= 1;
    end


    multiport_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
        )
        DUT (
        // write
        .clk_i  (clk),
        .rstn_i (rst),
    
        .w_valid_i (w_valid),
        .w_data_i  ({w2_data, w1_data}),
        .w_ready_o (w_ready),
    

        // read 0
        .r1_ready_i (r1_ready),
        .r1_valid_o (r1_valid),
        .r1_user_o  (r1_user),
        .r1_data_o  (r1_data),
        
        // read 1
        .r2_ready_i (r2_ready),
        .r2_valid_o (r2_valid),
        .r2_user_o  (r2_user),
        .r2_data_o  (r2_data)
    );


    initial begin
        wait(!rst);
        wait(rst);


        // 1) всё записали всё считали
        repeat(FIFO_DEPTH) begin
            w_valid <= 1;
            r1_ready <= 0;
            r2_ready <= 0;
            w1_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            w2_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            @(posedge clk);
        end

        repeat(FIFO_DEPTH) begin
            w_valid  <= 0;
            r1_ready <= 1;
            r2_ready <= 1;
            @(posedge clk);
        end

        repeat (10) @(posedge clk);

        // 2) записали считали, записали считали
        repeat(15) begin
            w_valid <= 1;
            r1_ready <= 0;
            r2_ready <= 0;
            w1_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            w2_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            @(posedge clk);

            w_valid  <= 0;
            r1_ready <= 1;
            r2_ready <= 1;
            @(posedge clk);
        end

        repeat(10) @(posedge clk);

        // 3) записали до almost full
        repeat(FIFO_DEPTH - 1 ) begin
            w_valid <= 1;
            r1_ready <= 0;
            r2_ready <= 0;
            w1_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            w2_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            @(posedge clk);
        end

        // 4) считали до almost empty
        repeat(FIFO_DEPTH - 1 - 1) begin
            w_valid <= 0;
            r1_ready <= 1;
            r2_ready <= 1;
            w1_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            w2_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            @(posedge clk);
        end

        repeat(10) @(posedge clk);

        // 5) записал ready только на 1
        repeat(FIFO_DEPTH) begin
            w_valid <= 1;
            r1_ready <= 0;
            r2_ready <= 0;
            w1_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            w2_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            @(posedge clk);
        end

        repeat(FIFO_DEPTH) begin
            w_valid  <= 0;
            r1_ready <= 1;
            r2_ready <= 0;
            @(posedge clk);
        end

        repeat(10) @(posedge clk);

        // 6) записал ready только на 2
        repeat(FIFO_DEPTH) begin
            w_valid <= 1;
            r1_ready <= 0;
            r2_ready <= 0;
            w1_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            w2_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            @(posedge clk);
        end

        repeat(FIFO_DEPTH) begin
            w_valid  <= 0;
            r1_ready <= 0;
            r2_ready <= 1;
            @(posedge clk);
        end

        repeat(10) @(posedge clk);

        // 7) записал ready чередуется
        repeat(FIFO_DEPTH) begin
            w_valid <= 1;
            r1_ready <= 0;
            r2_ready <= 0;
            w1_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            w2_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            @(posedge clk);
        end

        repeat(FIFO_DEPTH / 2) begin
            w_valid  <= 0;
            r1_ready <= 0;
            r2_ready <= 1;
            @(posedge clk);
            w_valid  <= 0;
            r1_ready <= 1;
            r2_ready <= 0;
            @(posedge clk);
        end


        repeat(10) @(posedge clk);

        // 8) full random
        repeat(10) begin
            w_valid  <= $urandom_range(1, 10);
            r1_ready <= $urandom_range(1, 10);
            r2_ready <= $urandom_range(1, 10);
            w1_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            w2_data[DATA_WIDTH - 1 : 0] <= $urandom_range(1, 10);
            @(posedge clk);
        end



        $finish();
    end



endmodule
