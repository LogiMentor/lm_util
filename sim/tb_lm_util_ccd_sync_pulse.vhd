library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;

-- Add your library and packages declaration here ...

entity tb_lm_util_ccd_sync_pulse is
  -- Generic declarations of the tested unit
  generic (
    g_delay_len : natural := 2
  );
end tb_lm_util_ccd_sync_pulse;

architecture behav of tb_lm_util_ccd_sync_pulse is
  constant C_CLK_IN_PERIOD  : time := 3 ns;
  constant C_CLK_OUT_PERIOD : time := 10 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal in_rst_n_i  : std_logic := '0';
  signal in_clk_i    : std_logic := '1';
  signal in_pulse_i  : std_logic;
  signal out_rst_n_i : std_logic := '0';
  signal out_clk_i   : std_logic := '1';
  signal s_out_clk   : std_logic := '1';
  -- Observed signals - signals mapped to the output ports of tested entity
  signal in_busy_o   : std_logic;
  signal out_pulse_o : std_logic;

  -- Add your code here ...

begin

  in_clk_i <= not in_clk_i after C_CLK_IN_PERIOD/2;

  s_out_clk <= not s_out_clk after C_CLK_OUT_PERIOD/2;

  out_clk_i <= s_out_clk after 1.3 ns;

  -- Unit Under Test port map
  inst_uut : entity lm_util_lib.lm_util_ccd_sync_pulse
    generic map(
      g_delay_len => g_delay_len
    )
    port map
    (
      in_rst_n_i  => in_rst_n_i,
      in_clk_i    => in_clk_i,
      in_pulse_i  => in_pulse_i,
      in_busy_o   => in_busy_o,
      out_rst_n_i => out_rst_n_i,
      out_clk_i   => out_clk_i,
      out_ce_i    => '1',
      out_pulse_o => out_pulse_o
    );
  proc_stim_out : process
  begin
    out_rst_n_i <= '0';
    wait until out_clk_i = '1';
    wait for 2 * C_CLK_OUT_PERIOD;
    out_rst_n_i <= '1'; --release the reset after 2 clock cycles

    wait;
  end process proc_stim_out;

  proc_stim_in : process
  begin
    in_rst_n_i <= '0';
    in_pulse_i <= '0';
    wait until in_clk_i = '1';
    wait for 2 * C_CLK_IN_PERIOD;
    in_rst_n_i <= '1'; --release the reset after 2 clock cycles
    wait for 5 * C_CLK_IN_PERIOD;
    assert false report "Send pulse on input domain." severity error;
    in_pulse_i <= '1';
    wait for C_CLK_IN_PERIOD;
    in_pulse_i <= '0';
    wait for 1 ps;
    assert in_busy_o = '1' report "Busy signal has not gone up." severity failure;
    assert false report "Busy signal has gone up." severity error;
    --
    wait until out_pulse_o = '1';
    assert in_busy_o = '1' report "Busy signal is no longer up." severity failure;
    assert false report "Out pulse emitted." severity error;
    wait until out_clk_i = '1';
    wait for 1 ps;
    assert out_pulse_o = '0' report "Out pulse still high." severity failure;
    assert false report "Out pulse passed." severity error;
    assert in_busy_o = '1' report "Busy signal is no longer up." severity failure;
    --
    wait until in_busy_o = '0';
    assert false report "Busy signal gone down." severity error;
    --
    wait for 200 ns;
    assert false report "TEST PASSED." severity failure;

    wait;
  end process proc_stim_in;

end behav;
