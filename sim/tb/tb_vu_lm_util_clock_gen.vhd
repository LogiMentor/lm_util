-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_clock_gen
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_clock_gen
--
--              Testbench verifies the clock generation functionality:
--              - clock phase
--              - clock duty cycle
--              - reset functionality
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_clock_gen is
  generic (
    -- input clock frequency divider
    g_clock_div : integer := 10;
    -- output clock phase
    g_clock_phase : integer := 0;
    -- positive output clock cycles
    g_pos_duty_cycle : integer := 5;

    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_clock_gen;

architecture a_tb of tb_vu_lm_util_clock_gen is
  constant C_CLK_IN_PERIOD : time := 10 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i   : std_logic := '1'; -- input clock
  signal rst_n_i : std_logic := '0'; -- input reset
  -- Observed signals - signals mapped to the output ports of tested entity
  signal clk_o : std_logic := '0'; -- output pulse

begin
  -- Clock generation
  clk_i <= not clk_i after C_CLK_IN_PERIOD / 2;

  -- Unit Under Test port map
  inst_dut : entity lm_util_lib.lm_util_clock_gen
    generic map(
      g_clock_div      => g_clock_div,
      g_clock_phase    => g_clock_phase,
      g_pos_duty_cycle => g_pos_duty_cycle
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      clk_o   => clk_o
    );

  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    if run("check") then
      -- reset all input signals
      rst_n_i <= '0';
      wait for C_CLK_IN_PERIOD * (g_clock_div - 1);
      rst_n_i <= '1';

      p_wait_clk(clk_i);
      if g_clock_phase > 0 then
        wait for 1 ps;
        -- Test reset functionality
        p_check_held_for(clk_o, '0', C_CLK_IN_PERIOD * g_clock_phase - 1 ps, "clk_o should be low after reset");
      end if;
      for i in 0 to 2 loop
        wait for 1 ps;
        -- Test clock phase
        p_check_held_for(clk_o, '1', C_CLK_IN_PERIOD * g_pos_duty_cycle - 1 ps, "clk_o should be high for g_pos_duty_cycle=" & integer'image(g_pos_duty_cycle) & " cycles [" & to_string(i) & "]");
        wait for 1 ps;
        -- Test clock duty cycle
        p_check_held_for(clk_o, '0', C_CLK_IN_PERIOD * (g_clock_div - g_pos_duty_cycle) - 1 ps, "clk_o should be low for the rest of the period [" & to_string(i) & "]");
      end loop;
    end if;
    test_runner_cleanup(runner);
  end process;

end a_tb;
