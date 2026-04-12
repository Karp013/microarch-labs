`timescale 1ns/1ps

module tb2();

    localparam ADDR_WIDTH = 11;
    localparam DATA_WIDTH = 3;
    localparam SETS = 8;
    localparam WAYS = 2;

    logic [ADDR_WIDTH:0]   addr;
    logic                  en;
    logic                  hit;
    logic [DATA_WIDTH-1:0] data;
    
    
    bit clk = 1; 
    initial begin 
        clk <= '0;
        forever #(10/2) clk = ~clk;
    end


    associative_array 
    #( 
        .ADDR_WIDTH(11),
        .DATA_WIDTH(3),
        .SETS(8),
        .WAYS(2)
    )
    DUT
    (
        .clk_i  (clk),
        .addr_i (addr),
        .data_i (data),
        .we_i   ('0),
        .en_i   ('1),
        .hit_o  (hit),
        .data_o (data)
    );

    initial begin
        repeat (2) @(posedge clk);

        // hit в way 0
        addr <= { 8'h12 , 3'h3};
        @(posedge clk);

        // hit в way 1
        addr <= { 8'h1D , 3'h5};
        @(posedge clk);

        // miss - tag matches, valid = 0
        addr <= { 8'h1A , 3'h1};
        @(posedge clk);

        // miss - tag does not matches
        addr <= { 8'hFF , 3'h7};
        @(posedge clk);
    end


endmodule