library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;
entity tb_lm_util_counter is
  -- Generic declarations of the tested unit
  generic (
    g_data_w   : integer := 16; --* counter data width
    g_wd_timer : integer := 5; --* watchdog timer value:
    g_dir      : integer := 1; --* counter direction, 1: up, 0 : down

    g_load_dat : integer := 0 --* data to be loaded;

  );
end tb_lm_util_counter;

architecture tb_arch of tb_lm_util_counter is
  -- Constants
  constant C_CLK_PERIOD : time := 10 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i      : std_logic := '1'; --* input clock
  signal rst_n_i    : std_logic := '0'; --* input reset
  signal ce_i       : std_logic := '0'; --* clock enable
  signal load_i     : std_logic := '0'; --* active high strobe for counter loading
  signal load_dat_i : std_logic_vector(g_data_w - 1 downto 0);--* data to be loaded
  --* output counter

  -- Observed signals - signals mapped to the output ports of tested entity
  signal cnt_o   : std_logic_vector(g_data_w - 1 downto 0); --* output counter
  signal timer_o : std_logic;
  --* timer output

begin
  -- Unit Under Test port map
  UUT : entity lm_util_lib.lm_util_counter
    generic map(
      g_data_w   => g_data_w,
      g_wd_timer => g_wd_timer,
      g_dir      => g_dir
    )

    port map
    (
      clk_i      => clk_i,
      rst_n_i    => rst_n_i,
      ce_i       => ce_i,
      load_i     => load_i,
      load_dat_i => load_dat_i,
      cnt_o      => cnt_o,
      timer_o    => timer_o
    );

  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  proc_stim : process
  begin
    -- reset the counter
    rst_n_i <= '0';
    wait until rising_edge(clk_i);
    -- deassert reset
    rst_n_i <= '1';
    wait until rising_edge(clk_i);

    -- loading data
    load_dat_i <= f_int2slv(g_load_dat, load_dat_i'length);
    load_i <= '1';

    -- enable clock
    ce_i <= '1';
    wait until rising_edge(clk_i);
    load_i <= '0';

    wait;
  end process proc_stim;

end tb_arch;
