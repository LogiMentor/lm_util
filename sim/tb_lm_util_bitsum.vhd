
library ieee;
use ieee.NUMERIC_STD.all;
use ieee.std_logic_1164.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
entity tb_lm_util_bitsum is
	-- Generic declarations of the tested unit
		generic(
		g_din_w : INTEGER := 28;
		g_nof_first_stage_chunk : INTEGER := 3);
end tb_lm_util_bitsum;

architecture tb_arch of tb_lm_util_bitsum is
	-- Component declaration of the tested unit
	component lm_util_bitsum
		generic(
		g_din_w : INTEGER;
		g_nof_first_stage_chunk : INTEGER );
	port(
		clk_i : in STD_LOGIC;
		dv_i : in STD_LOGIC;
		din_i : in STD_LOGIC_VECTOR(g_din_w-1 downto 0);
		dv_o : out STD_LOGIC;
		bitsum_o : out STD_LOGIC_VECTOR(f_ceil_log2(g_din_w)-1 downto 0) );
	end component;

	-- Stimulus signals - signals mapped to the input and inout ports of tested entity
	signal clk_i : STD_LOGIC := '0';
	signal dv_i : STD_LOGIC;
	signal din_i : STD_LOGIC_VECTOR(g_din_w-1 downto 0);
	-- Observed signals - signals mapped to the output ports of tested entity
	signal dv_o : STD_LOGIC;
	signal bitsum_o : STD_LOGIC_VECTOR(f_ceil_log2(g_din_w)-1 downto 0);

	-- Add your code here ...

begin        
  
  clk_i <= not clk_i after 5 ns;

	-- Unit Under Test port map
	UUT : lm_util_bitsum
		generic map (
			g_din_w => g_din_w,
			g_nof_first_stage_chunk => g_nof_first_stage_chunk
		)

		port map (
			clk_i => clk_i,
			dv_i => dv_i,
			din_i => din_i,
			dv_o => dv_o,
			bitsum_o => bitsum_o
		);

  process
    
  begin         
    -- initialize signals
    dv_i <= '0';
    din_i <= (others => '1'); 

    
    -- wait
    wait for 100 ns;
    wait until rising_edge(clk_i);
    
    -- test 1: all zero, expected 0
    dv_i  <= '1';
    din_i <= (others => '0'); 
    
    wait until rising_edge(clk_i);
    dv_i <= '0';   
    wait until rising_edge(clk_i);
    
    -- test 2: all ones, "g_din_w"
    dv_i  <= '1';
    din_i <= (others => '1'); 
    
    wait until rising_edge(clk_i);
    dv_i <= '0'; 
    wait until rising_edge(clk_i);
    wait;
  
  end process;	

end tb_arch;


