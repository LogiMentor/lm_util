-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_delay_var
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
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
    g_delay_max   : positive  := 8; --* max delay
    g_delay       : positive  := 8; --* delay
    g_data_w      : natural   := 8; --* input data width
    g_arch_type   : natural   := C_CES_SRL; --* architecture used
    g_pulse_level : std_logic := '1';
    runner_cfg    : string
  );
end;

architecture tb of tb_vu_lm_util_delay_var is

  constant C_CLK_PERIOD : time     := 10 ns;
  constant C_DELAY_W    : positive := f_ceil_log2(g_delay_max + 1);
  --Stimulus signals
  signal clk_i   : std_logic                                := '1';
  signal rst_n_i : std_logic                                := '0';
  signal dv_i    : std_logic                                := '1';
  signal delay_i : std_logic_vector(C_DELAY_W - 1 downto 0) := f_nat2slv(g_delay, C_DELAY_W);
  signal din_i   : std_logic_vector(g_data_w - 1 downto 0);
  --Observed signal
  signal dout_o : std_logic_vector(g_data_w - 1 downto 0); --* output delayed data
  signal dv_o   : std_logic;

begin

  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  -- Unit under test
  uut : entity lm_util_lib.lm_util_delay_var
    generic map(
      g_delay_max   => g_delay_max,
      g_data_w      => g_data_w,
      g_arch_type   => g_arch_type,
      g_pulse_level => f_sl2int(g_pulse_level)
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

  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("sequence") then
      rst_n_i <= '0';
      dv_o    <= '0';
      wait until rising_edge(clk_i);
      rst_n_i <= '1';
      wait until rising_edge(clk_i);
      dv_o <= '1';

      din_i <= (others => '0');
      wait until rising_edge(clk_i);

      if g_delay = 1 then
        din_i <= f_int2slv(1, g_data_w);
        wait for 1 ps;
        check_equal(dout_o, f_int2slv(0, g_data_w), "Mismatch immediate output for delay = 1");
        wait until rising_edge(clk_i);
        wait for 1 ps;
        check_equal(dout_o, f_int2slv(1, g_data_w), "Mismatch output for delay = 1");
      else
        --g_delay>1
        for i in 1 to g_delay loop
          din_i <= f_int2slv(i, g_data_w);
          wait until rising_edge(clk_i);
        end loop;

        -- Check delayed output (for valid g_delay range)
        for i in 0 to g_delay loop
          check_equal(dout_o, f_int2slv(i, g_data_w), "Mismatch at output for delay = " & integer'image(i));
          wait until rising_edge(clk_i);
        end loop;
      end if;
    elsif run("pulse") then
      rst_n_i <= '0';
      din_i   <= f_sl2slv(not g_pulse_level);
      wait for 100 ns;
      p_wait_clk(clk_i);
      rst_n_i <= '1';
      p_wait_clk(clk_i);

      din_i <= f_sl2slv(g_pulse_level);
      p_wait_clk(clk_i);
      din_i <= f_sl2slv(not g_pulse_level);
      p_wait_clk(clk_i, g_delay - 1);
      -- Check immediate output
      check_equal(dout_o, f_sl2slv(not g_pulse_level), "Mismatch immediate output for delay = " & integer'image(g_delay));
      wait for 1 ps;
      check_equal(dout_o, f_sl2slv(g_pulse_level), "Mismatch output for delay = " & integer'image(g_delay));
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
