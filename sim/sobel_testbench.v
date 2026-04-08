/*
 * Sobel Accelerator Test Bench
 * Tests the basic functionality of the Sobel accelerator
 */

module sobel_testbench;

    // Clock and reset
    reg clk;
    reg resetn;
    
    // AXI Write signals
    reg  [31:0] awaddr;
    reg  [4:0]  awid;
    reg  [7:0]  awlen;
    reg  [2:0]  awsize;
    reg  [1:0]  awburst;
    reg         awvalid;
    wire        awready;
    
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    reg         wlast;
    reg         wvalid;
    wire        wready;
    
    wire        bvalid;
    reg         bready;
    wire [1:0]  bresp;
    wire [4:0]  bid;
    
    // AXI Read signals
    reg  [31:0] araddr;
    reg  [4:0]  arid;
    reg  [7:0]  arlen;
    reg  [2:0]  arsize;
    reg  [1:0]  arburst;
    reg         arvalid;
    wire        arready;
    
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rlast;
    wire        rvalid;
    reg         rready;
    
    // Address definitions
    localparam PIXEL_INPUT_ADDR = 32'h1FD0_1000;
    localparam RESULT_ADDR      = 32'h1FD0_1004;
    localparam STATUS_ADDR      = 32'h1FD0_1008;
    
    // Instantiate accelerator
    axi_sobel_accelerator u_dut (
        .clk(clk),
        .resetn(resetn),
        .s_axi_awaddr(awaddr),
        .s_axi_awid(awid),
        .s_axi_awlen(awlen),
        .s_axi_awsize(awsize),
        .s_axi_awburst(awburst),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(wstrb),
        .s_axi_wlast(wlast),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_bresp(bresp),
        .s_axi_bid(bid),
        .s_axi_araddr(araddr),
        .s_axi_arid(arid),
        .s_axi_arlen(arlen),
        .s_axi_arsize(arsize),
        .s_axi_arburst(arburst),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata(rdata),
        .s_axi_rresp(rresp),
        .s_axi_rlast(rlast),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz clock
    end
    
    // Reset generation
    initial begin
        resetn = 0;
        #100;
        resetn = 1;
    end
    
    // Test stimulus
    initial begin
        // Initialize signals
        awaddr = 0;
        awid = 0;
        awlen = 0;
        awsize = 3'b010;  // 32-bit transfers
        awburst = 2'b01;  // INCR
        awvalid = 0;
        wdata = 0;
        wstrb = 4'hF;
        wlast = 0;
        wvalid = 0;
        bready = 1;
        
        araddr = 0;
        arid = 0;
        arlen = 0;
        arsize = 3'b010;
        arburst = 2'b01;
        arvalid = 0;
        rready = 1;
        
        // Wait for reset to complete
        @(negedge resetn);
        @(posedge clk);
        #1000;
        
        // Test 1: Write single pixel
        $display("Test 1: Writing pixel data...");
        write_pixel(PIXEL_INPUT_ADDR, 8'hAA);
        #100;
        write_pixel(PIXEL_INPUT_ADDR, 8'h55);
        #100;
        
        // Test 2: Read status
        $display("Test 2: Reading status...");
        read_register(STATUS_ADDR);
        
        // Test 3: Read result
        $display("Test 3: Reading result...");
        read_register(RESULT_ADDR);
        
        // Continue writing pixels for a while
        $display("Test 4: Writing multiple pixels...");
        for (int i = 0; i < 100; i++) begin
            write_pixel(PIXEL_INPUT_ADDR, i[7:0]);
            #10;
        end
        
        #1000;
        $display("Test bench completed");
        $finish;
    end
    
    // Task to write a pixel
    task write_pixel(input [31:0] addr, input [7:0] pixel);
        begin
            // Address phase
            awaddr = addr;
            awid = 5'h1;
            awlen = 0;
            awsize = 3'b010;
            awburst = 2'b01;
            awvalid = 1;
            
            @(posedge clk);
            while (!awready) @(posedge clk);
            
            // Data phase
            awvalid = 0;
            wdata = {24'b0, pixel};
            wstrb = 4'hF;
            wlast = 1;
            wvalid = 1;
            
            @(posedge clk);
            while (!wready) @(posedge clk);
            
            wvalid = 0;
            wlast = 0;
            
            // Wait for write response
            @(posedge clk);
            while (!bvalid) @(posedge clk);
            
            $display("  Pixel write: addr=0x%h, data=0x%h", addr, pixel);
        end
    endtask
    
    // Task to read a register
    task read_register(input [31:0] addr);
        input [31:0] read_data;
        begin
            // Address phase
            araddr = addr;
            arid = 5'h2;
            arlen = 0;
            arsize = 3'b010;
            arburst = 2'b01;
            arvalid = 1;
            
            @(posedge clk);
            while (!arready) @(posedge clk);
            
            arvalid = 0;
            
            // Wait for read data
            @(posedge clk);
            while (!rvalid) @(posedge clk);
            
            read_data = rdata;
            $display("  Register read: addr=0x%h, data=0x%h", addr, read_data);
        end
    endtask
    
endmodule
