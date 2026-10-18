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
--              - f_string_format against exact reference vectors
--                (sim/scripts/string_format_vectors.py, written by run.py):
--                every vector is compared and the mismatches are counted
--              - f_is_power_of_two: powers of two up to 2**30, their
--                neighbours, 0 and negative values
--              The range guards of f_string_format stop elaboration; they are
--              checked by sim/scripts/check_elab_failures.py.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

library std;
use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

entity tb_vu_lm_util_pkg is
  generic (
    -- reference vectors of f_string_format and their number
    g_vector_file  : string  := "";
    g_vector_count : natural := 0;

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

    -- one vector per line:
    --   sign high low exponent precision length expected literal
    -- with |value| = (high * 2**26 + low) * 2**exponent, rebuilt exactly;
    -- the decimal literal (rest of the line) is only used in messages
    procedure p_check_vectors is
      constant C_LOG_MAX : natural := 20;
      file f_vectors     : text open read_mode is g_vector_file;
      variable v_line    : line;
      variable v_sign    : integer;
      variable v_high    : integer;
      variable v_low     : integer;
      variable v_exp     : integer;
      variable v_prec    : integer;
      variable v_len     : integer;
      variable v_value   : real;
      variable v_count   : natural := 0;
      variable v_fail    : natural := 0;

      procedure p_compare(C_LEN : natural) is
        variable v_char     : character;
        variable v_expected : string(1 to C_LEN);
      begin
        read(v_line, v_char);
        for i in v_expected'range loop
          read(v_line, v_char);
          v_expected(i) := v_char;
        end loop;
        if f_string_format(v_value, v_prec) /= v_expected then
          v_fail := v_fail + 1;
          if v_fail <= C_LOG_MAX then
            info("mismatch: f_string_format(" & v_line.all & ", " & integer'image(v_prec) & ") = " &
                 f_string_format(v_value, v_prec) & ", expected " & v_expected);
          end if;
        end if;
      end procedure;
    begin
      while not endfile(f_vectors) loop
        readline(f_vectors, v_line);
        read(v_line, v_sign);
        read(v_line, v_high);
        read(v_line, v_low);
        read(v_line, v_exp);
        read(v_line, v_prec);
        read(v_line, v_len);
        v_value := (real(v_high) * 2.0**26 + real(v_low)) * 2.0**v_exp;
        if v_sign = 1 then
          v_value := -v_value;
        end if;
        v_count := v_count + 1;
        p_compare(v_len);
      end loop;
      info("f_string_format reference: " & integer'image(v_count) & " vectors, " &
           integer'image(v_fail) & " mismatches");
      check_equal(v_count, g_vector_count, "vectors read from " & g_vector_file);
      check_equal(v_fail, 0, "f_string_format mismatches");
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

      elsif run("is_power_of_two") then
        for i in 0 to 30 loop
          check(f_is_power_of_two(2**i), "f_is_power_of_two(2**" & integer'image(i) & ")");
          if i >= 2 then
            check_false(f_is_power_of_two(2**i - 1), "f_is_power_of_two(2**" & integer'image(i) & " - 1)");
            check_false(f_is_power_of_two(2**i + 1), "f_is_power_of_two(2**" & integer'image(i) & " + 1)");
          end if;
        end loop;
        check_false(f_is_power_of_two(6), "f_is_power_of_two(6)");
        check_false(f_is_power_of_two(integer'high), "f_is_power_of_two(integer'high)");
        check_false(f_is_power_of_two(0), "f_is_power_of_two(0)");
        check_false(f_is_power_of_two(-1), "f_is_power_of_two(-1)");
        check_false(f_is_power_of_two(-2), "f_is_power_of_two(-2)");
        check_false(f_is_power_of_two(-1024), "f_is_power_of_two(-1024)");
        check_false(f_is_power_of_two(integer'low), "f_is_power_of_two(integer'low)");

      elsif run("string_format_reference") then
        p_check_vectors;
      end if;
    end loop;
    test_runner_cleanup(runner);
  end process;

end a_tb;
