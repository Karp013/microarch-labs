package plru_pkg;
  
  //---------------------------------------------------------
  // Parameters
  //---------------------------------------------------------
    
    parameter int ADDR_WIDTH = 11;
    parameter int DATA_WIDTH = 8;
    parameter int SETS = 8;
    parameter int WAYS = 4;
  

  //---------------------------------------------------------
  // Typedefs
  //---------------------------------------------------------
  
    typedef enum logic [1:0] {
      CACHE_RESET,
      CACHE_WAIT_ADDR, 
      CACHE_WORK,
      CACHE_XXX = 'x
    } cache_state_e;

    typedef enum logic [1:0] {
      WB_IDLE, 
      WB_ACCESS,
      WB_XXX = 'x
    } wb_state_e;
  
  //---------------------------------------------------------
  // Function: plru_get_victim
  //---------------------------------------------------------
  
  // Returns the name of the way from which data should be extracted

    function automatic int plru_get_victim(input logic [WAYS-2:0] tree);

      int node;
      int victim;

      node   = 0;
      victim = 0;

      for (int level = 0; level < $clog2(WAYS); level++) begin

        victim = victim << 1;

        if (tree[node] == 1'b0) begin
          node = node * 2 + 1;
        end else begin
          victim |= 1;
          node = node * 2 + 2;
        end
      end

      return victim;

    endfunction


  //---------------------------------------------------------
  // Function: plru_update
  //---------------------------------------------------------
  
  // Updates plru_tree

    function automatic logic [WAYS-2:0] plru_update(input logic [WAYS-2:0] tree,
                                                    input int way);

      logic [WAYS-2:0] result;
      int node;
      int dir;

      result = tree;
      node   = 0;

      for (int level = $clog2(WAYS)-1; level >= 0; level--) begin

        dir = (way >> level) & 1;

        if (dir == 0) begin
          result[node] = 1'b1;
          node = node * 2 + 1;
        end else begin
          result[node] = 1'b0;
          node = node * 2 + 2;
        end
      end

      return result;

    endfunction


endpackage