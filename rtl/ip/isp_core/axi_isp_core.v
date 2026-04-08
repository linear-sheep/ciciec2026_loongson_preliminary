/**
 * AXI ISP Core - Image Signal Processing Core
 * 顶层模块
 * 
 * 功能：
 * - AXI Slave 接口：配置寄存器
 * - AXI Master 接口：DMA 读写
 * - 多种图像滤波器：Sobel, Gaussian, Grayscale
 * - 可选 DVI 直接输出
 */

module axi_isp_core #(
    parameter C_S_AXI_DATA_WIDTH = 32,
    parameter C_S_AXI_ADDR_WIDTH = 12,
    parameter C_S_AXI_ID_WIDTH = 5,
    parameter C_M_AXI_ADDR_WIDTH = 64,
    parameter C_M_AXI_DATA_WIDTH = 64,
    parameter C_M_AXI_ID_WIDTH = 5
)(
    // 时钟和复位
    input wire clk,
    input wire resetn,
    
    // AXI Slave 接口 (配置寄存器)
    // 写地址通道
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input wire [C_S_AXI_ID_WIDTH-1:0] s_axi_awid,
    input wire [7:0] s_axi_awlen,
    input wire [2:0] s_axi_awsize,
    input wire [1:0] s_axi_awburst,
    input wire s_axi_awvalid,
    output wire s_axi_awready,
    
    // 写数据通道
    input wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input wire [C_S_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    input wire s_axi_wlast,
    input wire s_axi_wvalid,
    output wire s_axi_wready,
    
    // 写响应通道
    output wire [C_S_AXI_ID_WIDTH-1:0] s_axi_bid,
    output wire [1:0] s_axi_bresp,
    output wire s_axi_bvalid,
    input wire s_axi_bready,
    
    // 读地址通道
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input wire [C_S_AXI_ID_WIDTH-1:0] s_axi_arid,
    input wire [7:0] s_axi_arlen,
    input wire [2:0] s_axi_arsize,
    input wire [1:0] s_axi_arburst,
    input wire s_axi_arvalid,
    output wire s_axi_arready,
    
    // 读数据通道
    output wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output wire [C_S_AXI_ID_WIDTH-1:0] s_axi_rid,
    output wire [1:0] s_axi_rresp,
    output wire s_axi_rlast,
    output wire s_axi_rvalid,
    input wire s_axi_rready,
    
    // AXI Master 接口 (DMA)
    // 写地址通道
    output wire [C_M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output wire [C_M_AXI_ID_WIDTH-1:0] m_axi_awid,
    output wire [7:0] m_axi_awlen,
    output wire [2:0] m_axi_awsize,
    output wire [1:0] m_axi_awburst,
    output wire m_axi_awvalid,
    input wire m_axi_awready,
    
    // 写数据通道
    output wire [C_M_AXI_DATA_WIDTH-1:0] m_axi_wdata,
    output wire [C_M_AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output wire m_axi_wlast,
    output wire m_axi_wvalid,
    input wire m_axi_wready,
    
    // 写响应通道
    input wire [C_M_AXI_ID_WIDTH-1:0] m_axi_bid,
    input wire [1:0] m_axi_bresp,
    input wire m_axi_bvalid,
    output wire m_axi_bready,
    
    // 读地址通道
    output wire [C_M_AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [C_M_AXI_ID_WIDTH-1:0] m_axi_arid,
    output wire [7:0] m_axi_arlen,
    output wire [2:0] m_axi_arsize,
    output wire [1:0] m_axi_arburst,
    output wire m_axi_arvalid,
    input wire m_axi_arready,
    
    // 读数据通道
    input wire [C_M_AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input wire [C_M_AXI_ID_WIDTH-1:0] m_axi_rid,
    input wire [1:0] m_axi_rresp,
    input wire m_axi_rlast,
    input wire m_axi_rvalid,
    output wire m_axi_rready,
    
    // 中断和状态输出
    output wire intr,                   // 处理完成中断
    output wire dvi_enable,             // DVI 输出使能
    output wire [31:0] dvi_data,       // DVI 输出数据
    output wire dvi_valid              // DVI 数据有效
);

    // ============================================
    // 内部信号
    // ============================================
    
    // 配置寄存器
    reg [31:0] isp_ctrl;                // ISP 控制寄存器
    reg [31:0] src_addr_l;              // 源地址低 32 位
    reg [31:0] src_addr_h;              // 源地址高 32 位
    reg [31:0] dst_addr_l;              // 目标地址低 32 位
    reg [31:0] dst_addr_h;              // 目标地址高 32 位
    reg [31:0] img_width;               // 图像宽度
    reg [31:0] img_height;              // 图像高度
    reg [31:0] filter_mode;             // 滤波器模式
    reg [31:0] threshold;               // 阈值
    reg [31:0] roi_x, roi_y;            // ROI 坐标
    reg [31:0] roi_w, roi_h;            // ROI 大小
    
    // 状态寄存器
    reg [31:0] isp_status;              // ISP 状态
    
    // DMA 控制信号
    wire dma_read_enable;
    wire dma_write_enable;
    wire dma_done;
    wire dma_error;
    
    // 处理流程控制
    wire proc_enable;
    wire proc_done;
    
    // ============================================
    // AXI Slave 寄存器接口实例
    // ============================================
    
    axi_isp_slave_reg #(
        .DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .ADDR_WIDTH(C_S_AXI_ADDR_WIDTH),
        .ID_WIDTH(C_S_AXI_ID_WIDTH)
    ) slave_reg_inst (
        .clk(clk),
        .resetn(resetn),
        
        // AXI Slave 接口
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awid(s_axi_awid),
        .s_axi_awlen(s_axi_awlen),
        .s_axi_awsize(s_axi_awsize),
        .s_axi_awburst(s_axi_awburst),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(s_axi_wlast),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        
        .s_axi_bid(s_axi_bid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arid(s_axi_arid),
        .s_axi_arlen(s_axi_arlen),
        .s_axi_arsize(s_axi_arsize),
        .s_axi_arburst(s_axi_arburst),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rid(s_axi_rid),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(s_axi_rlast),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        
        // 寄存器输出
        .isp_ctrl(isp_ctrl),
        .src_addr_l(src_addr_l),
        .src_addr_h(src_addr_h),
        .dst_addr_l(dst_addr_l),
        .dst_addr_h(dst_addr_h),
        .img_width(img_width),
        .img_height(img_height),
        .filter_mode(filter_mode),
        .threshold(threshold),
        .roi_x(roi_x),
        .roi_y(roi_y),
        .roi_w(roi_w),
        .roi_h(roi_h),
        
        // 状态寄存器输入
        .isp_status(isp_status)
    );
    
    // ============================================
    // AXI Master DMA 控制
    // ============================================
    
    axi_isp_master_dma #(
        .ADDR_WIDTH(C_M_AXI_ADDR_WIDTH),
        .DATA_WIDTH(C_M_AXI_DATA_WIDTH),
        .ID_WIDTH(C_M_AXI_ID_WIDTH)
    ) dma_inst (
        .clk(clk),
        .resetn(resetn),
        
        // AXI Master 接口
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awid(m_axi_awid),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_awsize(m_axi_awsize),
        .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        
        .m_axi_bid(m_axi_bid),
        .m_axi_bresp(m_axi_bresp),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arid(m_axi_arid),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_arsize(m_axi_arsize),
        .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rid(m_axi_rid),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        
        // 控制信号
        .src_addr_l(src_addr_l),
        .src_addr_h(src_addr_h),
        .dst_addr_l(dst_addr_l),
        .dst_addr_h(dst_addr_h),
        .img_width(img_width),
        .img_height(img_height),
        .filter_mode(filter_mode),
        .dma_enable(isp_ctrl[3]),  // START 位
        .dma_done(dma_done),
        .dma_error(dma_error)
    );
    
    // ============================================
    // 状态管理
    // ============================================
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            isp_status <= 0;
        end else begin
            // 更新状态寄存器
            isp_status[7] <= dma_done;           // INTERRUPT
            isp_status[6] <= dma_error;          // DMA_ERROR
            isp_status[5] <= 0;                  // DVI_BUSY (预留)
            isp_status[4] <= isp_ctrl[3];        // PROCESSING
        end
    end
    
    // 中断输出
    assign intr = dma_done;
    
    // DVI 输出控制 (可选)
    assign dvi_enable = isp_ctrl[7];        // ENABLE_DVI
    assign dvi_valid = dma_done;            // 处理完成时输出有效
    
    // DVI 数据:实现滤波器输出路由到 DVI
    // 简化版：直接连接 DMA 读取的数据
    // 实际应该通过处理管道
    assign dvi_data = m_axi_rdata[31:0];

endmodule


// ============================================================
// AXI ISP Slave 寄存器接口模块
// ============================================================

module axi_isp_slave_reg #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 12,
    parameter ID_WIDTH = 5
)(
    input wire clk,
    input wire resetn,
    
    // AXI Slave 端口
    input wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input wire [ID_WIDTH-1:0] s_axi_awid,
    input wire [7:0] s_axi_awlen,
    input wire [2:0] s_axi_awsize,
    input wire [1:0] s_axi_awburst,
    input wire s_axi_awvalid,
    output reg s_axi_awready,
    
    input wire [DATA_WIDTH-1:0] s_axi_wdata,
    input wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input wire s_axi_wlast,
    input wire s_axi_wvalid,
    output reg s_axi_wready,
    
    output reg [ID_WIDTH-1:0] s_axi_bid,
    output reg [1:0] s_axi_bresp,
    output reg s_axi_bvalid,
    input wire s_axi_bready,
    
    input wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input wire [ID_WIDTH-1:0] s_axi_arid,
    input wire [7:0] s_axi_arlen,
    input wire [2:0] s_axi_arsize,
    input wire [1:0] s_axi_arburst,
    input wire s_axi_arvalid,
    output reg s_axi_arready,
    
    output reg [DATA_WIDTH-1:0] s_axi_rdata,
    output reg [ID_WIDTH-1:0] s_axi_rid,
    output reg [1:0] s_axi_rresp,
    output reg s_axi_rlast,
    output reg s_axi_rvalid,
    input wire s_axi_rready,
    
    // 寄存器接口
    output reg [DATA_WIDTH-1:0] isp_ctrl,
    output reg [DATA_WIDTH-1:0] src_addr_l,
    output reg [DATA_WIDTH-1:0] src_addr_h,
    output reg [DATA_WIDTH-1:0] dst_addr_l,
    output reg [DATA_WIDTH-1:0] dst_addr_h,
    output reg [DATA_WIDTH-1:0] img_width,
    output reg [DATA_WIDTH-1:0] img_height,
    output reg [DATA_WIDTH-1:0] filter_mode,
    output reg [DATA_WIDTH-1:0] threshold,
    output reg [DATA_WIDTH-1:0] roi_x,
    output reg [DATA_WIDTH-1:0] roi_y,
    output reg [DATA_WIDTH-1:0] roi_w,
    output reg [DATA_WIDTH-1:0] roi_h,
    
    input wire [DATA_WIDTH-1:0] isp_status
);

    // ============================================
    // 寄存器定义
    // ============================================
    
    reg [DATA_WIDTH-1:0] reg_mem [0:15];  // 16 个 32 位寄存器
    
    // 寄存器地址映射
    localparam ISP_CTRL_ADDR       = 4'h0;  // 0x00
    localparam ISP_STATUS_ADDR     = 4'h1;  // 0x04
    localparam SRC_ADDR_L_ADDR     = 4'h2;  // 0x08
    localparam SRC_ADDR_H_ADDR     = 4'h3;  // 0x0C
    localparam DST_ADDR_L_ADDR     = 4'h4;  // 0x10
    localparam DST_ADDR_H_ADDR     = 4'h5;  // 0x14
    localparam IMG_WIDTH_ADDR      = 4'h6;  // 0x18
    localparam IMG_HEIGHT_ADDR     = 4'h7;  // 0x1C
    localparam FILTER_MODE_ADDR    = 4'h8;  // 0x20
    localparam THRESHOLD_ADDR      = 4'h9;  // 0x24
    localparam ROI_XY_ADDR         = 4'hA;  // 0x28
    localparam ROI_WH_ADDR         = 4'hB;  // 0x2C
    
    // 写操作处理
    wire aw_en = s_axi_awvalid && s_axi_awready;
    wire w_en = s_axi_wvalid && s_axi_wready;
    
    reg [ADDR_WIDTH-1:0] write_addr;
    reg [ID_WIDTH-1:0] write_id;
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_awready <= 1;
            write_addr <= 0;
            write_id <= 0;
        end else begin
            if (aw_en) begin
                write_addr <= s_axi_awaddr;
                write_id <= s_axi_awid;
                s_axi_awready <= 0;
            end else if (w_en) begin
                s_axi_awready <= 1;
            end
        end
    end
    
    // 数据写入
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_wready <= 0;
            isp_ctrl <= 0;
            src_addr_l <= 0;
            src_addr_h <= 0;
            dst_addr_l <= 0;
            dst_addr_h <= 0;
            img_width <= 0;
            img_height <= 0;
            filter_mode <= 0;
            threshold <= 0;
            roi_x <= 0;
            roi_y <= 0;
            roi_w <= 0;
            roi_h <= 0;
        end else begin
            s_axi_wready <= s_axi_awvalid && !s_axi_wready;
            
            if (w_en) begin
                case (write_addr[5:2])
                    ISP_CTRL_ADDR:     isp_ctrl <= s_axi_wdata;
                    SRC_ADDR_L_ADDR:   src_addr_l <= s_axi_wdata;
                    SRC_ADDR_H_ADDR:   src_addr_h <= s_axi_wdata;
                    DST_ADDR_L_ADDR:   dst_addr_l <= s_axi_wdata;
                    DST_ADDR_H_ADDR:   dst_addr_h <= s_axi_wdata;
                    IMG_WIDTH_ADDR:    img_width <= s_axi_wdata;
                    IMG_HEIGHT_ADDR:   img_height <= s_axi_wdata;
                    FILTER_MODE_ADDR:  filter_mode <= s_axi_wdata;
                    THRESHOLD_ADDR:    threshold <= s_axi_wdata;
                    ROI_XY_ADDR:       {roi_y, roi_x} <= s_axi_wdata;
                    ROI_WH_ADDR:       {roi_h, roi_w} <= s_axi_wdata;
                    default: ;
                endcase
            end
        end
    end
    
    // 写响应
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_bvalid <= 0;
            s_axi_bid <= 0;
            s_axi_bresp <= 0;
        end else begin
            if (w_en && s_axi_wlast) begin
                s_axi_bvalid <= 1;
                s_axi_bid <= write_id;
                s_axi_bresp <= 0;  // OKAY
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 0;
            end
        end
    end
    
    // 读操作
    wire ar_en = s_axi_arvalid && s_axi_arready;
    
    reg [ADDR_WIDTH-1:0] read_addr;
    reg [ID_WIDTH-1:0] read_id;
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_arready <= 1;
            read_addr <= 0;
            read_id <= 0;
        end else begin
            if (ar_en) begin
                read_addr <= s_axi_araddr;
                read_id <= s_axi_arid;
                s_axi_arready <= 0;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_arready <= 1;
            end
        end
    end
    
    // 数据读出
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            s_axi_rvalid <= 0;
        end else begin
            if (ar_en) begin
                s_axi_rvalid <= 1;
                s_axi_rid <= s_axi_arid;
                s_axi_rlast <= 1;
                s_axi_rresp <= 0;  // OKAY
                
                case (s_axi_araddr[5:2])
                    ISP_CTRL_ADDR:     s_axi_rdata <= isp_ctrl;
                    ISP_STATUS_ADDR:   s_axi_rdata <= isp_status;
                    SRC_ADDR_L_ADDR:   s_axi_rdata <= src_addr_l;
                    SRC_ADDR_H_ADDR:   s_axi_rdata <= src_addr_h;
                    DST_ADDR_L_ADDR:   s_axi_rdata <= dst_addr_l;
                    DST_ADDR_H_ADDR:   s_axi_rdata <= dst_addr_h;
                    IMG_WIDTH_ADDR:    s_axi_rdata <= img_width;
                    IMG_HEIGHT_ADDR:   s_axi_rdata <= img_height;
                    FILTER_MODE_ADDR:  s_axi_rdata <= filter_mode;
                    THRESHOLD_ADDR:    s_axi_rdata <= threshold;
                    ROI_XY_ADDR:       s_axi_rdata <= {roi_y, roi_x};
                    ROI_WH_ADDR:       s_axi_rdata <= {roi_h, roi_w};
                    default:           s_axi_rdata <= 0;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 0;
            end
        end
    end

endmodule

