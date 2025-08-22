The UTILITY library is a collection of modules that are used in almost every FPGA design, it is the Swiss Army Knife of every FPGA designer. All the modules are vendor independent high quality VHDL code.
In the UTILITY LIBRARY you will find a full set of memory modules (single port,
dual port, true dual port), synchronous and asynchronous FIFOs, Encoders and Decoders and a lot of other essential modules.

Benefits of libraries

VHDL libraries are a powerful mechanism the language offers to collect common modules together for reuse.
Reuse is a key to success with FPGA design, it helps to design faster, easier and with verified and validated
modules. Designing and testing a general purpose library is often considered as a time consuming effort and
most often there is no time for FPGA designers to build a complete general purpose library.
Using our library allow designers to focus on highlevel design without wasting time to develop building blocks.

Key Features

vendor independent "off the shelf" VHDL cores for FPGAs (Xilinx, Altera,
Achronix, Lattice and Microsemi)
VHDL modules are written in pure VHDL-93 standard (2008 is not fully supported by all vendors and synthesizers), 
completely vendor independent optimized in terms of speed, power and resource usage


Key benefits 

No cost for hardware/tool version update/upgrade
No time to re-generate the cores for different targets and/or tools
Considerably faster simulations compared to vendor pre-synthesized IP Cores
More than 150 useful functions in the ces_util package
More than 13.000 lines of VHDL source code and 7000 lines of comments
Campera-ES internal VHDL coding standard to help you quickly understand the source code
The ces_util_lib is the swiss army knife of every FPGA designer and is ideal for expert designers as well as beginners


CES UTILITY LIBRARY MODULES
Module name 					Description
ces_util_ccd_switch 			Cross clock domain switch
ces_util_counter 				General purpose configurable counter. Can be used also as Watchdog timer
ces_util_mux 					General purpose multiplexer
ces_util_demux 					General purpose demultiplexer
ces_util_delay 					Delay with architecture SRL, memory or pulse
ces_util_delay_var 				Variable delay module with SRL, memory or pulse architecture
ces_util_encoder 				General purpose encoder
ces_util_file_read/write 		Read or write formatted signals on files, for simulation purposes
ces_util_clock_gen 				Single ended or differential clock generator for simulation purposes
ces_util_pkg 					Utility package with more than 150 useful functions
ces_util_sync_pulse 			Synchronize a pulse through a cross clock domain
ces_util_ram_crw_crw			Synthesizable ram modules, single, simple dual, true dual port. The memory
								content can be initialized from an external text file
ces_util_fifo_sync 				Synchronous FIFO, with configurable depth and width
ces_util_fifo_async 			Asynchronous FIFO with two clock domains


-- NAMING CONVENTIONS: 
-- _e one-CLK early sample
-- _d one-CLK delayed sample
-- _d2 two-CLKs delayed sample
-- _n active low signal
-- C_ constant
-- s_ signal
-- _i input port
-- _o output port
-- _io inout port
-- t_ type
-- _st FSM state

Reset Strategy
all the ces util librariy cores used active low synchronous reset, with the exception of the ces_util_async_reset that is used to synchronize an asynchronous reset.
keep in mind that you should only reset Finite State Machine and counters, the datapath should almost always doesnt need to use a reset signal, unless you have feedback i nyour datapath (again when you have "memory" of an old state you might need a reset)
the fanout on the reset signal should be kept as low as possible