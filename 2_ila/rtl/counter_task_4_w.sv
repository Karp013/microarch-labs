module counter_task4_w(
  input  logic clk_i,
  input  logic rstn_i,

  input  logic [7:0] counter1_max_i,
  input  logic [7:0] counter2_max_i,

  (* MARK_DEBUG = "TRUE" *) output logic [7:0] counter1_o,
  (* MARK_DEBUG = "TRUE" *) output logic [7:0] counter2_o
);

    (* MARK_DEBUG = "TRUE" *) logic [7:0] counter11_o;
    (* MARK_DEBUG = "TRUE" *) logic [7:0] counter22_o;

    vio_0 vio_inst (
        .clk(clk_i),
        .probe_out0(counter11_o),
        .probe_out1(counter22_o)
    );


    counter_task4 inst0 (
    .clk_i(clk_i),
    .rstn_i(rstn_i),

    .counter1_max_i(counter11_o),
    .counter2_max_i(counter22_o),  
    .counter1_o    (counter1_o),
    .counter2_o    (counter2_o)
    );

endmodule