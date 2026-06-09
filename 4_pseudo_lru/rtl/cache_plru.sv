module cache_plru
#(
  parameter ADDR_WIDTH = 11,
  parameter DATA_WIDTH = 8,
  parameter SETS = 8,
  parameter WAYS = 2
)
(
  // cpu interface
  input  logic                  clk_i,
  input  logic                  rstn_i,
  input  logic [ADDR_WIDTH-1:0] addr_i,
  input  logic                  addr_valid_i,
  output logic                  ready_o,
  output logic                  valid_o,
  output logic [DATA_WIDTH-1:0] data_o,

  // memory interface (wishbone)
  input  logic                    ack_i,
  input  logic [DATA_WIDTH-1:0]   dat_i,
  output logic                    cyc_o,
  output logic                    stb_o,
  output logic [ADDR_WIDTH - 1:0] adr_o


);
  import plru_pkg::*;

  //---------------------------------------------------------
  // Localparams 
  //---------------------------------------------------------
  
    localparam SET_WIDTH = $clog2(SETS);
    localparam TAG_WIDTH = ADDR_WIDTH - SET_WIDTH;
    localparam STATE_WIDTH = WAYS + (WAYS - 1);


  //---------------------------------------------------------
  // Signals
  //---------------------------------------------------------
  
    logic addr_valid_d1; // a "valid" signal with a 1-cycle delay

    logic [WAYS-1 : 0] hit;

    logic [(SET_WIDTH > 0 ? SET_WIDTH-1 : 0) : 0] set; // comb set
    logic [(SET_WIDTH > 0 ? SET_WIDTH-1 : 0) : 0] set_ff;

    logic [DATA_WIDTH-1:0] data_ff;
    logic [DATA_WIDTH-1:0] cache_data;

    // state ram signals

    logic [(SET_WIDTH > 0 ? SET_WIDTH-1 : 0) : 0] state_addr_i;
    logic                                         state_we_i;
    logic [STATE_WIDTH-1:0]                       state_bit_en_i;
    logic [(SET_WIDTH > 0 ? SET_WIDTH-1 : 0) : 0] state_addr_rst_ff;
    logic [STATE_WIDTH-1:0]                       state_data_i;
    logic [STATE_WIDTH-1:0]                       state_data_o;
    logic [WAYS-1:0]                              valid_bits;

    // data ram signals
    
    logic [(SET_WIDTH > 0 ? SET_WIDTH-1 : 0) : 0] data_ram_addr_i;
    logic [DATA_WIDTH - 1 : 0]                    data_ram_data_i [WAYS];
    logic                                         data_ram_we_i [WAYS - 1:0];
    logic [DATA_WIDTH - 1 : 0]                    data_ram_data_o [WAYS];

    // tag ram signals

    logic [(SET_WIDTH > 0 ? SET_WIDTH-1 : 0) : 0] tag_addr_i;
    logic [TAG_WIDTH - 1 : 0]                     tag_data_i;
    logic                                         tag_we_i   [WAYS-1:0];
    logic [TAG_WIDTH - 1 : 0]                     tag_data_o [WAYS];
    logic [TAG_WIDTH - 1 : 0]                     tag; // comb tag
    logic [TAG_WIDTH - 1 : 0]                     tag_ff;

    // PLRU mechanism signals

    logic [WAYS-2 : 0]       plru_tree;
    logic [$clog2(WAYS)-1:0] victim_way;
    logic [$clog2(WAYS)-1:0] accessed_way;

    logic [WAYS-1:0] way_en;

    genvar i;


  assign set = (SET_WIDTH > 0) ? addr_i[0 +: SET_WIDTH] : '0;
  assign tag = addr_i[SET_WIDTH +: TAG_WIDTH];

  // -----------------------------------------------
  // Main cache fsm
  // -----------------------------------------------

    cache_state_e cache_state, cache_next;

    always_ff @(posedge clk_i or negedge rstn_i)
      if (!rstn_i) cache_state <= CACHE_RESET;
      else         cache_state <= cache_next;

    always_comb begin
      cache_next = cache_state;

      case (cache_state)
        CACHE_RESET:
          if (state_addr_rst_ff == SETS-1)
            cache_next = CACHE_WAIT_ADDR;

          CACHE_WAIT_ADDR:
            if (addr_valid_i)  
              cache_next = CACHE_WORK;

          CACHE_WORK:
            if (valid_o)  
              cache_next = CACHE_WAIT_ADDR;

          default:
            cache_next = CACHE_XXX;

      endcase
    end

    always_ff @(posedge clk_i or negedge rstn_i) begin
      if (!rstn_i) begin
        state_addr_rst_ff <= '0;
      end else

      case (cache_state)
          CACHE_WAIT_ADDR: begin
            // no action
          end

          CACHE_WORK: begin
            // no action
          end

          CACHE_RESET: begin
            state_addr_rst_ff <= state_addr_rst_ff + 1'b1;
          end
        endcase
    end

  // -----------------------------------------------
  // Wishbone fsm
  // -----------------------------------------------

    wb_state_e wb_state, wb_next;

    always_ff @(posedge clk_i or negedge rstn_i)
      if (!rstn_i) wb_state <= WB_IDLE;
      else         wb_state <= wb_next;

    always_comb begin
      wb_next = wb_state;

      case (wb_state)
        WB_IDLE:   if (!(|hit) && addr_valid_d1) wb_next = WB_ACCESS;
        WB_ACCESS: if ( ack_i) wb_next = WB_IDLE;
        default:               wb_next = WB_XXX;
      endcase
    end

    always_ff @(posedge clk_i or negedge rstn_i) begin
      if (!rstn_i) begin
        adr_o <= '0;
      end else begin

        case (wb_state)

          WB_IDLE: begin
            // no action
          end

          WB_ACCESS: begin // TODO: в таком случае теряем такт
            adr_o <= addr_i;
          end

        endcase

      end
    end

    assign cyc_o = wb_state == WB_ACCESS;
    assign stb_o = wb_state == WB_ACCESS;

    assign ready_o = (wb_state    != WB_ACCESS  ) &&
                     (cache_state == CACHE_WAIT_ADDR);

  // -----------------------------------------------
  // STATE_RAM
  // -----------------------------------------------
    
    // State ram structure
    // +-------------------+-----------------------+
    // | valid[WAYS-1:0]   | plru_tree[WAYS-2:0]   |
    // +-------------------+-----------------------+

    assign state_we_i = (cache_state == CACHE_RESET) ||
                        |hit ||
                        ((wb_state == WB_ACCESS) && ack_i);

    assign state_addr_i = (cache_state == CACHE_RESET)     ? state_addr_rst_ff :
                          (cache_state == CACHE_WAIT_ADDR) ? set               :
                          (wb_state    == WB_ACCESS  )     ? set_ff            : set_ff;


    always_comb begin : state_bit_en_comb_logic
      state_bit_en_i = '0;

      if (cache_state == CACHE_RESET)
        state_bit_en_i = '1;

      else if (|hit)
        state_bit_en_i = '1;

      else if ((wb_state == WB_ACCESS) && ack_i)
        state_bit_en_i = '1;

    end : state_bit_en_comb_logic


    always_comb begin : state_data_comb_logic

      if (cache_state == CACHE_RESET)
        state_data_i = '0;

      else begin
        state_data_i = state_data_o;

        if ((wb_state == WB_ACCESS) && ack_i) begin
          state_data_i[victim_way] = 1'b1; // valid bit update
          state_data_i[STATE_WIDTH-1:WAYS] = 
            plru_update(plru_tree, victim_way); // update plru tree
        end
        else if (|hit) begin
          state_data_i[STATE_WIDTH-1:WAYS] =
            plru_update(plru_tree, accessed_way); // update plru tree
        end
      end
    end : state_data_comb_logic


    assign valid_bits = state_data_o[WAYS-1:0];
    assign plru_tree  = state_data_o[STATE_WIDTH-1:WAYS];


    bram_1p_no_change #(
        .RAM_WIDTH     ( STATE_WIDTH ),
        .RAM_ADDR_BITS ( (SET_WIDTH > 0) ? SET_WIDTH : 1 )
      )
      state_ram
      (
        .clk_i   (clk_i),
        .addr_i  (state_addr_i),
        .data_i  (state_data_i),
        .we_i    (state_we_i),
        .en_i    (1),
        .bit_en_i(state_bit_en_i),
        .data_o  (state_data_o)
      );

  // -----------------------------------------------
  // TAG_RAM
  // -----------------------------------------------

    assign tag_addr_i = state_addr_i;
    assign tag_data_i = (wb_state == WB_ACCESS) ? tag_ff : tag;

    always_comb begin : tag_we_i_comb_logic
      for (int i = 0; i < WAYS; i++) begin
        tag_we_i[i] = ( (wb_state == WB_ACCESS) && ack_i && way_en[i] );
      end
    end : tag_we_i_comb_logic


    generate
      for (i = 0; i < WAYS; i++) begin : tag_way
        bram_1p_no_change #(
            .RAM_WIDTH     ( TAG_WIDTH ),
            .RAM_ADDR_BITS ( (SET_WIDTH > 0) ? SET_WIDTH : 1 )
          )
          tag_ram
          (
            .clk_i   (clk_i),
            .addr_i  (tag_addr_i),
            .data_i  (tag_data_i),
            .we_i    (tag_we_i[i]),
            .en_i    (1),
            .bit_en_i('1),
            .data_o  (tag_data_o[i])
          );
      end
    endgenerate

  // -----------------------------------------------
  // DATA_RAM
  // -----------------------------------------------

    assign data_ram_addr_i = state_addr_i;

    always_comb begin : data_ram_we_and_data_i_comb_logic
      for (int i = 0; i < WAYS; i++) begin
        data_ram_we_i[i] = ( (wb_state == WB_ACCESS) && ack_i ) && way_en[i];
        data_ram_data_i[i] = '0;
        if (data_ram_we_i[i])
          data_ram_data_i[i] = dat_i;
      end
    end : data_ram_we_and_data_i_comb_logic

    generate
        for (i = 0; i < WAYS; i++) begin : data_way
          bram_1p_no_change #(
              .RAM_WIDTH     ( DATA_WIDTH ),
              .RAM_ADDR_BITS ( (SET_WIDTH > 0) ? SET_WIDTH : 1 )
            )
            data_ram
            (
              .clk_i   (clk_i),
              .addr_i  (data_ram_addr_i),
              .data_i  (data_ram_data_i[i]),
              .we_i    (data_ram_we_i[i]),
              .en_i    (1),
              .bit_en_i('1),
              .data_o  (data_ram_data_o[i])
            );
        end
    endgenerate


  always_ff @(posedge clk_i) begin : tag_and_set_ff_logic
    if (!rstn_i) begin
      tag_ff <= '0;
      set_ff <= '0;
    end else if (addr_valid_i && ready_o) begin
      tag_ff <= tag;
      set_ff <= set;
    end
  end : tag_and_set_ff_logic


  always_ff @(posedge clk_i) begin : addr_valid_d1_logic
    
    if (!rstn_i)
      addr_valid_d1 <= 1'b0;
    else
      addr_valid_d1 <= ready_o && addr_valid_i;

  end : addr_valid_d1_logic

  assign valid_o = |hit || ((wb_state == WB_ACCESS) && ack_i);


  generate
    for (i = 0; i < WAYS; i++) begin : hit_array
      assign hit[i] = (addr_valid_d1 && (valid_bits[i] === 1'b1)) ? (tag_ff == tag_data_o[i]) : '0;
    end : hit_array
  endgenerate 


  always_comb begin : cache_data_comb_logic
    cache_data = data_ram_data_o[0];

    for (int i = 0; i < WAYS; i++) begin
      if (hit[i])
        cache_data = data_ram_data_o[i];
    end
  end : cache_data_comb_logic


  always_ff @(posedge clk_i) begin : data_ff_logic
    if (!rstn_i)
      data_ff <= '0;
    else begin
      if (|hit)
        data_ff <= cache_data;

      if ((wb_state == WB_ACCESS) && ack_i)
        data_ff <= dat_i;
    end
  end : data_ff_logic


  assign data_o = (wb_state == WB_ACCESS && ack_i) ? dat_i : data_ff;
  
  
  always_comb begin : accessed_way_comb_logic 
    accessed_way = victim_way;
    
    for (int i = 0; i < WAYS; i++) begin
      if (hit[i])
      accessed_way = i;
    end
  end : accessed_way_comb_logic 
  
  assign victim_way = plru_get_victim(plru_tree);
  
  always_comb begin : way_en_comb_logic

    way_en = '0;

    if ((wb_state == WB_ACCESS) && ack_i)
      way_en[victim_way] = 1'b1;

  end : way_en_comb_logic


  always_comb begin
    multi_hit_check: assert ($onehot0(hit))
      else $error("Multi-hit detected! Vector hit = %b", hit);
  end


endmodule : cache_plru
