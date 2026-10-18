-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_pkg
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_pkg functions
--
--              - f_string_format: large values up to the integer range,
--                carry of the rounded fraction, negative values, precision 0
--              The range guards of f_string_format stop elaboration; they are
--              checked by sim/scripts/check_elab_failures.py.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

entity tb_vu_lm_util_pkg is
  generic (
    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_pkg;

architecture a_tb of tb_vu_lm_util_pkg is
begin

  proc_main : process
    procedure p_check_format(C_VALUE : real; C_PRECISION : natural; C_EXPECTED : string) is
    begin
      check_equal(f_string_format(C_VALUE, C_PRECISION), C_EXPECTED,
        "f_string_format(" & real'image(C_VALUE) & ", " & integer'image(C_PRECISION) & ")");
    end procedure;
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("string_format_large") then
        p_check_format(3000000.0, 3, "3000000.000");
        p_check_format(123456789.125, 3, "123456789.125");
        p_check_format(1000000.5, 6, "1000000.500000");
        -- limits of the integer part
        p_check_format(2147483647.0, 3, "2147483647.000");
        p_check_format(2147483647.25, 2, "2147483647.25");
        p_check_format(2147483647.4, 3, "2147483647.400");
        p_check_format(-2147483647.0, 3, "-2147483647.000");

      elsif run("string_format_carry") then
        p_check_format(0.9995, 3, "1.000");
        p_check_format(9.9999, 2, "10.00");
        p_check_format(0.99996, 4, "1.0000");
        p_check_format(999.9996, 3, "1000.000");
        p_check_format(0.96, 1, "1.0");
        p_check_format(2147483646.9996, 3, "2147483647.000");

      elsif run("string_format_sign") then
        p_check_format(0.0, 3, "0.000");
        p_check_format(0.05, 3, "0.050");
        p_check_format(1.5, 3, "1.500");
        p_check_format(-1.5, 3, "-1.500");
        p_check_format(-0.25, 2, "-0.25");
        p_check_format(-1.9996, 3, "-2.000");
        p_check_format(-3000000.0, 3, "-3000000.000");

      elsif run("string_format_precision0") then
        -- no fraction digits: no decimal point, half rounds away from zero
        p_check_format(0.4, 0, "0");
        p_check_format(2.4, 0, "2");
        p_check_format(2.5, 0, "3");
        p_check_format(2.7, 0, "3");
        p_check_format(-2.5, 0, "-3");
        p_check_format(3000000.0, 0, "3000000");
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;

end a_tb;
