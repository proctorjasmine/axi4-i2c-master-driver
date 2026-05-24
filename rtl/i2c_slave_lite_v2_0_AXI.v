// AXI4-lite I2C IP for Lab 4

`timescale 1 ns / 1 ps

    module i2c_AXI #
(
    parameter integer C_S_AXI_ADDR_WIDTH = 5
)
(
    // AXI-lite
    input  wire                         S_AXI_ACLK,
    input  wire                         S_AXI_ARESETN,

    // Write channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input  wire [2:0]                   S_AXI_AWPROT,
    input  wire                         S_AXI_AWVALID,
    output wire                         S_AXI_AWREADY,
    input  wire [31:0]                  S_AXI_WDATA,
    input  wire [3:0]                   S_AXI_WSTRB,
    input  wire                         S_AXI_WVALID,
    output wire                         S_AXI_WREADY,
    output wire [1:0]                   S_AXI_BRESP,
    output wire                         S_AXI_BVALID,
    input  wire                         S_AXI_BREADY,

    // Read channel
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input  wire [2:0]                   S_AXI_ARPROT,
    input  wire                         S_AXI_ARVALID,
    output wire                         S_AXI_ARREADY,
    output wire [31:0]                  S_AXI_RDATA,
    output wire [1:0]                   S_AXI_RRESP,
    output wire                         S_AXI_RVALID,
    input  wire                         S_AXI_RREADY,

    // LEDs for pointer debug
    output wire [7:0]                   LED,
    output wire test_out_enable,
    output wire test_out_data, 
    output wire i2c_data_out,
    output wire i2c_clock_out,
    input wire i2c_data_in
);

    // ------------------------------
    // Register numbers (decoded by [4:2])
    // ------------------------------
    localparam integer ADDRESS_REG   = 3'b000; // 0x00 
    localparam integer REGISTER_REG  = 3'b001; // 0x04 
    localparam integer DATA_REG_I2C  = 3'b010; // 0x08 (R/W)
    localparam integer STATUS_REG    = 3'b011; // 0x0C (RO; W1C bit3)
    localparam integer CONTROL_REG   = 3'b100; // 0x10 (R/W)

    // ------------------------------
    // AXI friendly wires/regs
    // ------------------------------
    reg         axi_awready;
    reg         axi_wready;
    reg  [1:0]  axi_bresp;
    reg         axi_bvalid;
    reg         axi_arready;
    reg [31:0]  axi_rdata;
    reg  [1:0]  axi_rresp;
    reg         axi_rvalid;

    wire                        axi_clk    = S_AXI_ACLK;
    wire                        axi_resetn = S_AXI_ARESETN;
    wire [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr = S_AXI_AWADDR;
    wire                        axi_awvalid = S_AXI_AWVALID;
    wire                        axi_wvalid  = S_AXI_WVALID;
    wire [3:0]                  axi_wstrb   = S_AXI_WSTRB;
    wire                        axi_bready  = S_AXI_BREADY;
    wire [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr = S_AXI_ARADDR;
    wire                        axi_arvalid = S_AXI_ARVALID;
    wire                        axi_rready  = S_AXI_RREADY;

    assign S_AXI_AWREADY = axi_awready;
    assign S_AXI_WREADY  = axi_wready;
    assign S_AXI_BRESP   = axi_bresp;
    assign S_AXI_BVALID  = axi_bvalid;
    assign S_AXI_ARREADY = axi_arready;
    assign S_AXI_RDATA   = axi_rdata;
    assign S_AXI_RRESP   = axi_rresp;
    assign S_AXI_RVALID  = axi_rvalid;

    // ------------------------------
    // TX FIFO instance
    // ------------------------------
    wire clk = axi_clk;
    wire rst = ~axi_resetn;

    wire       fifo_empty, fifo_full, fifo_overflow;
    wire [7:0] fifo_rd_data;
    wire [3:0] fifo_wr_index, fifo_rd_index;

    reg        fifo_wr_req;
    reg  [7:0] fifo_wr_byte;
    reg        fifo_rd_req;        
    reg        fifo_clear_overflow;

    fifo tx_fifo (
        .clk                    (clk),
        .reset                  (rst),
        .wr_data                (fifo_wr_byte),
        .wr_request             (fifo_wr_req),
        .rd_data                (fifo_rd_data),
        .rd_request             (fifo_rd_req),
        .empty                  (fifo_empty),
        .full                   (fifo_full),
        .overflow               (fifo_overflow),
        .clear_overflow_request (fifo_clear_overflow),
        .wr_index               (fifo_wr_index),
        .rd_index               (fifo_rd_index)
    );

   
    
    
    // ------------------------------
    // RX FIFO instance
    // ------------------------------
    
    wire       rx_empty, rx_full, rx_overflow;
    wire [7:0] rx_rd_data;
    wire [3:0] rx_wr_index, rx_rd_index;

    reg        rx_wr_req;
    reg  [7:0] rx_wr_byte;
    reg        rx_rd_req;        
    reg        rx_clear_overflow;

    fifo rx_fifo (
        .clk                    (clk),
        .reset                  (rst),
        .wr_data                (rx_wr_byte),
        .wr_request             (rx_wr_req),
        .rd_data                (rx_rd_data),
        .rd_request             (rx_rd_req),
        .empty                  (rx_empty),
        .full                   (rx_full),
        .overflow               (rx_overflow),
        .clear_overflow_request (rx_clear_overflow),
        .wr_index               (rx_wr_index),
        .rd_index               (rx_rd_index)
    );
    
    // LEDs show indices
    assign LED[3:0] = rx_wr_index;
    assign LED[7:4] = rx_rd_index;

    // ------------------------------
    // Write address/data handshakes
    // ------------------------------
    wire wr_add_data_valid = axi_awvalid && axi_wvalid;
    reg  aw_en;

    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            axi_awready <= 1'b0;
            aw_en       <= 1'b1;
        end else begin
            if (wr_add_data_valid && ~axi_awready && aw_en) begin
                axi_awready <= 1'b1;
                aw_en       <= 1'b0;
            end else if (axi_bready && axi_bvalid) begin
                aw_en       <= 1'b1;
                axi_awready <= 1'b0;
            end else begin
                axi_awready <= 1'b0;
            end
        end
    end

    // Capture write address
    reg [C_S_AXI_ADDR_WIDTH-1:0] waddr;
    always @(posedge axi_clk) begin
        if (!axi_resetn)
            waddr <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        else if (wr_add_data_valid && ~axi_awready && aw_en)
            waddr <= axi_awaddr;
    end

    // WREADY one-clock pulse
    always @(posedge axi_clk) begin
        if (!axi_resetn)
            axi_wready <= 1'b0;
        else
            axi_wready <= (wr_add_data_valid && ~axi_wready && aw_en);
    end

    // Write response
    wire wr_add_data_ready = axi_awready && axi_wready;
    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            axi_bvalid <= 1'b0;
            axi_bresp  <= 2'b00;
        end else begin
            if (wr_add_data_valid && wr_add_data_ready && ~axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= 2'b00;
            end else if (axi_bvalid && axi_bready) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // ------------------------------
    // Read address handshake
    // ------------------------------
    reg [C_S_AXI_ADDR_WIDTH-1:0] raddr;
    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            axi_arready <= 1'b0;
            raddr       <= {C_S_AXI_ADDR_WIDTH{1'b0}};
        end else begin
            if (axi_arvalid && ~axi_arready) begin
                axi_arready <= 1'b1;
                raddr       <= axi_araddr;
            end else begin
                axi_arready <= 1'b0;
            end
        end
    end

    wire rd = axi_arvalid && axi_arready && ~axi_rvalid;

    // ------------------------------
    // Read data valid (R channel control)
    // ------------------------------
    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            axi_rvalid  <= 1'b0;
            axi_rresp   <= 2'b00;
        end else begin
            if (axi_arvalid && axi_arready && ~axi_rvalid) begin
                axi_rvalid <= 1'b1;
                axi_rresp  <= 2'b00;
            end else if (axi_rvalid && axi_rready) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // ------------------------------
    // STATUS value
    // ------------------------------
    
    reg ack_error;
    reg busy;
    
    wire [31:0] status_value = {
        16'h0000,          // [31:16]
        fifo_rd_index,     // [15:12]
        fifo_wr_index,     // [11:8]
        busy,              // [7]
        ack_error,         // [6]
        fifo_empty,        // [5] TXFE
        fifo_full,         // [4] TXFF
        fifo_overflow,     // [3] TXFO
        rx_empty,          // [2] RXFE
        rx_full,           // [1] RXFF
        rx_overflow        // [0] RXFO
    };

    //-----------------------------------
    // CONTROL REGISTER
    //----------------------------------
    wire [7:0] debug_out;
    reg test_out_en;
    reg start_reg;
    reg use_rep_start;
    reg use_reg;
    reg [3:0] byte_count;
    reg read_write;
    
    wire[31:0] control_value = {
        debug_out,          //[31:24] debug_out
        15'd0,              //[23:9] reserved
        test_out_en,           //[8] test out
        start_reg,              //[7] start
        use_rep_start,      //[6] use repeated start
        use_reg,            //[5] use register
        byte_count,         //[4:1] byte count
        read_write          //[0] r/~w
     };    

     //-----------------------------------
    // ADDRESS REGISTER
    //----------------------------------
    reg [6:0] address;
    
    wire[31:0] address_value = {
        25'd0,
        address
    };
    //-----------------------------------
    // REGISTER register lol
    //----------------------------------
    reg [7:0] register;
    
    wire[31:0] register_value = {
        24'd0,
        register    
    };

    // ------------------------------
    // WRITE: DATA pushes
    // ------------------------------
    wire wr = wr_add_data_valid && axi_awready && axi_wready;
    
    reg clear_start;
    reg clear_ack;

    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            fifo_wr_req         <= 1'b0;
            fifo_wr_byte        <= 8'h00;
            fifo_clear_overflow <= 1'b0;
            rx_clear_overflow <= 1'b0;
            clear_ack <= 1'b0;
            read_write <= 1'b0; 
            byte_count <= 4'b0;
            use_reg <=  1'b0;
            use_rep_start <= 1'b0;
            start_reg <= 1'b0;
            test_out_en <= 1'b0;  
            
        end else begin
            fifo_wr_req         <= 1'b0; // default deassert
            fifo_clear_overflow <= 1'b0;
            rx_clear_overflow <= 1'b0;
            clear_ack <= 1'b0;
            if (clear_start) begin
                start_reg <= 1'b0; 
            end

            if (wr) begin
                case (waddr[4:2])
                    DATA_REG_I2C: begin
                        if (axi_wstrb[0]) begin
                            fifo_wr_byte <= S_AXI_WDATA[7:0];
                            fifo_wr_req  <= 1'b1; // 1-cycle push
                        end
                    end
                    STATUS_REG: begin
                        if (axi_wstrb[0] && S_AXI_WDATA[3])
                            fifo_clear_overflow <= 1'b1; // W1C for tx overflow
                        if (axi_wstrb[0] && S_AXI_WDATA[0])
                            rx_clear_overflow <= 1'b1;  // w1c for rx overflow
                        if (axi_wstrb[0] && S_AXI_WDATA[6])
                            clear_ack <= 1'b1;  // w1c for ack error

                    end
                    CONTROL_REG: begin
                        if(axi_wstrb[0]) begin
                            read_write <= S_AXI_WDATA[0]; 
                            byte_count <= S_AXI_WDATA[4:1];
                            use_reg <=  S_AXI_WDATA[5];
                            use_rep_start <= S_AXI_WDATA[6];
                            start_reg <= S_AXI_WDATA[7];
                            test_out_en <= S_AXI_WDATA[8];  
                        end  
                    end
                    ADDRESS_REG: begin
                        if (axi_wstrb[0]) begin
                         address <= S_AXI_WDATA[6:0];
                        end
                    end
                    REGISTER_REG: begin
                        if (axi_wstrb[0]) begin
                           register <= S_AXI_WDATA[7:0]; 
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    // ------------------------------
    // READ mux: present data; arm a pop on DATA if not empty
    // (no fifo_rd_req here)
    // ------------------------------
    reg req_delay; // set when a DATA read is accepted and FIFO not empty

    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            axi_rdata <= 32'h0000_0000;
            req_delay   <= 1'b0;
        end else begin
            // clear req_delay by default
            req_delay <= 1'b0;

            if (rd) begin
                case (raddr[4:2])
                    STATUS_REG: begin
                        axi_rdata <= status_value;
                        // req_delay remains 0
                    end
                    DATA_REG_I2C: begin
                        axi_rdata <= {24'h0, rx_rd_data}; // present current head
                        if (!rx_empty)
                            req_delay <= 1'b1;                // request rd for next cycle
                    end
                    CONTROL_REG: begin
                        axi_rdata <= control_value;
                    end
                    ADDRESS_REG: begin
                        axi_rdata <= address_value;
                    end
                    REGISTER_REG: begin
                        axi_rdata <= register_value;
                    end
                    default: begin
                        axi_rdata <= 32'h0000_0000;
                        // req_delay remains 0
                    end
                endcase
            end
        end
    end

    // ------------------------------
    // Single-driver pulse: generate FIFO 1 cycle after req_delay
    // ------------------------------
    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            rx_rd_req <= 1'b0;
        end else begin
            rx_rd_req <= req_delay; // exact 1-cycle pulse
        end
    end
    
    reg tx_req_delay;

    always @(posedge axi_clk) begin
        if (!axi_resetn) begin
            fifo_rd_req <= 1'b0;
        end else begin
            fifo_rd_req <= tx_req_delay; // exact 1-cycle pulse
        end
    end
    
     // 200 KHz tick
    wire khz_clock;
    divide_by_500 div500(clk, khz_clock);
    reg test_clk_200k;

    always @ (posedge clk) begin
         if (rst) begin
            test_clk_200k <=1'b0;
         end else if (khz_clock) begin
            test_clk_200k <= ~test_clk_200k;
         end
    end
    
   
    //test out signal
    assign test_out_enable = test_out_en;
    assign test_out_data = khz_clock; //outputs 100khz clock for visibility
    //assign test_out_data = busy; //outputs 100khz clock for visibility

    
    // ------------------------------
    // FSM for I2C 
    // ------------------------------
    
    reg sda_low;
    reg scl_low;
    reg addr_ack; //1 = ack recived  0 = NACK
    reg [4:0] phase = 5'b0;
    
    //states for state machine
    reg[3:0] state; // [2:0] = 3 bits max value 8 states 
    localparam IDLE =4'd0;
    localparam START = 4'd1;
    localparam ADD7_R = 4'd2;
    localparam ADD7_W = 4'd3;
    localparam TX_REG = 4'd4;
    localparam TX_DATA = 4'd5;
    localparam RX_DATA = 4'd6;
    localparam RX_START = 4'd7;
    localparam RX_STOP = 4'd8;
    localparam STOP = 4'd9;
    
 
    reg [7:0] count;
    reg [3:0] byte_counter;
    reg [7:0] rx_byte;
    reg [3:0] bit_index;
    
    reg [7:0] tx_byte;
    reg tx_byte_valid;
    
    //metastability for sda input
    reg read_port_data;
    reg pre_read_port_data;
    always @ (posedge(axi_clk))
    begin
        pre_read_port_data <= i2c_data_in;
        read_port_data <= pre_read_port_data;
    end
    
    //busy handling
    always @(posedge clk or posedge rst) begin
    if (rst)
        busy <= 1'b0;
    else
        busy <= (state != IDLE);
    end
    
    wire start_clear;
    //for SCL:
    // SCL only begins when triggered. So when start condition is met
    
    // when phase = 0, 2 , 4  etc (EVEN) SCL goes high
    // when phase = 1, 3, 5, etc (ODD) SCL goes low

    //For SDA
    always @ (posedge clk) begin // posedge edge of clock 100
        tx_req_delay <= 1'b0;
        clear_start <= 1'b0;
        rx_wr_req <= 1'b0;
        if(clear_ack) begin
            ack_error <= 1'b0;
        end
        if(rst) begin
            state <= IDLE;
            count <= 8'd0;
        end
        else if (khz_clock) begin // facilitate movement whenever 200khz pulse is sent
            case(state)
                IDLE: begin
                    sda_low<= 1'b0; //let float
                    scl_low<= 1'b0; //let float
                    if (start_reg) begin
                        state <= START;
                        phase <= 1'b0;
                        //clear start bit
                        clear_start <= 1'b1;
                    end
                end
                START: begin
                    if (phase == 0)begin
                        scl_low <= 1'b0; //clock goes high (float)
                        sda_low <= 1'b0; //data goes high
                        phase <= phase + 1'b1;
                    end
                    else if (phase == 1) begin
                        sda_low <= 1'b1; //bring sda low hile clk is still high (start condition)
                        phase <= phase + 1'b1;

                    end
                    else if (phase == 2) begin
                        count <= 6;
                        if((read_write == 1'b0) || (use_reg)) begin //write(simple or complex) or complex read
                            state <= ADD7_W;
                            phase <= 0;
                        end
                        else if (read_write) begin //simple read
                            state <= ADD7_R;
                            phase <= 0;
                        end
                    end
                end 
                ADD7_W: begin
                    if (phase == 0) begin
                        //clock high data change
                        scl_low <= 1'b1; //low
                        //if data bit add[count] = 0, make sda_low 1
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low = 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;

                    end
                    //register address : holds the address bits
                    if (phase == 1) begin
                        scl_low <= 1'b0; // clock high    
                        phase <= phase + 1'b1;

                    end
                    if (phase == 2) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 3) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 4) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 5) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 6) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 7) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 8) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 9) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 10) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 11) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 12) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 13) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 14) begin
                        scl_low <= 1'b1; //low
                        //send write bit (zero)
                        sda_low <= 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 15) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 16) begin
                        sda_low <= 1'b0; //sda float to read clock
                        scl_low <= 1'b1; //low
                        phase <= phase + 1'b1;
                    end
                    if (phase == 17) begin
                        scl_low <= 1'b0; // clock high
                        //sample ack bit
                        //addr_ack <= (read_port_data == 1'b0); // addr_ack 0: successful ack
                        if (!read_port_data) begin //if 0
                            //here
                            phase <= 1'b0;
                            if (use_reg) begin
                                count <= 7;
                                state <= TX_REG;
                            end else begin //simple
                                byte_counter <= 4'b0;
                                state <= TX_DATA;
                            end
                        end else begin // means NACK, go back to idle
                            phase <= 1'b0;
                            ack_error <= 1'b1;
                            state <= IDLE;
                        end
                    end

                end
                
                ADD7_R: begin
                    if (phase == 0) begin
                        //clock high data change
                        scl_low <= 1'b1; //low
                        //if data bit add[count] = 0, make sda_low 1
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low = 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;

                    end
                    if (phase == 1) begin
                        scl_low <= 1'b0; // clock high    
                        phase <= phase + 1'b1;

                    end
                    if (phase == 2) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 3) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 4) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 5) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 6) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 7) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 8) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 9) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 10) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 11) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 12) begin
                        scl_low <= 1'b1; //low
                        if( address[count] == 0) begin
                            sda_low <= 1'b1;
                        end
                        else begin sda_low <= 1'b0; end
                        count <= count - 1'b1;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 13) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 14) begin
                        scl_low <= 1'b1; //low
                        //send read bit (float)
                        sda_low <= 1'b0;
                        phase <= phase + 1'b1;
                    end
                    if (phase == 15) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;
                    end
                    if (phase == 16) begin
                        sda_low <= 1'b0; //sda float to read clock
                        scl_low <= 1'b1; //low
                        phase <= phase + 1'b1;
                    end
                    if (phase == 17) begin
                        scl_low <= 1'b0; // clock high
                        //sample ack bit
                        //addr_ack <= (read_port_data == 1'b0); // addr_ack 0: successful ack
                        if (!read_port_data) begin //if 0
                            phase <= 1'b0;
                            byte_counter <= 4'b0;
                            bit_index <= 4'd7;
                            state <= RX_DATA;
                        end else begin // means NACK, go back to idle
                            phase <= 1'b0;
                            ack_error <= 1'b1;
                            state <= IDLE;
                        end
                    end

                end

                TX_REG: begin
                    if (phase == 0) begin
                       scl_low <= 1'b1; //bring clock low, start transfer of register
                       if( register[count] == 0) begin
                            sda_low <= 1'b1;
                       end 
                       else begin sda_low <= 1'b0; end
                       count <= count - 1'b1;
                       phase <= phase + 1'b1;
                    end
                    if (phase == 1) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;            
                    end
                    if (phase == 2) begin
                       scl_low <= 1'b1; //bring clock low
                       if( register[count] == 0) begin
                            sda_low <= 1'b1;
                       end 
                       else begin sda_low <= 1'b0; end
                       count <= count - 1'b1;
                       phase <= phase + 1'b1;
                    end
                    if (phase == 3) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;            
                    end
                    if (phase == 4) begin
                       scl_low <= 1'b1; //bring clock low
                       if( register[count] == 0) begin
                            sda_low <= 1'b1;
                       end 
                       else begin sda_low <= 1'b0; end
                       count <= count - 1'b1;
                       phase <= phase + 1'b1;
                    end
                    if (phase == 5) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;            
                    end
                    if (phase == 6) begin
                       scl_low <= 1'b1; //bring clock low
                       if( register[count] == 0) begin
                            sda_low <= 1'b1;
                       end 
                       else begin sda_low <= 1'b0; end
                       count <= count - 1'b1;
                       phase <= phase + 1'b1;
                    end
                    if (phase == 7) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;            
                    end
                    if (phase == 8) begin
                       scl_low <= 1'b1; //bring clock low
                       if( register[count] == 0) begin
                            sda_low <= 1'b1;
                       end 
                       else begin sda_low <= 1'b0; end
                       count <= count - 1'b1;
                       phase <= phase + 1'b1;
                    end
                    if (phase == 9) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;            
                    end
                    if (phase == 10) begin
                       scl_low <= 1'b1; //bring clock low
                       if( register[count] == 0) begin
                            sda_low <= 1'b1;
                       end 
                       else begin sda_low <= 1'b0; end
                       count <= count - 1'b1;
                       phase <= phase + 1'b1;
                    end
                    if (phase == 11) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;            
                    end
                    if (phase == 12) begin
                       scl_low <= 1'b1; //bring clock low
                       if( register[count] == 0) begin
                            sda_low <= 1'b1;
                       end 
                       else begin sda_low <= 1'b0; end
                       count <= count - 1'b1;
                       phase <= phase + 1'b1;
                    end
                    if (phase == 13) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;            
                    end
                    if (phase == 14) begin
                       scl_low <= 1'b1; //bring clock low
                       if( register[count] == 0) begin
                            sda_low <= 1'b1;
                       end 
                       else begin sda_low <= 1'b0; end
                       count <= count - 1'b1;
                       phase <= phase + 1'b1;
                    end
                    if (phase == 15) begin
                        scl_low <= 1'b0; // clock high
                        phase <= phase + 1'b1;            
                    end
                    if (phase == 16) begin
                        sda_low <= 1'b0; //sda float to read ack
                        scl_low <= 1'b1; //low
                        phase <= phase + 1'b1;
                    end
                    if (phase == 17) begin
                        scl_low <= 1'b0; // clock high
                        if (!read_port_data) begin //if 1, means ACK 
                            if (!read_write) begin //    write/TX
                                phase <= 1'b0;
                                byte_counter <= 4'b0;
                                tx_byte_valid <= 1'b0;
                                //tx_req_delay <= 1'b1;
                                state<= TX_DATA;
                            end else if (read_write) begin //  read/RX
                                if (use_rep_start) begin //go straight to start
                                   phase <= 1'b0;
                                   state <= RX_START;
                                end
                                else begin //send stop bit first
                                    phase <= 1'b0;
                                    state <= RX_STOP;
                                end
                            end
                        end else begin // means NACK, go back to idle
                            phase <= 1'b0;
                            ack_error <= 1'b1;
                            state <= IDLE;
                        end
                    end
                    
                end
                
                TX_DATA: begin
                    if(byte_counter == byte_count) begin
                        // do something here, data is done being sent OR no byte counts to be sent
                        state <= STOP;
                    end else begin
                        if(!tx_byte_valid) begin
                            tx_byte <= fifo_rd_data;
                            tx_byte_valid <= 1'b1;
                            phase <= 1'b0;
                        end
                    else if (byte_counter < byte_count) begin
                        if (phase == 0) begin
                            scl_low <= 1'b1; //bring clock low
                            //send data fifo_rd_data
                            if(tx_byte[7] == 0) begin
                                sda_low <= 1'b1;
                            end
                            else begin sda_low <= 1'b0; end   
                            phase <= phase + 1'b1;  
                        end
                        if (phase == 1) begin
                            scl_low <= 1'b0; 
                            phase <= phase + 1'b1;  

                        end
                        if (phase == 2) begin
                            scl_low <= 1'b1;
                            if(tx_byte[6] == 0) begin
                                sda_low <= 1'b1;
                            end
                            else begin sda_low <= 1'b0; end  
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 3) begin
                            scl_low <= 1'b0; 
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 4) begin
                            scl_low <= 1'b1;
                            if(tx_byte[5] == 0) begin
                                sda_low <= 1'b1;
                            end
                            else begin sda_low <= 1'b0; end  
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 5) begin
                            scl_low <= 1'b0; 
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 6) begin
                            scl_low <= 1'b1;
                            if(tx_byte[4] == 0) begin
                                sda_low <= 1'b1;
                            end
                            else begin sda_low <= 1'b0; end 
                            phase <= phase + 1'b1;  
                        end
                        if (phase == 7) begin
                            scl_low <= 1'b0; 
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 8) begin
                            scl_low <= 1'b1;
                            if(tx_byte[3] == 0) begin
                                sda_low <= 1'b1;
                            end
                            else begin sda_low <= 1'b0; end  
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 9) begin
                            scl_low <= 1'b0; 
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 10) begin
                            scl_low <= 1'b1;
                            if(tx_byte[2] == 0) begin
                                sda_low <= 1'b1;
                            end
                            else begin sda_low <= 1'b0; end  
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 11) begin
                            scl_low <= 1'b0; 
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 12) begin
                            scl_low <= 1'b1;
                            if(tx_byte[1] == 0) begin
                                sda_low <= 1'b1;
                            end
                            else begin sda_low <= 1'b0; end  
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 13) begin
                            scl_low <= 1'b0; 
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 14) begin
                            scl_low <= 1'b1;
                            if(tx_byte[0] == 0) begin
                                sda_low <= 1'b1;
                            end
                            else begin sda_low <= 1'b0; end 
                            tx_req_delay <= 1'b1; 
                            phase <= phase + 1'b1; 
                        end
                        if (phase == 15) begin
                            scl_low <= 1'b0; 
                            phase <= phase + 1'b1; 
                            
                        end
                        if (phase == 16) begin
                            sda_low <= 1'b0; //float for ack
                            scl_low <= 1'b1; //low
                            //read req                 
                            phase <= phase + 1'b1;
                        end
                        if (phase == 17) begin
                            scl_low <= 1'b0; // clock high
                            //sample ack bit
                            //addr_ack <= (read_port_data == 1'b0); // addr_ack 0: successful ack
                            if (!read_port_data) begin //if 1, means ACK 
                                //read request for tx fifo
                                //fifo_rd_req = 1'b1;
                                phase <= 1'b0;
                                byte_counter <= byte_counter + 1'b1; 
                                tx_byte_valid <= 1'b0;                             
                                state<= TX_DATA;
                            end else begin // means NACK, go back to StOP then IDLE
                                phase <= 1'b0;
                                ack_error <= 1'b1;
                                state <= STOP;
                            end
                        end
                        end
                    end
                
                end
                RX_DATA: begin
                    if(byte_counter == byte_count) begin
                        // do something here, data is done being sent OR no byte counts to be sent
                        state <= STOP;
                    end else begin  //still bytes to read
                        if (phase == 0) begin
                            scl_low <= 1'b1; //bring clock low
                            sda_low <= 1'b0; // SDA MUST BE LEFT HIGH FOR RECIEVING DATA!!!                           
                            phase <= phase + 1'b1;  
                        end
                        if (phase == 1) begin
                            scl_low <= 1'b0; 
                            //sample here, MSB of byte
                            rx_byte[bit_index] <= read_port_data; 
                            if (bit_index == 0) begin //end of reading 
                                bit_index <= 4'd7;
                                phase <= phase + 1'b1;
                            end else begin
                                bit_index <= bit_index - 1'd1;
                                phase <= 1'b0;
                            end

                        end
                        if (phase == 2) begin //NACK or ACK control
                            scl_low <= 1'b1; //bring clock low
                            if (byte_counter == byte_count -1) begin //means last byte to read, send NACK
                                sda_low <= 1'b0;
                            end
                            else if (byte_counter < byte_count -1) begin
                                sda_low <= 1'b1; //data low to send ACK
                            end
                            phase <= phase + 1'b1;
                        end
                        if (phase == 3) begin
                            scl_low <= 1'b0;
                            
                            rx_wr_byte <= rx_byte;
                            rx_wr_req <= 1'b1;
                            
                            byte_counter <= byte_counter + 1'd1;
                            phase <= 1'b0;
                        end
                        
                        
                    end    
                end
                RX_START: begin
                    if (phase == 0)begin
                        scl_low <= 1'b0; //clock goes high (float)
                        sda_low <= 1'b0; //data goes high
                        phase <= phase + 1'b1;
                    end
                    else if (phase == 1) begin
                        sda_low <= 1'b1; //bring sda low hile clk is still high (start condition)
                        phase <= phase + 1'b1;

                    end
                    else if (phase == 2) begin
                        count <= 6;
                        phase <= 1'b0;
                        state <= ADD7_R;
                    end
                end
                RX_STOP: begin
                    if (phase == 0) begin
                        sda_low <= 1'b1;
                        scl_low <= 1'b1; //goes low
                        phase <= phase + 1'b1;
                    end
                    if (phase == 1) begin
                        scl_low <= 1'b0;
                        phase <= phase + 1'b1;

                    end
                    if (phase == 2) begin
                        sda_low <= 1'b0;
                        phase <= 1'b0;
                        state <= RX_START;
                    end
                end
                STOP: begin
                    if (phase == 0) begin
                        sda_low <= 1'b1;
                        scl_low <= 1'b1; //goes low
                        phase <= phase + 1'b1;
                    end
                    if (phase == 1) begin
                        scl_low <= 1'b0;
                        phase <= phase + 1'b1;

                    end
                    if (phase == 2) begin
                        sda_low <= 1'b0;
                        phase <= 1'b0;
                        state <= IDLE;
                    end
                end
            
            endcase
        
        end
    
    end

    
    //sda and clock signals
    assign i2c_data_out = sda_low;
    assign i2c_clock_out = scl_low; 
    
endmodule


//system clock = 100Mhz /200hz = 500 divisor
module divide_by_500(
    input clk,
    output reg out);
    
    reg [8:0] count;
    
    always @ (posedge(clk))
    begin
        if (count < 9'd500)
        begin
           count <= count + 1;
           out <= 0;
        end
        else
        begin
            count <= 0;
            out <= 1;
        end
    end    

endmodule
