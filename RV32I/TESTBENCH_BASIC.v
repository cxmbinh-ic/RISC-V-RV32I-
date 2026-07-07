`timescale 1ns/1ps

module rv32i_basic_tb;

    // 1. Khai báo các tín hiệu kết nối với CPU Top-Level
    reg clk;
    reg reset;

    // 2. Tạo thực thể (instantiate) con CPU master của bạn
    rv32i_top uut (
        .clk(clk),
        .reset(reset)
    );

    // 3. Bộ tạo xung Clock tuần hoàn (Chu kỳ 10ns -> Tần số 100MHz)
    always begin
        #5 clk = ~clk;
    end

    // 4. Kịch bản điều khiển Mô phỏng
    initial begin
        
        clk = 0;
        reset = 1; 

        // Giữ reset trong 2 chu kỳ clock (20ns) để toàn mạch ổn định
        #20; 
        reset = 0; // Tắt reset để CPU chính thức bắt đầu Fetch lệnh từ IMEM

        // Chạy mô phỏng trong 200ns (Đủ để chạy khoảng 20 lệnh pipeline)
        #200;

        // Kết thúc mô phỏng
        $display("Simulation finished. Open waveform to verify hazards!");
        $finish;
    end
    initial begin
        $dumpfile("rv32i_pipeline_waveform.vcd"); // Tên file sóng xuất ra
        $dumpvars(0, rv32i_basic_tb);             // Trích xuất tất cả các dây bên trong UUT
    end

endmodule