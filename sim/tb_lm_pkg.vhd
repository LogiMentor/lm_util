--=============================================================================
-- Module Name : tb_lm_pkg
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: simple package for testbenches with procedure to print messages
--              check values and wait for conditions
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
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;


package tb_lm_pkg is

  type t_slv_array is array(integer range <>) of std_logic_vector;


  procedure p_message (
  constant C_MSG : in string);

  -- checks matching signals
  procedure p_signal_check (
  constant C_MSG   : in string;        -- signal name
  constant C_VALUE : in std_logic;     -- expected value
  signal s_sig     : in std_logic;
  signal s_errors   : out integer);

  -- checks matching standard logic vectors
  procedure p_vector_check (
  constant C_MSG   : in string;               -- signal name
  constant C_VALUE : in std_logic_vector;     -- expected value
  signal s_sig     : in std_logic_vector;
  signal s_errors   : out integer);

  -- checks matching arrays of standard logic vectors
  procedure p_array_check (
  constant C_MSG   : in string;               -- signal name
  constant C_VALUE : in t_slv_array;     -- expected value
  signal s_sig     : in t_slv_array;
  signal s_errors   : out integer);

  procedure p_wait_for_event (
  constant C_MSG     : in string;        -- message
  constant C_TIMEOUT : in time;          -- timeout
  signal s_trigger   : in std_logic;
  signal s_errors   : out integer);

  procedure p_wait_for_condition (
  constant C_MSG     : in string;        -- message
  constant C_TIMEOUT : in time;          -- timeout
  signal s_trigger   : in std_logic;
  signal s_condition : in std_logic;
  signal s_errors   : out integer);

  procedure p_wait_for_condition_ntimes (
  constant C_MSG     : in string;        -- message
  constant C_TIMEOUT : in time;          -- timeout
  constant C_N       : in integer;
  signal s_trigger   : in std_logic;
  signal s_condition : in std_logic;
  signal s_errors   : out integer);

  procedure p_sim_report (
  constant C_MSG : in string);



end tb_lm_pkg;

package body tb_lm_pkg is


  constant C_TIME_WIDTH    : integer := 15;  -- Number of chars for time field

  --todo: fix "Shared variables must be of a protected type." warning
  shared variable v_errors : integer := 0;  -- error counter during simulation


  procedure p_message (
    constant C_MSG : in string) is
    variable v_txt : line;
  begin
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" -- ") & C_MSG);
    writeline(OUTPUT, v_txt);
  end;


  -- checks matching signals
  procedure p_signal_check (
    constant C_MSG   : in string;        -- signal name
    constant C_VALUE : in std_logic;     -- expected value
    signal s_sig     : in std_logic;     -- signal to check
    signal s_errors   : out integer) is
    variable v_txt : line;
  begin
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" "));
    write(v_txt, C_MSG);
    write(v_txt, string'(" "));
    if s_sig = C_VALUE then
      write(v_txt, string'("verified to be "));
    else
      write(v_txt, string'("has incorrect value! Expected "));
      v_errors := v_errors + 1;
    end if;
    if C_VALUE = '1' then
      write(v_txt, string'("1!"));
    else
      write(v_txt, string'("0!"));
    end if;
    writeline(OUTPUT, v_txt);
    s_errors <= v_errors;
  end;


  -- checks matching standard logic vectors
  procedure p_vector_check (
    constant C_MSG   : in string;               -- signal name
    constant C_VALUE : in std_logic_vector;     -- expected value
    signal s_sig     : in std_logic_vector;    -- signal to check
    signal s_errors   : out integer) is
    variable v_txt : line;
  begin
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" "));
    write(v_txt, C_MSG);
    write(v_txt, string'(" "));
    if s_sig = C_VALUE then
      write(v_txt, string'("verified to be "));
    else
      write(v_txt, string'("has incorrect value! Expected "));
      write(v_txt, f_slv2hex(C_VALUE));
      write(v_txt, string'(", but got "));
      v_errors := v_errors + 1;
      s_errors <= v_errors;
    end if;
    write(v_txt, f_slv2hex(s_sig));
    writeline(OUTPUT, v_txt);
  end;


  -- checks matching arrays of standard logic vectors
  procedure p_array_check (
    constant C_MSG   : in string;               -- signal name
    constant C_VALUE : in t_slv_array;     -- expected value
    signal s_sig     : in t_slv_array;     -- signal to check
    signal s_errors   : out integer) is
    variable v_txt : line;
  begin
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" "));
    write(v_txt, C_MSG);
    write(v_txt, string'(" "));
    if s_sig = C_VALUE then
      write(v_txt, string'("verified to be "));
    else
      write(v_txt, string'("has incorrect value! Expected "));
      for i in C_VALUE'range loop
        write(v_txt, f_slv2hex(C_VALUE(i)));
        write(v_txt, string'(" "));
      end loop;
      write(v_txt, string'(", but got "));
      v_errors := v_errors + 1;
      s_errors <= v_errors;
    end if;
    for i in s_sig'range loop
      write(v_txt, f_slv2hex(s_sig(i)));
      write(v_txt, string'(" "));
    end loop;
    writeline(OUTPUT, v_txt);
  end;


  procedure p_wait_for_event (
    constant C_MSG     : in string;        -- message
    constant C_TIMEOUT : in time;          -- timeout
    signal s_trigger   : in std_logic;     -- trigger signal
    signal s_errors   : out integer) is
    variable v_txt : line;
    variable v_t1  : time;
  begin
    v_t1 := now;
    wait on s_trigger for C_TIMEOUT;
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" "));
    write(v_txt, C_MSG);
    if now - v_t1 >= C_TIMEOUT then
      write(v_txt, string'(" - Timed out!"));
      v_errors := v_errors + 1;
      s_errors <= v_errors;
    else
      write(v_txt, string'(" - OK!"));
    end if;
    writeline(OUTPUT, v_txt);
  end;


  procedure p_wait_for_condition (
    constant C_MSG     : in string;        -- message
    constant C_TIMEOUT : in time;          -- timeout
    signal s_trigger   : in std_logic;     -- trigger signal
    signal s_condition : in std_logic;
    signal s_errors   : out integer) is
    variable v_txt : line;
    variable v_t1  : time;
  begin
    v_t1 := now;
    wait until s_trigger = s_condition;
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" "));
    write(v_txt, C_MSG);
    if now - v_t1 >= C_TIMEOUT then
      write(v_txt, string'(" - Timed out!"));
      v_errors := v_errors + 1;
      s_errors <= v_errors;
    else
      write(v_txt, string'(" - OK!"));
    end if;
    writeline(OUTPUT, v_txt);
  end;


  procedure p_wait_for_condition_ntimes (
    constant C_MSG     : in string;        -- message
    constant C_TIMEOUT : in time;          -- timeout
    constant C_N       : in integer;
    signal s_trigger   : in std_logic;     -- trigger signal
    signal s_condition : in std_logic;
    signal s_errors   : out integer) is
    variable v_txt : line;
    variable v_t1  : time;
  begin
    v_t1 := now;
    for i in 1 to C_N loop
      wait until s_trigger = s_condition;
    end loop;
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" "));
    write(v_txt, C_MSG);
    if now - v_t1 >= C_TIMEOUT then
      write(v_txt, string'(" - Timed out!"));
      v_errors := v_errors + 1;
      s_errors <= v_errors;
    else
      write(v_txt, string'(" - OK!"));
    end if;
    writeline(OUTPUT, v_txt);
  end;


  --* Report number of errors encountered during simulation
  procedure p_sim_report (
    constant C_MSG : in string) is
    variable v_txt : line;
  begin
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" Simulation completed with "));
    --write(v_txt, v_errors);
    write(v_txt, string'(" errors!"));
    writeline(OUTPUT, v_txt);
  end;




end package body;

