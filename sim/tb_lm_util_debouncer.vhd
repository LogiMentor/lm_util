library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;
entity tb_lm_util_debouncer is
  -- Generic declarations of the tested unit
  generic (
    -- debounce length in clock cycles
    g_debounce_length : natural := 10;
    -- debounce level: 0: std_logic '0', 1: std_logic '1', 2: both ('0', and '1')
    g_debounce_lvl : natural := 2
  );
end tb_lm_util_debouncer;

architecture tb_arch of tb_lm_util_debouncer is
  -- Constants
  constant C_CLK_PERIOD : time := 10 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i   : std_logic := '1'; --* input clock
  signal rst_n_i : std_logic := '0'; --* input reset
  signal ce_i    : std_logic := '0'; --* clock enable
  signal din_i   : std_logic := '0'; --* active high strobe for counter loading
  --* output counter

  -- Observed signals - signals mapped to the output ports of tested entity
  signal dout_o : std_logic;--* data to be loaded
  --* timer output

begin
  -- Unit Under Test port map
  UUT : entity lm_util_lib.lm_util_debouncer
    generic map(
      g_debounce_length => g_debounce_length,
      g_debounce_lvl    => g_debounce_lvl
    )

    port map
    (
      clk_i   => clk_i,
      ce_i    => ce_i,
      rst_n_i => rst_n_i,
      din_i   => din_i,
      dout_o  => dout_o
    );
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  proc_stim : process
  begin
    din_i <= '1', '0' after 40 ns, '1' after 60 ns, '0' after 70 ns, '1' after 600 ns, '0' after 610 ns, '1' after 800 ns;

    -- reset the counter
    rst_n_i <= '0';
    wait until rising_edge(clk_i);
    -- deassert reset
    rst_n_i <= '1';
    wait until rising_edge(clk_i);
    ce_i <= '1';
    wait for 1 ps;

    wait;
  end process proc_stim;

end tb_arch;
