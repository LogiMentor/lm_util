-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_delay_var
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_delay_var
--
--              Verifies the variable delay functionality of the
--              lm_util_delay_var module. It tests the behavior of the
--              variable delay element with different delay settings.
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
entity tb_vu_lm_util_delay_var is
  generic (
    g_delay_max   : positive  := 8; -- max delay
    g_delay       : positive  := 8; -- delay
    g_data_w      : natural   := 8; -- input data width
    g_arch_type   : natural   := C_LM_SRL; -- architecture used
    g_pulse_level : natural   := 1; -- pulse active level (0 or 1)
    runner_cfg    : string
  );
end;

architecture a_tb of tb_vu_lm_util_delay_var is

  constant C_CLK_PERIOD : time     := 10 ns;
  constant C_DELAY_W    : positive := f_ceil_log2(g_delay_max + 1);
  constant C_PULSE_LVL  : std_logic := f_int2sl(g_pulse_level);
  --Stimulus signals
  signal clk_i   : std_logic                                := '1';
  signal rst_n_i : std_logic                                := '0';
  signal dv_i    : std_logic                                := '1';
  signal delay_i : std_logic_vector(C_DELAY_W - 1 downto 0) := f_nat2slv(g_delay, C_DELAY_W);
  signal din_i   : std_logic_vector(g_data_w - 1 downto 0);
  --Observed signal
  signal dout_o : std_logic_vector(g_data_w - 1 downto 0); -- output delayed data
  signal dv_o   : std_logic;

begin

  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  -- Unit under test
  inst_dut : entity lm_util_lib.lm_util_delay_var
    generic map(
      g_delay_max   => g_delay_max,
      g_data_w      => g_data_w,
      g_arch_type   => g_arch_type,
      g_pulse_level => g_pulse_level
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      dv_i    => dv_i,
      delay_i => delay_i,
      din_i   => din_i,
      dv_o    => dv_o,
      dout_o  => dout_o
    );

  proc_test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("sequence") then
      rst_n_i <= '0';
      dv_i    <= '0';
      wait until rising_edge(clk_i);
      rst_n_i <= '1';
      wait until rising_edge(clk_i);
      dv_i <= '1';

      din_i <= (others => '0');
      wait until rising_edge(clk_i);

      if g_delay = 1 then
        din_i <= f_int2slv(1, g_data_w);
        wait for 1 ps;
        check_equal(dout_o, f_int2slv(0, g_data_w), "Mismatch immediate output for delay = 1");
        wait until rising_edge(clk_i);
        wait for 1 ps;
        check_equal(dout_o, f_int2slv(1, g_data_w), "Mismatch output for delay = 1");
        check_equal(dv_o, '1', "dv_o not asserted for delay = 1");
      else
        --g_delay>1
        for i in 1 to g_delay loop
          din_i <= f_int2slv(i, g_data_w);
          wait until rising_edge(clk_i);
        end loop;

        -- Check delayed output (for valid g_delay range)
        for i in 0 to g_delay loop
          check_equal(dout_o, f_int2slv(i, g_data_w), "Mismatch at output for delay = " & integer'image(i));
          check_equal(dv_o, '1', "dv_o not asserted at output for delay = " & integer'image(i));
          wait until rising_edge(clk_i);
        end loop;
      end if;
    elsif run("pulse") then
      rst_n_i <= '0';
      din_i   <= f_sl2slv(not C_PULSE_LVL);
      wait for 100 ns;
      p_wait_clk(clk_i);
      -- reset drives the inactive level of the configured polarity
      wait for 1 ps;
      check_equal(dout_o, f_sl2slv(not C_PULSE_LVL), "Output not at the inactive level during reset");
      check_equal(dv_o, '0', "dv_o asserted during reset");
      rst_n_i <= '1';
      p_wait_clk(clk_i);

      din_i <= f_sl2slv(C_PULSE_LVL);
      p_wait_clk(clk_i);
      din_i <= f_sl2slv(not C_PULSE_LVL);
      p_wait_clk(clk_i, g_delay - 1);
      -- Check immediate output
      check_equal(dout_o, f_sl2slv(not C_PULSE_LVL), "Mismatch immediate output for delay = " & integer'image(g_delay));
      wait for 1 ps;
      check_equal(dout_o, f_sl2slv(C_PULSE_LVL), "Mismatch output for delay = " & integer'image(g_delay));
      check_equal(dv_o, '1', "dv_o should pulse with the delayed output");

      -- the output pulse and dv_o are one cycle wide
      p_wait_clk(clk_i);
      wait for 1 ps;
      check_equal(dout_o, f_sl2slv(not C_PULSE_LVL), "Output pulse should be one cycle wide for delay = " & integer'image(g_delay));
      check_equal(dv_o, '0', "dv_o should deassert after the delayed pulse");
    elsif run("pulse_long_input") then
      rst_n_i <= '0';
      din_i   <= f_sl2slv(not C_PULSE_LVL);
      wait for 100 ns;
      p_wait_clk(clk_i);
      rst_n_i <= '1';
      p_wait_clk(clk_i);

      -- hold the input active for longer than the delay: only its leading
      -- edge produces an output pulse, one cycle wide
      din_i <= f_sl2slv(C_PULSE_LVL);
      for i in 1 to 2 * g_delay + 4 loop
        if i = g_delay + 2 then
          din_i <= f_sl2slv(not C_PULSE_LVL);
        end if;
        p_wait_clk(clk_i);
        wait for 1 ps;
        if i = g_delay then
          check_equal(dout_o, f_sl2slv(C_PULSE_LVL), "Missing output pulse " & integer'image(g_delay) & " cycles after the leading edge");
          check_equal(dv_o, '1', "dv_o should pulse with the delayed output");
        else
          check_equal(dout_o, f_sl2slv(not C_PULSE_LVL), "Unexpected active output at cycle " & integer'image(i));
          check_equal(dv_o, '0', "Unexpected dv_o at cycle " & integer'image(i));
        end if;
      end loop;
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
