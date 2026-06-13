-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_pulse_stretch
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_pulse_stretch
--
--              This testbench verifies the pulse stretching functionality of the
--              lm_util_pulse_stretch module. It tests the stretching of input pulses
--              to ensure correct behavior of pulse_o across various input patterns:
--              - Single pulse input
--              - Two consecutive pulses
--              - Long pulse input
--              - Handling of fixed and variable pulse lengths
--              - Resynchronization stage behavior
--              - Output pulse level
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

entity tb_vu_lm_util_pulse_stretch is
  generic (
    g_has_fixed_length : natural   := 1;
    g_pulse_length     : natural   := 5;
    g_has_resync_stage : natural   := 0;
    g_out_level        : natural   := 1;

    runner_cfg : string
  );
end;

architecture a_tb of tb_vu_lm_util_pulse_stretch is

  constant C_CLK_PERIOD     : time    := 10 ns;
  constant C_LONG_PULSE_LEN : natural := 10;
  constant C_TIMEOUT        : time    := C_CLK_PERIOD * f_sel_a_b(g_has_resync_stage, 4, 2);
  constant C_OUT_LEVEL      : std_logic := f_int2sl(g_out_level);

  --Stimulus signals
  signal clk_i   : std_logic := '1';
  signal rst_n_i : std_logic := '0';
  signal pulse_i : std_logic := not C_OUT_LEVEL;
  --Observed signal
  signal pulse_o : std_logic;
begin
  -- Clock generation
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  -- UUT instantiation
  inst_dut : entity lm_util_lib.lm_util_pulse_stretch
    generic map(
      g_has_fixed_length => g_has_fixed_length,
      g_pulse_length     => g_pulse_length,
      g_pulse_overlength => g_pulse_length,
      g_has_resync_stage => g_has_resync_stage,
      g_out_level        => C_OUT_LEVEL
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      pulse_i => pulse_i,
      pulse_o => pulse_o
    );

  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    rst_n_i <= '0';
    p_wait_clk(clk_i);
    rst_n_i <= '1';
    p_wait_clk(clk_i);

    if run("single_pulse") then
      -- Check output pulse width for single input pulse
      -- Generate a single pulse
      pulse_i <= C_OUT_LEVEL;
      p_wait_clk(clk_i);
      pulse_i <= not C_OUT_LEVEL;
      --check output pulse width. Must be equal g_pulse_length
      p_check_pulse_width(pulse_o, C_OUT_LEVEL, C_CLK_PERIOD * (g_pulse_length), C_TIMEOUT, "Single pulse check");
    elsif run("two_pulses") then
      -- Check output pulse width for two consecutive input pulses

      -- generate two pulses with a delay
      pulse_i <= C_OUT_LEVEL;
      p_wait_clk(clk_i);
      pulse_i <= not C_OUT_LEVEL, C_OUT_LEVEL after C_CLK_PERIOD, not C_OUT_LEVEL after C_CLK_PERIOD * 2 + 1 ps;
      p_wait_clk(clk_i);

      -- check output pulse width. Must be equal g_pulse_length
      if (g_has_resync_stage /= 0) and (g_has_fixed_length = 0) then
        -- note: is it +2 intended behavior?
        p_check_pulse_width(pulse_o, C_OUT_LEVEL, C_CLK_PERIOD * (g_pulse_length + 2), C_TIMEOUT, "Two pulses check + Resync");
      else
        p_check_pulse_width(pulse_o, C_OUT_LEVEL, C_CLK_PERIOD * g_pulse_length, C_TIMEOUT, "Two pulses check");
      end if;
    elsif run("long_pulse") then
      -- Check output pulse width for long pulse. Output pulse width = input pulse width + g_pulse_overlength
      pulse_i <= C_OUT_LEVEL, not C_OUT_LEVEL after C_CLK_PERIOD * C_LONG_PULSE_LEN + 1 ps; --1 ps to solve weird timing issue
      p_wait_clk(clk_i);

      -- check output pulse width
      if (g_has_fixed_length = 0) then
        -- If not fixed length, check for overlength
          -- Note: pulse is 1 cycle shorter? Is it intended behavior?
        if (g_has_resync_stage /= 0) then
          -- pulse length is
          p_check_pulse_width(pulse_o, C_OUT_LEVEL, C_CLK_PERIOD * (g_pulse_length + C_LONG_PULSE_LEN - 1), C_TIMEOUT, "Long pulse check + Overlength");
        else
          p_check_pulse_width(pulse_o, C_OUT_LEVEL, C_CLK_PERIOD * (g_pulse_length + C_LONG_PULSE_LEN - 1), C_TIMEOUT, "Long pulse check + Overlength + no resync");
        end if;
      else
        p_check_pulse_width(pulse_o, C_OUT_LEVEL, C_CLK_PERIOD * g_pulse_length, C_TIMEOUT, "Long pulse check");
      end if;
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
