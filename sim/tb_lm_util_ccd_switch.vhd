library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;

-- Add your library and packages declaration here ...

entity tb_lm_util_ccd_switch is
  -- Generic declarations of the tested unit
  generic (
    g_priority_lo : boolean := false;
    g_or_high     : boolean := false;
    g_and_low     : boolean := false
  );
end tb_lm_util_ccd_switch;

architecture behav of tb_lm_util_ccd_switch is
  constant C_CLK_IN_PERIOD : time := 10 ns;
  constant C_T0            : time := 100 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i         : std_logic := '1';
  signal rst_n_i       : std_logic := '0';
  signal switch_high_i : std_logic := '0';
  signal switch_low_i  : std_logic := '0';

  -- Observed signals - signals mapped to the output ports of tested entity
  signal out_level_o   : std_logic := '0';

begin
  clk_i <= not clk_i after C_CLK_IN_PERIOD/2;

  -- Unit Under Test port map
  uut : entity lm_util_lib.lm_util_ccd_switch
    generic map(
      g_priority_lo => g_priority_lo,
      g_or_high     => g_or_high,
      g_and_low     => g_and_low
    )
    port map
    (
      clk_i         => clk_i,
      rst_n_i       => rst_n_i,
      switch_high_i => switch_high_i,
      switch_low_i  => switch_low_i,
      out_level_o   => out_level_o);

  proc_stim_out : process
  begin
    -- reset all input signals
    rst_n_i       <= '0';
    switch_high_i <= '0';
    switch_low_i  <= '0';
    wait for C_T0;
    wait until clk_i;
    -- Deassert reset signal
    rst_n_i <= '1';
    wait until clk_i;
    wait for 3 ns;
    switch_high_i <= '1';
    wait until clk_i;
    switch_high_i <= '0';
    wait for 3 ns;
    switch_low_i <= '1';
    wait until clk_i;
    switch_high_i <= '1';
    wait until clk_i;
    switch_low_i <= '0';
    switch_high_i <= '0';
    wait;
  end process proc_stim_out;
end behav;
