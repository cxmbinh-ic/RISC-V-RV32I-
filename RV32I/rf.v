module rf(
    input clk, reset,
    input [4:0]  rs1_addr, rs2_addr, rd_addr,
    input [31:0] rd_data,
    input        reg_write,
    output reg [31:0] rs1_data, rs2_data
);
reg [31:0] reg_file [0:31];
integer i;
always @(posedge clk or posedge reset) begin
    if (reset)
        for (i = 0; i < 32; i = i + 1) reg_file[i] <= 32'b0;
    else if (reg_write && rd_addr != 5'b0)
        reg_file[rd_addr] <= rd_data;
end
always @(*) begin
    if(rs1_addr == rd_addr && reg_write && rd_addr != 5'b0)
        rs1_data = rd_data;
    else
        rs1_data = reg_file[rs1_addr];
    if(rs2_addr == rd_addr && reg_write && rd_addr != 5'b0)
        rs2_data = rd_data;
    else
        rs2_data = reg_file[rs2_addr];
end
endmodule