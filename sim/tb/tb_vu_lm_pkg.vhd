--=============================================================================
-- Module Name : tb_vu_lm_pkg
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench utilities package for VUnit
--
--=============================================================================


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

package tb_vu_lm_pkg is

  constant C_CLK_PERIOD : time := 10 ns;
  constant C_T_EPSILON  : time := 1 ps;

  -- Check that a signal has pulse width withing an interval.
  -- The signal must be C_EXPECTED for at least C_T_MIN and at most C_T_MAX.
  procedure p_check_pulse_width(
    signal s_sig        : in std_logic;
    constant C_EXPECTED : in std_logic;
    constant C_T_MIN    : in time;
    constant C_T_MAX    : in time;
    constant C_TIMEOUT  : in time;
    constant C_MSG      : in string := ""
  );

  -- Check that a signal has a specific pulse width.
  procedure p_check_pulse_width(
    signal s_sig        : in std_logic;
    constant C_EXPECTED : in std_logic;
    constant C_DURATION : in time;
    constant C_TIMEOUT  : in time;
    constant C_MSG      : in string := ""
  );

  -- Check that a signal is held at a specific value for a given duration.
  procedure p_check_held_for(
    signal s_sig        : in std_logic;
    constant C_EXPECTED : in std_logic;
    C_DURATION          : in time;
    C_MSG               : in string := ""
  );

  -- Wait for a clock edge, default is one clock cycle.
  procedure p_wait_clk(
    signal s_clk     : in std_logic;
    constant C_COUNT : natural := 1
  );

  -- Wait for a specific time duration if t > 0 ns.
  procedure p_wait_for(C_T : time);

  procedure p_wait_signal(
    signal clk_i        : in std_logic;
    signal s_i          : in std_logic;
    constant C_EXPECTED : std_logic;
    constant C_TIMEOUT  : time   := 0 ps;
    constant C_MSG      : string := ""
  );

  procedure p_wait_signal(
    signal s_i          : in std_logic;
    constant C_EXPECTED : std_logic;
    constant C_TIMEOUT  : time;
    constant C_MSG      : string := ""
  );

  impure function f_random_vector(n : natural) return std_logic_vector;
end package;

package body tb_vu_lm_pkg is
  procedure p_check_pulse_width(
    signal s_sig        : in std_logic;
    constant C_EXPECTED : in std_logic;
    constant C_T_MIN    : in time;
    constant C_T_MAX    : in time;
    constant C_TIMEOUT  : in time;
    constant C_MSG      : in string := ""
  ) is
    variable v_t0 : time;
    variable v_dt : time;
  begin
    assert C_T_MAX >= C_T_MIN report "C_T_MAX must be greater than or equal to C_T_MIN" severity failure;

    -- Phase 1: Wait for signal to become C_EXPECTED
    wait until s_sig = C_EXPECTED for C_TIMEOUT;
    check(s_sig = C_EXPECTED, "C_TIMEOUT: signal does not reached value " & std_logic'image(C_EXPECTED) & " after timeout " & time'image(C_TIMEOUT) & "-- " & C_MSG);

    -- Phase 2: wait for signal to become not C_EXPECTED
    v_t0 := now;
    wait until s_sig /= C_EXPECTED for C_T_MAX + 1 ps; -- 1 ps to account for phase 1 wait time
    v_dt := now - v_t0;
    check(s_sig /= C_EXPECTED, "Signal hold value " & std_logic'image(C_EXPECTED) & " for more than " & time'image(C_T_MAX) & " (" & time'image(v_dt) & ") -- " & C_MSG);
    check(v_dt >= C_T_MIN, "Signal did not hold value " & std_logic'image(C_EXPECTED) & " for at least " & time'image(C_T_MIN) & " but only for " & time'image(v_dt) & " -- " & C_MSG);
  end procedure;

  procedure p_check_pulse_width(
    signal s_sig        : in std_logic;
    constant C_EXPECTED : in std_logic;
    constant C_DURATION : in time;
    constant C_TIMEOUT  : in time;
    constant C_MSG      : in string := ""
  ) is
  begin
    p_check_pulse_width(s_sig, C_EXPECTED, C_DURATION, C_DURATION, C_TIMEOUT, C_MSG);
  end;

  procedure p_check_held_for(
    signal s_sig        : in std_logic;
    constant C_EXPECTED : in std_logic;
    constant C_DURATION : in time;
    constant C_MSG      : in string := ""
  ) is
    variable t_start : time;
  begin
    check_equal(s_sig, C_EXPECTED, C_MSG);
    t_start := now;
    wait until s_sig /= C_EXPECTED for C_DURATION;
    check(now - t_start >= C_DURATION,
    "Signal did not hold value " & std_logic'image(C_EXPECTED) &
    " for " & time'image(C_DURATION) & " but only for " & time'image(now - t_start) &
    " -- " & C_MSG);
  end procedure;

  procedure p_wait_clk(
    signal s_clk     : in std_logic;
    constant C_COUNT : natural := 1
  ) is
  begin
    for i in 1 to C_COUNT loop
      wait until rising_edge(s_clk);
    end loop;
  end;

  procedure p_wait_for(C_T : time) is
  begin
    if C_T > 0 ns then
      wait for C_T;
    end if;
  end;

  procedure p_wait_signal(
    signal clk_i        : in std_logic;
    signal s_i          : in std_logic;
    constant C_EXPECTED : std_logic;
    constant C_TIMEOUT  : time   := 0 ps;
    constant C_MSG      : string := ""
  ) is
    variable v_tstart : time;
  begin
    v_tstart := now;
    loop
      wait until rising_edge(clk_i);
      wait for C_T_EPSILON;
      exit when s_i = C_EXPECTED;
      if (C_TIMEOUT > 0 ps) then
        check(now < v_tstart + C_TIMEOUT,
        "No signal " & std_logic'image(C_EXPECTED) &
        " for " & time'image(C_TIMEOUT) &
        " -- " & C_MSG);
      end if;
    end loop;
  end procedure;

  procedure p_wait_signal(
    signal s_i          : in std_logic;
    constant C_EXPECTED : std_logic;
    constant C_TIMEOUT  : time;
    constant C_MSG      : string := ""
  ) is
    variable v_tstart : time;
  begin
    if s_i /= C_EXPECTED then
      v_tstart := now;
      wait until s_i = C_EXPECTED for C_TIMEOUT;
      check(now < v_tstart + C_TIMEOUT,
      "No signal " & std_logic'image(C_EXPECTED) &
      " for " & time'image(C_TIMEOUT) &
      " s_i=" & std_logic'image(s_i) &
      " -- " & C_MSG);
    end if;
  end procedure;

  -- Random utilities
  shared variable seed1 : positive := 101;
  shared variable seed2 : positive := 303;

  impure function f_random_vector(n : natural) return std_logic_vector is
    variable result                   : std_logic_vector(n - 1 downto 0);
    variable r                        : real;
  begin
    for i in 0 to n - 1 loop
      uniform(seed1, seed2, r);
      result(i) := '1' when r >= 0.5 else
      '0';
    end loop;
    return result;
  end function;
end package body;
