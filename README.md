# 4-Channel-AHB-APB-DMA-Controller-RTL-Design-
## 1. Overview
This project implements a synthesizable, 4-Channel Direct Memory Access (DMA) Controller in Verilog. The DMA offloads data transfer operations from the CPU, allowing high-speed Memory-to-Memory copies. It features an AMBA APB Slave interface for CPU configuration and a pipelined AMBA AHB-Lite Master interface for executing memory transfers.

## 2. Key Features
**4 Independent Channels:** Supports concurrent configuration of up to 4 distinct data transfer tasks.
**Round-Robin Arbitration:** Ensures fair bus allocation among competing channels, preventing lower-priority channel starvation.
**Synchronous FIFO Buffering:** Internal 32-bit x 4-depth FIFO decouples read and write operations, handling memory latency seamlessly.
**Standard AMBA Protocols:**
**APB (Advanced Peripheral Bus):** Low-bandwidth interface for configuring Source, Destination, Count, and Control registers.
**AHB-Lite (Advanced High-performance Bus):** High-bandwidth, pipelined interface for data movement.

##3. System Architecture
The design is highly modular, consisting of a top-level wrapper [top_level_module](dma_top.v) and four primary sub-modules:
**A. APB Slave** [apb_slave](dma_apb_slave.v)
Acts as the configuration register file. It decodes the APB address to route data to the specific channel's registers:
_0x00_: Source Address
_0x04_: Destination Address
_0x08_: Transfer Count
_0x0C_: Control/Status (Bit 0 = Start)
**B. Round-Robin Arbiter** [arbiter](dma_arbiter.v)
Monitors the _req_ (start) signals from the 4 channels. If multiple channels request the bus simultaneously, it grants access using a rotating priority pointer to ensure absolute fairness.
**C. Synchronous FIFO**  [fifo](dma_fifo_1.v)
A circular buffer (_Depth_ = 4, _Width_ = 32-bit) with full and empty flags. It allows the AHB Master to read a burst of data from the source even if the destination memory is temporarily unready.
**D. AHB-Lite Master** [ahb_master](dma_ahb_master.v)
The core execution engine. It utilizes a 6-State Finite State Machine (FSM):
_IDLE_: Waits for an Arbiter grant and loads configuration.
_READ_ADDR_: Drives the source address onto the AHB bus.
_READ_DATA_: Captures memory data and pushes it to the FIFO.
_WRITE_ADDR_: Drives the destination address.
_WRITE_DATA_: Pops data from the FIFO and writes it to memory.
_CHECK_DONE_: Decrements the count and checks for job completion.

##4. Verification & Simulation
The design was verified using a self-checking Top-Level Testbench [tb_top](tb_dma_top.v) simulated in _QuestaSim_.
**Testbench Features:**
**APB BFM (Bus Functional Model):** Uses Verilog task routines to emulate CPU configuration writes.
**AHB Memory Model:** Simulates a pipelined RAM (RAM like) array that responds to _HTRANS_, _HADDR_, and _HWDATA_ with realistic latency (_HREADY_).
**Self-Checking Logic:** Automatically verifies data integrity by comparing the final destination memory contents against the original source data, outputting a _SUCCESS _banner upon passing.
