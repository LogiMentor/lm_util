-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_ccd_switch
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_ccd_switch
--
--              Verifies that the output goes high when switch_high_i='1' and
--              goes low when switch_low_i='1'.
--
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_ccd_switch is
  generic (
    g_priority_lo : boolean := false;
    g_or_high     : boolean := false;
    g_and_low     : boolean := false;

    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_ccd_switch;

architecture tb_architecture of tb_vu_lm_util_ccd_switch is
  constant C_CLK_IN_PERIOD : time := 10 ns;
  constant C_T0            : time := 100 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i         : std_logic := '1';
  signal rst_n_i       : std_logic := '0';
  signal switch_high_i : std_logic := '0';
  signal switch_low_i  : std_logic := '0';

  -- Observed signals - signals mapped to the output ports of tested entity
  signal out_level_o : std_logic := '0';

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

  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    --todo: divide into separate test cases:
    if run("check") then
      -- reset all input signals
      rst_n_i       <= '0';
      switch_high_i <= '0';
      switch_low_i  <= '0';
      wait for C_T0;
      wait until clk_i;
      -- Deassert reset signal
      rst_n_i <= '1';
      wait until clk_i;
      wait for 1 ps;
      check_equal(out_level_o, '0', "ccd_switch output should be 0");

      -- Test switch_high_i stimulus reaction
      switch_low_i  <= '0';
      switch_high_i <= '1';
      wait for 1 ps;
      if (g_or_high) then
        check_equal(out_level_o, '1', "ccd_switch output should become 1 immediately");
      else
        check_equal(out_level_o, '0', "ccd_switch output should stay 0 until clk");
      end if;
      wait until clk_i;
      wait for 1 ps;
      check_equal(out_level_o, '1', "ccd_switch output should be 1 after clk with switch_high_i");
      
      -- Test switch_low_i stimulus reaction
      switch_low_i  <= '1';
      switch_high_i <= '0';
      wait for 1 ps;
      if (g_and_low) then
        check_equal(out_level_o, '0', "ccd_switch output should become 0 immediately");
      else
        check_equal(out_level_o, '1', "ccd_switch output should stay 1 until clk");
      end if;
      wait until clk_i;
      wait for 1 ps;
      check_equal(out_level_o, '0', "ccd_switch output should become 0 after clk with switch_low_i");

      -- Test switch_low_i+switch_high_i stimulus reaction after 0
      switch_low_i  <= '1';
      switch_high_i <= '1';
      wait for 1 ps;

      if ((not g_and_low and g_or_high) or (g_and_low and g_or_high and not g_priority_lo)) then
        check_equal(out_level_o, '1', "ccd_switch output should become 1 immediately (low+high after 0)");
      else
        check_equal(out_level_o, '0', "ccd_switch output should stay 0 until clk (low+high after 0)");
      end if;

      wait until clk_i;
      wait for 1 ps;
      if (g_and_low and g_or_high) or (not g_and_low and not g_or_high) then
        if (g_priority_lo) then
          check_equal(out_level_o, '0', "ccd_switch output should become 0 after clk (low+high after 0)");
        else
          check_equal(out_level_o, '1', "ccd_switch output should became 1 after clk (low+high after 0)");
        end if;
      end if;

      -- Test switch_low_i+switch_high_i stimulus reaction after 1
      -- set out_level_o to 1
      switch_low_i  <= '0';
      switch_high_i <= '1';
      wait until clk_i;

      switch_low_i  <= '1';
      switch_high_i <= '1';
      wait for 1 ps;

      if ((g_and_low and not g_or_high) or (g_and_low and g_or_high and g_priority_lo)) then
        check_equal(out_level_o, '0', "ccd_switch output should become 0 immediately (low+high after 1)");
      else
        check_equal(out_level_o, '1', "ccd_switch output should stay 1 until clk (low+high after 1)");
      end if;

      wait until clk_i;
      wait for 1 ps;
      if (g_and_low and g_or_high) or (not g_and_low and not g_or_high) then
        if (g_priority_lo) then
          check_equal(out_level_o, '0', "ccd_switch output should become 0 after cll (low+high after 1)");
        else
          check_equal(out_level_o, '1', "ccd_switch output should became 1 after clk (low+high after 1)");
        end if;
      end if;

    end if;
    test_runner_cleanup(runner);
  end process;

end tb_architecture;
