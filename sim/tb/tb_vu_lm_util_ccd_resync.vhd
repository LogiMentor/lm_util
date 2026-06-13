-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_ccd_resync
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_ccd_resync
--
--              This testbench verifies the functionality of the
--              lm_util_ccd_resync module, which is responsible for
--              synchronizing the input data across multiple clock domains.
--              The testbench applies asynchronous input signal
--              and wait for output signal.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_ccd_resync is
  generic (
    g_meta_levels : integer := C_META_DELAY_LEN;

    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_ccd_resync;

architecture a_tb of tb_vu_lm_util_ccd_resync is
  constant C_CLK_IN_PERIOD : time := 10 ns;
  constant C_T0            : time := 98 ns;
  constant C_T1            : time := 118 ns;
  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i     : std_logic := '1';
  signal ccd_din_i : std_logic := '0';
  -- Observed signals - signals mapped to the output ports of tested entity
  signal ccd_din_o : std_logic;

begin
  clk_i <= not clk_i after C_CLK_IN_PERIOD/2;

  -- Unit Under Test port map
  inst_dut : entity lm_util_lib.lm_util_ccd_resync
    generic map(
      g_meta_levels => g_meta_levels
    )
    port map
    (
      clk_i     => clk_i,
      ccd_din_i => ccd_din_i,
      ccd_din_o => ccd_din_o
    );

  main : process

  begin
    test_runner_setup(runner, runner_cfg);
    if run("check") then
      -- Apply assynchronous input signal
      ccd_din_i <= '0', '1' after C_T0, '0' after C_T1;
      wait for C_T0; -- ccd_i -> '1'
      -- wait for g_meta_levels clock cycles to allow the signal to propagate through the meta-stability registers
      p_wait_clk(clk_i, g_meta_levels);
      wait for 1 ps;
      check(ccd_din_o = '1', "CCD output should be 1");

      wait for C_T1;  -- ccd_i -> '0'
      p_wait_clk(clk_i, g_meta_levels);
      wait for 1 ps;
      check(ccd_din_o = '0', "CCD output should be 0");
    end if;
    test_runner_cleanup(runner);
  end process;

end tb_architecture;
