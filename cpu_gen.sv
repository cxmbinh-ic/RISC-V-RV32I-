class cpu_gen;
    //1. transaction handle
    cpu_transaction tr;

    //2. mailboxes — one to driver, one to scoreboard
    mailbox #(cpu_transaction) gentodrive_mbx;


    //3. constructor
    function new(mailbox #(cpu_transaction) drv_mbx);
        this.gentodrive_mbx = drv_mbx;
    endfunction

    //4. task run
    int num_instr = 10;
    task run();
        $display("STARTING GENERATING CPU INSTR");
        repeat(num_instr) begin
            tr = new();
            assert(tr.randomize()) else
                $fatal(0, "Randomization failed!");
            tr.build_instruction();
            gentodrive_mbx.put(tr);  // send to driver
            tr.display("GENERATE OUT");
        end
    endtask

    //5. run directed tests for SVA
    task run_direct();
        $display("START DIRECTED TESTS");
        // --- T1: LW x1,0(x0) -> ADD x2,x1,x1   (F5, F9, F10) ---
        tr = new();
        tr.opcode = 7'b0000011; tr.rd = 5'd1; tr.rs1 = 5'd0; tr.rs2 = 5'd0;
        tr.funct3 = 3'b010; tr.imm = 12'd0; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T1a-LW");
    
        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd2; tr.rs1 = 5'd1; tr.rs2 = 5'd1;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T1b-ADD");

        //-----T2: LW x1,0(x0) -> SW x1, 0(x2) (F6)
        tr = new();
        tr.opcode = 7'b0000011; tr.rd = 5'd1; tr.rs1 = 5'd0; tr.rs2 = 5'd0;
        tr.funct3 = 3'b010; tr.imm = 12'd0; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T2a-LW");

        tr = new();
        tr.opcode = 7'b0100011; tr.rs1 = 5'd2; tr.rs2 = 5'd1;
        tr.funct3 = 3'b010; tr.imm = 12'd0; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T2b-ADD");

        // --- T3: LW x1,0(x0) -> ADDI x2,x3,4   (F8, no dependency) ---
        tr = new();
        tr.opcode = 7'b0000011; tr.rd = 5'd1; tr.rs1 = 5'd0; tr.rs2 = 5'd0;
        tr.funct3 = 3'b010; tr.imm = 12'd0;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T3a-LW");

        tr = new();
        tr.opcode = 7'b0010011; tr.rd = 5'd2; tr.rs1 = 5'd3; tr.rs2 = 5'd0;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000; tr.imm = 12'd4;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T3b-ADDI");

        //---- T4: LW x1,0(x0) -> LW x2, 0(x1) (F24)
        tr = new();
        tr.opcode = 7'b0000011; tr.rd = 5'd1; tr.rs1 = 5'd0; tr.rs2 = 5'd0;
        tr.funct3 = 3'b010; tr.imm = 12'd0;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T4a-LW");

        tr = new();
        tr.opcode = 7'b0000011; tr.rd = 5'd2; tr.rs1 = 5'd1; tr.rs2 = 5'd0;
        tr.funct3 = 3'b010; tr.imm = 12'd0;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T4b-LW");

        //----- T5: ADD x1, x2, x3 -> SUB x4, x1, x5 (F11,F17)
        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd1; tr.rs1 = 5'd2; tr.rs2 = 5'd3;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T5a-ADD");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd4; tr.rs1 = 5'd1; tr.rs2 = 5'd5;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0100000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T5b-SUB");

        //----- T6: ADD x1, x2, x3 ->  ADD -> x30, x29, x28 (bubble)-> SUB x4, x1, x5 (F13,F17)
        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd1; tr.rs1 = 5'd2; tr.rs2 = 5'd3;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T6a-ADD");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd30; tr.rs1 = 5'd29; tr.rs2 = 5'd28;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T6b-ADD");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd4; tr.rs1 = 5'd1; tr.rs2 = 5'd5;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0100000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T6c-SUB");

        //----- T7: ADD x1, x2, x3 ->  ADD -> x1, x30, x28 -> ADD x2, x1, x3 (F14)
        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd1; tr.rs1 = 5'd2; tr.rs2 = 5'd3;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T7a-ADD");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd1; tr.rs1 = 5'd30; tr.rs2 = 5'd28;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T7b-ADD");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd2; tr.rs1 = 5'd1; tr.rs2 = 5'd3;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T7c-ADD");

        //---- T8: ADD x0, x2,x3 -> ADD x1,x0,x3 (F15)
        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd0; tr.rs1 = 5'd2; tr.rs2 = 5'd3;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T8a-ADD");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd1; tr.rs1 = 5'd0; tr.rs2 = 5'd3;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T8b-ADD");

        //------ T9: BEQ x1 , 16(x2) -> ADD x1,x2,x3 -> ADD x4,x5,x6 -> ADD x7,x8,x9 -> ADD x10,x11,x12 (F18,F19,F20)
        
        tr = new();
        tr.opcode = 7'b1100011 ; tr.rs1 = 5'd1; tr.rs2 = 5'd2;
        tr.funct3 = 3'b000; tr.imm = 12'd16;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T9a-BEQ");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd1; tr.rs1 = 5'd2; tr.rs2 = 5'd3;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T9b-ADD");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd4; tr.rs1 = 5'd5; tr.rs2 = 5'd6;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T9c-ADD");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd7; tr.rs1 = 5'd8; tr.rs2 = 5'd9;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T9d-ADD");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd10; tr.rs1 = 5'd11; tr.rs2 = 5'd12;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T9e-ADD");


        //----------------T10 : ADDI x1,0(x0) -> ADDI x2, 1(x0) -> BEQ x1, 16(x2) -> ADD x1,x2,x3
        tr = new();
        tr.opcode = 7'b0010011 ; tr.rd = 5'd1; tr.rs1 = 5'd0; tr.rs2 = 5'd0;
        tr.funct3 = 3'b000; tr.imm = 12'd0;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T10a-ADDI");

        tr = new();
        tr.opcode = 7'b0010011 ; tr.rd = 5'd2; tr.rs1 = 5'd0; tr.rs2 = 5'd0;
        tr.funct3 = 3'b000; tr.imm = 12'd1;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T10b-ADDI");

        tr = new();
        tr.opcode = 7'b1100011 ; tr.rs1 = 5'd1; tr.rs2 = 5'd2;
        tr.funct3 = 3'b000; tr.imm = 12'd16;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T10c-BEQ");

        tr = new();
        tr.opcode = 7'b0110011; tr.rd = 5'd1; tr.rs1 = 5'd2; tr.rs2 = 5'd3;
        tr.funct3 = 3'b000; tr.funct7 = 7'b0000000;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T10d-ADD");

        //----------T11: LW x1,0(x0) -> BEQ x1,x4,+16 (F23)
        tr = new();
        tr.opcode = 7'b0000011; tr.rd = 5'd1; tr.rs1 = 5'd0; tr.rs2 = 5'd0;
        tr.funct3 = 3'b010; tr.imm = 13'd0;
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T11a-LW");

        tr = new();
        tr.opcode = 7'b1100011; tr.rs1 = 5'd1; tr.rs2 = 5'd4;
        tr.funct3 = 3'b000;
        tr.imm = 13'b0;
        tr.imm[10:1] = 10'd8;   // +16 byte forward offset (4 instructions)
        tr.build_instruction();
        gentodrive_mbx.put(tr);
        tr.display("T11b-BEQ");
        //--------- T12: 

    endtask
endclass
