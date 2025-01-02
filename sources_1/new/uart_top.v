//////////////////////////////////////////////////////////////////////////////////
// Description:
//   UART顶层模块
//   集成UART发送与接收功能，通过异步FIFO缓冲接收数据并控制数据的发送。
//   模块包括系统时钟与复位、UART接口以及异步FIFO用于数据缓冲。
//   
// Parameter Dependencies:
//   UART_DIVISOR_V   = 根据系统时钟和所需波特率配置分频值（例如50MHz时钟，115200波特率）
//   RAM_DEPTH        = 异步FIFO内部RAM的深度
//   RAM_ADDR_WIDTH   = 异步FIFO内部RAM的地址宽度，决定RAM深度为2^RAM_ADDR_WIDTH
//   WR_WIDTH         = 异步FIFO写端口的数据宽度
//   RD_WIDTH         = 异步FIFO读端口的数据宽度
//   WR_CNT_WIDTH     = 异步FIFO写端口计数器的位宽
//   RD_CNT_WIDTH     = 异步FIFO读端口计数器的位宽
//   RAM_RD2WR        = 异步FIFO读数据位宽与写数据位宽的比率
//
// Example:
//   - UART_DIVISOR_V = 433，适用于50MHz系统时钟和115200波特率
//   - RAM_DEPTH = 2048，则 RAM_ADDR_WIDTH = 11
//   - FIFO 写端口数据宽度 = 8 位，FIFO 读端口数据宽度 = 8 位
//   - WR_CNT_WIDTH = 12，FIFO 最多可存储 2048 个 8 位数据，需要 12 位计数器来表示
//
//////////////////////////////////////////////////////////////////////////////////

module uart_top (
    // 系统时钟和复位
    input         clk,      // 系统时钟
    input         rst_n,    // 低有效复位信号

    // UART引脚 
    input         rxd,      // UART接收数据输入
    output        txd       // UART发送数据输出
);

    // 内部复位信号，高有效
    wire rst;
    assign rst = ~rst_n;

    // UART发送信号
    reg          uart_wr;        // UART写使能信号
    reg  [7:0]   uart_data_in;   // UART待发送数据
    wire         uart_busy;      // UART发送忙信号

    // UART接收信号
    wire [7:0]   uart_data_out;  // UART接收的数据
    wire         uart_rx_ready;  // UART接收数据准备好信号
    wire         uart_rd_i; // UART读使能信号

    // 异步FIFO信号
    wire         fifo_full;          // FIFO满信号
    wire         fifo_empty;         // FIFO空信号
    wire [7:0]   fifo_rd_data;       // FIFO读取的数据
    wire [7:0]   fifo_wr_data;       // FIFO写入的数据
    wire         fifo_wr_en;         // FIFO写使能
    wire         fifo_rd_en;         // FIFO读使能

    wire [11:0]   wr_data_count;       // FIFO读取的数据
    wire [11:0]   rd_data_count;       // FIFO写入的数据

    assign fifo_wr_en = uart_rx_ready && !fifo_full;
    assign uart_rd_i = !fifo_full;
    assign fifo_wr_data = uart_data_out;
    assign fifo_rd_en = uart_wr && !rst;

    // 实例化UART模块
    uart #(
        .UART_DIVISOR_V(433) // 根据系统时钟和所需波特率配置（例如50MHz时钟，115200波特率）
    ) uart_inst (
        .clk_i(clk),
        .rst_i(rst),
        // 发送接口
        .wr_i(uart_wr),
        .data_i(uart_data_in),
        .tx_busy_o(uart_busy),
        .txd_o(txd),
        // 接收接口
        .rd_i(uart_rd_i), // 不需要外部读取信号，因为我们直接使用接收数据
        .data_o(uart_data_out),
        .rx_ready_o(uart_rx_ready),
        // UART引脚
        .rxd_i(rxd)
    );

    // 实例化异步FIFO模块
    async_fifo #(
        .RAM_DEPTH       (2048),      // 内部RAM存储器深度
        .RAM_ADDR_WIDTH  (11),        // 内部RAM读写地址宽度
        .WR_WIDTH        (8),         // 写数据位宽
        .RD_WIDTH        (8),         // 读数据位宽
        .WR_IND          (1),         // 单次写操作访问的ram_mem单元个数
        .RD_IND          (1),         // 单次读操作访问的ram_mem单元个数
        .RAM_WIDTH       (8),         // RAM基本存储单元位宽
        .WR_L2           (0),         // log2(WR_IND)
        .RD_L2           (0),         // log2(RD_IND)
        .WR_CNT_WIDTH    (12),        // FIFO写端口计数器的位宽 (11 + 1 - 0)
        .RD_CNT_WIDTH    (12),        // FIFO读端口计数器的位宽 (11 + 1 - 0)
        .RAM_RD2WR       (1)          // 读数据位宽和写数据位宽的比
    ) fifo_inst (
        // 写相关
        .wr_clk(clk),                      // 写时钟
        .wr_rst_n(rst_n),                   // 写复位，低有效
        .wr_en(fifo_wr_en), // 写使能，连接到UART接收准备好且FIFO未满
        .wr_data(uart_data_out),           // 写入数据，连接到UART接收的数据
        .fifo_full(fifo_full),             // FIFO满信号
        .wr_data_count(wr_data_count),

        // 读相关
        .rd_clk(clk),                      // 读时钟
        .rd_rst_n(rst_n),                   // 读复位，低有效
        .rd_en(fifo_rd_en),                // 读使能
        .rd_data(fifo_rd_data),            // 读取数据
        .fifo_empty(fifo_empty),            // FIFO空信号
        .rd_data_count(rd_data_count)
    );

    // FIFO读取使能信号和UART发送逻辑
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            uart_wr <= 1'b0;           // 复位时关闭UART写使能
            uart_data_in <= 8'd0;      // 复位时清零发送数据
        end else begin
            if (!fifo_empty && !uart_busy) begin
                uart_wr <= 1'b1;                // 触发UART写使能
                uart_data_in <= fifo_rd_data;   // 将FIFO读取的数据送入UART发送数据
            end else begin
                uart_wr <= 1'b0; // 保持写使能为低
            end
        end
    end

endmodule
