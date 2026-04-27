module associative_array 
#( 
parameter ADDR_WIDTH = 11,
parameter DATA_WIDTH = 3,
parameter SETS = 8,
parameter WAYS = 2
)
(
input  logic                  clk_i,
input  logic                  re,
input  logic [ADDR_WIDTH-1:0] addr_i,
input  logic [DATA_WIDTH-1:0] data_i,
input  logic                  we_i,
input  logic                  en_i,
output logic                  hit_o,
output logic [DATA_WIDTH-1:0] data_o
);

    localparam SET_WIDTH = $clog2(SETS);
    localparam TAG_WIDTH = ADDR_WIDTH - SET_WIDTH;

    logic [WAYS-1 : 0] valid;
    logic [WAYS-1 : 0] hit;

    logic [TAG_WIDTH  - 1 : 0] tag [WAYS];
    logic [DATA_WIDTH - 1 : 0] data [WAYS];

    logic [(SET_WIDTH > 0 ? SET_WIDTH-1 : 0) : 0] set;


    logic [TAG_WIDTH - 1 : 0] addr_tag;
    logic [TAG_WIDTH - 1 : 0] addr_tag_ff;

    assign set = (SET_WIDTH > 0) ? addr_i[0 +: SET_WIDTH] : 1'b0;
    assign addr_tag = addr_i[SET_WIDTH +: TAG_WIDTH]; 

     
    bram_1p_no_change #(
    .RAM_WIDTH     ( WAYS ),
    .RAM_ADDR_BITS ( (SET_WIDTH > 0) ? SET_WIDTH : 1 ),
    .INIT_FILE     ( "state.mem")
    ) 
    state_ram
    (
    .clk_i  (clk_i),
    .addr_i (set),
    .data_i (data_i),
    .we_i   (we_i),
    .en_i   (en_i),
    .data_o (valid)
    );


    genvar i;
    generate
        for (i = 0; i < WAYS; i++) begin : tag_way
            bram_1p_no_change #(
            .RAM_WIDTH     ( TAG_WIDTH ),
            .RAM_ADDR_BITS ( (SET_WIDTH > 0) ? SET_WIDTH : 1 ),
            .INIT_FILE     ( $sformatf("tag%0d.mem", i))
            ) 
            tag_ram
            (
            .clk_i  (clk_i),
            .addr_i (set),
            .data_i (data_i),
            .we_i   (we_i),
            .en_i   (en_i),
            .data_o (tag[i])
            );
        end
    endgenerate


    generate
        for (i = 0; i < WAYS; i++) begin : data_way
            bram_1p_no_change #(
            .RAM_WIDTH     ( DATA_WIDTH ),
            .RAM_ADDR_BITS ( (SET_WIDTH > 0) ? SET_WIDTH : 1 ),
            .INIT_FILE     ( $sformatf("data%0d.mem", i))
            ) 
            data_ram
            (
            .clk_i  (clk_i),
            .addr_i (set),
            .data_i (data_i ),
            .we_i   (we_i),
            .en_i   (en_i),
            .data_o (data[i])
            );
        end
    endgenerate


    always_ff @(posedge clk_i) begin
        addr_tag_ff <= addr_tag;
    end


    generate
        for (i = 0; i < WAYS; i++) begin
            assign hit[i] = (addr_tag_ff == tag[i]) && valid[i];
        end
        always_comb begin
            data_o = data[0];
            for (int i = 0; i < WAYS; i++) begin
                if (hit[i]) begin
                    data_o = data[i]; // |  
                end
            end
        end
    endgenerate


    assign hit_o = |hit;


    always_comb begin
        multi_hit_check: assert ($onehot0(hit))
            else $error("Multi-hit detected! Vector hit = %b", hit);
    end

endmodule