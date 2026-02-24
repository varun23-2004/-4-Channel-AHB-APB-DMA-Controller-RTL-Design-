module dma_ahb_mas (clk, rstn, 
	grant,
	src_addr_flat, dest_addr_flat, count_flat, transfer_done, 
	fifo_full, fifo_empty, fifo_rdata, fifo_w_en, fifo_r_en, fifo_wdata, 
	HREADY, HRDATA, HWDATA, HSIZE, HADDR, HTRANS, HBURST, HWRITE);
//global signals
input wire clk, rstn;

//from arbiter
input wire [3:0] grant;

//from apb slave
input wire [127:0] src_addr_flat;
input wire [127:0] dest_addr_flat;
input wire [127:0] count_flat;
	output reg [3:0] transfer_done;

// FIFO interface (to internal buffer)
input wire fifo_full;
input wire fifo_empty;
input wire [31:0] fifo_rdata;
	output reg fifo_w_en;
	output reg fifo_r_en;
	output wire [31:0] fifo_wdata;

// AHB-lite bus (memory interface)
input wire HREADY;
input wire [31:0] HRDATA;
	output reg [31:0] HWDATA;
	output wire [2:0] HSIZE;	
	output reg [31:0] HADDR;
	output reg [1:0] HTRANS;
	output wire [2:0] HBURST;
	output reg HWRITE;

// CONSTRAINTS & ASSIGNMENTS 
assign HSIZE=3'b010; //32 bit word
assign HBURST= 3'b000; //only single burst
assign fifo_wdata=HRDATA;
localparam S_IDLE=3'd0;
localparam S_WRITE_ADDR=3'd1;
localparam S_WRITE_DATA=3'd2;
localparam S_READ_ADDR=3'd3;
localparam S_READ_DATA=3'd4;
localparam S_CHECK_DONE=3'd5;
reg [2:0] state;
reg [1:0] active_ch;
reg [31:0] current_src;
reg [31:0] current_dest;
reg [31:0] current_count;

//1. CHANNEL CONFIGURATOR

reg [31:0] next_src;
reg [31:0] next_dest;
reg [31:0] next_count;
reg [1:0] channel_idx;
	
//default zero 
always @(*) 
begin
	next_src=32'd0;
	next_dest=32'd0;
	next_count=32'd0;		
	channel_idx=2'd0;
	
	case (grant)
		4'b0001: begin
			next_src= src_addr_flat[31:0];
			next_dest= dest_addr_flat[31:0];
			next_count= count_flat[31:0];
			channel_idx=2'd0;
			end
		4'b0010: begin
			next_src= src_addr_flat[63:32];
			next_dest= dest_addr_flat[63:32];
			next_count= count_flat[63:32];
			channel_idx=2'd1;
			end
		4'b0100: begin
			next_src= src_addr_flat[95:64];
			next_dest= dest_addr_flat[95:64];
			next_count= count_flat [95:64];
			channel_idx=2'd2;
			end
		4'b1000: begin 
			next_src= src_addr_flat[127:96];
			next_dest= dest_addr_flat[127:96];
			next_count= count_flat[127:96];
			channel_idx=2'd3;
			end
		default: begin
			next_src=32'd0;
			next_dest=32'd0;
			next_count=32'd0;
			end
	endcase
end

//2.FSM
always @ (posedge clk or negedge rstn)
begin	
	if (!rstn) 
	begin
		state<=S_IDLE;
		current_src<=32'd0;
		current_dest<=32'd0;
		current_count<=32'd0;
		HADDR<=32'd0;
		HWDATA<=32'd0;
		HWRITE<=1'd0;
		HTRANS<=2'd0;
		fifo_w_en<=1'd0;
		fifo_r_en<=1'd0;
		transfer_done<=4'b0000;
		active_ch<=2'b0;

	end
	else 
	begin
	//Default assignments
	HTRANS<=2'b00;
	fifo_w_en<=1'd0;
	fifo_r_en<=1'd0;
	transfer_done<=4'b0000;
	
	//FSM DESIGN
	case (state)
	S_IDLE: begin
		if(grant !=4'b0000) begin
			current_src <= next_src;
			current_dest <= next_dest;
			current_count <= next_count;
			active_ch <= channel_idx;
			state <=S_READ_ADDR;
		end
	end
	
	S_READ_ADDR: 
	begin
		if (!fifo_full) 
		begin
			HADDR <= current_src;
			HWRITE <= 1'b0;
			HTRANS <= 2'b10;
			if (HREADY) state <= S_READ_DATA;
		end
	end
	
	S_READ_DATA: 
	begin
		if (HREADY) 
		begin
			fifo_w_en <= 1'b1;
			current_src <= current_src + 32'd4;
			state <= S_WRITE_ADDR;
		end
	end
	
	S_WRITE_ADDR: 
	begin
		if (!fifo_empty) 
		begin
			HADDR <= current_dest;
			HWRITE <= 1'b1;
			HTRANS <= 2'b10;
			fifo_r_en <= 1'b1;
			if (HREADY) state <= S_WRITE_DATA;
		end
	end
	
	S_WRITE_DATA: 
	begin
		HWDATA <= fifo_rdata;
		if (HREADY) 
		begin 
			current_dest <= current_dest + 32'd4;
			current_count <= current_count - 32'd1;
			state <= S_CHECK_DONE;
		end
	end
	
	S_CHECK_DONE: 
	begin
		if(current_count == 0) 
		begin
		transfer_done[active_ch] <= 1'b1;
		state <= S_IDLE;
		end
		else 
		begin
		state <= S_READ_ADDR;
		end
	end
	
	default: state <= S_IDLE;
	endcase
end
end
endmodule
