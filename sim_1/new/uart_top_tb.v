`timescale 1ns / 1ps

module uart_top_tb;

    // 系统时钟和复位信号
    reg clk;
    reg rst_n;

    // UART引脚
    reg rxd;
    wire txd;

    // 参数定义
    parameter CLK_FREQ = 50000000;      // 50 MHz
    parameter BAUD_RATE = 115200;       // 115200 波特率
    parameter BIT_PERIOD = CLK_FREQ / BAUD_RATE; // 每位的时钟周期数

    // 初始化信号
    initial begin
        clk = 0;
        rst_n = 0;
        rxd = 1; // 空闲状态为高电平
        #100; // 等待100ns
        rst_n = 1; // 释放复位
    end

    // 时钟生成
    always #10 clk = ~clk; // 50MHz 时钟周期为20ns

    // 实例化被测模块
    uart_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .rxd(rxd),
        .txd(txd)
    );

    // 定义要发送的5个数据字节
    reg [7:0] data_array [0:4];
    integer i;

    initial begin
        // 初始化数据
        data_array[0] = 8'hA5;
        data_array[1] = 8'h3C;
        data_array[2] = 8'h7F;
        data_array[3] = 8'h00;
        data_array[4] = 8'hFF;

        // 等待复位完成
        @(posedge rst_n);
        #100;

        // 发送5个数据字节
        for (i = 0; i < 5; i = i + 1) begin
            send_byte(data_array[i]);
            #100000; // 等待足够时间间隔
        end

        // 结束仿真
        #100000;
        $finish;
    end

    // 发送一个字节的任务
    task send_byte;
        input [7:0] byte;
        integer j;
        begin
            // 发送起始位（低电平）
            send_bit(0);
            // 发送数据位（低位优先）
            for (j = 0; j < 8; j = j + 1) begin
                send_bit(byte[j]);
            end
            // 发送停止位（高电平）
            send_bit(1);
        end
    endtask

    // 发送单个位的任务
    task send_bit;
        input bit_val;
        integer k;
        begin
            // 设置rxd线的值
            rxd = bit_val;
            // 等待一个比特周期
            for (k = 0; k < BIT_PERIOD; k = k + 1) begin
                @(posedge clk);
            end
        end
    endtask

endmodule
