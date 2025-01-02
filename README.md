# UART Top 模块

*本README由AI生成，可能存在不准确之处，请谨慎参考。*

## 项目简介

UART Top 模块是一个顶层的UART（通用异步收发传输）模块，用于实现串口数据的发送与接收。该模块集成了UART的发送和接收功能，通过异步FIFO（先进先出）缓冲区来处理接收的数据，并控制数据的发送。该模块适用于需要通过串口进行数据通信并需要数据缓冲的各种嵌入式系统设计。

## 主要功能

- **UART 发送与接收**：实现标准的UART通信协议，支持数据的发送和接收。
- **数据缓冲**：使用异步FIFO缓冲接收的数据，确保数据传输的稳定性和可靠性。
- **参数化设计**：支持多种配置参数，适应不同的系统时钟频率和波特率需求。

## 参数依赖

在使用UART Top模块时，需要根据具体的系统需求配置以下参数：

- `UART_DIVISOR_V`：根据系统时钟和所需波特率配置分频值。例如，50MHz系统时钟和115200波特率时，`UART_DIVISOR_V` 设置为433。
- `RAM_DEPTH`：异步FIFO内部RAM的深度，决定FIFO能够缓冲的数据量。
- `RAM_ADDR_WIDTH`：异步FIFO内部RAM的地址宽度，决定RAM深度为2^`RAM_ADDR_WIDTH`。
- `WR_WIDTH`：异步FIFO写端口的数据宽度。
- `RD_WIDTH`：异步FIFO读端口的数据宽度。
- `WR_CNT_WIDTH`：异步FIFO写端口计数器的位宽。
- `RD_CNT_WIDTH`：异步FIFO读端口计数器的位宽。
- `RAM_RD2WR`：异步FIFO读数据位宽与写数据位宽的比率。

## 示例配置

以下是一个典型的配置示例：

- **系统时钟**：50MHz
- **波特率**：115200
- **UART_DIVISOR_V**：433
- **RAM_DEPTH**：2048（对应 `RAM_ADDR_WIDTH` = 11）
- **FIFO 数据宽度**：
  - 写端口数据宽度：8位
  - 读端口数据宽度：8位
- **计数器位宽**：
  - `WR_CNT_WIDTH`：12位（可以表示最多2048个8位数据）

## 模块接口

```verilog
module uart_top (
    // 系统时钟和复位
    input         clk,      // 系统时钟
    input         rst_n,    // 低有效复位信号

    // UART引脚 
    input         rxd,      // UART接收数据输入
    output        txd       // UART发送数据输出
);
```

### 输入信号

- `clk`：系统时钟输入。
- `rst_n`：低有效复位信号。

### UART接口

- `rxd`：UART接收数据输入。
- `txd`：UART发送数据输出。

## 使用说明

1. **参数配置**：根据系统时钟和所需波特率设置`UART_DIVISOR_V`，并根据需求配置FIFO的深度和数据宽度等参数。
2. **模块集成**：将`uart_top`模块集成到您的设计中，连接系统时钟、复位信号以及UART的RXD和TXD引脚。
3. **TCL脚本**：项目包含用于Vivado的TCL脚本，确保在Vivado环境中进行正确的设置和配置。
4. **测试**：包含一个测试平台（tb文件），请自行阅读和使用以验证模块功能。
5. **数据传输**：通过UART接口发送和接收数据，接收到的数据将自动存储到FIFO中，并可以根据需要将数据发送回。

## 资源占用

| 资源类型 | 已使用 / 总量 |
|----------|---------------|
| LUT      | 79 / 203800    |
| FF       | 137 / 407600   |
| BRAM     | 0.5 / 445      |
| IO       | 4 / 400        |
| BUFG     | 1 / 32         |

## 依赖工具

- **硬件描述语言**：Verilog
- **开发工具**：Vivado（已通过Vivado测试）
- **测试平台**：包含测试平台文件（tb文件）供参考

## 许可

允许自由复制、修改和商业化使用。
