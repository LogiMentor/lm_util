-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_counter
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_counter
--              Testbench verifies the counter functionality:
--              - watchdog mode
--              - counter mode
--              - upcounter mode
--              - todo: downcounter mode (see issue #10)
--              - todo: load value
--              - reset functionality
--
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_counter is
  generic (
    g_data_w   : integer := 16; -- counter data width
    g_wd_timer : integer := 30; -- watchdog timer value:
    g_dir      : integer := 1; -- counter direction, 1: up, 0 : down

    g_load_dat : integer := 5; -- data to be loaded;

    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_counter;

architecture a_tb of tb_vu_lm_util_counter is
  -- Constants
  constant C_CLK_PERIOD : time := 10 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i      : std_logic := '1'; -- input clock
  signal rst_n_i    : std_logic := '0'; -- input reset
  signal ce_i       : std_logic := '0'; -- clock enable
  signal load_i     : std_logic := '0'; -- active high strobe for counter loading
  signal load_dat_i : std_logic_vector(g_data_w - 1 downto 0);-- data to be loaded
  -- output counter

  -- Observed signals - signals mapped to the output ports of tested entity
  signal cnt_o   : std_logic_vector(g_data_w - 1 downto 0); -- output counter
  signal timer_o : std_logic;
  -- timer output
begin
  -- Unit Under Test port map
  inst_dut : entity lm_util_lib.lm_util_counter
    generic map(
      g_data_w   => g_data_w,
      g_wd_timer => g_wd_timer,
      g_dir      => g_dir
    )

    port map
    (
      clk_i      => clk_i,
      rst_n_i    => rst_n_i,
      ce_i       => ce_i,
      load_i     => load_i,
      load_dat_i => load_dat_i,
      cnt_o      => cnt_o,
      timer_o    => timer_o
    );

  -- Clock generation
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    if run("counter") then
      -- reset the counter
      rst_n_i <= '0';
      p_wait_clk(clk_i);
      -- deassert reset
      rst_n_i <= '1';
      p_wait_clk(clk_i);
      wait for 1 ps;
      check_equal(f_slv2int(cnt_o), 0, "Counter output should be 0 after reset");
      check_equal(timer_o, '0', "Timer output should be 0 after reset");
      -- enable clock
      ce_i <= '1';
      wait for 1 ps;
      check_equal(f_slv2int(cnt_o), 0, "Counter output should be 0 after ce");
      check_equal(timer_o, '0', "Timer output should be 0 after ce");
      p_wait_clk(clk_i, g_wd_timer-1);
      wait for 1 ps;
      check_equal(f_slv2nat(cnt_o), g_wd_timer - 1, "Counter output should be equal to g_wd_timer=" & to_string(g_wd_timer - 1) & " after g_wd_timer=" & to_string(g_wd_timer-1) & " clocks");
      p_wait_clk(clk_i);
    elsif run("watchdog") then
      -- reset the counter
      rst_n_i <= '0';
      p_wait_clk(clk_i);
      -- deassert reset
      rst_n_i <= '1';
      p_wait_clk(clk_i);
      -- enable clock
      ce_i <= '1';
      wait for 1 ps;

      p_check_held_for(timer_o, '0', g_wd_timer * C_CLK_PERIOD - 1 ps, "Timer output should be 0 after reset for g_wd_timer=" & to_string(g_wd_timer));

      p_wait_clk(clk_i);
      check_equal(timer_o, '1', "timer_p should ho high after g_wd_timer=" & to_string(g_wd_timer));

      -- load the counter with a value
      --load_i     <= '1';
      --load_dat_i <= f_int2slv(g_load_dat, g_data_w);

    elsif run("load") then
      -- reset the counter
      rst_n_i <= '0';
      p_wait_clk(clk_i);
      -- deassert reset
      rst_n_i <= '1';
      p_wait_clk(clk_i);
      -- enable clock
      ce_i <= '1';
      wait for 1 ps;

      p_check_held_for(timer_o, '0', g_wd_timer * C_CLK_PERIOD - 1 ps, "Timer output should be 0 after reset for g_wd_timer=" & to_string(g_wd_timer));

      p_wait_clk(clk_i);
      check_equal(timer_o, '1', "timer_p should ho high after g_wd_timer=" & to_string(g_wd_timer));

      -- load the counter with a value
      --load_i     <= '1';
      --load_dat_i <= f_int2slv(g_load_dat, g_data_w);

    end if;

    -- load the counter with a value
    --load_i     <= '1';
    --load_dat_i <= f_int2slv(g_load_dat, g_data_w);

    test_runner_cleanup(runner);
  end process;

end tb_architecture;
