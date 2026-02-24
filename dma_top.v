module dma_top(clk, rst_n,
					psel, penable, pwrite, paddr, pwdata, prdata, pready, pslverr,
					HREADY, HRDATA, HWDATA, HSIZE, HADDR, HTRANS, HBURST, HWRITE);
					
//GLOBAL SIGNALS
input wire clk, rst_n;
//APB SLAVE (to CPU)
input wire psel,penable, pwrite;
input wire [31:0] paddr;
input wire [31:0] pwdata;
output wire [31:0] prdata;
output wire pready, pslverr;
//AHB MASTER (to MEMORY)
input wire HREADY;
input wire [31:0] HRDATA;
output wire [31:0] HWDATA;
output wire [2:0] HSIZE;
output wire [31:0] HADDR;
output wire [1:0] HTRANS;
output wire [2:0] HBURST;
output wire HWRITE;
//INTERNAL WIRES (motherboard)
// config wires (apb->ahb)
wire [127:0] w_src;
wire [127:0] w_dest;
wire [127:0] w_count;
//handshake signals
wire [3:0] w_req;
wire [3:0] w_grant;
wire [3:0] w_transfer_done;
//FIFO wires (AHB<->FIFO)
wire w_fifo_w_en, w_fifo_r_en;
wire [31:0] w_fifo_wdata;
wire [31:0] w_fifo_rdata;
wire w_fifo_full, w_fifo_empty;



//Instantiate FIFO
dma_fifo_1 u_fifo(
		.clk(clk),.rst_n(rst_n),
		.w_en(w_fifo_w_en),.r_en(w_fifo_r_en),
		.data_in(w_fifo_wdata),.data_out(w_fifo_rdata),
		.full(w_fifo_full),.empty(w_fifo_empty));
		
//Instantiate ARBITER
dma_arbiter u_arbiter(
		.clk(clk),.rst_n(rst_n),
		.req(w_req),.grant(w_grant));
		
//Instantiate APB slave
dma_apb_slave u_apb_slave(
		.clk(clk),.rstn(rst_n),
		.psel(psel),.penable(penable),.pwrite(pwrite),.pready(pready),.pslverr(pslverr),
		.paddr(paddr),.pwdata(pwdata),.prdata(prdata),
		.req(w_req),.done(w_transfer_done),
		.src_addr(w_src),.dest_addr(w_dest),.count_addr(w_count));
		
//Instantiate AHB master
dma_ahb_master u_ahb_master(
		.clk(clk),.rstn(rst_n),
		.grant(w_grant),
		.transfer_done(w_transfer_done),
		.src_addr_flat(w_src),.dest_addr_flat(w_dest),.count_flat(w_count),
		.fifo_full(w_fifo_full),.fifo_empty(w_fifo_empty),
		.fifo_w_en(w_fifo_w_en),.fifo_r_en(w_fifo_r_en),
		.fifo_wdata(w_fifo_wdata),.fifo_rdata(w_fifo_rdata),
		.HREADY(HREADY),.HRDATA(HRDATA),.HWDATA(HWDATA),.HSIZE(HSIZE),.HADDR(HADDR),.HTRANS(HTRANS),.HBURST(HBURST),.HWRITE(HWRITE));
endmodule