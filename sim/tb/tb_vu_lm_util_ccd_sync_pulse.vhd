-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_ccd_sync_pulse
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_ccd_sync_pulse
--
--              Test basic pulse propagation across the ccd_sync_pulse
--              module.
--              Testbench verifies:
--                - an input pulse is correctly propagated to the output after
--                  the specified delay.
--                - the busy signal is asserted during pulse propagation.
--                - the busy signal returns low after the pulse is propagated.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_ccd_sync_pulse is
  generic (
    g_delay_len : natural := 2;

    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_ccd_sync_pulse;

architecture tb_architecture of tb_vu_lm_util_ccd_sync_pulse is
  constant C_CLK_IN_PERIOD  : time := 3 ns;
  constant C_CLK_OUT_PERIOD : time := 10 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal in_rst_n_i  : std_logic := '0';
  signal in_clk_i    : std_logic := '1';
  signal in_pulse_i  : std_logic := '0';
  signal out_rst_n_i : std_logic := '0';
  signal out_clk_i   : std_logic := '1';
  signal s_out_clk   : std_logic := '1';
  -- Observed signals - signals mapped to the output ports of tested entity
  signal in_busy_o   : std_logic;
  signal out_pulse_o : std_logic;

begin
  -- Clock generation
  in_clk_i  <= not in_clk_i after C_CLK_IN_PERIOD/2;
  s_out_clk <= not s_out_clk after C_CLK_OUT_PERIOD/2;
  out_clk_i <= s_out_clk after 1.3 ns;

  -- Unit Under Test port map
  uut : entity lm_util_lib.lm_util_ccd_sync_pulse
    generic map(
      g_delay_len => g_delay_len
    )
    port map
    (
      in_rst_n_i  => in_rst_n_i,
      in_clk_i    => in_clk_i,
      in_pulse_i  => in_pulse_i,
      in_busy_o   => in_busy_o,
      out_rst_n_i => out_rst_n_i,
      out_clk_i   => out_clk_i,
      out_ce_i    => '1',
      out_pulse_o => out_pulse_o
    );
  proc_stim_out : process
  begin
    out_rst_n_i <= '0';
    wait until out_clk_i = '1';
    wait for 2 * C_CLK_OUT_PERIOD;
    out_rst_n_i <= '1'; --release the reset after 2 clock cycles
    wait;
  end process proc_stim_out;

  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    if run("check") then
      -- reset all input signals
      in_rst_n_i <= '0';
      in_pulse_i <= '0';
      p_wait_clk(in_clk_i, 2);
      in_rst_n_i <= '1'; --release the reset after 2 clock cycles
      check_equal(in_busy_o, '0', "Busy signal is up after reset.");
      p_wait_clk(in_clk_i, 5);
      info("Send pulse on input domain.");
      in_pulse_i <= '1';
      p_wait_clk(in_clk_i);
      in_pulse_i <= '0';
      wait for 1 ps;
      check_equal(in_busy_o, '1', "Busy signal has not gone up.");
      info("Busy signal has gone up.");
      --
      p_wait_signal(out_pulse_o, '1', C_CLK_IN_PERIOD * (g_delay_len + 1) + C_CLK_OUT_PERIOD * (g_delay_len + 2), "No out_pulse_o detected");
      --wait until out_pulse_o = '1';
      check_equal(in_busy_o, '1', "Busy signal is no longer up.");
      info("Out pulse emitted.");
      p_wait_clk(out_clk_i);
      wait for 1 ps;
      check_equal(out_pulse_o, '0', "Out pulse still high.");
      info("Out pulse passed.");
      check_equal(in_busy_o, '1', "Busy signal is no longer up.");
      --
      p_wait_signal(in_busy_o, '0', C_CLK_IN_PERIOD * g_delay_len + C_CLK_OUT_PERIOD * (g_delay_len + 2), "in_busy_o does not go down");
      info("Busy signal gone down.");
    end if;
    test_runner_cleanup(runner);
  end process;

end tb_architecture;
