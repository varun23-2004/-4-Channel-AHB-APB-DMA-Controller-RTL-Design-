`timescale 1ns/1ps

module tb_dma_fifo;
parameter DATA_WIDTH=32;
parameter ADDR_WIDTH=2;

reg clk,rst_n,w_en,r_en;
reg [DATA_WIDTH-1:0] data_in;
wire [DATA_WIDTH-1:0] data_out;
wire full,empty;

dma_fifo_1 #(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH))
uut(.clk(clk),
	 .rst_n(rst_n),
	 .w_en(w_en),
	 .r_en(r_en),
	 .data_in(data_in),
	 .data_out(data_out),
	 .full(full),
	 .empty(empty));
	 
initial begin
	clk=0;
	forever #5 clk=~clk;
end

//RESET
initial begin
rst_n=0;
w_en=0;
r_en=0;
data_in=0;

#20;
rst_n=1;
$display("----RESET COMPLETE---");

//WRITE 
@(posedge clk) w_en=1; data_in=32'h10;
@(posedge clk) w_en=0;

@(posedge clk) w_en=1; data_in=32'h20;
@(posedge clk) w_en=0;

@(posedge clk) w_en=1; data_in=32'h30;
@(posedge clk) w_en=0; 

@(posedge clk) w_en=1; data_in=32'h40;
@(posedge clk) w_en=0;

$display ("----FIFO IS BE FULL NOW----");

//READ
@(posedge clk) r_en=1;
@(posedge clk) r_en=0;

@(posedge clk) r_en=1;
@(posedge clk) r_en=0;

@(posedge clk) r_en=1;
@(posedge clk) r_en=0;

@(posedge clk) r_en=1;
@(posedge clk) r_en=0;

$display ("----FIFO IS EMPTY NOW----");

//WRITE AND READ
$display("--- Preparing for Simultaneous Test (Pre-filling) ---");

@(posedge clk); w_en=1; data_in=32'hAA; r_en=0;
@(posedge clk); w_en=1; data_in=32'hBB; r_en=0;
@(posedge clk); w_en=0; r_en=0;
 
$display("--- Starting Simultaneous Read/Write Test ---");

@(posedge clk); w_en=1; data_in=32'hCC; r_en=1; 
@(posedge clk); w_en=0; r_en=0;
$display("---- ALL TESTS COMPLETE ----");
$finish;
end
endmodule
