-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_edge_detector
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_edge_detector
--
--              This testbench verifies both rising and falling edge detection
--              based on the specified event edge.
--              The testbench checks the output signal against expected
--              timing characteristics to ensure correct functionality.

--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_edge_detector is
  generic (
    g_event_edge : integer := C_RISING_EDGE;
    runner_cfg   : string
  );
end tb_vu_lm_util_edge_detector;

architecture tb of tb_vu_lm_util_edge_detector is

  constant C_CLK_PERIOD : time := 10 ns;

  signal clk_i  : std_logic := '0';
  signal din_i  : std_logic := '0';
  signal dout_o : std_logic;

begin
  -- Clock generator
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  -- Unit under test
  uut_rising : entity lm_util_lib.lm_util_edge_detector
    generic map(
      g_event_edge => g_event_edge
    )
    port map
    (
      clk_i  => clk_i,
      din_i  => din_i,
      dout_o => dout_o
    );

  -- Test runner process
  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    -- Rising edge detection
    if run("rising_edge_detect") then
      -- no edge yet
      din_i <= '0';
      p_check_held_for(dout_o, '0', C_CLK_PERIOD*2, "No edge yet");

      -- generate rising edge
      p_wait_clk(clk_i);
      din_i <= '1';
      p_wait_clk(clk_i);
      wait for 1 ps;
      check_equal(dout_o, '1', "Rising edge should be detected");
      -- stay high
      p_wait_clk(clk_i);
      wait for 1 ps;
      p_check_held_for(dout_o, '0', C_CLK_PERIOD*2, "No new edge");
    end if;

    -------------------------------------------------------------------
    -- Test: Detect Falling Edge
    -------------------------------------------------------------------
    if run("falling_edge_detect") then
      -- Start from high
      din_i <= '1';
      p_wait_clk(clk_i, 2);
      p_check_held_for(dout_o, '0', C_CLK_PERIOD*2, "No edge yet");

      -- generate falling edge
      p_wait_clk(clk_i);
      din_i <= '0';
      p_wait_clk(clk_i);
      wait for 1 ps;
      check_equal(dout_o, '1', "Falling edge should be detected");

      -- stay low
      p_wait_clk(clk_i);
      wait for 1 ps;
      p_check_held_for(dout_o, '0', C_CLK_PERIOD*2, "No new edge");

    end if;

    test_runner_cleanup(runner);
  end process;

end tb;
