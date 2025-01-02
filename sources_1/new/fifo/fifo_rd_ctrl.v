`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Description: 
//   FIFO 读控制器模块
//   生成 FIFO 读空标志 (fifo_empty) 和读数据计数器 (rd_data_count)，并控制 RAM 读使能信号 (ram_rd_en)。
//   管理读指针 (rd_ptr)，确保数据正确从 FIFO 中读取，并通过与写指针的比较判断 FIFO 是否为空。
//   
// Parameter Dependencies:
//   RAM_ADDR_WIDTH = ceil(log2(RAM_DEPTH))
//   RD_CNT_WIDTH   = RAM_ADDR_WIDTH + 1 - 2
//   RD_IND         = 每次读操作读指针自增的增量
//
// Example:
//   - RAM_ADDR_WIDTH = 5, RD_CNT_WIDTH = 4, RD_IND = 4
//     FIFO 深度 = 2^5 = 32
//     读数据计数器位宽 = 4
//     读指针每次自增 4
//
////////////////////////////////////////////////////////////////////////////////

module fifo_rd_ctrl
#(
    parameter RAM_ADDR_WIDTH = 'd5,                         // 存储器地址线位宽
    parameter RD_CNT_WIDTH   = RAM_ADDR_WIDTH + 'd1 - 'd2,  // 读端口计数器位宽
    parameter RD_IND         = 'd4                           // 每进行一次读操作，读指针需要自增的增量
)
(
        // 读端口接口
        input   wire                        rd_clk          , // 读时钟
        input   wire                        rd_rst_n        , // 读复位信号，低有效
        input   wire                        rd_en           , // 读 FIFO 使能信号，高有效
        input   wire [RAM_ADDR_WIDTH:0]     wr_ptr_sync     , // 从写时钟域同步过来的写指针，二进制无符号数表示

        // 读控制输出
        output  reg  [RAM_ADDR_WIDTH:0]     rd_ptr          , // 读指针
        output  reg                         fifo_empty      , // FIFO 读空标志
        output  wire [RD_CNT_WIDTH-1:0]     rd_data_count   , // 读端口数据数量计数器
        output  wire                        ram_rd_en         // 实际有效的 RAM 读使能信号，有效时读指针自增
    );
    
    // 内部信号定义
    reg [RAM_ADDR_WIDTH:0] rd_ram_cnt ; // 存储单元中存储有效数据的单元数，读写指针进行减法后的结果
    
    // 读空标志逻辑
    // 判断 FIFO 是否为空：当读写指针的高 RD_CNT_WIDTH 位相同时，认为 FIFO 为空
    always@(*) begin
        if(wr_ptr_sync[RAM_ADDR_WIDTH : RAM_ADDR_WIDTH - RD_CNT_WIDTH + 'd1] == 
           rd_ptr[RAM_ADDR_WIDTH : RAM_ADDR_WIDTH - RD_CNT_WIDTH + 'd1]) begin
            // 当读写指针高 RD_CNT_WIDTH 位相同时，FIFO 为空
            fifo_empty = 1'b1;
        end else begin
            // FIFO 不为空
            fifo_empty = 1'b0;
        end
    end

    // RAM 读使能信号逻辑
    // 当读使能信号 rd_en 有效且 FIFO 不为空时，生成 RAM 读使能信号 ram_rd_en 为高电平
    assign ram_rd_en = (rd_en && !fifo_empty) ? 1'b1 : 1'b0;
    
    // 读指针更新逻辑
    // 在读时钟上升沿，如果 RAM 读使能信号有效，则读指针自增
    always@(posedge rd_clk or negedge rd_rst_n) begin
        if(~rd_rst_n) begin
            // 复位时，读指针初始化为0
            rd_ptr <= 'd0;
        end else if(ram_rd_en) begin
            // 读使能有效时，读指针自增
            rd_ptr <= rd_ptr + RD_IND;
        end else begin
            // 其他情况下，保持读指针不变
            rd_ptr <= rd_ptr;
        end
    end

    // 读计数器逻辑
    // 计算 FIFO 中存储的有效数据单元数
    always@(*) begin
        if(rd_ptr[RAM_ADDR_WIDTH] == wr_ptr_sync[RAM_ADDR_WIDTH]) begin
            // 读写指针的最高位相同，说明在同一轮 RAM 地址空间中
            // 写指针减去读指针得到有效数据单元数
            rd_ram_cnt = wr_ptr_sync - rd_ptr;
        end else if(rd_ptr[RAM_ADDR_WIDTH] != wr_ptr_sync[RAM_ADDR_WIDTH]) begin
            // 读写指针不在同一轮 RAM 地址空间中
            // 写指针一定比读指针大，对最高位不同的情况，设置写指针最高位为1，读指针最高位为0
            rd_ram_cnt = {1'b1, wr_ptr_sync[RAM_ADDR_WIDTH-1:0]} - {1'b0, rd_ptr[RAM_ADDR_WIDTH-1:0]};
        end else begin
            // 其他情况，保持读计数器不变
            rd_ram_cnt = rd_ram_cnt;
        end    
    end

    // 读数据计数器逻辑
    // 计算可读取的数据数量，以 RD_CNT_WIDTH 位表示
    // 舍去低 WR_CNT_WIDTH 位的计数，以符合读数据位宽
    // 例如：如果 RD_CNT_WIDTH = 4，RAM_ADDR_WIDTH = 5，则 rd_ram_cnt[5 : 5 + 1 - 4] = rd_ram_cnt[5:2]
    assign rd_data_count = rd_ram_cnt[RAM_ADDR_WIDTH : RAM_ADDR_WIDTH + 'd1 - RD_CNT_WIDTH];
    
endmodule
