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

endclass