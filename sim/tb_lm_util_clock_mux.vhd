library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;

	-- Add your library and packages declaration here ...

entity tb_lm_util_clock_mux is
	-- Generic declarations of the tested unit
		generic(
		g_num_clocks : POSITIVE := 4);
end tb_lm_util_clock_mux;

architecture tb_arch of tb_lm_util_clock_mux is
	-- Component declaration of the tested unit
	component lm_util_clock_mux
		generic(
		g_num_clocks : POSITIVE );
	port(
		clk_i : in STD_LOGIC_VECTOR(g_num_clocks-1 downto 0);
		clk_sel_i : in STD_LOGIC_VECTOR(g_num_clocks-1 downto 0);
		clk_o : out STD_LOGIC );
	end component;

	-- Stimulus signals - signals mapped to the input and inout ports of tested entity
	signal clk_i : STD_LOGIC_VECTOR(g_num_clocks-1 downto 0) := (others => '0');
	signal clk_sel_i : STD_LOGIC_VECTOR(g_num_clocks-1 downto 0) := (others => '0');
	-- Observed signals - signals mapped to the output ports of tested entity
	signal clk_o : STD_LOGIC;
  -- delayed clocks, to test glitches
	signal s_clk_del : STD_LOGIC_VECTOR(g_num_clocks-1 downto 0) := (others => '0');

begin         
  
  clk_i(0) <= not clk_i(0) after 10 ns;
  clk_i(1) <= not clk_i(1) after 8 ns;
  clk_i(2) <= not clk_i(2) after 5 ns;
  clk_i(3) <= not clk_i(3) after 3 ns;
  
  s_clk_del(0) <= transport clk_i(0) after 800 ps;
  s_clk_del(1) <= transport clk_i(1) after 550 ps;
  s_clk_del(2) <= transport clk_i(2) after 350 ps;
  s_clk_del(3) <= transport clk_i(3) after 210 ps;
  
  

	-- Unit Under Test port map
	UUT : lm_util_clock_mux
		generic map (
			g_num_clocks => g_num_clocks
		)

		port map (
			clk_i => s_clk_del,
			clk_sel_i => clk_sel_i,
			clk_o => clk_o
		);

	proc_stim: process
  begin          
    clk_sel_i <= clk_sel_i(clk_sel_i'left-1 downto 0) & '1';
    wait for 1 us;
    for k in 0 to g_num_clocks-1 loop
      clk_sel_i <= clk_sel_i(clk_sel_i'left-1 downto 0) & clk_sel_i(clk_sel_i'left); 
      wait for 1 us;
    end loop;
	--Invalid input
	clk_sel_i <= (others => '0');  
	clk_sel_i(1 downto 0) <= "11";
    wait for 1 us;
	clk_sel_i <= (others => '0');
    wait for 1 us;
  end process proc_stim;

end tb_arch;



