`timescale 1ns/1ps

// TODO: опускать cyc_o, stb_o, ready_o сразу

module tb;

  import plru_pkg::*;

  localparam SET_WIDTH  = $clog2(SETS);
  localparam TAG_WIDTH  = ADDR_WIDTH - SET_WIDTH;

  //----------------------------------------------------------
  // DUT signals
  //----------------------------------------------------------

  logic clk;
  logic rstn;

  logic [ADDR_WIDTH-1:0] addr_i;
  logic                  addr_valid_i;

  logic                  ready_o;
  logic                  valid_o;
  logic [DATA_WIDTH-1:0] data_o;

  logic                  ack_i;
  logic [DATA_WIDTH-1:0] dat_i;

  logic                  cyc_o;
  logic                  stb_o;
  logic [ADDR_WIDTH-1:0] adr_o;

  //----------------------------------------------------------
  // DUT
  //----------------------------------------------------------

  cache_plru #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .SETS       (SETS),
    .WAYS       (WAYS)
  ) dut (
    .clk_i(clk),
    .rstn_i(rstn),

    .addr_i(addr_i),
    .addr_valid_i(addr_valid_i),

    .ready_o(ready_o),
    .valid_o(valid_o),
    .data_o(data_o),

    .ack_i(ack_i),
    .dat_i(dat_i),

    .cyc_o(cyc_o),
    .stb_o(stb_o),
    .adr_o(adr_o)
  );

  //----------------------------------------------------------
  // clock
  //----------------------------------------------------------

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  //----------------------------------------------------------
  // fake memory
  //----------------------------------------------------------

  logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

  initial begin
    foreach(mem[i])
      mem[i] = i[DATA_WIDTH-1:0];
  end

  initial begin
    ack_i = 0;
    dat_i = 0;
  end

  // A simple WB slave model:
  // It sends an ACK 3 cycles after the request.
  always begin
    @(posedge clk);

    if (cyc_o && stb_o) begin
      repeat(3) @(posedge clk);

      dat_i <= mem[adr_o];
      ack_i <= 1'b1;

      @(posedge clk);

      ack_i <= 1'b0;
    end
  end

  //----------------------------------------------------------
  // helpers
  //----------------------------------------------------------
  logic [WAYS-1:0] selected_way;

  task automatic cpu_read(input string name,
      input logic [TAG_WIDTH-1:0] tag,
      input logic [SET_WIDTH-1:0] set);

    logic [ADDR_WIDTH-1:0] addr;
    logic                  exp_hit;
    logic [DATA_WIDTH-1:0] exp_data;

    begin

      addr = {tag, set};

      @(posedge clk);
      wait (ready_o);

      addr_i       <= addr;
      addr_valid_i <= 1'b1;

      @(posedge clk);

      addr_valid_i <= 1'b0;

      wait (valid_o);

      exp_data = addr[DATA_WIDTH-1:0];

      $display(
        "[%0t] %-8s tag=%02h set=%0d addr=%03h data=%02h",
        $time,
        name,
        tag,
        set,
        addr,
        data_o
      );

      if (data_o !== exp_data) begin
        $error(
          "[%0t] %-8s DATA ERROR exp=%02h got=%02h",
          $time,
          name,
          exp_data,
          data_o
        );
      end

      @(posedge clk);

    end

  endtask


  task reset_cache();
    rstn <= '0;
    repeat(2) @(posedge clk);
    rstn <= '1;
    wait(ready_o);
  endtask

  //----------------------------------------------------------
  // test
  //----------------------------------------------------------

  initial begin

    addr_i       <= '0;
    addr_valid_i <= '0;


    //----------------------------------------------------------
    // test 1 - miss and hit
    //----------------------------------------------------------
    reset_cache();
    cpu_read("A", 8'h01, 3'd0); // miss
    cpu_read("A", 8'h01, 3'd0); // hit

    //----------------------------------------------------------
    // test 2 - fill one set, all hits
    //----------------------------------------------------------
    reset_cache();
    cpu_read("A", 8'h01, 3'd0);
    cpu_read("B", 8'h02, 3'd0);
    cpu_read("C", 8'h03, 3'd0);
    cpu_read("D", 8'h04, 3'd0);

    cpu_read("A", 8'h01, 3'd0);
    cpu_read("B", 8'h02, 3'd0);
    cpu_read("C", 8'h03, 3'd0);
    cpu_read("D", 8'h04, 3'd0);

    //----------------------------------------------------------
    // test 3 - evict
    //----------------------------------------------------------
    reset_cache();
    cpu_read("A", 8'h01, 3'd0); //0 - E
    cpu_read("B", 8'h02, 3'd0); //2
    cpu_read("C", 8'h03, 3'd0); //1
    cpu_read("D", 8'h04, 3'd0); //3

    cpu_read("E", 8'h05, 3'd0); //0

    // Exactly one of A, B, C, or D must be a miss.
    cpu_read("A?", 8'h01, 3'd0); //
    cpu_read("B?", 8'h02, 3'd0);
    cpu_read("C?", 8'h03, 3'd0);
    cpu_read("E?", 8'h05, 3'd0);
    // cpu_read("E?", 8'h05, 3'd0);

    //----------------------------------------------------------
    // test 4 - another set
    //----------------------------------------------------------
    reset_cache();
    cpu_read("A0", 8'h01, 3'd0);
    cpu_read("A1", 8'h01, 3'd1);

    cpu_read("B0", 8'h02, 3'd0);
    cpu_read("B1", 8'h02, 3'd1);


    $finish;
  end

endmodule
