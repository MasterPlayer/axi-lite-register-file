`timescale 1 ns / 1 ps



module axi_register_file #(
    parameter integer DATA_WIDTH = 32          ,
    parameter integer ADDR_WIDTH = 32          ,
    parameter integer REG_COUNT  = 1           ,
    parameter integer BASEADDR   = 32'h00000000
) (
    input  logic                                      CLK          ,
    input  logic                                      RESETN       ,
    input  logic [    ADDR_WIDTH-1:0]                 AWADDR       ,
    input  logic                                      AWVALID      ,
    output logic                                      AWREADY      ,
    input  logic [    DATA_WIDTH-1:0]                 WDATA        ,
    input  logic [(DATA_WIDTH/8)-1:0]                 WSTRB        ,
    input  logic                                      WVALID       ,
    output logic                                      WREADY       ,
    output logic [               1:0]                 BRESP        ,
    output logic                                      BVALID       ,
    input  logic                                      BREADY       ,
    input  logic [    ADDR_WIDTH-1:0]                 ARADDR       ,
    input  logic                                      ARVALID      ,
    output logic                                      ARREADY      ,
    output logic [    DATA_WIDTH-1:0]                 RDATA        ,
    output logic [               1:0]                 RRESP        ,
    output logic                                      RVALID       ,
    input  logic                                      RREADY       ,
    //
    input  logic [   (REG_COUNT-1):0][DATA_WIDTH-1:0] REG_IN       ,
    input  logic [   (REG_COUNT-1):0]                 REG_IN_VALID ,
    //
    output logic [   (REG_COUNT-1):0][DATA_WIDTH-1:0] REG_OUT      ,
    output logic [   (REG_COUNT-1):0]                 REG_OUT_VALID
);


    logic [ADDR_WIDTH-1:0] axi_awaddr ;
    logic                  axi_awready;
    logic                  axi_wready ;
    logic [           1:0] axi_bresp  ;
    logic                  axi_bvalid ;
    logic [ADDR_WIDTH-1:0] axi_araddr ;
    logic                  axi_arready;
    logic [DATA_WIDTH-1:0] axi_rdata  ;
    logic [           1:0] axi_rresp  ;
    logic                  axi_rvalid ;

    localparam integer ADDR_LSB_CFG          = (DATA_WIDTH/32) + 1                ;
    localparam integer EFFECTIVE_ADDR_WIDTH  = $clog2(REG_COUNT)                  ;

    localparam integer OPT_MEM_ADDR_BITS_CFG = $clog2(REG_COUNT)                  ;
    // localparam integer HIGHADDR              = ADDR_LSB_CFG+OPT_MEM_ADDR_BITS_CFG ;
    localparam integer LOWADDR               = EFFECTIVE_ADDR_WIDTH + ADDR_LSB_CFG;

    logic [(REG_COUNT-1):0][DATA_WIDTH-1:0] register = '{default:'{default:0}};
    logic [(REG_COUNT-1):0] register_valid = '{default:0};
    logic                  slv_reg_rden;
    logic                  slv_reg_wren;
    logic [DATA_WIDTH-1:0] reg_data_out;
    logic                  aw_en       ;

    integer byte_index;

    always_comb begin
        AWREADY = axi_awready;
        WREADY  = axi_wready;
        BRESP   = axi_bresp;
        BVALID  = axi_bvalid;
        ARREADY = axi_arready;
        RDATA   = axi_rdata;
        RRESP   = axi_rresp;
        RVALID  = axi_rvalid;
    end 

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    always @( posedge CLK ) begin : axi_awready_proc
        if (~RESETN)
            axi_awready <= 1'b0;
        else    
            if (~axi_awready && AWVALID && WVALID && aw_en && (AWADDR[(ADDR_WIDTH-1):LOWADDR] == BASEADDR[(ADDR_WIDTH-1):LOWADDR]))
                axi_awready <= 1'b1;
            else 
                // if (BREADY && axi_bvalid)
                //     axi_awready <= 1'b0;
                // else
                    axi_awready <= 1'b0;
    end       

    always @( posedge CLK ) begin : aw_en_proc
        if (~RESETN)
            aw_en <= 1'b1;
        else
            if (~axi_awready && AWVALID && WVALID && aw_en)
                aw_en <= 1'b0;
            else 
                if (BREADY && axi_bvalid )
                    aw_en <= 1'b1;
    end       

    always @( posedge CLK ) begin : axi_awaddr_proc
        if (~RESETN)
            axi_awaddr <= 0;
        else
            if (~axi_awready && AWVALID && WVALID && aw_en)
                axi_awaddr <= AWADDR;
    end       

    always @( posedge CLK ) begin : axi_wready_proc
        if (~RESETN)
            axi_wready <= 1'b0;
        else    
            if (~axi_wready && WVALID && AWVALID && aw_en && (AWADDR[(ADDR_WIDTH-1):LOWADDR] == BASEADDR[(ADDR_WIDTH-1):LOWADDR]))
                axi_wready <= 1'b1;
            else
                axi_wready <= 1'b0;
    end       

    always_comb begin 
        slv_reg_wren = axi_wready && WVALID && axi_awready && AWVALID;
    end

    always @( posedge CLK ) begin : axi_bvalid_proc
        if (~RESETN)
            axi_bvalid  <= 0;
        else
            if (axi_awready && AWVALID && ~axi_bvalid && axi_wready)
                axi_bvalid <= 1'b1;
            else
                if (BREADY && axi_bvalid)
                    axi_bvalid <= 1'b0; 
    end   

    always @( posedge CLK ) begin : axi_bresp_proc
        if (~RESETN)
            axi_bresp   <= 2'b0;
        else
            if (axi_awready && AWVALID && ~axi_bvalid && axi_wready && WVALID)
                axi_bresp  <= 2'b0; // 'OKAY' response 
    end   

    always @( posedge CLK ) begin : axi_arready_proc
        if (~RESETN)
            axi_arready <= 1'b0;
        else    
            if (~axi_arready && ARVALID && (ARADDR[ADDR_WIDTH-1:LOWADDR] == BASEADDR[ADDR_WIDTH-1:LOWADDR]))
                axi_arready <= 1'b1;
            else
                axi_arready <= 1'b0;
    end       

    always @( posedge CLK ) begin : axi_araddr_proc
        if (~RESETN)
            axi_araddr  <= 32'b0;
        else    
            if (~axi_arready && ARVALID)
                axi_araddr  <= ARADDR;
    end       

    always @( posedge CLK ) begin : axi_rvalid_proc
        if (~RESETN)
            axi_rvalid <= 0;
        else
            if (axi_arready && ARVALID && ~axi_rvalid)
                axi_rvalid <= 1'b1;
            else 
                if (axi_rvalid && RREADY)
                    axi_rvalid <= 1'b0;
    end    

    always @( posedge CLK ) begin : axi_rresp_proc
        if (~RESETN)
            axi_rresp  <= 0;
        else
            if (axi_arready && ARVALID && ~axi_rvalid)
                axi_rresp  <= 2'b0; // 'OKAY' response             
    end    

    always_comb begin 
        slv_reg_rden = axi_arready & ARVALID & ~axi_rvalid;
    end 

    always @(*) begin
        reg_data_out <= register[axi_araddr[(ADDR_LSB_CFG+OPT_MEM_ADDR_BITS_CFG):ADDR_LSB_CFG]];
    end

    always @( posedge CLK ) begin
        if (~RESETN)
            axi_rdata  <= 0;
        else 
            if (slv_reg_rden) 
                axi_rdata <= reg_data_out;     // register read data
    end    
    

    generate 

        for (genvar reg_index = 0; reg_index < REG_COUNT; reg_index++) begin 
    
            always @(posedge CLK) begin : register_proc
                if (~RESETN )
                    register[reg_index] <= 0;
                else
                    if (slv_reg_wren) begin 
                        if (axi_awaddr[ADDR_LSB_CFG+OPT_MEM_ADDR_BITS_CFG:ADDR_LSB_CFG] == reg_index) begin 
                            for ( byte_index = 0; byte_index <= (DATA_WIDTH/8)-1; byte_index = byte_index + 1 ) begin 
                                if (WSTRB[byte_index] == 1 ) begin 
                                    // register[reg_index][byte_index] <= WDATA[(byte_index*8) +: 8];
                                    register[reg_index][(byte_index*8) +: 8] <= WDATA[(byte_index*8) +: 8];
                                end 
                            end 
                        end 
                    end else begin 
                        if (REG_IN_VALID[reg_index]) 
                            register[reg_index] <= REG_IN[reg_index];
                    end 
            end    

            always_ff @(posedge CLK) begin 
                if (~RESETN) begin 
                    register_valid[reg_index] <= 1'b0;
                end else begin 
                    if (slv_reg_wren) begin 
                        if (axi_awaddr[ADDR_LSB_CFG+OPT_MEM_ADDR_BITS_CFG:ADDR_LSB_CFG] == reg_index) begin 
                            register_valid[reg_index] <= 1'b1;
                        end else begin 
                            register_valid[reg_index] <= 1'b0;                         
                        end 
                    end else begin 
                        register_valid[reg_index] <= 1'b0;                         
                    end 
                end 
            end 

            always_comb begin
                REG_OUT[reg_index]       = register[reg_index];
                REG_OUT_VALID[reg_index] = register_valid[reg_index];
            end 

        end 

    endgenerate
    // generate
    //     for (genvar index = 0; index < REG_COUNT; index++) begin 
    //         always_comb begin 
    //             register[index] = REG_IN[index];
    //         end         
    //     end 
    // endgenerate




endmodule
