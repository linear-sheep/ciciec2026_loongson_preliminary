`timescale 1ns / 1ps

/**
 * Sobel Accelerator Simulation Testbench
 * 
 * 功能：
 *   - 完整 AXI-4 Slave 协议仿真
 *   - 从缓存测试图片读取像素
 *   - 向加速器写入像素并读取结果
 *   - 记录仿真日志和波形输出
 *   - 统计边缘检测性能指标
 */

module sobel_sim_tb ();

    // ========================================
    // 系统时钟和复位
    // ========================================
    
    reg sys_clk;
    reg sys_resetn;
    
    // 100 MHz 系统时钟
    initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk;
    end
    
    // 系统复位信号
    initial begin
        sys_resetn = 0;
        repeat(10) @(posedge sys_clk);
        sys_resetn = 1;
    end
    
    // ========================================
    // AXI4 Slave 写地址通道
    // ========================================
    reg  [3:0]  axi_awaddr;
    reg  [4:0]  axi_awid;
    reg  [7:0]  axi_awlen;
    reg  [2:0]  axi_awsize;
    reg  [1:0]  axi_awburst;
    reg         axi_awvalid;
    wire        axi_awready;
    
    // ========================================
    // AXI4 Slave 写数据通道
    // ========================================
    reg  [31:0] axi_wdata;
    reg  [3:0]  axi_wstrb;
    reg         axi_wlast;
    reg         axi_wvalid;
    wire        axi_wready;
    
    // ========================================
    // AXI4 Slave 写响应通道
    // ========================================
    wire [4:0]  axi_bid;
    wire [1:0]  axi_bresp;
    wire        axi_bvalid;
    reg         axi_bready;
    
    // ========================================
    // AXI4 Slave 读地址通道
    // ========================================
    reg  [3:0]  axi_araddr;
    reg  [4:0]  axi_arid;
    reg  [7:0]  axi_arlen;
    reg  [2:0]  axi_arsize;
    reg  [1:0]  axi_arburst;
    reg         axi_arvalid;
    wire        axi_arready;
    
    // ========================================
    // AXI4 Slave 读数据通道
    // ========================================
    wire [31:0] axi_rdata;
    wire [4:0]  axi_rid;
    wire [1:0]  axi_rresp;
    wire        axi_rlast;
    wire        axi_rvalid;
    reg         axi_rready;
    
    // ========================================
    // 被测试设备接口（AXI Sobel 加速器）
    // ========================================
    
    axi_sobel_accelerator #(
        .C_S00_AXI_DATA_WIDTH(32),
        .C_S00_AXI_ADDR_WIDTH(4),
        .C_S00_AXI_ID_WIDTH(5)
    ) dut (
        // 时钟和复位
        .s00_axi_aclk(sys_clk),
        .s00_axi_aresetn(sys_resetn),
        
        // 写地址通道
        .s00_axi_awaddr(axi_awaddr),
        .s00_axi_awid(axi_awid),
        .s00_axi_awlen(axi_awlen),
        .s00_axi_awsize(axi_awsize),
        .s00_axi_awburst(axi_awburst),
        .s00_axi_awvalid(axi_awvalid),
        .s00_axi_awready(axi_awready),
        
        // 写数据通道
        .s00_axi_wdata(axi_wdata),
        .s00_axi_wstrb(axi_wstrb),
        .s00_axi_wlast(axi_wlast),
        .s00_axi_wvalid(axi_wvalid),
        .s00_axi_wready(axi_wready),
        
        // 写响应通道
        .s00_axi_bid(axi_bid),
        .s00_axi_bresp(axi_bresp),
        .s00_axi_bvalid(axi_bvalid),
        .s00_axi_bready(axi_bready),
        
        // 读地址通道
        .s00_axi_araddr(axi_araddr),
        .s00_axi_arid(axi_arid),
        .s00_axi_arlen(axi_arlen),
        .s00_axi_arsize(axi_arsize),
        .s00_axi_arburst(axi_arburst),
        .s00_axi_arvalid(axi_arvalid),
        .s00_axi_arready(axi_arready),
        
        // 读数据通道
        .s00_axi_rdata(axi_rdata),
        .s00_axi_rid(axi_rid),
        .s00_axi_rresp(axi_rresp),
        .s00_axi_rlast(axi_rlast),
        .s00_axi_rvalid(axi_rvalid),
        .s00_axi_rready(axi_rready)
    );
    
    // ========================================
    // 仿真数据存储
    // ========================================
    
    // 测试图片数据（1280×720）
    reg [7:0] test_image [0:921599];
    
    // 边缘检测结果存储
    reg [15:0] result_image [0:921599];
    
    // 日志记录文件
    integer log_file;
    
    // ========================================
    // 统计变量
    // ========================================
    
    integer pixel_count;
    integer result_count;
    integer edge_count_50;
    integer edge_count_100;
    integer edge_count_150;
    integer max_magnitude;
    integer min_magnitude;
    reg [63:0] sum_magnitude;
    
    // ========================================
    // VCD 记录和日志初始化
    // ========================================
    
    initial begin
        // 打开 VCD 文件作记录为自动单位转换
        $dumpfile("sobel_sim.vcd");
        $dumpvars(0, sobel_sim_tb);
        
        // 打开日志文件
        log_file = $fopen("sobel_sim.log", "w");
        
        // 初始化统计
        pixel_count = 0;
        result_count = 0;
        edge_count_50 = 0;
        edge_count_100 = 0;
        edge_count_150 = 0;
        max_magnitude = 0;
        min_magnitude = 65535;
        sum_magnitude = 0;
    end
    
    // ========================================
    // 初始化 AXI 信号
    // ========================================
    
    initial begin
        // 写地址通道
        axi_awaddr = 0;
        axi_awid = 0;
        axi_awlen = 0;
        axi_awsize = 2;  // 32-bit (2^2 = 4 bytes)
        axi_awburst = 0; // INCR
        axi_awvalid = 0;
        
        // 写数据通道
        axi_wdata = 0;
        axi_wstrb = 4'b1111;  // 所有字节有效
        axi_wlast = 0;
        axi_wvalid = 0;
        
        // 写响应通道
        axi_bready = 0;
        
        // 读地址通道
        axi_araddr = 0;
        axi_arid = 0;
        axi_arlen = 0;
        axi_arsize = 2;  // 32-bit
        axi_arburst = 0; // INCR
        axi_arvalid = 0;
        
        // 读数据通道
        axi_rready = 0;
    end
    
    // ========================================
    // 测试图片初始化
    // ========================================
    
    initial begin
        integer i, j;
        
        // 创建竖直边缘测试图案
        // 左半边 = 50（深色）
        // 右半边 = 200（浅色）
        for (i = 0; i < 720; i = i + 1) begin
            for (j = 0; j < 640; j = j + 1) begin
                test_image[i * 1280 + j] = 8'd50;
            end
            for (j = 640; j < 1280; j = j + 1) begin
                test_image[i * 1280 + j] = 8'd200;
            end
        end
        
        $fwrite(log_file, "====================================\n");
        $fwrite(log_file, "Sobel Accelerator Simulation Log\n");
        $fwrite(log_file, "====================================\n");
        $fwrite(log_file, "Time: %0t\n", $time);
        $fwrite(log_file, "Test Pattern: Vertical Edge (50 -> 200)\n");
        $fwrite(log_file, "\n");
    end
    
    // ========================================
    // 主仿真程序
    // ========================================
    
    task main_simulation;
        begin
            // 等待复位释放
            wait(sys_resetn);
            repeat(5) @(posedge sys_clk);
            
            $display("========================================");
            $display("Sobel Accelerator Simulation Started");
            $display("========================================\n");
            
            $fwrite(log_file, "[%0t] Simulation started\n", $time);
            
            // 阶段 1：写入所有像素
            write_all_pixels();
            
            // 等待处理完成
            $display("Waiting for processing...");
            repeat(3000) @(posedge sys_clk);
            
            // 阶段 2：读取所有结果
            read_all_results();
            
            // 等待清理
            repeat(100) @(posedge sys_clk);
            
            // 输出统计
            display_statistics();
            
            // 关闭日志
            $fwrite(log_file, "\nSimulation completed at %0t\n", $time);
            $fclose(log_file);
            
            $display("\n========================================");
            $display("Simulation Completed");
            $display("Log file: sobel_sim.log");
            $display("Waveform: sobel_sim.vcd");
            $display("========================================\n");
            
            #100 $finish;
        end
    endtask
    
    // ========================================
    // 写入所有像素数据
    // ========================================
    
    task write_all_pixels;
        integer i, row, col;
        integer progress;
        begin
            $display("Phase 1: Writing pixels...");
            $fwrite(log_file, "[%0t] Phase 1: Writing pixels\n", $time);
            
            pixel_count = 0;
            progress = 0;
            
            for (i = 0; i < 921600; i = i + 1) begin
                write_pixel_to_accelerator(test_image[i]);
                pixel_count = pixel_count + 1;
                
                // 进度指示（每行）
                if ((i + 1) % 1280 == 0) begin
                    row = (i + 1) / 1280;
                    $display("  Progress: %3d%% (%d/720 rows, %d pixels)", 
                        (row * 100) / 720, row, i + 1);
                    $fwrite(log_file, "  [%0t] Progress: %d%% (%d rows)\n", 
                        $time, (row * 100) / 720, row);
                end
            end
            
            $display("  Completed: %d pixels written", pixel_count);
            $fwrite(log_file, "  Completed: %d pixels written\n", pixel_count);
        end
    endtask
    
    // ========================================
    // 单个像素写入
    // ========================================
    
    task write_pixel_to_accelerator(input [7:0] pixel);
        begin
            // 设置写地址为 0（像素输入寄存器）
            axi_awaddr = 4'h0;
            axi_awid = 5'h0;
            axi_awlen = 8'h0;   // 单次传输
            axi_awsize = 3'h2;  // 32-bit
            axi_awburst = 2'h1; // INCR
            axi_awvalid = 1;
            
            axi_wdata = {24'h0, pixel};
            axi_wstrb = 4'b0001;  // 仅最低字节有效
            axi_wlast = 1;
            axi_wvalid = 1;
            
            axi_bready = 1;
            
            // 等待地址通道准备好
            @(posedge sys_clk);
            while (!axi_awready) @(posedge sys_clk);
            
            // 等待数据通道准备好
            while (!axi_wready) @(posedge sys_clk);
            
            // 等待响应
            axi_awvalid = 0;
            axi_wvalid = 0;
            
            while (!axi_bvalid) @(posedge sys_clk);
            
            @(posedge sys_clk);
            axi_bready = 0;
        end
    endtask
    
    // ========================================
    // 读取所有结果
    // ========================================
    
    task read_all_results;
        integer i;
        integer warmup_pixels;
        integer valid_count;
        integer row;
        integer progress;
        integer result_val;
        begin
            warmup_pixels = (2 * 1280) + 3;  // 2563
            valid_count = 921600 - warmup_pixels;
            
            $display("\nPhase 2: Reading results...");
            $display("  Warmup pixels: %d", warmup_pixels);
            $display("  Valid results: %d", valid_count);
            
            $fwrite(log_file, "\n[%0t] Phase 2: Reading results\n", $time);
            $fwrite(log_file, "  Warmup pixels: %d\n", warmup_pixels);
            $fwrite(log_file, "  Valid results: %d\n", valid_count);
            
            result_count = 0;
            
            for (i = 0; i < valid_count; i = i + 1) begin
                read_result_from_accelerator(result_val);
                result_image[i + warmup_pixels] = result_val[15:0];
                result_count = result_count + 1;
                
                // 更新统计
                if (result_val > max_magnitude)
                    max_magnitude = result_val;
                if (result_val < min_magnitude)
                    min_magnitude = result_val;
                sum_magnitude = sum_magnitude + result_val;
                
                if (result_val > 50)
                    edge_count_50 = edge_count_50 + 1;
                if (result_val > 100)
                    edge_count_100 = edge_count_100 + 1;
                if (result_val > 150)
                    edge_count_150 = edge_count_150 + 1;
                
                // 进度指示
                if ((i + 1) % 1280 == 0) begin
                    row = (i + 1) / 1280;
                    $display("  Progress: %3d%% (%d/%d results)", 
                        (i + 1) * 100 / valid_count, i + 1, valid_count);
                    $fwrite(log_file, "  [%0t] Progress: %d%% (%d results)\n", 
                        $time, (i + 1) * 100 / valid_count, i + 1);
                end
            end
            
            $display("  Completed: %d results read", result_count);
            $fwrite(log_file, "  Completed: %d results read\n", result_count);
        end
    endtask
    
    // ========================================
    // 单个结果读取
    // ========================================
    
    task read_result_from_accelerator(output [31:0] result_data);
        begin
            // 设置读地址为 0x04（结果寄存器）
            axi_araddr = 4'h4;
            axi_arid = 5'h0;
            axi_arlen = 8'h0;   // 单次传输
            axi_arsize = 3'h2;  // 32-bit
            axi_arburst = 2'h1; // INCR
            axi_arvalid = 1;
            
            axi_rready = 1;
            
            // 等待地址通道准备好
            @(posedge sys_clk);
            while (!axi_arready) @(posedge sys_clk);
            
            // 等待数据准备好
            axi_arvalid = 0;
            
            while (!axi_rvalid) @(posedge sys_clk);
            
            result_data = axi_rdata;
            
            @(posedge sys_clk);
            axi_rready = 0;
        end
    endtask
    
    // ========================================
    // 输出统计信息
    // ========================================
    
    task display_statistics;
        integer avg_magnitude;
        begin
            $display("\n========== Statistics ==========");
            
            if (result_count > 0)
                avg_magnitude = sum_magnitude / result_count;
            else
                avg_magnitude = 0;
            
            $display("  Pixels written:        %d", pixel_count);
            $display("  Results read:          %d", result_count);
            $display("  Max magnitude:         %d", max_magnitude);
            $display("  Min magnitude:         %d", min_magnitude);
            $display("  Average magnitude:     %d", avg_magnitude);
            $display("  Edge pixels (>50):     %d (%.2f%%)", 
                edge_count_50, (edge_count_50 * 100.0) / result_count);
            $display("  Edge pixels (>100):    %d (%.2f%%)", 
                edge_count_100, (edge_count_100 * 100.0) / result_count);
            $display("  Edge pixels (>150):    %d (%.2f%%)", 
                edge_count_150, (edge_count_150 * 100.0) / result_count);
            $display("================================\n");
            
            // 写到日志
            $fwrite(log_file, "\n========== Statistics ==========\n");
            $fwrite(log_file, "  Pixels written:        %d\n", pixel_count);
            $fwrite(log_file, "  Results read:          %d\n", result_count);
            $fwrite(log_file, "  Max magnitude:         %d\n", max_magnitude);
            $fwrite(log_file, "  Min magnitude:         %d\n", min_magnitude);
            $fwrite(log_file, "  Average magnitude:     %d\n", avg_magnitude);
            $fwrite(log_file, "  Edge pixels (>50):     %d (%.2f%%)\n", 
                edge_count_50, (edge_count_50 * 100.0) / result_count);
            $fwrite(log_file, "  Edge pixels (>100):    %d (%.2f%%)\n", 
                edge_count_100, (edge_count_100 * 100.0) / result_count);
            $fwrite(log_file, "  Edge pixels (>150):    %d (%.2f%%)\n", 
                edge_count_150, (edge_count_150 * 100.0) / result_count);
            $fwrite(log_file, "================================\n");
        end
    endtask
    
    // ========================================
    // 启动仿真
    // ========================================
    
    initial begin
        main_simulation();
    end

endmodule
