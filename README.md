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

## 3. System Architecture
The design is highly modular, consisting of a top-level wrapper [top_level_module](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/RTL%20files/dma_top.v) and four primary sub-modules:


**A. APB Slave** [apb_slave](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/RTL%20files/dma_apb_slave.v)

Acts as the configuration register file. It decodes the APB address to route data to the specific channel's registers:

_0x00_: Source Address

_0x04_: Destination Address

_0x08_: Transfer Count

_0x0C_: Control/Status (Bit 0 = Start)


**B. Round-Robin Arbiter** [arbiter](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/RTL%20files/dma_arbiter.v)

Monitors the _req_ (start) signals from the 4 channels. If multiple channels request the bus simultaneously, it grants access using a rotating priority pointer to ensure absolute fairness.


**C. Synchronous FIFO**  [fifo](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/RTL%20files/dma_fifo_1.v)

A circular buffer (_Depth_ = 4, _Width_ = 32-bit) with full and empty flags. It allows the AHB Master to read a burst of data from the source even if the destination memory is temporarily unready.


**D. AHB-Lite Master** [ahb_master](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/RTL%20files/dma_ahb_master.v)

The core execution engine. It utilizes a 6-State Finite State Machine (FSM):

_IDLE_: Waits for an Arbiter grant and loads configuration.

_READ_ADDR_: Drives the source address onto the AHB bus.

_READ_DATA_: Captures memory data and pushes it to the FIFO.

_WRITE_ADDR_: Drives the destination address.

_WRITE_DATA_: Pops data from the FIFO and writes it to memory.

_CHECK_DONE_: Decrements the count and checks for job completion.

<img width="960" height="493" alt="rtl_schematic" src="https://github.com/user-attachments/assets/041d116a-c669-4d9d-a42e-ca2daafeb203" />


## 4. Verification & Simulation
The design was verified using a self-checking Top-Level Testbench [tb_top](tb_dma_top.v) simulated in _QuestaSim_.

**Testbench Features:**

**APB BFM (Bus Functional Model):** Uses Verilog task routines to emulate CPU configuration writes. <img width="960" height="470" alt="apb" src="https://github.com/user-attachments/assets/9ccb6de8-e11c-41b1-8257-7425fffe1b0d" />


**AHB Memory Model:** Simulates a pipelined RAM (RAM like) array that responds to _HTRANS_, _HADDR_, and _HWDATA_ with realistic latency (_HREADY_).
<img width="958" height="476" alt="ahb" src="https://github.com/user-attachments/assets/3178b5c5-c3de-480a-b5ef-5e546f33717e" />


**Self-Checking Logic:** Automatically verifies data integrity by comparing the final destination memory contents against the original source data, outputting a _SUCCESS_ banner upon passing.
<img width="960" height="489" alt="waveform_top" src="https://github.com/user-attachments/assets/25acb667-92a1-44fd-a83e-196826f56e88" />

