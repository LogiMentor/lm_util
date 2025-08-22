library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

library ieee;
use ieee.NUMERIC_STD.all;
use ieee.std_logic_1164.all;

	-- Add your library and packages declaration here ...

entity tb_lm_util_lfsr is
	-- Generic declarations of the tested unit
		generic(
		g_data_w : INTEGER := 11 );
end tb_lm_util_lfsr;

architecture tb_arch of tb_lm_util_lfsr is
	-- Stimulus signals - signals mapped to the input and inout ports of tested entity
	signal clk_i : STD_LOGIC := '0';
	signal rst_n_i : STD_LOGIC;
	signal load_i : STD_LOGIC;
	signal seed_i : STD_LOGIC_VECTOR(g_data_w-1 downto 0);
	-- Observed signals - signals mapped to the output ports of tested entity
	signal rng_o : STD_LOGIC_VECTOR(g_data_w-1 downto 0);

	signal async_reset_i  : std_logic;

begin                             
  
  clk_i <= not clk_i after 5 ns;
  
  rst_n_i<= '0', '1' after 150 ns;  
  
  async_reset_i <= not rst_n_i;

	-- Unit Under Test port map
	UUT : entity lm_util_lib.lm_util_lfsr
		generic map (
			g_data_w => g_data_w
		)

		port map (
			clk_i => clk_i,
			rst_n_i => rst_n_i,
			load_i => load_i,
			seed_i => seed_i,
			rng_o => rng_o
		);       



  proc_stim: process
    
  begin   
    load_i  <= '0';
    seed_i  <= std_logic_vector(to_unsigned(5,g_data_w));
    wait until rst_n_i = '1';
    wait until rising_edge(clk_i); 
    
    wait for 100 ns;
    wait until rising_edge(clk_i); 
    
    load_i <= '1';
    wait until rising_edge(clk_i); 
    load_i <= '0';
    
    wait;
  
  end process proc_stim;	

end tb_arch;


