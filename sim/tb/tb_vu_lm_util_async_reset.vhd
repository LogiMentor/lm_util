-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_async_reset
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_async_reset
--
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_async_reset is
  generic (
    g_delay_len : integer   := C_META_DELAY_LEN;
    g_rst_lvl   : natural   := 0;

    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_async_reset;

architecture a_tb of tb_vu_lm_util_async_reset is
  constant C_RST_LVL     : std_logic := f_int2sl(g_rst_lvl);
  signal arst_i        : std_logic;
  signal clk_i         : std_logic := '1';
  signal rst_n_o       : std_logic;
  signal s_check_en    : std_logic := '0';
  signal s_check_start : std_logic := '0';
  signal s_check_end   : std_logic := '0';
begin

  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  inst_dut : entity lm_util_lib.lm_util_async_reset
    generic map(
      g_delay_len => g_delay_len,
      g_rst_lvl   => C_RST_LVL
    )
    port map
    (
      arst_i  => arst_i,
      clk_i   => clk_i,
      rst_n_o => rst_n_o
    );

  main : process
    constant C_RST_ACTIVE : std_logic := '0';
    constant C_T0         : time      := 103 ns;
    constant C_SHORT_RST  : time      := 3 ns;
    constant C_LONG_RST   : time      := 19 ns;

  begin
    test_runner_setup(runner, runner_cfg);

    -- here we have several test approaches as an example
    if run("reset_pulse_check_waits") then
      -- using waits
      -- apply asynchronous long reset pulse > C_CLK_PERIOD
      arst_i <= not C_RST_LVL, C_RST_LVL after C_T0, not C_RST_LVL after C_T0 + C_LONG_RST;
      wait for C_T0 + 1 ps;
      check(rst_n_o = C_RST_ACTIVE, "Reset output should be asserted");
      -- wait for the reset input signal to be deasserted
      wait until arst_i = not C_RST_LVL;
      -- wait for the next cycles
      p_wait_clk(clk_i);
      wait for C_CLK_PERIOD * (g_delay_len - 1) - C_T_EPSILON;
      check(rst_n_o = C_RST_ACTIVE, "Reset output should be still asserted");
      p_wait_clk(clk_i);
      wait for C_T_EPSILON;
      check(rst_n_o = not C_RST_ACTIVE, "Reset output should be deasserted");
    elsif run("reset_pulse_check_waitfor") then
      -- using self-written check_held_for() procedure

      -- apply asynchronous short reset pulse < C_CLK_PERIOD
      arst_i <= not C_RST_LVL, C_RST_LVL after C_T0, not C_RST_LVL after C_T0 + C_SHORT_RST;
      wait for C_T0;
      -- Wait for the next clk edge
      p_wait_clk(clk_i);
      p_check_held_for(rst_n_o, C_RST_ACTIVE, C_CLK_PERIOD * (g_delay_len - 1), "Reset pulse to short");
    elsif run("reset_pulse_check_stability") then
      -- using vunit-provided procedure check_stable()  -- see stability_check
      -- https://vunit.github.io/check/user_guide.html#stability-check-check-stable

      -- apply asynchronous short reset pulse < C_CLK_PERIOD
      arst_i <= not C_RST_LVL, C_RST_LVL after C_T0, not C_RST_LVL after C_T0 + C_SHORT_RST;
      wait for C_T0 + C_T_EPSILON;
      check(rst_n_o = C_RST_ACTIVE, "Reset output should be asserted");
      -- stability test
      s_check_en    <= '1';
      s_check_start <= '1';
      wait until rising_edge(clk_i);
      s_check_start <= '0';
      s_check_end   <= '1';
      p_wait_clk(clk_i, g_delay_len - 1);
      s_check_end <= '0';
    end if;

    test_runner_cleanup(runner);
  end process;

  stability_check : check_stable(clk_i, s_check_en, s_check_start, s_check_end, rst_n_o, result("rst_n_o."));

end tb_architecture;
