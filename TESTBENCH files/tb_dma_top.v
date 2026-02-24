`timescale 1ns/1ps

module tb_dma_top;
//GLOBAL SIGNALS
reg clk;
reg rst_n;

// APB Signals (TB drives these to configure DMA)
reg psel,penable,pwrite;
reg  [31:0] paddr;
reg  [31:0] pwdata;
wire [31:0] prdata;
wire pready, pslverr;

// AHB Signals (TB responds to these acting like Memory)
wire HREADY;
wire [31:0] HRDATA;
wire [31:0] HWDATA;
wire [2:0]  HSIZE;
wire [31:0] HADDR;
wire [1:0]  HTRANS;
wire [2:0]  HBURST;
wire        HWRITE;

    // Instantiate the Top Module (DUT)
    dma_top DUT (
        .clk(clk),
        .rst_n(rst_n),
        //APB signals
        .psel(psel),.penable(penable),.pwrite(pwrite),
        .paddr(paddr),
        .pwdata(pwdata),
        .prdata(prdata),
        .pready(pready),
        .pslverr(pslverr),
        //AHB SIGNALS
        .HREADY(HREADY),
        .HRDATA(HRDATA),
        .HWDATA(HWDATA),
        .HSIZE(HSIZE),
        .HADDR(HADDR),
        .HTRANS(HTRANS),
        .HBURST(HBURST),
        .HWRITE(HWRITE)
    );

    // Clock Generation
initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100 MHz Clock
end

    // Fake Memory Model (AHB Slave)
    // We create a tiny RAM of 1024 words
    reg [31:0] fake_ram [0:1023]; 
    
    // AHB is pipelined, so we need to remember the address from cycle 1
    // to use it for data in cycle 2.
    reg [31:0] ahb_addr_reg;
    reg        ahb_write_reg;
    reg        ahb_active_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ahb_active_reg <= 1'b0;
        end else begin
            // Cycle 1: Address Phase (Capture the request)
            if (HTRANS == 2'b10 && HREADY) begin // NONSEQ Transfer
                ahb_addr_reg   <= HADDR;
                ahb_write_reg  <= HWRITE;
                ahb_active_reg <= 1'b1;
            end else begin
                ahb_active_reg <= 1'b0;
            end

            // Cycle 2: Data Phase (Execute the request)
            if (ahb_active_reg && HREADY) begin
                if (ahb_write_reg) begin
                    // Write to RAM (Divide address by 4 for word index)
                    fake_ram[ahb_addr_reg[11:2]] <= HWDATA; 
                end
            end
        end
    end

    // Assign Output Read Data (If Active and Reading)
    assign HRDATA = (ahb_active_reg && !ahb_write_reg) ? fake_ram[ahb_addr_reg[11:2]] : 32'd0;
    
    // Always ready for this simple test
    assign HREADY = 1'b1; 

    // APB Tasks (Fake CPU)
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            paddr   <= addr;
            pwdata  <= data;
            pwrite  <= 1;
            psel    <= 1;
            penable <= 0;
            @(posedge clk);
            penable <= 1;
            @(posedge clk);
            psel    <= 0;
            penable <= 0;
            pwrite  <= 0;
        end
    endtask

    // MAIN TEST SCENARIO
    initial begin
        // A. Initialization
        rst_n   = 0;
        psel    = 0;
        penable = 0;
        pwrite  = 0;
        paddr   = 0;
        pwdata  = 0;
        
        // Initialize RAM with secret data at Source Address (0x100)
        // 0x100 / 4 = index 64
        fake_ram[64] = 32'hAABB_CCDD; 
        fake_ram[65] = 32'h1122_3344;
        fake_ram[66] = 32'h5566_7788;
        
        // Wait and release reset
        #20 rst_n = 1;
        $display("--- Reset Done. Memory Initialized. ---");

        // B. Configure DMA Channel 0 via APB
        // Write Source Address = 0x100 (Offset 0x00)
        apb_write(32'h00, 32'h0000_0100);
        
        // Write Dest Address = 0x200 (Offset 0x04)
        apb_write(32'h04, 32'h0000_0200);
        
        // Write Count = 3 words (Offset 0x08)
        apb_write(32'h08, 32'd3);
        
        $display("--- DMA Channel 0 Configured. Starting Transfer... ---");
        
        // Start Channel 0 (Offset 0x0C)
        apb_write(32'h0C, 32'h0000_0001);

        // C. Wait for DMA to do its job
        // It takes a few dozen clock cycles to read and write 3 words.
        #500; 

        // D. Self-Checking (Did it work?)
        $display("--- Checking Destination Memory... ---");
        
        // Dest Address 0x200 / 4 = index 128
        if (fake_ram[128] == 32'hAABB_CCDD && 
            fake_ram[129] == 32'h1122_3344 && 
            fake_ram[130] == 32'h5566_7788) begin
            $display("========================================");
            $display("   SUCCESS! DMA TRANSFER COMPLETE!      ");
            $display("========================================");
        end else begin
            $display("ERROR: Data mismatch! Transfer failed.");
            $display("RAM[128] = %h", fake_ram[128]);
        end

        #50;
        $finish;
    end

endmodule