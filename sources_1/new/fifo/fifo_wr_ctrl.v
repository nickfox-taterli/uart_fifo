`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Description: 
//   FIFO 写控制器模块
//   生成 FIFO 写满标志 (fifo_full) 和写数据计数器 (wr_data_count)，并控制 RAM 写使能信号 (ram_wr_en)。
//   管理写指针 (wr_ptr)，确保数据正确写入 FIFO，并通过与读指针的比较判断 FIFO 是否已满。
//   
// Parameter Dependencies:
//   RAM_ADDR_WIDTH = ceil(log2(RAM_DEPTH))
//   WR_CNT_WIDTH   = RAM_ADDR_WIDTH + 1
//   WR_IND         = 每次写操作写指针自增的增量
//
// Example:
//   - RAM_ADDR_WIDTH = 5, WR_CNT_WIDTH = 6, WR_IND = 1
//     FIFO 深度 = 2^5 = 32
//     写数据计数器位宽 = 6
//     写指针每次自增 1
//
////////////////////////////////////////////////////////////////////////////////

module fifo_wr_ctrl
#(
    parameter RAM_ADDR_WIDTH = 'd5, // 存储器地址线位宽
    parameter WR_CNT_WIDTH   = RAM_ADDR_WIDTH+'d1, // 写端口计数器位宽
    parameter WR_IND         = 'd1  // 每进行一次写操作，写指针需要自增的增量
)
(
        // 写端口接口
        input   wire                        wr_clk          , // 写时钟
        input   wire                        wr_rst_n        , // 写复位信号，低有效
        input   wire                        wr_en           , // 写使能信号
        input   wire [RAM_ADDR_WIDTH:0]     rd_ptr_sync     , // 从读时钟域同步过来的读指针，二进制
        
        // 写控制输出
        output  reg  [RAM_ADDR_WIDTH:0]     wr_ptr          , // 写指针，相比 RAM 访存地址扩展一位
        output  reg                         fifo_full       , // FIFO 写满标志
        output  wire [WR_CNT_WIDTH-1:0]     wr_data_count   , // 写端口数据数量计数器 
        output  wire                        ram_wr_en         // RAM 写使能信号，非满且 wr_en 输入有效时有效
    );
    
    // 内部信号定义
    reg [RAM_ADDR_WIDTH:0] wr_ram_cnt ;  // 存储单元中存储有效数据的单元数，读写指针进行减法后的结果
    
    // 写满标志逻辑
    // 判断 FIFO 是否已满：当写指针的低位与读指针相同，但写指针的最高位与读指针不同
    always@(*) begin
        if((wr_ptr[RAM_ADDR_WIDTH-1:0] == rd_ptr_sync[RAM_ADDR_WIDTH-1:0]) && 
           (wr_ptr[RAM_ADDR_WIDTH] != rd_ptr_sync[RAM_ADDR_WIDTH])) begin
            // 读写指针最高位不同，低位全部相同，FIFO 满
            fifo_full = 1'b1;
        end else begin
            // FIFO 未满
            fifo_full = 1'b0;
        end
    end
    
    // RAM 写使能信号逻辑
    // 当写使能且 FIFO 未满时，允许写入 RAM
    assign ram_wr_en = (wr_en && !fifo_full) ? 1'b1 : 1'b0;
    
    // 写指针更新逻辑
    // 在写时钟上升沿，如果 RAM 写使能有效，则写指针自增
    always@(posedge wr_clk or negedge wr_rst_n) begin
        if(~wr_rst_n) begin
            // 复位时，写指针初始化为0
            wr_ptr <= 'd0;
        end else if(ram_wr_en) begin
            // 写使能有效时，写指针自增
            wr_ptr <= wr_ptr + WR_IND;
        end else begin
            // 其他情况下，保持写指针不变
            wr_ptr <= wr_ptr;
        end
    end

    // 写计数器逻辑
    // 计算 FIFO 中存储的有效数据单元数
    always@(*) begin
        if(rd_ptr_sync[RAM_ADDR_WIDTH] == wr_ptr[RAM_ADDR_WIDTH]) begin
            // 读写指针的最高位相同，说明在同一轮 RAM 地址空间中
            // 写指针减去读指针得到有效数据单元数
            wr_ram_cnt = wr_ptr - rd_ptr_sync;
        end else if(rd_ptr_sync[RAM_ADDR_WIDTH] != wr_ptr[RAM_ADDR_WIDTH]) begin
            // 读写指针不在同一轮 RAM 地址空间中
            // 写指针的最高位为1，读指针的最高位为0
            wr_ram_cnt = {1'b1, wr_ptr[RAM_ADDR_WIDTH-1:0]} - {1'b0, rd_ptr_sync[RAM_ADDR_WIDTH-1:0]};
        end else begin
            // 其他情况，保持写计数器不变
            wr_ram_cnt = wr_ram_cnt;
        end
    end

    // 写数据计数器逻辑
    // 计算写入的数据数量，以 WR_CNT_WIDTH 位表示
    // 舍去低 WR_L2 位的计数，以符合写数据位宽
    // 例如：如果 WR_CNT_WIDTH = 6，RAM_ADDR_WIDTH = 5，则 wr_ram_cnt[5 : 0 - 1] = wr_ram_cnt[5:1]
    assign wr_data_count = wr_ram_cnt[RAM_ADDR_WIDTH: RAM_ADDR_WIDTH + 'd1 - WR_CNT_WIDTH];
    
endmodule
