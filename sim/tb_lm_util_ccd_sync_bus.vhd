library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Add your library and packages declaration here ...

entity tb_lm_util_ccd_sync_bus is
  -- Generic declarations of the tested unit
  generic (
    g_bus_width   : natural := 16;
    g_meta_levels : natural := C_META_DELAY_LEN
  );
end tb_lm_util_ccd_sync_bus;

architecture behav of tb_lm_util_ccd_sync_bus is
  constant C_CLK_IN_PERIOD : time := 10 ns;
  constant C_T0            : time := 100 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal in_clk_i    : std_logic := '1'; --< input clock
  signal in_rst_n_i  : std_logic := '0'; --< input reset
  signal in_data_i   : std_logic_vector(g_bus_width - 1 downto 0); --< input data
  signal s_out_clk_i : std_logic := '1'; --< auxilary signal for output clock
  signal out_clk_i   : std_logic := '1'; --< output clock
  signal out_req_i   : std_logic := '0'; --< data request: from the secondary clock domain

  -- Observed signals - signals mapped to the output ports of tested entity
  signal out_rdy_o  : std_logic; -- data ready
  signal out_data_o : std_logic_vector(g_bus_width - 1 downto 0); -- output data

begin
  in_clk_i    <= not in_clk_i after C_CLK_IN_PERIOD/2;
  s_out_clk_i <= not s_out_clk_i after C_CLK_IN_PERIOD/2;
  out_clk_i   <= s_out_clk_i after 3 ns; -- clock phase difference 

  -- Unit Under Test port map
  uut : entity lm_util_lib.lm_util_ccd_sync_bus

    generic map(
      g_bus_width   => g_bus_width,
      g_meta_levels => g_meta_levels
    )
    port map
    (
      in_clk_i   => in_clk_i,
      in_rst_n_i => in_rst_n_i,
      in_data_i  => in_data_i,
      out_rdy_o  => out_rdy_o,
      out_clk_i  => out_clk_i,
      out_req_i  => out_req_i,
      out_data_o => out_data_o
    );
  proc_stim_in : process
  begin
    -- reset all input signals
    in_rst_n_i <= '0';
    wait for C_T0;

    wait until rising_edge(in_clk_i);
    --Deassert reset
    in_rst_n_i <= '1';

    wait until rising_edge(in_clk_i);

    in_data_i <= std_logic_vector(to_unsigned(1, g_bus_width));

    -- Wait for data ready
    wait until rising_edge(out_rdy_o);
    wait until rising_edge(in_clk_i);
    wait until rising_edge(in_clk_i);

    in_data_i <= std_logic_vector(to_unsigned(2, g_bus_width));

    wait until rising_edge(in_clk_i);
    wait until rising_edge(in_clk_i);

    wait;
  end process proc_stim_in;

  proc_stim_out : process
  begin
    -- reset all input signals
    out_req_i <= '0';
    wait for C_T0;

    wait until rising_edge(out_clk_i);
    wait until rising_edge(out_clk_i);
    wait until rising_edge(out_clk_i);
    out_req_i <= '1';
    wait until rising_edge(out_clk_i);
    out_req_i <= '0';

    wait until rising_edge(out_rdy_o);
    wait until rising_edge(out_clk_i);
    out_req_i <= '1';
    wait until rising_edge(out_clk_i);
    out_req_i <= '0';
    wait;
  end process proc_stim_out;

end behav;
