/**
 * AXI ISP Core 驱动库
 * 
 * 功能：
 * - ISP Core 初始化和配置
 * - 图像处理 API
 * - 中断和状态管理
 */

#ifndef ISP_DRIVER_H
#define ISP_DRIVER_H

#include <stdint.h>
#include <string.h>

// ============================================
// ISP Core 基地址和寄存器定义
// ============================================

#define ISP_BASE_ADDR           0xbfd02000UL

// 寄存器偏移
#define ISP_CTRL                (ISP_BASE_ADDR + 0x00)
#define ISP_STATUS              (ISP_BASE_ADDR + 0x04)
#define ISP_SRC_ADDR_L          (ISP_BASE_ADDR + 0x08)
#define ISP_SRC_ADDR_H          (ISP_BASE_ADDR + 0x0C)
#define ISP_DST_ADDR_L          (ISP_BASE_ADDR + 0x10)
#define ISP_DST_ADDR_H          (ISP_BASE_ADDR + 0x14)
#define ISP_IMG_WIDTH           (ISP_BASE_ADDR + 0x18)
#define ISP_IMG_HEIGHT          (ISP_BASE_ADDR + 0x1C)
#define ISP_FILTER_MODE         (ISP_BASE_ADDR + 0x20)
#define ISP_THRESHOLD           (ISP_BASE_ADDR + 0x24)
#define ISP_ROI_X               (ISP_BASE_ADDR + 0x28)
#define ISP_ROI_Y               (ISP_BASE_ADDR + 0x2C)
#define ISP_ROI_W               (ISP_BASE_ADDR + 0x30)
#define ISP_ROI_H               (ISP_BASE_ADDR + 0x34)

// ISP_CTRL 位定义
#define ISP_CTRL_START          (1 << 3)    // 启动处理
#define ISP_CTRL_WRITE_DDR      (1 << 5)    // 写入 DDR
#define ISP_CTRL_ENABLE_ROI     (1 << 4)    // 处理 ROI
#define ISP_CTRL_INVERT         (1 << 6)    // 反转输出
#define ISP_CTRL_ENABLE_DVI     (1 << 7)    // 启用 DVI 输出

// ISP_STATUS 位定义
#define ISP_STATUS_INTERRUPT    (1 << 7)    // 中断标志
#define ISP_STATUS_DMA_ERROR    (1 << 6)    // DMA 错误
#define ISP_STATUS_DVI_BUSY     (1 << 5)    // DVI 忙碌
#define ISP_STATUS_PROCESSING   (1 << 4)    // 正在处理

// 滤波器模式定义
#define ISP_MODE_SOBEL          0
#define ISP_MODE_GAUSSIAN       1
#define ISP_MODE_GRAYSCALE      2
#define ISP_MODE_RESERVED       3

// ============================================
// 辅助宏定义
// ============================================

#define RegWrite(addr, val)  (*((volatile uint32_t *)(addr)) = (val))
#define RegRead(addr)        (*((volatile uint32_t *)(addr)))

// ============================================
// 数据结构
// ============================================

/**
 * ISP 处理参数结构体
 */
typedef struct {
    uint32_t src_addr;          // 源图像地址（DDR）
    uint32_t dst_addr;          // 目的地址（DDR 或内部缓冲）
    uint32_t img_width;         // 图像宽度（像素）
    uint32_t img_height;        // 图像高度（像素）
    uint32_t filter_mode;       // 滤波器类型（0=Sobel, 1=Gaussian, 2=Grayscale）
    uint32_t threshold;         // 阈值（用于 Sobel）
    uint32_t roi_x, roi_y;      // ROI 起始坐标
    uint32_t roi_w, roi_h;      // ROI 大小
    uint32_t enable_roi;        // 是否仅处理 ROI
    uint32_t enable_dvi;        // 是否直接输出到 DVI
} isp_config_t;

/**
 * ISP 状态结构体
 */
typedef struct {
    uint32_t is_processing;     // 正在处理
    uint32_t is_complete;       // 处理完成
    uint32_t has_error;         // 发生错误
    uint32_t dvi_busy;          // DVI 忙碌
} isp_status_t;

// ============================================
// ISP 驱动函数
// ============================================

/**
 * ISP 初始化
 */
void isp_init(void) {
    // 重置 ISP Core
    RegWrite(ISP_CTRL, 0);
}

/**
 * 设置 ISP 配置
 */
void isp_set_config(const isp_config_t *config) {
    // 写入源/目的地址（64 位）
    RegWrite(ISP_SRC_ADDR_L, config->src_addr & 0xFFFFFFFF);
    RegWrite(ISP_SRC_ADDR_H, (config->src_addr >> 32) & 0xFFFFFFFF);
    RegWrite(ISP_DST_ADDR_L, config->dst_addr & 0xFFFFFFFF);
    RegWrite(ISP_DST_ADDR_H, (config->dst_addr >> 32) & 0xFFFFFFFF);
    
    // 写入图像大小
    RegWrite(ISP_IMG_WIDTH, config->img_width);
    RegWrite(ISP_IMG_HEIGHT, config->img_height);
    
    // 写入滤波器模式和阈值
    RegWrite(ISP_FILTER_MODE, config->filter_mode);
    RegWrite(ISP_THRESHOLD, config->threshold);
    
    // 写入 ROI（如果启用）
    if (config->enable_roi) {
        RegWrite(ISP_ROI_X, config->roi_x);
        RegWrite(ISP_ROI_Y, config->roi_y);
        RegWrite(ISP_ROI_W, config->roi_w);
        RegWrite(ISP_ROI_H, config->roi_h);
    }
}

/**
 * 启动 ISP 处理
 * 
 * 参数：
 *   write_ddr: 1=写入 DDR, 0=不写入（仅用于 DVI）
 *   enable_dvi: 1=启用 DVI 输出, 0=禁用
 */
void isp_start_process(uint32_t write_ddr, uint32_t enable_dvi) {
    uint32_t ctrl_val = ISP_CTRL_START;  // 启动位
    
    if (write_ddr) {
        ctrl_val |= ISP_CTRL_WRITE_DDR;
    }
    
    if (enable_dvi) {
        ctrl_val |= ISP_CTRL_ENABLE_DVI;
    }
    
    RegWrite(ISP_CTRL, ctrl_val);
}

/**
 * 停止 ISP 处理
 */
void isp_stop_process(void) {
    RegWrite(ISP_CTRL, 0);
}

/**
 * 等待处理完成
 * 
 * 返回值：
 *   0: 成功完成
 *   -1: 超时或错误
 */
int isp_wait_complete(uint32_t timeout_ms) {
    uint32_t timeout_count = timeout_ms * 50;  // 假设 50MHz 系统时钟
    
    while (timeout_count--) {
        uint32_t status = RegRead(ISP_STATUS);
        
        // 检查完成标志
        if (status & ISP_STATUS_INTERRUPT) {
            return 0;  // 完成
        }
        
        // 检查错误
        if (status & ISP_STATUS_DMA_ERROR) {
            return -1;  // 错误
        }
    }
    
    return -1;  // 超时
}

/**
 * 读取 ISP 状态
 */
isp_status_t isp_get_status(void) {
    isp_status_t status = {0};
    uint32_t isp_stat = RegRead(ISP_STATUS);
    
    status.is_processing = (isp_stat & ISP_STATUS_PROCESSING) ? 1 : 0;
    status.is_complete = (isp_stat & ISP_STATUS_INTERRUPT) ? 1 : 0;
    status.has_error = (isp_stat & ISP_STATUS_DMA_ERROR) ? 1 : 0;
    status.dvi_busy = (isp_stat & ISP_STATUS_DVI_BUSY) ? 1 : 0;
    
    return status;
}

/**
 * Sobel 边缘检测快捷函数
 * 
 * 参数：
 *   src_addr: 源灰度图像地址
 *   dst_addr: 目的地址（存储边缘结果）
 *   width: 图像宽度
 *   height: 图像高度
 *   threshold: 边缘阈值
 *   enable_dvi: 是否输出到 DVI
 */
int isp_sobel_edge_detect(uint32_t src_addr, uint32_t dst_addr,
                          uint32_t width, uint32_t height,
                          uint32_t threshold, uint32_t enable_dvi) {
    isp_config_t config = {
        .src_addr = src_addr,
        .dst_addr = dst_addr,
        .img_width = width,
        .img_height = height,
        .filter_mode = ISP_MODE_SOBEL,
        .threshold = threshold,
        .enable_roi = 0,
        .enable_dvi = enable_dvi
    };
    
    isp_set_config(&config);
    isp_start_process(1, enable_dvi);
    
    return isp_wait_complete(5000);  // 5 秒超时
}

/**
 * 高斯模糊快捷函数
 */
int isp_gaussian_blur(uint32_t src_addr, uint32_t dst_addr,
                      uint32_t width, uint32_t height,
                      uint32_t enable_dvi) {
    isp_config_t config = {
        .src_addr = src_addr,
        .dst_addr = dst_addr,
        .img_width = width,
        .img_height = height,
        .filter_mode = ISP_MODE_GAUSSIAN,
        .threshold = 0,
        .enable_roi = 0,
        .enable_dvi = enable_dvi
    };
    
    isp_set_config(&config);
    isp_start_process(1, enable_dvi);
    
    return isp_wait_complete(5000);
}

/**
 * 灰度化快捷函数
 */
int isp_grayscale_convert(uint32_t src_addr, uint32_t dst_addr,
                          uint32_t width, uint32_t height,
                          uint32_t enable_dvi) {
    isp_config_t config = {
        .src_addr = src_addr,
        .dst_addr = dst_addr,
        .img_width = width,
        .img_height = height,
        .filter_mode = ISP_MODE_GRAYSCALE,
        .threshold = 0,
        .enable_roi = 0,
        .enable_dvi = enable_dvi
    };
    
    isp_set_config(&config);
    isp_start_process(1, enable_dvi);
    
    return isp_wait_complete(5000);
}

/**
 * ROI 处理快捷函数
 * 
 * 只处理感兴趣区域，而不是整个图像
 */
int isp_process_roi(uint32_t src_addr, uint32_t dst_addr,
                    uint32_t img_width, uint32_t img_height,
                    uint32_t roi_x, uint32_t roi_y,
                    uint32_t roi_w, uint32_t roi_h,
                    uint32_t filter_mode, uint32_t threshold) {
    isp_config_t config = {
        .src_addr = src_addr,
        .dst_addr = dst_addr,
        .img_width = img_width,
        .img_height = img_height,
        .filter_mode = filter_mode,
        .threshold = threshold,
        .roi_x = roi_x,
        .roi_y = roi_y,
        .roi_w = roi_w,
        .roi_h = roi_h,
        .enable_roi = 1,
        .enable_dvi = 0
    };
    
    isp_set_config(&config);
    isp_start_process(1, 0);
    
    return isp_wait_complete(5000);
}

/**
 * 清除中断标志
 */
void isp_clear_interrupt(void) {
    // 在中断处理程序中调用
    // 下一次读 ISP_STATUS 会自动清除
}

/**
 * 链式处理多个滤波器
 * 例：RGB -> Grayscale -> Sobel -> DVI
 */
int isp_pipeline_process(uint32_t src_addr_rgb,
                        uint32_t temp_gray,
                        uint32_t dst_addr_edge,
                        uint32_t width, uint32_t height) {
    int ret;
    
    // 步骤 1: RGB -> 灰度
    printf("[ISP] Step 1: RGB -> Grayscale\n");
    ret = isp_grayscale_convert(src_addr_rgb, temp_gray, width, height, 0);
    if (ret != 0) {
        printf("[ISP ERROR] Grayscale conversion failed\n");
        return -1;
    }
    
    // 步骤 2: 灰度 -> Sobel 边缘（输出到 DVI）
    printf("[ISP] Step 2: Grayscale -> Sobel Edge (DVI output)\n");
    ret = isp_sobel_edge_detect(temp_gray, dst_addr_edge, width, height, 50, 1);
    if (ret != 0) {
        printf("[ISP ERROR] Sobel edge detection failed\n");
        return -1;
    }
    
    printf("[ISP] Pipeline complete\n");
    return 0;
}

#endif  // ISP_DRIVER_H

