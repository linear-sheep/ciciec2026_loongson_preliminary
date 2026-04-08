/**
 * ISP 图像处理管道 - Sobel 边缘检测模块
 * 
 * 优化版本：支持流式处理和行缓冲
 */

module isp_sobel_filter (
    input wire clk,
    input wire resetn,
    
    // 输入像素流
    input wire [7:0] pixel_in,
    input wire pixel_valid,
    input wire [31:0] pixel_row,     // 当前行号
    input wire [31:0] pixel_col,     // 当前列号
    input wire [31:0] img_width,
    input wire [31:0] img_height,
    input wire [7:0] threshold,      // 边缘阈值
    
    // 输出结果
    output reg [15:0] edge_out,      // 边缘强度 (0-65535)
    output reg edge_valid,
    output wire pipeline_ready       // 管道是否准备好接收下一个像素
);

    // ============================================
    // 3 行行缓冲（用于 3x3 窗口）
    // ============================================
    
    reg [7:0] line_a [0:1279];    // 第 i-1 行
    reg [7:0] line_b [0:1279];    // 第 i 行
    reg [7:0] line_c [0:1279];    // 第 i+1 行
    
    reg [31:0] col_ptr;           // 当前列指针
    wire write_en = pixel_valid && pixel_col < img_width;
    
    // 行缓冲写入逻辑
    always @(posedge clk) begin
        if (write_en) begin
            case (pixel_row[1:0])
                0: line_a[col_ptr] <= pixel_in;
                1: line_b[col_ptr] <= pixel_in;
                2: line_c[col_ptr] <= pixel_in;
                default: ;
            endcase
        end
    end
    
    // ============================================
    // 3x3 窗口提取
    // ============================================
    
    reg [7:0] p00, p01, p02;   // 第 0 行
    reg [7:0] p10, p11, p12;   // 第 1 行
    reg [7:0] p20, p21, p22;   // 第 2 行
    
    wire window_valid = (pixel_row >= 2) && (pixel_col >= 1) && (pixel_col < img_width - 1);
    
    always @(posedge clk) begin
        if (pixel_valid && pixel_col > 0) begin
            // 从缓冲区读取 3x3 窗口
            if (pixel_row >= 2) begin
                p00 <= line_a[col_ptr - 1];
                p01 <= line_a[col_ptr];
                p02 <= line_a[col_ptr + 1];
                p10 <= line_b[col_ptr - 1];
                p11 <= line_b[col_ptr];
                p12 <= line_b[col_ptr + 1];
                p20 <= line_c[col_ptr - 1];
                p21 <= line_c[col_ptr];
                p22 <= line_c[col_ptr + 1];
            end
        end
    end
    
    // ============================================
    // Sobel 算子计算
    // ============================================
    
    // Gx = [-1  0  1]
    //      [-2  0  2]
    //      [-1  0 -1]
    
    // Gy = [-1 -2 -1]
    //      [ 0  0  0]
    //      [ 1  2  1]
    
    wire signed [15:0] gx = {1'b0, p00} + {3'b0, p10} - {3'b0, p12} - {1'b0, p22} 
                            - ({1'b0, p02} << 1) + ({1'b0, p20} << 1);
    
    wire signed [15:0] gy = {1'b0, p20} + {1'b0, p21} + {1'b0, p22}
                            - {1'b0, p00} - {1'b0, p01} - {1'b0, p02};
    
    // 计算边缘强度（简化版：|Gx| + |Gy|）
    wire [15:0] gx_abs = (gx[15]) ? -gx : gx;
    wire [15:0] gy_abs = (gy[15]) ? -gy : gy;
    wire [15:0] magnitude = gx_abs + gy_abs;
    
    // 更精确版本（可选）：sqrt(Gx^2 + Gy^2)
    // wire [31:0] magnitude_sq = gx * gx + gy * gy;
    // (需要平方根模块)
    
    // ============================================
    // 阈值判决
    // ============================================
    
    reg [15:0] magnitude_delayed;
    reg threshold_valid;
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            magnitude_delayed <= 0;
            threshold_valid <= 0;
        end else begin
            if (window_valid) begin
                magnitude_delayed <= magnitude;
                threshold_valid <= 1;
            end else begin
                threshold_valid <= 0;
            end
        end
    end
    
    // ============================================
    // 输出阶段
    // ============================================
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            edge_out <= 0;
            edge_valid <= 0;
        end else begin
            if (threshold_valid) begin
                // 应用阈值（可选）
                if (magnitude_delayed > {8'b0, threshold}) begin
                    edge_out <= magnitude_delayed;
                end else begin
                    edge_out <= 0;
                end
                edge_valid <= 1;
            end else begin
                edge_valid <= 0;
            end
        end
    end
    
    // 管道准备信号
    assign pipeline_ready = !pixel_valid || col_ptr < img_width;

endmodule


/**
 * ISP 图像处理管道 - 高斯模糊模块
 */

module isp_gaussian_filter (
    input wire clk,
    input wire resetn,
    
    // 输入像素流
    input wire [7:0] pixel_in,
    input wire pixel_valid,
    input wire [31:0] pixel_row,
    input wire [31:0] pixel_col,
    input wire [31:0] img_width,
    input wire [31:0] img_height,
    
    // 输出: 模糊后的灰度值
    output reg [7:0] blur_out,
    output reg blur_valid
);

    // ============================================
    // 3 行行缓冲
    // ============================================
    
    reg [7:0] line_a [0:1279];
    reg [7:0] line_b [0:1279];
    reg [7:0] line_c [0:1279];
    
    reg [31:0] col_ptr;
    wire write_en = pixel_valid && pixel_col < img_width;
    
    always @(posedge clk) begin
        if (write_en) begin
            case (pixel_row[1:0])
                0: line_a[col_ptr] <= pixel_in;
                1: line_b[col_ptr] <= pixel_in;
                2: line_c[col_ptr] <= pixel_in;
                default: ;
            endcase
        end
    end
    
    // ============================================
    // 3x3 窗口提取
    // ============================================
    
    reg [7:0] p00, p01, p02;
    reg [7:0] p10, p11, p12;
    reg [7:0] p20, p21, p22;
    
    wire window_valid = (pixel_row >= 2) && (pixel_col >= 1) && (pixel_col < img_width - 1);
    
    always @(posedge clk) begin
        if (pixel_valid && pixel_col > 0 && pixel_row >= 2) begin
            p00 <= line_a[col_ptr - 1];
            p01 <= line_a[col_ptr];
            p02 <= line_a[col_ptr + 1];
            p10 <= line_b[col_ptr - 1];
            p11 <= line_b[col_ptr];
            p12 <= line_b[col_ptr + 1];
            p20 <= line_c[col_ptr - 1];
            p21 <= line_c[col_ptr];
            p22 <= line_c[col_ptr + 1];
        end
    end
    
    // ============================================
    // 高斯卷积 (1/16 * [1 2 1; 2 4 2; 1 2 1])
    // ============================================
    
    wire [15:0] sum = 
        p00 + (p01 << 1) + p02 +
        (p10 << 1) + (p11 << 2) + (p12 << 1) +
        p20 + (p21 << 1) + p22;
    
    wire [7:0] blur_result = sum >> 4;  // 除以 16
    
    // ============================================
    // 输出缓冲
    // ============================================
    
    reg [7:0] blur_delayed;
    reg blur_delayed_valid;
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            blur_out <= 0;
            blur_valid <= 0;
        end else begin
            if (window_valid) begin
                blur_out <= blur_result;
                blur_valid <= 1;
            end else begin
                blur_valid <= 0;
            end
        end
    end

endmodule


/**
 * ISP 图像处理管道 - 灰度化模块
 * 输入: RGB24 或 ARGB32
 * 输出: 8-bit 灰度
 */

module isp_grayscale_filter (
    input wire clk,
    input wire resetn,
    
    // 输入像素 (RGB)
    input wire [23:0] rgb_in,   // R[23:16], G[15:8], B[7:0]
    input wire pixel_valid,
    
    // 输出灰度
    output reg [7:0] gray_out,
    output reg gray_valid
);

    // 提取 RGB 分量
    wire [7:0] r = rgb_in[23:16];
    wire [7:0] g = rgb_in[15:8];
    wire [7:0] b = rgb_in[7:0];
    
    // BT.601 标准灰度化
    // Y = 0.299*R + 0.587*G + 0.114*B
    // 或近似：Y = (77*R + 150*G + 29*B) >> 8
    
    wire [15:0] y_temp = ({2'b0, r} << 6) + ({2'b0, r} << 4) + ({2'b0, r} << 3) +  // 77*R
                         ({2'b0, g} << 7) + ({2'b0, g} << 4) + ({2'b0, g} << 3) +  // 150*G
                         ({2'b0, b} << 4) + ({2'b0, b} << 3) + ({2'b0, b} << 2) +  // 29*B
                         ({2'b0, b} << 1) + {2'b0, b};
    
    wire [7:0] gray_result = y_temp >> 8;
    
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            gray_out <= 0;
            gray_valid <= 0;
        end else begin
            if (pixel_valid) begin
                gray_out <= gray_result;
                gray_valid <= 1;
            end else begin
                gray_valid <= 0;
            end
        end
    end

endmodule

