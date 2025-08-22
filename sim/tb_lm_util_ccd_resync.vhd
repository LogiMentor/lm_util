library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;

-- Add your library and packages declaration here ...

entity tb_lm_util_ccd_resync is
  -- Generic declarations of the tested unit
  generic (
    g_meta_levels : natural := 2
  );
end tb_lm_util_ccd_resync;

architecture behav of tb_lm_util_ccd_resync is
  constant C_CLK_IN_PERIOD  : time := 10 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i     : std_logic := '1';
  signal ccd_din_i : std_logic := '0';
  -- Observed signals - signals mapped to the output ports of tested entity
  signal ccd_din_o : std_logic;

begin
  clk_i <= not clk_i after C_CLK_IN_PERIOD/2;

  -- Unit Under Test port map
  inst_uut : entity lm_util_lib.lm_util_ccd_resync
    generic map(
      g_meta_levels => g_meta_levels
    )
    port map
    (
      clk_i     => clk_i,
      ccd_din_i => ccd_din_i,
      ccd_din_o => ccd_din_o
    );

  proc_stim_out : process
  begin
    ccd_din_i <= '0';
    wait for 98 ns;
    ccd_din_i <= '1';
    wait;
  end process proc_stim_out;


end behav;
