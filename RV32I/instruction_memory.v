module IMEM(
    input [31:0] address,
    output reg [31:0] instruction
);
reg [31:0] memory [0:1023];
always @(*) begin
    instruction = memory[address[11:2]];
end
initial begin
    $readmemh("program.hex", memory);
end
endmodule