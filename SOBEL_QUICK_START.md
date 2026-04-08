# Sobel 加速器 - 快速参考指南

## 🎯 概览

您的 SoC 现已整合 Sobel 边缘检测加速器！本指南提供快速集成和验证步骤。

## 📦 已创建的文件

### 硬件模块 (Verilog)
```
f:\la32r_soc\rtl\ip\sobel\
├── line_buffer.v                  (3行像素缓冲)
├── sobel_edge_detector.v          (Sobel卷积计算)
└── axi_sobel_accelerator.v        (AXI接口包装器)
```

### 软件驱动 (C/C++)
```
f:\la32r_soc\sdk\software\
└── sobel_driver.h                 (完整驱动程序库)
```

### 文档
```
f:\la32r_soc\doc\
└── SOBEL_ACCELERATOR_INTEGRATION.md (详细规格和说明)

f:\la32r_soc\
└── README_SOBEL.md                (完整集成总结)
```

### 测试
```
f:\la32r_soc\sim\
└── sobel_testbench.v              (功能验证测试台)
```

### 修改的文件
```
f:\la32r_soc\rtl\
└── soc_top.v                      (已添加加速器实例化)
```

## 🚀 快速开始

### 1️⃣ 编译硬件

```bash
# 使用您的 FPGA 工具 (Vivado, Quartus 等)
# 确保包含这些文件:
# - rtl/soc_top.v (已修改)
# - rtl/ip/sobel/*.v (新增3个文件)
# - rtl/ip/Bus_interconnects/AxiCrossbar_2x8.v (现有)
```

### 2️⃣ 运行仿真

```bash
# 使用 ModelSim 或其他仿真工具
# 编译:
vlog f:\la32r_soc\rtl\ip\sobel\*.v
vlog f:\la32r_soc\sim\sobel_testbench.v

# 运行:
vsim sobel_testbench -do "run -all"
```

### 3️⃣ 集成软件驱动

```c
// 在你的 C 代码中包含驱动
#include "sobel_driver.h"

// 初始化
sobel_init();

// 处理图像
sobel_image_t img = {
    .width = 1280,
    .height = 720,
    .input_data = input_buffer,
    .output_data = output_buffer
};
sobel_process_image_fast(&img);
```

## 📋 地址映射速查表

| 地址 | 名称 | 类型 | 用途 |
|------|------|------|------|
| 0x1FD0_1000 | PIXEL_INPUT | Write | 像素输入 |
| 0x1FD0_1004 | RESULT | Read | 结果读取 |
| 0x1FD0_1008 | STATUS | Read | 状态标志 |

## 💾 寄存器说明

### PIXEL_INPUT (0x1FD0_1000)
```
[7:0]    : 像素值 (0-255)
[31:8]   : 未使用 (写0)
```

### RESULT (0x1FD0_1004)
```
[15:0]   : 边缘幅度 (0-65535)
[31:16]  : 未使用
```

### STATUS (0x1FD0_1008)
```
[0]      : 结果有效标志
[31:1]   : 未使用
```

## ⚡ 性能参数

| 参数 | 值 |
|------|-----|
| 时钟频率 | 100 MHz (可扩展) |
| 像素吞吐量 | 1 px/cycle |
| 预热延迟 | 2×WIDTH + 3 cycles |
| 对于 1280 宽 | 2,563 cycles (~25.6 μs) |

## 🔧 关键配置

```verilog
// 在 axi_sobel_accelerator.v 中可配置:
parameter IMG_WIDTH = 1280;      // 图像宽度
parameter AXI_DATA_WIDTH = 32;   // AXI 数据宽度
```

## ⚠️ 重要提示

### ✅ 必须做的:
- [x] 连接 sys_clk 和 sys_resetn
- [x] 验证 axiOut_1 被正确路由
- [x] 确保 AXI 握手信号连通
- [x] 考虑预热延迟在软件中

### ❌ 注意避免:
- 不要在预热期间读取结果
- 不要超过 32 位像素数据宽度 (需修改代码)
- 不要忽视 3×3 内核的边缘效应

## 🧪 验证检查清单

```
[ ] 硬件编译通过
[ ] 仿真测试通过
[ ] 设备寻址正确 (0x1FD0_1000)
[ ] 可成功写入像素
[ ] 可读取结果寄存器
[ ] 预热延迟后出现有效结果
[ ] 产出边缘检测正确
```

## 📊 Python 测试脚本示例

```python
import numpy as np
from PIL import Image

def process_with_sobel(image_path, threshold=50):
    # 加载图像
    img = Image.open(image_path).convert('L')
    pixels = np.array(img, dtype=np.uint8)
    
    # 准备缓冲区
    height, width = pixels.shape
    results = np.zeros((height, width), dtype=np.uint16)
    
    # 通过硬件发送所有像素
    for plane in pixels.flatten():
        write_pixel_via_axi(plane)
    
    # 读取结果
    for i in range(2*width + 3, width*height):
        results.flat[i] = read_result_via_axi()
    
    # 阈值化
    binary = (results > threshold).astype(np.uint8) * 255
    
    return binary
```

## 🐛 故障排除

### 问题 1: 没收到结果
**原因**: 可能在预热期结束前尝试读取
**解决**: 确保写入了足够像素 (至少 2×WIDTH+3)

### 问题 2: 结果全是 0
**原因**: 输入也全 0，或者计算未触发
**解决**: 验证像素确实被写入，检查 window_valid 信号

### 问题 3: 地址译码失败  
**原因**: AxiCrossbar 可能未正确配置
**解决**: 检查 soc_top.v 中的 axiOut_1 连接

## 📚 更多信息

- 详细硬件规格: `doc/SOBEL_ACCELERATOR_INTEGRATION.md`
- 完整集成总结: `README_SOBEL.md`
- API 文档: `sdk/software/sobel_driver.h` (含详细注释)
- 测试示例: `sim/sobel_testbench.v`

## 🎓 原理简介

### Sobel 卷积核
```
Gx 计算:          Gy 计算:
[-1  0  1]       [-1 -2 -1]
[-2  0  2]  ×    [ 0  0  0]
[-1  0  1]       [ 1  2  1]

边缘幅度 = |Gx| + |Gy|  (快速近似)
或 = sqrt(Gx² + Gy²)    (精确)
```

### 处理流程
```
1. 输入像素 → 
2. Line Buffer 缓冲 3 行 →
3. 3×3 窗口完整 →
4. Sobel 卷积计算 →
5. 结果寄存器 →
6. CPU 读取结果
```

## 💡 优化提示

1. **并行写读**: 使用 `sobel_process_image_fast()` 而不是两阶段
2. **DMA 支持**: 考虑添加 DMA 自动加载像素 (需扩展)
3. **批处理**: 处理多幅图像时避免重复初始化
4. **阈值在线**: 在读数据时同时进行阈值化处理

## 📞 支持信息

- 所有模块均包含详细注释
- 每个函数都有完整文档字符串
- 参考 C 驱动包含 5 个高层函数

---

**最后更新**: 2026-04-08  
**状态**: ✅ 完全可用
