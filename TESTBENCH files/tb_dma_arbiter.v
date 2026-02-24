`timescale 1ns/1ps
module tb_dma_arbiter;
parameter NUM_CHAN=4;

reg clk,rst_n;
reg [NUM_CHAN-1:0] req;
wire [NUM_CHAN-1:0] grant;

dma_arbiter #(.NUM_CHAN(NUM_CHAN))
uut (.clk(clk),
	  .rst_n(rst_n),
	  .req(req),
	  .grant(grant));
	 
initial begin
	clk=0;
	forever #5 clk=~clk;
end

//reset
initial begin
rst_n=0;
req=000;

#20;
rst_n=1;
$display("---RESET COMPLETE---");

//	1. SINGLE REQUEST CHECK 
req=4'b0001;
repeat (2) @(posedge clk);
$display("---SINGLE REQUEST COMPLETE");
#10;
//2. MULTI REQUEST CHECK
req=4'b0011;
repeat (4) @(posedge clk);
$display("---MULTI REQUEST COMPLETE");
#10;
//3. ALL REQUEST CHECK
req=4'b1111;
repeat (6) @(posedge clk);
$display("---ALL REQUEST COMPLETE");
$finish;
end
endmodule