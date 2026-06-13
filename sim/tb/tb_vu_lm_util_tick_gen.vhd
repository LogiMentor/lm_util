-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_tick_gen
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_tick_gen
--
--              This testbench verifies the tick generation functionality of the
--              lm_util_tick_gen module. It tests the generation of tick pulses
--              at the specified clock division ratio.
--              The testbench checks:
--              - Correct generation of tick pulses based on the clock division

--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_tick_gen is
  generic (
    g_clock_div : natural := 10;

    runner_cfg : string
  );
end;

architecture tb of tb_vu_lm_util_tick_gen is

  constant C_CLK_PERIOD : time    := 10 ns;
  constant C_ITERATIONS : integer := 10;

  --Stimulus signals
  signal clk_i   : std_logic := '0';
  signal rst_n_i : std_logic;
  --Observed signal
  signal pulse_o : std_logic;
begin

  -- Clock generation
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  -- Unit under test
  dut : entity lm_util_lib.lm_util_tick_gen
    generic map(
      g_clock_div => g_clock_div
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      pulse_o => pulse_o
    );

  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    rst_n_i <= '0';
    p_wait_clk(clk_i, 3);
    rst_n_i <= '1';

    --p_wait_clk(clk_i, 3);

    for i in 1 to g_clock_div * C_ITERATIONS loop
      p_wait_clk(clk_i);
      wait for 1 ps;
      if i mod g_clock_div = 0 then
        check_equal(pulse_o, '1', "Pulse should be '1'");
      else
        check_equal(pulse_o, '0', "Pulse should be '0'");
      end if;
    end loop;

    test_runner_cleanup(runner);
  end process;

end architecture;
