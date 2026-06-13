-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_delay_srl
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_delay_srl
--
--              The testbench verifies the generation of a delayed pulse
--              signal based on the specified delay and pulse width.
--              The testbench checks the output signal against expected timing
--              characteristics to ensure correct functionality.

--               This testbench verifies the srl-based delay module
--               across multiple delay and data width configurations,
--               ensuring correct timing and data propagation
--               for a variety of input sequences and edge cases.
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
entity tb_vu_lm_util_delay_srl is
  generic (
    g_delay    : natural := 2; -- actual delay can be different from a power of 2
    g_data_w   : natural := 32; -- input data width
    g_srl_depth : natural := 5; -- Shift register depth for the target platform
    runner_cfg : string
  );
end;

architecture a_tb of tb_vu_lm_util_delay_srl is

  constant C_CLK_PERIOD : time := 10 ns;

  --Stimulus signals
  signal clk_i   : std_logic := '0';
  signal rst_n_i : std_logic := '0';
  signal ce_i    : std_logic := '1';
  signal din_i   : std_logic_vector(g_data_w - 1 downto 0);
  --Observed signal
  signal dout_o : std_logic_vector(g_data_w - 1 downto 0); -- output delayed data

begin

  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  -- Unit under test
  inst_dut : entity lm_util_lib.lm_util_delay_srl
    generic map(
      g_delay  => g_delay,
      g_data_w => g_data_w,
      g_srl_depth => g_srl_depth
    )
    port map
    (
      clk_i => clk_i,
      ce_i  => ce_i,
      --st_n_i => rst_n_i,
      din_i  => din_i,
      dout_o => dout_o
    );

  proc_test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("sequence") then
      -- Feed known sequence
      din_i <= (others => '0');
      wait until rising_edge(clk_i);

      if g_delay = 0 then
        din_i <= f_int2slv(1, g_data_w);
        wait for 1 ps;
        check_equal(dout_o, f_int2slv(1, g_data_w), "Mismatch output for delay = 0");
      elsif g_delay = 1 then
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
    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
