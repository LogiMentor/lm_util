-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_clock_measure
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_clock_measure
--
--              Testbench verifies the clock measurement functionality:
--              - frequency measurement
--              - no measurement is published during a reset or after it,
--                before a new and complete window has been measured
--                (reset length, reset phase, slow and stopped measured clock)
--
--              A monitor checks every write of the output register, also
--              when the written value does not change: the time of each
--              publication and the measured value.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_clock_measure is
  generic (
    -- reference clock frequency Herts
    g_ref_clock_freq : integer := 1_000_000;
    -- clock count width, number of bits of the clock cycles counter
    g_clock_width : integer := 32;

    -- clock frequency
    g_clock_freq : integer := 1_00_000;

    -- clock periods in ps, 0: derived from the frequencies above
    g_ref_period_ps  : natural := 0;
    g_meas_period_ps : natural := 0;
    -- start delay of the measured clock, ps
    g_meas_phase_ps : natural := 0;
    -- reset length in ref_clk_i cycles for the reset tests
    g_rst_cycles : positive := 1;

    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_clock_measure;

architecture a_tb of tb_vu_lm_util_clock_measure is
  function f_period(C_PS : natural; C_FREQ : integer) return time is
    variable v_period : time;
  begin
    if C_PS > 0 then
      v_period := C_PS * 1 ps;
    else
      v_period := 1 sec / C_FREQ;
    end if;
    return v_period;
  end function;

  constant C_CLK_REF_PERIOD : time := f_period(g_ref_period_ps, g_ref_clock_freq);
  constant C_CLK_IN_PERIOD  : time := f_period(g_meas_period_ps, g_clock_freq);
  -- measurement window: g_ref_clock_freq reference clock cycles
  constant C_WINDOW         : time := g_ref_clock_freq * C_CLK_REF_PERIOD;
  -- expected count: measured clock edges in one window
  constant C_COUNT_MIN      : natural := C_WINDOW / C_CLK_IN_PERIOD;
  constant C_COUNT_MAX      : natural := (C_WINDOW + C_CLK_IN_PERIOD - 1 fs) / C_CLK_IN_PERIOD;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal ref_clk_i          : std_logic := '1'; -- reference input known clock
  signal rst_n_i            : std_logic := '0'; -- input reset, active low, synchronous with ref_clk_i
  signal clock_to_measure_i : std_logic := '1'; -- input, clock to be measured
  -- Observed signals - signals mapped to the output ports of tested entity
  signal output_frequency_hz_o : std_logic_vector(g_clock_width - 1 downto 0); -- output pulse

  -- measured clock running
  signal s_meas_run    : boolean := true;
  -- rst_n_i as sampled by the DUT on the last ref_clk_i edge
  signal s_rst_seen    : std_logic := '0';
  -- earliest time a publication is allowed: set by the reset and clock stop
  -- sequences of proc_main
  signal s_pub_allowed : time    := 0 ns;
  -- publications seen by the monitor
  signal s_pub_count   : natural := 0;

begin
  -- Clock generation
  ref_clk_i <= not ref_clk_i after C_CLK_REF_PERIOD / 2;

  proc_meas_clk : process
  begin
    p_wait_for(g_meas_phase_ps * 1 ps);
    loop
      wait for C_CLK_IN_PERIOD / 2;
      if not s_meas_run then
        wait until s_meas_run;
      end if;
      clock_to_measure_i <= not clock_to_measure_i;
    end loop;
  end process;

  proc_rst_seen : process(ref_clk_i)
  begin
    if rising_edge(ref_clk_i) then
      s_rst_seen <= rst_n_i;
    end if;
  end process;

  -- Unit Under Test port map
  inst_dut : entity lm_util_lib.lm_util_clock_measure
    generic map(
      g_ref_clock_freq => g_ref_clock_freq,
      g_clock_width    => g_clock_width
    )
    port map
    (
      ref_clk_i             => ref_clk_i,
      rst_n_i               => rst_n_i,
      clock_to_measure_i    => clock_to_measure_i,
      output_frequency_hz_o => output_frequency_hz_o
    );

  -- every write of the output register is a publication, also when the value
  -- does not change: it must not happen in reset or before s_pub_allowed, and
  -- it must carry the count of a complete window
  proc_pub_mon : process
    variable v_count : natural;
  begin
    wait on output_frequency_hz_o'transaction;
    v_count := to_integer(unsigned(output_frequency_hz_o));
    check(s_rst_seen = '1', "publication during reset, value " & integer'image(v_count));
    check(now >= s_pub_allowed,
      "publication at " & time'image(now) & " before " & time'image(s_pub_allowed) &
      ", value " & integer'image(v_count));
    check(v_count >= C_COUNT_MIN and v_count <= C_COUNT_MAX,
      "published " & integer'image(v_count) & " at " & time'image(now) &
      ", expected " & integer'image(C_COUNT_MIN) & " to " & integer'image(C_COUNT_MAX));
    s_pub_count <= s_pub_count + 1;
  end process;

  proc_main : process
    -- synchronous reset of C_CYCLES ref_clk_i cycles; the first complete window
    -- ends on the second tick, 2 * g_ref_clock_freq cycles after the release
    procedure p_reset(C_CYCLES : positive) is
    begin
      wait until rising_edge(ref_clk_i);
      rst_n_i <= '0';
      p_wait_clk(ref_clk_i, C_CYCLES);
      rst_n_i       <= '1';
      s_pub_allowed <= now + (2 * g_ref_clock_freq - 1) * C_CLK_REF_PERIOD;
    end procedure;

    -- wait for the next publication
    procedure p_wait_pub is
      constant C_TIMEOUT : time := 4 * C_WINDOW + 8 * C_CLK_IN_PERIOD;
      variable v_count   : natural;
    begin
      v_count := s_pub_count;
      wait until s_pub_count /= v_count for C_TIMEOUT;
      check(s_pub_count /= v_count, "no publication for " & time'image(C_TIMEOUT));
    end procedure;

    variable v_pub_allowed : time;
  begin
    test_runner_setup(runner, runner_cfg);
    if run("check") then
      -- reset all input signals
      rst_n_i <= '0';
      wait for C_CLK_IN_PERIOD + C_CLK_REF_PERIOD;
      rst_n_i       <= '1';
      s_pub_allowed <= now + (2 * g_ref_clock_freq - 1) * C_CLK_REF_PERIOD;
      wait for C_CLK_IN_PERIOD + C_CLK_REF_PERIOD;

      -- the first complete window ends on the second tick after the reset
      p_wait_clk(ref_clk_i, 2 * g_ref_clock_freq + 200);

      check_equal(output_frequency_hz_o, g_clock_freq, "Frequency measure failed");

    elsif run("reset_ready_pending") then
      -- measured-domain ready toggled before a reset and synchronized after
      -- it: 10 ns reference, 14 ns measured clock, 20-cycle window
      wait for 30 ns;
      rst_n_i       <= '1';
      s_pub_allowed <= 30 ns + (2 * g_ref_clock_freq - 1) * C_CLK_REF_PERIOD;
      wait for 280 ns;
      rst_n_i <= '0';
      wait for 10 ns;
      rst_n_i       <= '1';
      s_pub_allowed <= 320 ns + (2 * g_ref_clock_freq - 1) * C_CLK_REF_PERIOD;
      p_wait_pub;

    elsif run("reset_sweep") then
      -- reset at every ref_clk_i cycle across two windows after a publication:
      -- the reset meets the measured-domain ready toggle, the ready
      -- synchronizer and the tick toggle synchronizer at every phase
      p_reset(g_rst_cycles);
      p_wait_pub;
      for i in 0 to 2 * g_ref_clock_freq loop
        p_wait_clk(ref_clk_i, i);
        p_reset(g_rst_cycles);
        p_wait_pub;
      end loop;

    elsif run("reset_clock_stopped") then
      -- measured clock stopped before the reset, during it and for two windows
      -- after it: nothing may be published until the clock runs again for a
      -- complete window
      p_reset(g_rst_cycles);
      p_wait_pub;
      for i in 0 to g_ref_clock_freq loop
        p_wait_clk(ref_clk_i, i);
        s_meas_run <= false;
        p_wait_clk(ref_clk_i, 1 + i mod 3);
        p_reset(g_rst_cycles);
        s_pub_allowed <= time'high;
        p_wait_clk(ref_clk_i, 2 * g_ref_clock_freq + i);
        s_meas_run    <= true;
        v_pub_allowed := now + C_WINDOW;
        s_pub_allowed <= v_pub_allowed;
        p_wait_pub;
      end loop;
    end if;
    test_runner_cleanup(runner);
  end process;

end a_tb;
