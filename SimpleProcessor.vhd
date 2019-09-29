library ieee;
use ieee.std_logic_1164.all;

entity SimpleProcessor is
	port(
			clock			: in std_logic;
			reset			: in std_logic;
			MEM_read		: out std_logic;
			MEM_write	: out std_logic;
			MFC			: in std_logic;
			MEM_address	: out std_logic_vector(15 downto 0);
			Data_to_Mem	: out std_logic_vector(15 downto 0);
			Data_from_Mem : in std_logic_vector(15 downto 0);
			-- for ModelSim debugging only
			debug_PC	: out std_logic_vector(15 downto 0);
			debug_IR	: out std_logic_vector(15 downto 0);
			debug_state : out std_logic_vector(2 downto 0);
			debug_r1	: out std_logic_vector(15 downto 0);
			debug_r2	: out std_logic_vector(15 downto 0);
			debug_r3	: out std_logic_vector(15 downto 0);
			debug_r4	: out std_logic_vector(15 downto 0);
			debug_r5	: out std_logic_vector(15 downto 0);
			debug_r6	: out std_logic_vector(15 downto 0);
			debug_r7	: out std_logic_vector(15 downto 0);
			debug_RA	: out std_logic_vector(15 downto 0);
			debug_RB	: out std_logic_vector(15 downto 0);
			debug_Extension : out std_logic_vector(15 downto 0);
			debug_RZ	: out std_logic_vector(15 downto 0);
			debug_RY	: out std_logic_vector(15 downto 0)
	);
end SimpleProcessor;

architecture implementation of SimpleProcessor is
	component RegisterFile8by16Bit is
		port(
			clock, reset, RF_write			:in std_logic;
			AddressA, AddressB, AddressC	:in std_logic_vector(2 downto 0);
			InputC								:in std_logic_vector(15 downto 0);
			OutputA, OutputB   				:out std_logic_vector(15 downto 0);
			-- for debugging only
			debug_r1	: out std_logic_vector(15 downto 0);
			debug_r2	: out std_logic_vector(15 downto 0);
			debug_r3	: out std_logic_vector(15 downto 0);
			debug_r4	: out std_logic_vector(15 downto 0);
			debug_r5	: out std_logic_vector(15 downto 0);
			debug_r6	: out std_logic_vector(15 downto 0);
			debug_r7	: out std_logic_vector(15 downto 0);
		);
	end component;
	component ALU is
		port(
			ALU_op 			: in std_logic_vector(1 downto 0);
			A, B 				: in std_logic_vector(15 downto 0);
			A_inv, B_inv 	: in std_logic;
			C_in				: in std_logic;
			ALU_out 			: out std_logic_vector(15 downto 0);
			N, C, V, Z 		: out std_logic
		);
	end component;
	component Immediate is
		port(
			IR: in std_logic_vector(15 downto 0);
			PC: in std_logic_vector(15 downto 0);
			extend: in std_logic_vector(2 downto 0);
			extension: out std_logic_vector(15 downto 0)
		);
	end component;
	component ControlUnit is
		port(
			clock	: in  std_logic;
			reset	: in  std_logic;
			status: in  std_logic_vector(15 downto 0);
			MFC	: in  std_logic;
			IR		: in  std_logic_vector(15 downto 0);
			RF_write	: out std_logic;
			C_select	: out std_logic_vector(1 downto 0);
			B_select : out std_logic;
			Y_select	: out std_logic_vector(1 downto 0);
			ALU_op	: out std_logic_vector(1 downto 0);
			A_inv		: out std_logic;
			B_inv		: out std_logic;
			C_in		: out std_logic;
			MEM_read	: out std_logic;
			MEM_write: out std_logic;
			MA_select: out std_logic;
			IR_enable: out std_logic;
			PC_select: out std_logic_vector(1 downto 0);
			PC_enable: out std_logic;
			INC_select: out std_logic;
			extend	: out std_logic_vector(2 downto 0);
			Status_enable : out std_logic;
			-- for ModelSim debugging only
			debug_state	: out std_logic_vector(2 downto 0)
		);
	end component;
	component Adder16Bit is
		port(
			X, Y 	: in std_logic_vector(15 downto 0);
			C_in 	: in std_logic;
			S 		: out std_logic_vector(15 downto 0);
			C_out_14, C_out_15 : out std_logic
		);
	end component;
	component Reg16Bit is
		port(
			clock   : in std_logic;
			reset   : in std_logic;
			enable  : in std_logic;
			D		  : in std_logic_vector(15 downto 0);
			Q		  : out std_logic_vector(15 downto 0)
		);
	end component;
	component Mux2Input16Bit is
		port(
			s : in  std_logic;
			input0, input1 : in  std_logic_vector(15 downto 0);
			result : out std_logic_vector(15 downto 0));
	end component;
	component Mux4Input16Bit is
		port(
			s : in  std_logic_vector(1 downto 0);
			input0, input1, input2, input3 : in  std_logic_vector(15 downto 0);
			result : out std_logic_vector(15 downto 0));
	end component;
	component Mux4Input3Bit is
		port(
			s : in  std_logic_vector(1 downto 0);
			input0, input1, input2, input3 : in  std_logic_vector(2 downto 0);
			result : out std_logic_vector(2 downto 0));
	end component;

	-- component data
	signal Data_RFOutA,Data_RFOutB: std_logic_vector(15 downto 0);
	signal Data_MuxC 					: std_logic_vector(2 downto 0);
	signal Data_RA, Data_RB			: std_logic_vector(15 downto 0);
	signal Data_MuxB, Data_ALU		: std_logic_vector(15 downto 0);
	signal Data_RZ						: std_logic_vector(15 downto 0);
	signal Data_MuxY, Data_RY		: std_logic_vector(15 downto 0);
	signal Data_IR, Data_Extension: std_logic_vector(15 downto 0);
	signal Data_MuxInc, Data_Adder: std_logic_vector(15 downto 0);
	signal Data_MuxPC, Data_PC		: std_logic_vector(15 downto 0);
	signal Data_PC_temp				: std_logic_vector(15 downto 0);
	signal Data_Status				: std_logic_vector(15 downto 0);
	-- control signals
	signal	RF_write	: std_logic;
	signal 	C_select	: std_logic_vector(1 downto 0);
	signal	B_select : std_logic;
	signal 	Y_select	: std_logic_vector(1 downto 0);
	signal	ALU_op	: std_logic_vector(1 downto 0);
	signal	A_inv		: std_logic;
	signal	B_inv		: std_logic;
	signal	C_in		: std_logic;
	signal   N, C, V, Z : std_logic;
	signal	MA_select: std_logic;
	signal	IR_enable: std_logic;
	signal	PC_select: std_logic_vector(1 downto 0);
	signal	PC_enable: std_logic;
	signal	INC_select: std_logic;
	signal	extend	: std_logic_vector(2 downto 0);
	signal	Status_enable : std_logic;
	-- add your interal signals below
	
begin
	-- for debugging only
	debug_PC <= Data_PC;
	debug_IR <= Data_IR;
	debug_RA <= Data_RA;
	debug_RB <= Data_RB;
	debug_Extension <= Data_Extension;
	debug_RZ <= Data_RZ;
	debug_RY <= Data_RY;

	-- Connect processor components below
	ReigsterFile : RegisterFile8by16Bit port map(clock, reset, RF_write,Data_IR(15 downto 13), Data_IR(12 downto 10), Data_MuxC, Data_RY, Data_RFOutA, Data_RFOutB);
	MuxC : Mux4Input3Bit port map (C_select, Data_IR(12 downto 10), Data_IR(9 downto 7), "111", "000", Data_MuxC);
	RA : Reg16Bit port map(clock, reset, 1, Data_RFOutA, Data_RA);
	RB : Reg16Bit port map(clock, reset, 1, Data_RFOutB, Data_RB);
	MuxB : Mux2Input16Bit port map(B_select, Data_RB, , Data_MuxB);
	ALU : ALU port map( ALU_op, Data_RA, Data_MuxB, A_inv, B_inv, C_in, Data_ALU, N, C, V, Z);
	RZ : Reg16Bit port map(clock, reset, 1, Data_ALU, Data_RZ);
	RM : Reg16Bit port map(clock, reset, 1, Data_RB, Data_RM);
	MUXY :  Mux4Input16Bit port map(Y_select, Data_RZ, Data_from_Mem, Data_PC_temp, Data_ZEROS, Data_MuxY);
	RY : Reg16Bit port map(clock, reset, 1, Data_MuxY, Data_RZ);
	IR : Reg16Bit port map(clock, reset, IR_enable, Data_from_Mem, Data_IR);
	Control Unit : ControlUnit port map (clock, reset, Data_Status, MFC, Data_IR, RF_write, C_select, B_select, Y_select, ALU_op, A_inv, B_inv, C_in, MEM_read, MEM_write, MA_select, IR_enable, PC_select, PC_enable, INC_select, extend, Status_enable, debug_state);
	Immediate : Immediate port map( Data_IR, Data_PC, extend, Data_Extension);
	MuxInC : Mux2Input16Bit port map(INC_select, 1, Data_Extension, Data_MuxInc);
	--Adder : Adder16Bit port map (Data_MuxInc, Data_PC, C_in, Data_Adder, C_out_14, C_out_15);
	MuxPC : Mux4Input16Bit port map (PC_select, Data_RA, Data_Adder, Data_Extension, Data_ZEROS, Data_MuxPC);
	PC : Reg16Bit port map(clock, reset, PC_enable, Data_MuxPC, Data_PC);
	MuxMA : Mux2Input16Bit port map(MA_select, Data_RZ, Data_PC, MEM_address);
	PC_temp : Reg16Bit port map(clock, reset, 1, Data_PC, Data_PC_temp);
	Status : Reg16Bit port map(clock, reset, Status_enable, Data_RFOutB, Data_Status);
	
	
end implementation;