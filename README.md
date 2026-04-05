# 龙芯中科杯 - 参赛 SoC 项目 (LA32R)

本项目为龙芯中科杯初赛参赛代码。本项目基于 32 位 LoongArch 架构（LA32R），实现了一个完整的单核 SoC 系统，集成了 Cache、跨时钟域处理系统、AXI 总线互联架构，以及 UART、DVI、定时器等丰富外设。

## 📁 目录结构说明

- `rtl/`：硬件逻辑设计 (RTL) 源码
  - `open-la500/`：32位 LoongArch CPU 核心代码（五级流水线、TLB、D-Cache/I-Cache 等）。
  - `ip/`：外设 IP 模块，涵盖 `APB_UART`、`Bus_interconnects` (AXI Crossbar)、`confreg` (系统寄存器与外设控制)、`DVI` 显示输出等。
  - `soc_top.v`：SoC 顶层模块，负责 CPU、总线以及各外设的参数传递与例化互连。
- `fpga/`：FPGA 开发相关文件
  - `project/`：Xilinx Vivado 工程目录（包含 `Loongson_Soc.xpr` 等工程文件）。
  - `constraints/`：FPGA 管脚与时序约束文件（`soc.xdc`）。
- `sdk/`：软件开发包及应用程序
  - 包含了底层驱动、BSP 以及多项测试程序实例（`coremark`, `dhrystone`, `hello_world`, `pinball_game` 等）。
  - 包含了交叉编译环境初始化的相关脚本。
- `sim/`：仿真验证环境
  - 提供了 SoC 系统的测试平台（`mycpu_tb.v`）以及仿真必要的 SRAM 等模型。
- `doc/`：项目的相关设计和说明文档。

## ✨ 核心特性

1. **指令集与内核**：基于 LA32R 指令集实现，配有完整的异常与硬件中断响应机制（支持外部中断连线）。
2. **总线架构**：采用 AXI 协议进行高性能互联，通过自研的 AXI Crossbar 实现 CPU 对多个存储器和从设备的访问调度。
3. **外设扩展**：
   - **Confreg**：支持系统配置以及各种板载交互（定时器、LED 灯、数码管、拨码开关和按键）。
   - **UART**：支持标准串口收发交互。
   - **DVI**：实现了面向视频输出的显示控制接口。

## 🚀 快速上手

### 1. 硬件工程初始化与综合
首先，需要使用 `fpga/create_project.tcl` 脚本生成 Vivado 工程。这里提供两种生成方式：

**方式一：通过终端（命令行）生成**
在终端进入 `fpga` 目录后执行以下命令：
```bash
cd la32r_soc/fpga
vivado -mode batch -source create_project.tcl
```

**方式二：通过 Vivado 软件 GUI 生成**
1. 打开 Xilinx Vivado 开发环境。
2. 在底部 Tcl Console 窗口中，使用 `cd` 命令切换到项目的 `fpga` 目录（例如 `cd d:/la32r_soc/fpga`）。
3. 运行命令 `source create_project.tcl` 等待工程生成。

生成完成后，将自动打开 `fpga/project/Loongson_Soc.xpr` 文件。在 Vivado 中即可进行 RTL 详细网表分析、代码综合、布局布线以及比特流 (`.bit`) 的生成和烧录。

### 2. 软件工具链配置
Linux 环境下进入 `sdk/toolchains/` 目录，准备龙芯的交叉编译工具链：
```bash
# **重要提示**：运行前请务必打开 `init.sh` 脚本，
# 将末尾 `LA32RSOC_WINDOWS_HOME="/mnt/d/Project/0loongson/soc_course/la32r_soc"` 的路径值修改为你本地实际的工程绝对路径。
cd sdk/toolchains/
bash init.sh
```

### 3. 编译生成 .mif 和 .bin 产物
环境配置好后，你可以进入相应的例程目录进行编译：
```bash
cd sdk/software/examples/hello_world
make
```
编译成功后会生成 `.bin` （用于指令真实分发或烧录）和 `.mif` 内存初始化文件。可以直接将生成的 `.mif` 替换掉原本项目根目录的 `sdk/axi_ram.mif`，从而为验证平台载入新的测试程序段。

### 4. 系统仿真
在 Vivado 中将工程设为仿真模式，运行 `sim/mycpu_tb.v` 顶层测试台。仿真会自动挂载 SDK 中的 `mif` 内存文件，可以在波形图中直观验证 CPU 时序及总线交互动作。