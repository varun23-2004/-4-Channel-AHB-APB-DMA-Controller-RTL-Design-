`timescale 1ns/1ps

module tb_apb;
reg clk, rstn;
reg psel,pwrite, penable;
reg [31:0] paddr, pwdata;
reg [3:0] done;

wire pready, pslverr;
wire [31:0] prdata;
wire [127:0] src_addr, dest_addr, count_addr;
wire [3:0] req;

dma_apb_slave DUT (.clk(clk),.rstn(rstn),
						 .psel(psel),.pwrite(pwrite),.penable(penable),
						 .paddr(paddr),.pwdata(pwdata),.done(done),
						 .pready(pready),.pslverr(pslverr),.prdata(prdata),
						 .src_addr(src_addr),.dest_addr(dest_addr),.count_addr(count_addr),
						 .req(req));
						 
initial clk=0;
always #5 clk=~clk;

//APB write task
task apb_write (input [31:0]addr, input [31:0] data);
begin
	@(negedge clk); //'negedge' cause the defined signals stablise 
	psel=1; penable=0; //before the next rising edge when the DUT samples them 
	pwrite=1; paddr=addr; pwdata=data;
	@(negedge clk);
	penable=1;
	@(negedge clk);
	psel=0; penable=0; pwrite=0;
end
endtask

//APB read task
task apb_read (input [31:0] addr);
begin
	@(negedge clk);
	psel=1; penable=0;
	pwrite=0; paddr=addr;
	@(negedge clk);
	penable=1;
	@(negedge clk);
	psel=0; penable=0;
end
endtask

//initialising inputs 
initial begin
//RESET check
$display("\n Task 1: RESET");
psel=0; penable=0; pwrite=0; paddr=0; pwdata=0; done=0;
rstn=0;
repeat (4) @(posedge clk);
rstn=1;
@(posedge clk);

//WRITE & READ BACK
$display ("\n Task 2: Write and Read back CH0 register");
apb_write(32'h00, 32'hAAAA_0000); //ch0 src
apb_write(32'h04, 32'hBBBB_0000); //ch0 dest
apb_write(32'h08, 32'h0000_0010); //ch0 count 
apb_read(32'h00); $display("ch0 src=%h (expect AAAA0000)",prdata);
apb_read(32'h04); $display("ch0 dst=%h (expect BBBB0000)",prdata);
apb_read(32'h08); $display("ch0 cnt=%h (expect 00000010)",prdata);

//ENABLE channel
$display("\n Task3: Enable CH0 via config reg");
apb_write(32'h0C, 32'h0000_0001);
@(posedge clk); 
	#1;
$display("req=%b (expect 0001)",req);

//Write blocked while channel is active
$display("\n Task 4: Write blocked while channel is active");
apb_write(32'h00, 32'hDEAD_DEAD);
apb_read(32'h00);
$display("ch0 src= %h (expect AAAA0000, not DEADDEAD)",prdata);

//'done' clears 'enable'
$display("\n Task 5: 'done' clears CH0 'enable'");
@(negedge clk); 
	done[0]=1;
@(negedge clk); 
	done[0]=0;
@(posedge clk); 
	#1;
$display("req=%b (expect 0000)",req);

//PSLVERR working
$display("\n Task 6: Is 'pslverr' working");
@(negedge clk);
psel=1; penable=0; pwrite=1; paddr=32'hFFFF_0000; pwdata=32'hDEAD;
@(negedge clk); 
penable=1;
@(posedge clk);
#1;
$display("pslverr=%b (expect 1)",pslverr);
@(negedge clk); psel=0; penable=0; pwrite=0;

//All 4 channels req bits
$display("\n Task 7: All 4 channels enabled independently");
apb_write(32'h0C, 32'h1);
apb_write(32'h1C, 32'h1);
apb_write(32'h2C, 32'h1);
apb_write(32'h3C, 32'h1);
@(posedge clk);
#1;
$display("req=%b (expect 1111)",req);

// Simulation Done 
$display("\n Simulation done");
$finish;
end
endmodule