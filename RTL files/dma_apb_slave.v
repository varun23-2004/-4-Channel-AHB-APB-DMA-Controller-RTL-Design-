module dma_apb_slave (clk,rstn,psel,penable,pwrite,paddr,pwdata,prdata,pready,src_addr,dest_addr,count_addr,req,pslverr,done);
input wire clk, rstn;
//APB SLAVE signals
input wire psel, penable, pwrite;
input wire [31:0] paddr;
input wire [31:0] pwdata;
output reg [31:0] prdata;
output wire pready; 
output wire pslverr;
//OUTPUT TO DMA ENGINE 
////(acc to config (127 cause 4channels*32bits each=128 bits)
output wire [127:0] src_addr;
output wire [127:0] dest_addr;
output wire [127:0] count_addr;
output wire [3:0] req;
input wire [3:0] done;

//INTERNAL REGISTERS
reg [31:0] reg_src[0:3];
reg [31:0] reg_dest[0:3];
reg [31:0] reg_count[0:3];
reg [31:0] reg_config[0:3];


//DECODING ADDRESS INTO CHANNEL ADDRESS AND REGISTER ADDRESS
//paddr[31:6] -> must be 0 (within slave address range)
//paddr[5:4] -> channel (ch0=00, ch1=01, ch2=10, ch3=11)
//paddr[3:2] -> register (src=00, dest=01, count=10, config=11)
//paddr[1:0] -> must be 0 (word-aligned)
////extracting the bits [5:4] from 'paddr' to find channel(0,1,2,3)
wire [1:0] ch_id= paddr[5:4];
////extracting the bits [3:2] from 'paddr'to find register from the 4 registers
////which is defined above
wire [1:0] reg_id= paddr[3:2];

wire addr_valid= (paddr[31:6] == 26'd0) && (paddr[1:0] == 2'b00);
//1. WRITE 
////reset
//////using this for cause verilog dosent allow array to be cleared normally reg_src=0 
//////instead we use this method (integer method)
integer i;
always @(posedge clk or negedge rstn) 
begin
	if(!rstn) 
	begin
		for(i=0;i<4;i=i+1)
		begin
			reg_src[i]<=32'd0;
			reg_dest[i]<=32'd0;
			reg_count[i]<=32'd0;
			reg_config[i]<=32'd0;
		end
	end
	else 
	begin
		for (i=0;i<4;i=i+1)
		begin	
			if (done[i])
				reg_config[i][0]<=1'b0;
		end
		if(psel && penable && pwrite && addr_valid && !req[ch_id]) 
		begin
			case (reg_id)
				2'b00: reg_src[ch_id]<=pwdata;
				2'b01: reg_dest[ch_id]<=pwdata;
				2'b10: reg_count[ch_id]<=pwdata;
				2'b11: reg_config[ch_id]<=pwdata;
				default: ;
			endcase 
		end
	end
end

//2. READ
always @(*)
begin
	if (psel && penable && !pwrite)
	begin	
		case (reg_id)
			2'b00: prdata=reg_src[ch_id];
			2'b01: prdata=reg_dest[ch_id];
			2'b10: prdata=reg_count[ch_id];
			2'b11: prdata=reg_config[ch_id];
			default: prdata= 32'd0;
		endcase
	end
	else 
	begin
		prdata=32'd0;
	end
end

assign pready=1'b1;
assign pslverr = psel && penable && !addr_valid;

//3. OUTPUT TO DMA 
//// send them as 1D array cause verilog cannot send 2D array through 1 port
assign src_addr={reg_src[3], reg_src[2],reg_src[1],reg_src[0]};
assign dest_addr={reg_dest[3],reg_dest[2], reg_dest[1],reg_dest[0] };
assign count_addr={reg_count[3], reg_count[2], reg_count[1], reg_count[0]};
assign req={reg_config[3][0],reg_config[2][0],reg_config[1][0],reg_config[0][0]};
endmodule
