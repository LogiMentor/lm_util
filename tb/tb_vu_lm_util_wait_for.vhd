--=============================================================================
-- Module Name : tb_vu_lm_util_wait_for
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_wait_for
--
--              This testbench verifies the waiting functionality of the
--              tb_vu_lm_pkg module. It tests the ability to wait for
--              specific signal conditions and time durations.
--              The testbench checks no assertions are raised during the wait
--              periods on successful completion.
--              todo:
--                - check for assertion raise during failed wait
--                - add tests for p_check_pulse_width, p_check_held_for, p_wait_clk
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_wait_for is
  generic (
    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_wait_for;

architecture tb_architecture of tb_vu_lm_util_wait_for is
  signal s : std_logic;

begin

  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("reset_pulse_check_waits") then
      -- test held_wait_for procedure
      s <= '0', '1' after 10 ns;
      wait for 0 ns;
      p_check_held_for(s, '0', 10 ns, "Test fail");
    elsif run("p_wait_signal") then
      -- test p_wait_signal
      s <= '0', '1' after 10 ns;
      p_wait_signal(s, '1', 10.001 ns);
    end if;

    test_runner_cleanup(runner);
  end process;

end tb_architecture;
