`timescale 1ns/1ps

module tb_ahb;

reg clk, rstn;
reg [3:0] grant;
reg [127:0] src_addr_flat, dest_addr_flat, count_flat;

// fifo side
reg fifo_full, fifo_empty;
reg [31:0] fifo_rdata;
wire fifo_w_en, fifo_r_en;
wire [31:0] fifo_wdata;

// ahb bus
reg HREADY;
reg [31:0] HRDATA;
wire [31:0] HWDATA, HADDR;
wire [2:0] HSIZE, HBURST;
wire [1:0] HTRANS;
wire HWRITE;

wire [3:0] transfer_done;

dma_ahb_mas DUT(
	.clk(clk), .rstn(rstn),
	.grant(grant),
	.src_addr_flat(src_addr_flat),
	.dest_addr_flat(dest_addr_flat),
	.count_flat(count_flat),
	.transfer_done(transfer_done),
	.fifo_full(fifo_full), .fifo_empty(fifo_empty),
	.fifo_rdata(fifo_rdata),
	.fifo_w_en(fifo_w_en), .fifo_r_en(fifo_r_en),
	.fifo_wdata(fifo_wdata),
	.HREADY(HREADY), .HRDATA(HRDATA),
	.HWDATA(HWDATA), .HSIZE(HSIZE),
	.HADDR(HADDR), .HTRANS(HTRANS),
	.HBURST(HBURST), .HWRITE(HWRITE)
);

initial clk=0;
always #5 clk=~clk;

// just a helper so i dont repeat @posedge everywhere
task tick;
	input integer n;
	integer k;
	begin
		for(k=0; k<n; k=k+1) @(posedge clk);
		#1;
	end
endtask

initial begin

	// init everything
	rstn=0; grant=0;
	src_addr_flat=0; dest_addr_flat=0; count_flat=0;
	fifo_full=0; fifo_empty=0;
	fifo_rdata=32'hCAFE0001;
	HREADY=1; HRDATA=32'hCAFE0001;

	tick(4);
	rstn=1;
	tick(1);

	// ------ TC1: check reset ------
	$display("TC1: Reset");
	$display("  HTRANS=%b HWRITE=%b HADDR=%h (expect 00, 0, 00000000)", HTRANS, HWRITE, HADDR);
	$display("  fifo_w_en=%b fifo_r_en=%b transfer_done=%b", fifo_w_en, fifo_r_en, transfer_done);

	// ------ TC2: no grant, should stay idle ------
	$display("\nTC2: No grant - stays idle");
	tick(3);
	$display("  HTRANS=%b (expect 00)", HTRANS);
	$display("  transfer_done=%b (expect 0000)", transfer_done);

	// ------ TC3: grant ch0, check read address phase ------
	// state flow: IDLE(latch) -> READ_ADDR -> visible next cycle
	$display("\nTC3: Grant CH0 - read addr phase");
	src_addr_flat[31:0]  = 32'hAAAA0000;
	dest_addr_flat[31:0] = 32'hBBBB0000;
	count_flat[31:0]     = 32'd1;
	grant = 4'b0001;
	tick(1); // idle latches config, moves to READ_ADDR
	grant = 0;
	tick(1); // READ_ADDR runs
	$display("  HADDR=%h  (expect AAAA0000)", HADDR);
	$display("  HWRITE=%b (expect 0 - its a read)", HWRITE);
	$display("  HTRANS=%b (expect 10 - nonseq)", HTRANS);
	$display("  HSIZE=%b  (expect 010 - 32bit)", HSIZE);
	$display("  HBURST=%b (expect 000 - single)", HBURST);

	// ------ TC4: read data phase then write addr phase ------
	$display("\nTC4: Read data + write addr");
	tick(1); // READ_DATA
	$display("  fifo_w_en=%b  (expect 1 - pushing hrdata into fifo)", fifo_w_en);
	$display("  fifo_wdata=%h (expect CAFE0001 - same as HRDATA)", fifo_wdata);
	tick(1); // WRITE_ADDR
	$display("  HADDR=%h  (expect BBBB0000 - dest now)", HADDR);
	$display("  HWRITE=%b (expect 1 - write phase)", HWRITE);
	$display("  fifo_r_en=%b (expect 1 - reading from fifo)", fifo_r_en);

	// ------ TC5: write data and done ------
	$display("\nTC5: Write data + transfer done");
	tick(1); // WRITE_DATA
	$display("  HWDATA=%h (expect CAFE0001 - from fifo)", HWDATA);
	tick(1); // CHECK_DONE - count hits 0
	$display("  transfer_done=%b (expect 0001 - ch0 done)", transfer_done);

	// ------ TC6: hready=0 should stall in read_addr ------
	// addr must stay stable on bus during wait - ahb spec req
	$display("\nTC6: HREADY=0 stall in READ_ADDR");
	src_addr_flat[31:0]  = 32'hCCCC0000;
	dest_addr_flat[31:0] = 32'hDDDD0000;
	count_flat[31:0]     = 32'd1;
	grant = 4'b0001;
	tick(1);
	grant=0;
	HREADY=0;
	tick(1); // READ_ADDR but stalled
	$display("  stalled: HTRANS=%b HADDR=%h (expect 10, CCCC0000 - held)", HTRANS, HADDR);
	tick(1); // still stalled
	$display("  still stalled: HTRANS=%b", HTRANS);
	HREADY=1; // release
	tick(1); tick(1); tick(1); tick(1); tick(1); // let it finish
	$display("  transfer_done=%b (expect 0001 - finished after stall)", transfer_done);

	// ------ TC7: fifo_full stalls read_addr ------
	// when fifo is full we cant do the read - htrans should go 00
	$display("\nTC7: fifo_full=1 stalls READ_ADDR");
	src_addr_flat[31:0]  = 32'hEEEE0000;
	dest_addr_flat[31:0] = 32'hFFFF0000;
	count_flat[31:0]     = 32'd1;
	grant=4'b0001;
	tick(1);
	grant=0; fifo_full=1;
	tick(1);
	$display("  fifo full: HTRANS=%b (expect 00 - no addr issued)", HTRANS);
	tick(1);
	$display("  still full: HTRANS=%b", HTRANS);
	fifo_full=0;
	tick(1);
	$display("  fifo clear: HTRANS=%b HADDR=%h (expect 10, EEEE0000)", HTRANS, HADDR);
	tick(1); tick(1); tick(1); tick(1);
	$display("  transfer_done=%b (expect 0001)", transfer_done);

	// ------ TC8: count=2, multi word transfer ------
	// src and dest should each increment by 4 per word
	$display("\nTC8: count=2 multi-word");
	src_addr_flat[31:0]  = 32'h10000000;
	dest_addr_flat[31:0] = 32'h20000000;
	count_flat[31:0]     = 32'd2;
	grant=4'b0001;
	tick(1);
	grant=0;

	// word 1
	tick(1); // READ_ADDR
	$display("  word1 read:  HADDR=%h (expect 10000000)", HADDR);
	tick(1); // READ_DATA
	$display("  word1 fifo:  fifo_w_en=%b (expect 1)", fifo_w_en);
	tick(1); // WRITE_ADDR
	$display("  word1 write: HADDR=%h (expect 20000000)", HADDR);
	tick(1); // WRITE_DATA
	tick(1); // CHECK_DONE count=2->1, loops back

	// word 2
	tick(1); // READ_ADDR again
	$display("  word2 read:  HADDR=%h (expect 10000004 - incremented)", HADDR);
	tick(1); // READ_DATA
	tick(1); // WRITE_ADDR
	$display("  word2 write: HADDR=%h (expect 20000004 - incremented)", HADDR);
	tick(1); // WRITE_DATA
	tick(1); // CHECK_DONE count=1->0, done
	$display("  transfer_done=%b (expect 0001 - after 2 words)", transfer_done);

	// ------ TC9: ch1 grant, check correct slice used ------
	$display("\nTC9: CH1 grant - slice [63:32]");
	src_addr_flat[63:32]  = 32'h55550000;
	dest_addr_flat[63:32] = 32'h66660000;
	count_flat[63:32]     = 32'd1;
	grant=4'b0010; // ch1
	tick(1);
	grant=0;
	tick(1); // READ_ADDR
	$display("  CH1 read:  HADDR=%h (expect 55550000)", HADDR);
	tick(1); // READ_DATA
	tick(1); // WRITE_ADDR
	$display("  CH1 write: HADDR=%h (expect 66660000)", HADDR);
	tick(1); // WRITE_DATA
	tick(1); // CHECK_DONE
	$display("  transfer_done=%b (expect 0010 - bit1 not bit0)", transfer_done);

	$display("\n--- done ---");
	$finish;
end

endmodule
