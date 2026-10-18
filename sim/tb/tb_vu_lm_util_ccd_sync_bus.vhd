-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_ccd_sync_bus
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_ccd_sync_bus (testbench)
--
--              A request asserted in the output clock domain must latch the
--              input bus once, on its rising edge as seen in the input
--              domain, and report it with a single out_rdy_o pulse.
--              Tests:
--                basic_transfer        two back-to-back request cycles
--                req_held_across_reset a request held through the reset
--                                      release is not a new request
--                req_rises_after_reset a request whose resynchronized edge
--                                      lands on the first cycle after the
--                                      reset release is transferred
--              The output domain has no reset, so its registers start
--              uninitialized and produce one spurious out_rdy_o pulse while
--              the resynchronized valid settles; the monitor starts counting
--              only after that settling time.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_ccd_sync_bus is
  generic (
    g_bus_width         : natural  := 8;
    g_meta_levels       : natural  := 2;
    -- output clock period; the input clock period is 10 ns
    g_out_clk_period_ns : positive := 7;
    -- Required for VUnit
    runner_cfg          : string   := ""
  );
end tb_vu_lm_util_ccd_sync_bus;

architecture a_tb of tb_vu_lm_util_ccd_sync_bus is
  constant C_IN_CLK_PERIOD  : time := 10 ns;
  constant C_OUT_CLK_PERIOD : time := g_out_clk_period_ns * 1 ns;
  -- worst case request-to-ready latency, with margin
  constant C_TIMEOUT        : time := 8 * (g_meta_levels + 2) * (C_IN_CLK_PERIOD + C_OUT_CLK_PERIOD);
  constant C_DATA_A         : std_logic_vector(g_bus_width - 1 downto 0) := f_nat2slv(16#A5#, g_bus_width);
  constant C_DATA_B         : std_logic_vector(g_bus_width - 1 downto 0) := f_nat2slv(16#3C#, g_bus_width);

  -- Stimulus signals
  signal in_clk_i   : std_logic := '1';
  signal out_clk_i  : std_logic := '1';
  signal in_rst_n_i : std_logic := '0';
  signal in_data_i  : std_logic_vector(g_bus_width - 1 downto 0) := (others => '0');
  signal out_req_i  : std_logic := '0';
  -- Observed signals
  signal out_rdy_o  : std_logic;
  signal out_data_o : std_logic_vector(g_bus_width - 1 downto 0);
  -- out_rdy_o monitor
  signal s_mon_en    : boolean := false;
  signal s_rdy_count : natural := 0;
  signal s_rdy_data  : std_logic_vector(g_bus_width - 1 downto 0) := (others => '0');

begin
  in_clk_i  <= not in_clk_i after C_IN_CLK_PERIOD / 2;
  out_clk_i <= not out_clk_i after C_OUT_CLK_PERIOD / 2;

  inst_dut : entity lm_util_lib.lm_util_ccd_sync_bus
    generic map(
      g_bus_width   => g_bus_width,
      g_meta_levels => g_meta_levels
    )
    port map(
      in_clk_i   => in_clk_i,
      in_rst_n_i => in_rst_n_i,
      in_data_i  => in_data_i,
      out_rdy_o  => out_rdy_o,
      out_clk_i  => out_clk_i,
      out_req_i  => out_req_i,
      out_data_o => out_data_o
    );

  -- count the out_rdy_o pulses and keep the data reported with the last one
  proc_monitor : process(out_clk_i)
  begin
    if rising_edge(out_clk_i) then
      if s_mon_en and out_rdy_o = '1' then
        s_rdy_count <= s_rdy_count + 1;
        s_rdy_data  <= out_data_o;
      end if;
    end if;
  end process proc_monitor;

  proc_main : process
    variable v_count : natural;

    -- hold the input reset, then release it and let the output domain settle
    procedure p_reset_and_settle is
    begin
      in_rst_n_i <= '0';
      p_wait_clk(in_clk_i, 10);
      in_rst_n_i <= '1';
      p_wait_clk(out_clk_i, 4 * (g_meta_levels + 2));
      s_mon_en <= true;
      wait for 0 ns;
    end procedure;

    -- raise the request and wait for exactly one more out_rdy_o pulse
    procedure p_transfer(constant C_DATA : std_logic_vector) is
    begin
      v_count   := s_rdy_count;
      in_data_i <= C_DATA;
      wait until rising_edge(out_clk_i);
      out_req_i <= '1';
      wait until s_rdy_count /= v_count for C_TIMEOUT;
      check_equal(s_rdy_count, v_count + 1, "Expected one out_rdy_o pulse for the request");
      check_equal(s_rdy_data, C_DATA, "Wrong data reported with out_rdy_o");
      wait until rising_edge(out_clk_i);
      out_req_i <= '0';
      -- let the deasserted request reach the input domain
      wait for C_TIMEOUT;
      check_equal(s_rdy_count, v_count + 1, "Unexpected extra out_rdy_o pulse");
    end procedure;

  begin
    test_runner_setup(runner, runner_cfg);

    if run("basic_transfer") then
      p_reset_and_settle;
      check_equal(s_rdy_count, 0, "out_rdy_o pulse without a request");
      p_transfer(C_DATA_A);
      p_transfer(C_DATA_B);

    elsif run("req_held_across_reset") then
      -- the request is already high long before the reset release
      out_req_i <= '1';
      in_data_i <= C_DATA_A;
      p_reset_and_settle;
      wait for C_TIMEOUT;
      check_equal(s_rdy_count, 0, "A request held across reset must not be transferred");
      -- a new request cycle after the release is still served
      wait until rising_edge(out_clk_i);
      out_req_i <= '0';
      wait for C_TIMEOUT;
      p_transfer(C_DATA_B);

    elsif run("req_rises_after_reset") then
      -- the request is sampled high for the first time g_meta_levels input
      -- clock edges before the first edge out of reset, so its
      -- resynchronized rising edge lands on that first cycle
      in_rst_n_i <= '0';
      in_data_i  <= C_DATA_A;
      p_wait_clk(in_clk_i, 10);
      out_req_i  <= '1';
      p_wait_clk(in_clk_i, g_meta_levels);
      in_rst_n_i <= '1';
      -- the monitor cannot start before the output domain settles, so the
      -- transfer is checked through the output register instead
      p_wait_clk(out_clk_i, 4 * (g_meta_levels + 2));
      s_mon_en <= true;
      wait for C_TIMEOUT;
      check_equal(out_data_o, C_DATA_A, "The request rising right after reset was not transferred");
      check_equal(s_rdy_count, 0, "Unexpected extra out_rdy_o pulse");
    end if;

    test_runner_cleanup(runner);
  end process;

end a_tb;
