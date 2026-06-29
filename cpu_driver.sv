
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

endclass