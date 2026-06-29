class cpu_env;
    //1. mailboxes
    mailbox #(cpu_transaction) gentodrive_mbx;
    mailbox #(cpu_transaction) montoscb_mbx;

    //2. component handles
    cpu_gen        gen;
    cpu_driver     drv;
    cpu_monitor    mon;
    cpu_scoreboard sco;

    //3. virtual interface
    virtual cpu_if vif;

    //4. constructor
    function new(virtual cpu_if vif);
        this.vif = vif;
    endfunction

    //5. build
    function void build();
        gentodrive_mbx = new();
        montoscb_mbx   = new();
        gen = new(gentodrive_mbx);
        drv = new(gentodrive_mbx, this.vif);
        mon = new(montoscb_mbx,   this.vif);
        sco = new(montoscb_mbx);
    endfunction

    //6. run
    task run();
        $display("[ENVIRONMENT] Launching all parallel components...");
        fork
            gen.run();
            drv.run();
            mon.run();
            sco.run();
        join_any
        $display("[ENVIRONMENT] Generator has finished its instruction stream.");
        repeat(50) @(posedge vif.clk);
        sco.report();
        $display("[ENVIRONMENT] Testbench finished.");
    endtask

endclass