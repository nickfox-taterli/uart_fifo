//////////////////////////////////////////////////////////////////////////////////
// Description: 
//   UART 模块
//   实现基本的 UART 发送与接收功能，包括起始位、数据位和停止位的处理。
//   使用分频器对时钟进行分频，以匹配所需的波特率。模块包括同步复位、发送与接收逻辑。
//   
// Parameter Dependencies:
//   UART_DIVISOR_V   = 根据系统时钟和所需波特率配置分频值（例如50MHz时钟，115200波特率时，分频值约为433）
//   UART_DIVISOR_W   = 分频器的位宽，由 $clog2(UART_DIVISOR_V) 自动计算
//
// Example:
//   - UART_DIVISOR_V = 433，适用于50MHz系统时钟和115200波特率
//   - UART_DIVISOR_W = $clog2(433) ≈ 9
//
// Functional Overview:
//   - **发送（TX）逻辑**：当写使能信号 `wr_i` 被触发时，加载数据到发送移位寄存器，并开始发送过程。
//     发送过程包括起始位、8位数据位和停止位的发送，通过分频器控制发送速率。
//   - **接收（RX）逻辑**：当检测到起始位时，开始接收过程，通过分频器在数据位中点采样，依次接收8位数据位和停止位。
//     接收完成后，数据可通过 `data_o` 端口读取，并通过 `rx_ready_o` 信号指示数据已准备好。
//   - **同步复位**：模块使用同步复位信号 `rst_i`，确保复位操作在时钟边沿同步进行。
//   - **引脚接口**：包括 UART 的接收引脚 `rxd_i` 和发送引脚 `txd_o`。
//////////////////////////////////////////////////////////////////////////////////

module uart
#(
    // 参数定义
    parameter UART_DIVISOR_V   = 433, // 在50MHz时，分频115200的值大约为433
    parameter UART_DIVISOR_W   = $clog2(UART_DIVISOR_V) // 自动计算分频器的位宽
)
(
    // 时钟与复位
    input         clk_i,        // 输入时钟
    input         rst_i,        // 同步复位

    // 发送接口
    input         wr_i,         // 写使能
    input  [7:0]  data_i,       // 待发送的数据
    output        tx_busy_o,    // 发送忙信号

    // 接收接口
    input         rd_i,         // 读使能
    output [7:0]  data_o,       // 接收的数据
    output        rx_ready_o,   // 接收数据准备好信号

    // UART引脚
    input         rxd_i,        // UART接收数据输入
    output        txd_o         // UART发送数据输出
);

// 常量定义
localparam   START_BIT = 4'd0; // 起始位索引
localparam   STOP_BIT  = 4'd9; // 停止位索引

// TX寄存器定义
reg                       tx_busy_q;          // 发送忙信号寄存器
reg [3:0]                 tx_bits_q;          // 发送位计数寄存器
reg [UART_DIVISOR_W-1:0]  tx_count_q;         // 发送分频计数器
reg [7:0]                 tx_shift_reg_q;    // 发送移位寄存器
reg                       txd_q;              // 发送数据寄存器

// RX寄存器定义
reg                       rxd_q;              // 同步后的接收数据寄存器
reg [7:0]                 rx_data_q;          // 接收数据寄存器
reg [3:0]                 rx_bits_q;          // 接收位计数寄存器
reg [UART_DIVISOR_W-1:0]  rx_count_q;         // 接收分频计数器
reg [7:0]                 rx_shift_reg_q;    // 接收移位寄存器
reg                       rx_ready_q;         // 接收数据准备好信号寄存器
reg                       rx_busy_q;          // 接收忙信号寄存器

// RX重新同步
reg rxd_ms_q; // 多级同步寄存器，用于防止亚稳态

// RXD重新同步逻辑，防止亚稳态
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        rxd_ms_q <= 1'b1; // 复位时设置为高电平（空闲状态）
        rxd_q    <= 1'b1; // 同步后的接收数据初始化为高电平
    end else begin
        rxd_ms_q <= rxd_i;  // 第一阶段同步
        rxd_q    <= rxd_ms_q; // 第二阶段同步
    end
end

// RX时钟分频逻辑
wire rx_sample_w = (rx_count_q == {(UART_DIVISOR_W){1'b0}}); // 分频计数器达到0时采样

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        rx_count_q <= {(UART_DIVISOR_W){1'b0}}; // 复位时清零分频计数器
    end else begin
        if (!rx_busy_q) begin
            // 初始化分频器，当RX空闲时，设置为分频器的一半，用于在中点采样
            rx_count_q <= UART_DIVISOR_V >> 1;
        end else if (rx_count_q != 0) begin
            // 递减分频计数器
            rx_count_q <= rx_count_q - 1;
        end else if (rx_sample_w) begin
            // 采样时钟达到
            if (rx_bits_q == STOP_BIT) begin
                // 到达停止位，复位分频计数器
                rx_count_q <= {(UART_DIVISOR_W){1'b0}};
            end else begin
                // 继续下一个比特的分频计数
                rx_count_q <= UART_DIVISOR_V;
            end
        end
    end
end

// RX移位寄存器逻辑
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        rx_shift_reg_q <= 8'h00; // 复位时清空移位寄存器
        rx_busy_q      <= 1'b0;  // 复位时RX不忙
    end else if (rx_busy_q && rx_sample_w) begin
        if (rx_bits_q == STOP_BIT) begin
            // 到达停止位，结束接收
            rx_busy_q <= 1'b0;
        end else if (rx_bits_q == START_BIT) begin
            // 检查开始位是否有效
            if (rxd_q) begin
                rx_busy_q <= 1'b0; // 错误的开始位，取消接收
            end
        end else begin
            // 读取数据位，右移并存入移位寄存器
            rx_shift_reg_q <= {rxd_q, rx_shift_reg_q[7:1]};
        end
    end else if (!rx_busy_q && !rxd_q) begin
        // 检测到开始位（rxd_q为低电平）
        rx_shift_reg_q <= 8'h00; // 清空移位寄存器
        rx_busy_q      <= 1'b1;  // 设置RX忙信号
    end
end

// RX比特计数逻辑
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        rx_bits_q <= START_BIT; // 复位时比特计数器初始化为起始位
    end else if (rx_ready_q) begin
        // 数据被读取后，复位比特计数
        rx_bits_q <= START_BIT;
    end else if (rx_sample_w && rx_busy_q) begin
        if (rx_bits_q == STOP_BIT) begin
            rx_bits_q <= START_BIT; // 到达停止位后复位比特计数
        end else begin
            rx_bits_q <= rx_bits_q + 1; // 增加比特计数
        end
    end else if (!rx_busy_q) begin
        rx_bits_q <= START_BIT; // 当不忙时，保持比特计数为起始位
    end
end

// RX数据处理逻辑
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        rx_ready_q  <= 1'b0;    // 复位时清除准备好信号
        rx_data_q   <= 8'h00;    // 复位时清空接收数据
    end else begin
        if (rd_i) begin
            // 读取数据后，清除准备信号
            rx_ready_q <= 1'b0;
        end

        if (rx_busy_q && rx_sample_w) begin
            if (rx_bits_q == STOP_BIT) begin
                if (rxd_q) begin
                    // 接收完成且停止位正确，设置接收数据和准备好信号
                    rx_data_q  <= rx_shift_reg_q;
                    rx_ready_q <= 1'b1;
                end else begin
                    // 错误的停止位，清除数据和准备信号
                    rx_ready_q <= 1'b0;
                    rx_data_q  <= 8'h00;
                end
            end
        end
    end
end

// TX时钟分频逻辑
wire tx_sample_w = (tx_count_q == {(UART_DIVISOR_W){1'b0}}); // 分频计数器达到0时采样

always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        tx_count_q <= {(UART_DIVISOR_W){1'b0}}; // 复位时清零分频计数器
    end else begin
        if (!tx_busy_q) begin
            // 空闲状态，加载分频值以准备发送
            tx_count_q <= UART_DIVISOR_V;
        end else if (tx_count_q != 0) begin
            // 递减分频计数器
            tx_count_q <= tx_count_q - 1;
        end else if (tx_sample_w) begin
            // 分频计数器归零后，重新加载分频值
            tx_count_q <= UART_DIVISOR_V;
        end
    end
end

// TX移位寄存器逻辑
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        tx_shift_reg_q <= 8'h00; // 复位时清空移位寄存器
        tx_busy_q      <= 1'b0;  // 复位时TX不忙
    end else if (tx_busy_q) begin
        if (tx_bits_q != START_BIT && tx_sample_w) begin
            // 发送数据位，右移移位寄存器
            tx_shift_reg_q <= {1'b0, tx_shift_reg_q[7:1]};
        end

        if (tx_bits_q == STOP_BIT && tx_sample_w) begin
            // 到达停止位，复位发送忙信号
            tx_busy_q <= 1'b0;
        end
    end else if (wr_i) begin
        // 写入数据并开始发送
        tx_shift_reg_q <= data_i; // 加载待发送数据到移位寄存器
        tx_busy_q      <= 1'b1;   // 设置发送忙信号
    end
end

// TX比特计数逻辑
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        tx_bits_q <= 4'd0; // 复位时比特计数器初始化为0
    end else if (tx_sample_w && tx_busy_q) begin
        if (tx_bits_q == STOP_BIT) begin
            tx_bits_q <= START_BIT; // 到达停止位后复位比特计数
        end else begin
            tx_bits_q <= tx_bits_q + 1; // 增加比特计数
        end
    end
end

// UART发送引脚逻辑
reg txd_r; // 临时寄存器，用于组合逻辑

always @(*) begin
    txd_r = 1'b1; // 默认为高电平（空闲状态）

    if (tx_busy_q) begin
        case (tx_bits_q)
            START_BIT: txd_r = 1'b0; // 起始位为低电平
            STOP_BIT:  txd_r = 1'b1; // 停止位为高电平
            default:   txd_r = tx_shift_reg_q[0]; // 数据位，取移位寄存器最低位
        endcase
    end
end

// TXD寄存器同步输出逻辑
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
        txd_q <= 1'b1; // 复位时设置为高电平（空闲状态）
    end else begin
        txd_q <= txd_r; // 更新发送数据输出
    end
end

// 输出端口连接
assign tx_busy_o  = tx_busy_q;    // 连接发送忙信号到输出端口
assign rx_ready_o = rx_ready_q;   // 连接接收准备好信号到输出端口
assign txd_o      = txd_q;        // 连接发送数据输出寄存器到TXD引脚
assign data_o     = rx_data_q;    // 连接接收数据寄存器到数据输出端口

endmodule
