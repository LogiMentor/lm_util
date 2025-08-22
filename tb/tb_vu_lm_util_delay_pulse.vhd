--=============================================================================
-- Module Name : tb_vu_lm_util_delay_pulse
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_delay_pulse
--
--              The testbench verifies the generation of a delayed pulse
--              signal based on the specified delay and pulse width.
--              The testbench checks the output signal against expected timing
--              characteristics to ensure correct functionality.
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
entity tb_vu_lm_util_delay_pulse is
  generic (
    g_delay       : natural   := 2; --* actual delay can be different from a power of 2
    g_pulse_level : std_logic := '1'; --* input pulse active level, used only in "pulse" mode
    g_pulse_width : positive  := 1; --* pulse width in clks
    runner_cfg    : string
  );
end;

architecture tb of tb_vu_lm_util_delay_pulse is

  constant C_CLK_PERIOD : time := 10 ns;

  --Stimulus signals
  signal clk_i   : std_logic := '1';
  signal rst_n_i : std_logic := '0';
  signal ce_i    : std_logic := '1';
  signal din_i   : std_logic; --* input data, pulse
  --Observed signal
  signal dout_o : std_logic; --* output delayed data

begin
  --assert g_delay - g_pulse_width >= 0 report "Delay must be greater than or equal to pulse width" severity ERROR;

  -- Clock generation
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  -- Unit under test
  uut : entity lm_util_lib.lm_util_delay_pulse
    generic map(
      g_delay       => g_delay,
      g_pulse_level => g_pulse_level
    )
    port map
    (
      clk_i   => clk_i,
      ce_i    => ce_i,
      rst_n_i => rst_n_i,
      din_i   => din_i,
      dout_o  => dout_o
    );
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("pulse") then
      rst_n_i <= '0';
      din_i   <= not g_pulse_level;
      wait for 100 ns;
      wait until rising_edge(clk_i);
      rst_n_i <= '1';

      din_i <= not g_pulse_level;
      wait until rising_edge(clk_i);

      if g_delay = 0 then
        din_i <= g_pulse_level;
        wait for 1 ps;
        check_equal(dout_o, g_pulse_level, "Mismatch output for delay = 0");
      elsif g_delay = 1 then
        din_i <= g_pulse_level;
        wait for 1 ps;
        check_equal(dout_o, not g_pulse_level, "Mismatch immediate output for delay = 1");
        p_wait_clk(clk_i);
        wait for 1 ps;
        check_equal(dout_o, g_pulse_level, "Mismatch output for delay = 1");
      else
        --g_delay>1
        din_i <= g_pulse_level;
        p_wait_clk(clk_i, g_pulse_width);
        din_i <= not g_pulse_level;
        p_wait_clk(clk_i, g_delay - g_pulse_width);
        -- Check immediate output
        check_equal(dout_o, not g_pulse_level, "Mismatch immediate output for delay = " & integer'image(g_delay));
        wait for 1 ps;
        check_equal(dout_o, g_pulse_level, "Mismatch output for delay = " & integer'image(g_delay));
      end if;
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
