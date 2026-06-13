-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_bitsum
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_bitsum
--              Checks bitsum functionality for various input data widths
--              and chunk sizes.
--              Bit sum is calculated as the number of '1's in the input data.
--              Tests include:
--              - All zeros input data
--              - All ones input data
--              - Arbitrary input data using f_count_ones() function (see run.py)
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_bitsum is
  generic (
    -- Input data width
    g_din_w                 : natural := 28;
    -- Number of first stage chunks, used to calculate bitsum
    g_nof_first_stage_chunk : natural := 3;
    -- Input data for the test
    g_d_in : natural := 1024;

    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_bitsum;

architecture a_tb of tb_vu_lm_util_bitsum is
  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i : std_logic := '0';
  signal dv_i  : std_logic;
  signal din_i : std_logic_vector(g_din_w - 1 downto 0);
  -- Observed signals - signals mapped to the output ports of tested entity
  signal dv_o     : std_logic;
  signal bitsum_o : std_logic_vector(f_ceil_log2(g_din_w) - 1 downto 0);
begin

  -- Clock generation
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  -- Unit under test instantiation
  inst_dut : entity lm_util_lib.lm_util_bitsum
    generic map(
      g_din_w                 => g_din_w,
      g_nof_first_stage_chunk => g_nof_first_stage_chunk
    )
    port map
    (
      clk_i    => clk_i,
      dv_i     => dv_i,
      din_i    => din_i,
      dv_o     => dv_o,
      bitsum_o => bitsum_o
    );

  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("check_sequence") then
      -- Test with all zeros and all ones input data
      dv_i <= '0';
      -- wait
      p_wait_clk(clk_i, 2);

      -- Check all zeros
      din_i <= (others => '0');
      dv_i  <= '1';
      p_wait_clk(clk_i);
      dv_i <= '0';
      p_wait_signal(clk_i, dv_o, '1', C_CLK_PERIOD * g_din_w, "No dv_o signal (zeros)");
      wait for 1 ps;
      -- check zeros
      check_equal(unsigned(bitsum_o), 0, "Invalid output for zeros input");

      -- Check all ones
      din_i <= (others => '1');
      dv_i  <= '1';
      p_wait_clk(clk_i);
      dv_i <= '0';
      p_wait_signal(clk_i, dv_o, '1', C_CLK_PERIOD * g_din_w, "No dv_o signal (ones)");
      wait for 1 ps;
      -- check ones
      check_equal(unsigned(bitsum_o), g_din_w, "Invalid output for ones input");
    elsif run("check_sum") then
      -- Test against arbitrary input data using f_count_ones()

      -- initialize signals
      dv_i <= '0';
      p_wait_clk(clk_i, 2);

      -- Apply input data
      din_i <= std_logic_vector(to_unsigned(g_d_in, g_din_w));
      dv_i  <= '1';
      p_wait_clk(clk_i);
      dv_i <= '0';

      -- Wait for dv_o signal
      p_wait_signal(clk_i, dv_o, '1', C_CLK_PERIOD * g_din_w, "No dv_o signal");
      wait for 1 ps;

      -- Check output data for correctness using f_count_ones()
      check_equal(bitsum_o, f_count_ones(din_i), "Invalid bit sum");
    end if;
    test_runner_cleanup(runner);
  end process;

end tb_architecture;
