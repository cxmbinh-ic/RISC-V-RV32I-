module pipe_if_id (
    input  wire        clk,
    input  wire        reset,
    input  wire        en,          // Controlled by Hazard Detection Unit (0 = freeze/stall)
    input  wire        flush,       // Controlled by Control Hazard Logic (1 = flush to NOP)
    input  wire [31:0] if_pc,
    input  wire [31:0] if_instr,
    output reg  [31:0] id_pc,
    output reg  [31:0] id_instr
);

    always @(posedge clk) begin
        if (reset || flush) begin
            id_pc    <= 32'b0;
            id_instr <= 32'h00000013; // RISC-V NOP instruction (addi x0, x0, 0)
        end else if (en) begin
            id_pc    <= if_pc;
            id_instr <= if_instr;
        end
    end

endmodule