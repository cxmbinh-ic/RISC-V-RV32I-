
class cpu_driver;
    //1.trans
    cpu_transaction tr;
    //2.mailbox
    mailbox #(cpu_transaction) driver_mbx;
    //3.interface
    virtual cpu_if vif;
    //4. contructor
    function new(mailbox #(cpu_transaction) mbx, virtual cpu_if vif);
        this.driver_mbx = mbx;
        this.vif = vif;
    endfunction
    //5. task run  
    task run();
    int idx;
    $display("STARTING DRIVING CPU");
    //reset = 1
    $display("RESETTING CPU");
    vif.cb_driver.reset <= 1;
    idx = 0;
    //hold 2 clock cycle for reset
    repeat(2) @(vif.cb_driver);
    while(driver_mbx.num()>0) begin
        driver_mbx.get(tr);       
        @(vif.cb_driver);
        vif.cb_driver.drv_instr_addr <= idx[9:0];
        vif.cb_driver.drv_instr <= tr.instr;
        idx++;
    end
    
    //reset = 0
    $display("RELEASING RESET");
    vif.cb_driver.reset <= 0;
    //drive cpu
    endtask
    //------- T12: reset in the midle of stall
    task run_T12();
    $display("STARTING DRIVING CPU T12");
    vif.cb_driver.reset <= 1;
    // get T1a LW
    driver_mbx.get(tr);       
    @(vif.cb_driver);
    vif.cb_driver.drv_instr_addr <= 10'd0;
    vif.cb_driver.drv_instr <= tr.instr;
    // get T1b ADD
    driver_mbx.get(tr);       
    @(vif.cb_driver);
    vif.cb_driver.drv_instr_addr <= 10'd1;
    vif.cb_driver.drv_instr <= tr.instr;
     
    vif.cb_driver.reset <= 0;

    // Waiting for stall and reset in the midle
    @(posedge vif.clk iff(vif.Control_Mux_SVA == 1'b1));
    $display("reset mid stall at time=%0t", $time);
    vif.cb_driver.reset <= 1;
    @(vif.cb_driver);
    vif.cb_driver.reset <= 0;
    endtask

endclass
