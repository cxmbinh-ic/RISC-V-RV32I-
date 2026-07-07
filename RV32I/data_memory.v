module data_memory (
    input  wire        clk,
    input  wire        MemWrite,    // Controlled by the Control Unit (High for SW)
    input  wire        MemRead,     // Controlled by the Control Unit (High for LW)
    input  wire [31:0] Address,     // Calculated Address output from the ALU
    input  wire [31:0] WriteData,   // Data from rs2_data to write into RAM
    output wire [31:0] ReadData     // Data read from RAM sent back to rd
);

    // RAM array: 64 slots of 32-bit words (256 bytes total for simulation)
    reg [31:0] ram [0:63];
    wire [5:0] word_addr = Address[7:2];

    // Synchronous Write: Write data into RAM on the clock edge if MemWrite is enabled
    always @(posedge clk) begin
        if (MemWrite) begin
            ram[word_addr] <= WriteData;
        end
    end

    // Asynchronous Read: Output data instantly if MemRead is high
    assign ReadData = (MemRead) ? ram[word_addr] : 32'b0;

endmodule