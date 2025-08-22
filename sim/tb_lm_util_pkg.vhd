--=============================================================================
-- Module Name   : lm_util_pkg_tb
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description   : Self-checking testbench for the lm_util_pkg package
-- 
-- 
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Logimentor Srl

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-------------------------------------------------------------------------------
-- Revision History: 20/10/2014 A.Campera: initial release
-- Last revised:   
-- Date         Version Author      Description
-- 26/03/2015   1.0.0   A.Campera   initial release
-- 
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use ieee.float_pkg.all;


library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

entity tb_lm_util_pkg is

end tb_lm_util_pkg;

architecture tb of tb_lm_util_pkg is


  function log2floor (l : positive) return natural is
    variable i, bitcount : natural;
  begin
    i        := l;
    bitcount := 0;
    while (i > 1) loop
      bitcount := bitcount + 1;
      i        :=to_integer(shift_right(to_unsigned(i, 32), 1));
    end loop;
    return bitcount;
  end log2floor;

  function log2ceil (l : positive) return natural is
    variable i, bitcount : natural;
  begin
    if l = 1 then
      bitcount := 1;
    else
      i        := l-1;
      bitcount := 0;
      while (i > 0) loop
        bitcount := bitcount + 1;
        i        :=to_integer(shift_right(to_unsigned(i, 32), 1));
      end loop;
    end if;
    return bitcount;
  end log2ceil;

begin


  stim_proc : process
    constant C_TEST      : integer            := 8;
    variable v_a_signed  : signed(7 downto 0) := "10101111";
    variable v_res1      : signed(4 downto 0);
    variable v_res2      : signed(4 downto 0);
    variable v_a_integer : integer;
    variable v_a_natural : natural;
    variable v_a_real    : real;
    variable v_a_float64 : float64;
    variable v_slv       : std_logic_vector(15 downto 8);
  begin

    p_console_log(string'("Starting Test on resize function..."));

    wait for 10 ns;                     -- wait few ns before start

    v_res1 := f_ces_resize(v_a_signed, 5);
    v_res2 := resize(v_a_signed, 5);
    p_console_log(string'("f_ces_resize(10101111,5) = std_logic_vector'image(v_res1) "));
    p_console_log(string'("resize(10101111,5) = std_logic_vector'image(v_res2) "));

    wait for 10 ns;
    v_a_integer := f_div_ceil (5, 3);
    wait for 10 ns;
    v_a_real    := real(C_TEST);
    v_a_real    := log2(real(C_TEST));
    v_a_float64 := to_float(v_a_real, v_a_float64);
    v_a_real    := floor(log2(real(C_TEST)));
    v_a_float64 := to_float(v_a_real, v_a_float64);
    v_a_integer := log2floor(C_TEST);
    v_a_integer := log2ceil(1);
    v_a_integer := log2ceil(2);
    v_a_integer := integer(log2(64.0));
    v_a_integer := f_ceil_log2(64);
    v_a_natural := f_floor_log2(v_a_integer);
    v_a_integer := f_div_ceil_2pwr(9, 2);
   
    wait for 1 ns;
    v_slv := x"12";
    p_console_log(f_slv2string(v_slv));

    assert false
      report "********** TC_001: TEST PASSED! **********"
      severity failure;



  end process stim_proc;
end tb;


