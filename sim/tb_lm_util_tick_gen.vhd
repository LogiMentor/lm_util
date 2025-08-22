library ieee;
use ieee.NUMERIC_STD.all;
use ieee.std_logic_1164.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

use std.textio.all;

entity tb_lm_util_tick_gen is
  -- Generic declarations of the tested unit
  generic (
    g_clock_div : natural := 10
  );
end tb_lm_util_tick_gen;

architecture tb_arch of tb_lm_util_tick_gen is

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  constant C_CKL_PERIOD : time := 10 ns;
  signal clk_i          : std_logic := '1';
  signal rst_n_i        : std_logic:= '0';
  -- Observed signals - signals mapped to the output ports of tested entity
  signal pulse_o : std_logic;
  signal s_cnt   : natural := 0;

begin
  -- Clock generation
  clk_i <= not clk_i after C_CKL_PERIOD / 2;

  -- Unit Under Test port map
  inst_uut : entity lm_util_lib.lm_util_tick_gen
    generic map(
      g_clock_div => g_clock_div
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      pulse_o => pulse_o
    );

  process
  begin
    -- Hold reset for a few cycles
    rst_n_i <= '0';
    wait for 3 * C_CKL_PERIOD;
    rst_n_i <= '1';

    -- Wait and observe pulses
    wait for g_clock_div * C_CKL_PERIOD;

    assert pulse_o = '0' report "pulse_o should be low." severity failure;
    wait for 1 ps;
    assert pulse_o = '1' report "pulse_o should be high." severity failure;
    wait for g_clock_div * C_CKL_PERIOD;
    assert pulse_o = '0' report "pulse_o should be low again." severity failure;

    -- Finish simulation
    report "Test finished." severity note;
    wait;
  end process;
end tb_arch;
