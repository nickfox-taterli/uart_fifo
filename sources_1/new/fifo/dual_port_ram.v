`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Description: 
//   双端口RAM模块 (Dual Port RAM)
//   实现一个可配置参数的双端口RAM，支持独立的读写时钟和使能信号。
//   通过参数配置读写数据位宽及读取的RAM单元数量，以满足不同的存储需求。
//   
// Parameter Dependencies:
//   - RAM_DEPTH      = 存储器深度
//   - RAM_ADDR_WIDTH = 读写地址宽度，需与 RAM_DEPTH 匹配
//   - RAM_DATA_WIDTH = RAM存储器的数据位宽
//   - RAM_RD_WIDTH   = RAM读取数据位宽
//   - RAM_RD2WR      = 读数据位宽和RAM位宽的比，即一次读取的RAM单元数量
//                       RAM_RD2WR = RAM_RD_WIDTH / RAM_DATA_WIDTH
//                       当读位宽小于等于写位宽时，值为1
//
// Example:
//   - RAM_DEPTH = 32
//   - RAM_ADDR_WIDTH = 5
//   - RAM_DATA_WIDTH = 8
//   - RAM_RD_WIDTH = 16
//   - RAM_RD2WR = 2
//   
// Functional Overview:
//   - **写端口（Write Port）**：在写时钟上升沿，当写端口使能和写使能信号有效时，将写数据写入指定地址。
//   - **读端口（Read Port）**：在读时钟上升沿，当读端口使能信号有效时，从指定地址读取 RAM_RD2WR 个 RAM 单元的数据，并将其组合输出。
//   - **数据组合**：读取的数据按低位数据来自高地址的顺序组合到读数据输出端口。
////////////////////////////////////////////////////////////////////////////////

module dual_port_ram
#(
    parameter RAM_DEPTH       = 'd32     , // RAM 深度
    parameter RAM_ADDR_WIDTH  = 'd5      , // 读写地址宽度，需与 RAM_DEPTH 匹配
    parameter RAM_DATA_WIDTH  = 'd8      , // RAM 数据位宽
    parameter RAM_RD_WIDTH    = 'd8      , // RAM 读取数据位宽
    parameter RAM_RD2WR       = 'd1        // 读数据位宽和 RAM 位宽的比，即一次读取的 RAM 单元数量
                                            // RAM_RD2WR = RAM_RD_WIDTH / RAM_DATA_WIDTH
                                            // 当读位宽小于等于写位宽时，值为1
)
(
    // 写端口接口
    input   wire                        wr_clk      , // 写时钟
    input   wire                        wr_port_ena , // 写端口使能，高有效
    input   wire                        wr_en       , // 写数据使能，高有效
    input   wire [RAM_ADDR_WIDTH-1:0]   wr_addr     , // 写地址
    input   wire [RAM_DATA_WIDTH-1:0]   wr_data     , // 写数据
    
    // 读端口接口
    input   wire                        rd_clk      , // 读时钟
    input   wire                        rd_port_ena , // 读端口使能，高有效
    input   wire [RAM_ADDR_WIDTH-1:0]   rd_addr     , // 读地址
    output  reg  [RAM_RD_WIDTH-1:0]     rd_data         // 读数据
);
    
    // 存储空间定义
    // 使用块RAM实现，提高存储效率和速度
    (* ram_style = "block" *) reg [RAM_DATA_WIDTH-1:0] ram_mem [RAM_DEPTH-1:0];
    
    // 写端口逻辑
    // 在写时钟上升沿，当写端口使能和写使能信号有效时，将写数据写入指定地址
    always @(posedge wr_clk) begin
        if (wr_port_ena && wr_en) begin
            ram_mem[wr_addr] <= wr_data;
        end else begin  
            ram_mem[wr_addr] <= ram_mem[wr_addr]; // 保持不变
        end
    end

    // 读端口逻辑
    // 在读时钟上升沿，当读端口使能信号有效时，从指定地址读取 RAM_RD2WR 个 RAM 单元的数据
    // 并将其组合输出到 rd_data，低位数据来自高地址
    genvar i;
    generate
        for (i = 0; i < RAM_RD2WR; i = i + 1) begin: rd_data_out
            always @(posedge rd_clk) begin
                if (rd_port_ena) begin
                    // 读取数据，并按低位数据来自高地址的顺序组合
                    rd_data[RAM_RD_WIDTH-1 - i*RAM_DATA_WIDTH : RAM_RD_WIDTH - (i+1)*RAM_DATA_WIDTH] 
                        <= ram_mem[rd_addr + i]; 
                end else begin
                    // 保持 rd_data 不变
                    rd_data[RAM_RD_WIDTH-1 - i*RAM_DATA_WIDTH : RAM_RD_WIDTH - (i+1)*RAM_DATA_WIDTH] 
                        <= rd_data[RAM_RD_WIDTH-1 - i*RAM_DATA_WIDTH : RAM_RD_WIDTH - (i+1)*RAM_DATA_WIDTH];
                end
            end        
        end
    endgenerate

endmodule
