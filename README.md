# 4-Channel-AHB-APB-DMA-Controller-RTL-Design-
## 1. Overview
This repository contains the RTL design and verification of a 4-channel Direct Memory Access (DMA) Controller, built around the ARM AMBA protocol suite. The DMA controller acts as a bridge to offload heavy data-transfer tasks from the main CPU, thereby significantly increasing overall System-on-Chip (SoC) efficiency.

The architecture features an APB Slave interface dedicated to configuring the DMA transfer parameters (source address, destination address, and transfer count) and an AHB Master interface responsible for executing high-speed memory reads and writes. To handle simultaneous transfer requests from multiple peripherals, the design incorporates a Round-Robin Arbiter that ensures fair, starvation-free bandwidth allocation across all four channels. Additionally, a synchronous FIFO is integrated into the datapath to buffer data between the source and destination, managing burst transfers and preventing data loss during latency mismatches.


## 2. Project Objectives

**Protocol Implementation:** To design and integrate standard AMBA APB (slave) and AHB (master) interfaces, ensuring strict adherence to timing and handshaking protocols.

**Fair Data Arbitration**: To develop a robust 4-channel round-robin arbitration mechanism that successfully manages concurrent peripheral requests without dropping or stalling active transfers.

**Data Flow Management:** To implement FIFO-based buffering to safely handle high-throughput burst data between read and write domains.


## 3. Key Features
**4 Independent Channels:** Supports concurrent configuration of up to 4 distinct data transfer tasks.
**Round-Robin Arbitration:** Ensures fair bus allocation among competing channels, preventing lower-priority channel starvation.
**Synchronous FIFO Buffering:** Internal 32-bit x 4-depth FIFO decouples read and write operations, handling memory latency seamlessly.
**Standard AMBA Protocols:**
**APB (Advanced Peripheral Bus):** Low-bandwidth interface for configuring Source, Destination, Count, and Control registers.
**AHB-Lite (Advanced High-performance Bus):** High-bandwidth, pipelined interface for data movement.

## 4. System Architecture
The DMA controller is designed to be modular, splitting the configuration (setup) from the datapath (actual data movement). It uses a top-level wrapper [dma_top](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/RTL%20files/dma_top.v)  to connect four main sub-modules:

**A. APB Slave (Configuration Interface)**: [apb_slave](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/RTL%20files/dma_apb_slave.v)

This module acts as the bridge between the CPU and the DMA hardware.

i) Address Decoding: It reads standard _32-bit_ APB addresses to set up the four DMA channels. It uses specific memory offsets (_0x00_ for _Source_, _0x04_ for _Destination_, _0x08_ for _Count_, _0x0C_ for _Config_) to store the setup data in the correct channel's registers.

ii) Data Routing: To give the AHB Master instant access to all configurations at once, it bundles the individual 32-bit registers into wide 128-bit buses (_src_addr, dest_addr, count_addr_).

iii) Auto-Clearing Start Bit: Writing a '_1_' to Bit 0 of a channel's Config register acts as a "_Start_" button. Once the transfer finishes, the hardware automatically clears this bit back to '_0_', saving the CPU from having to do it manually.


**B. Round-Robin Arbiter (Channel Management)**: [arbiter](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/RTL%20files/dma_arbiter.v)

Since all four channels might ask to transfer data at the exact same time, the Arbiter acts as a traffic controller.

i) Fair Access: It checks the req (request) signals from all channels. If multiple channels want to transfer data, it grants access one by one using a rotating pointer.

ii) Preventing Starvation: Once a channel finishes its turn, it gets moved to the back of the line. This ensures no single channel hogs the bus and every peripheral gets a fair chance to move its data.


**C. Synchronous FIFO (Data Buffer)**  [fifo](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/RTL%20files/dma_fifo_1.v)

The FIFO acts as a temporary storage area between reading data from the source and writing it to the destination.

i) Structure: It is a circular buffer (_Depth = 4, Width = 32-bit_) that tracks whether it is full or empty to prevent data loss.

ii) Handling Delays: By buffering the data, it allows the AHB Master to keep reading a burst of data from the source even if the destination memory is temporarily busy or not ready to receive it.


**D. AHB-Lite Master (Execution Master)** [ahb_master](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/RTL%20files/dma_ahb_master.v)

This is the core engine that actually moves the data over the AHB bus. It operates using a clear 6-state Finite State Machine (FSM):

i) _IDLE_: Waits for permission (_grant_) from the Arbiter. Once granted, it loads the channel's configuration.

ii)_READ_ADDR_: Sends the source address to the memory.

iii)_READ_DATA_: Captures the actual data from the source memory and pushes it into the FIFO.

iv) _WRITE_ADDR_: Sends the target destination address to the memory.

v) _WRITE_DATA_: Pulls data out of the FIFO and writes it to the destination memory.

vi) _CHECK_DONE_: Reduces the transfer count by one. If the count hits zero, it signals that the job is done. If not, it loops back to keep moving data.
<img width="508" height="429" alt="block_diagram" src="https://github.com/user-attachments/assets/2dabdcb8-c938-44d2-8e2e-c6a646635df5" />


## 5. Verification & Simulation
The design was verified using a self-checking Top-Level Testbench [tb_top](https://github.com/varun23-2004/-4-Channel-AHB-APB-DMA-Controller-RTL-Design-/blob/main/TESTBENCH%20files/tb_dma_top.v) simulated in _QuestaSim_.

**Testbench Features:**

**APB BFM (Bus Functional Model):** Uses Verilog task routines to emulate CPU configuration writes. <img width="960" height="470" alt="apb" src="https://github.com/user-attachments/assets/9ccb6de8-e11c-41b1-8257-7425fffe1b0d" />


**AHB Memory Model:** Simulates a pipelined RAM (RAM like) array that responds to _HTRANS_, _HADDR_, and _HWDATA_ with realistic latency (_HREADY_).
<img width="958" height="476" alt="ahb" src="https://github.com/user-attachments/assets/3178b5c5-c3de-480a-b5ef-5e546f33717e" />


**Self-Checking Logic:** Automatically verifies data integrity by comparing the final destination memory contents against the original source data, outputting a _SUCCESS_ banner upon passing.
<img width="960" height="489" alt="waveform_top" src="https://github.com/user-attachments/assets/25acb667-92a1-44fd-a83e-196826f56e88" />


## 6. Register Map

In System-on-Chip (SoC) design, a register map acts as the software-to-hardware interface. It defines the specific memory addresses that a processor (CPU) must read or write to in order to configure, control, and monitor a hardware peripheral. Here is what the register map is exactly doing in our_ apb_slave_

**Stores Channel Configurations**: It captures the 32-bit data (_pwdata_) sent by the CPU and stores it into specific internal 2D array registers (_reg_src_, _reg_dest_, _reg_count_,_ reg_config_) based on the decoded address.

**Flattens Data for the DMA Engine**: It takes those individual 32-bit registers for all 4 channels and concatenates them into massive 128-bit wide output buses (_src_addr_,_ dest_addr_, _count_addr_). This gives the AHB master and Arbiter immediate, parallel access to all configurations at once, rather than making them wait to read a memory array.

**Translates Software Writes to Hardware Triggers**: It continuously extracts bit 0 from each channel's reg_config and groups them into the 4-bit req output signal. This allows a simple software register write to instantly become a physical hardware request to the arbiter.

Manages Hardware-to-Software Feedback: It monitors the 4-bit done input signal coming back from the DMA engine. When a channel completes its transfer, the register map automatically resets that specific channel's request bit back to 0 (_reg_config[i][0] <= 1'b0_). This prevents the CPU from needing to manually clear the bit.


| Offset | Register Name | R/W | Description                                                      |
|--------|---------------|-----|------------------------------------------------------------------|
| 0x00   | CH0_SRC_ADDR  | R/W | Channel 0: Source Memory Address                                 |
| 0x04   | CH0_DEST_ADDR | R/W | Channel 0: Destination Memory Address                            |
| 0x08   | CH0_COUNT     | R/W | Channel 0: Transfer Count / Bytes                                |
| 0x0C   | CH0_CONFIG    | R/W | Channel 0: Configuration & Control. Bit [0]: DMA Request Enable. |
| 0x10   | CH1_SRC_ADDR  | R/W | Channel 1: Source Memory Address                                 |
| 0x14   | CH1_DEST_ADDR | R/W | Channel 1: Destination Memory Address                            |
| 0x18   | CH1_COUNT     | R/W | Channel 1: Transfer Count / Bytes                                |
| 0x1C   | CH1_CONFIG    | R/W | Channel 1: Configuration & Control. Bit [0]: DMA Request Enable. |
| 0x20   | CH2_SRC_ADDR  | R/W | Channel 2: Source Memory Address                                 |
| 0x24   | CH2_DEST_ADDR | R/W | Channel 2: Destination Memory Address                            |
| 0x28   | CH2_COUNT     | R/W | Channel 2: Transfer Count / Bytes                                |
| 0x2C   | CH2_CONFIG    | R/W | Channel 2: Configuration & Control. Bit [0]: DMA Request Enable. |
| 0x30   | CH3_SRC_ADDR  | R/W | Channel 3: Source Memory Address                                 |
| 0x34   | CH3_DEST_ADDR | R/W | Channel 3: Destination Memory Address                            |
| 0x38   | CH3_COUNT     | R/W | Channel 3: Transfer Count / Bytes                                |
| 0x3C   | CH3_CONFIG    | R/W | Channel 3: Configuration & Control. Bit [0]: DMA Request Enable. |

