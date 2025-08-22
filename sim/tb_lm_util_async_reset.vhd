library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;


entity tb_lm_util_async_reset is
  -- Generic declarations of the tested unit
  generic(
    g_delay_len   : integer := C_META_DELAY_LEN;
    g_rst_lvl     : std_logic := '0');
end tb_lm_util_async_reset;

architecture tb_architecture of tb_lm_util_async_reset is

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal arst_i   : std_logic;
  signal clk_i    : std_logic := '1';
  -- Observed signals - signals mapped to the output ports of tested entity
  signal rst_n_o  : std_logic;


begin

  clk_i <= not clk_i after 5 ns;

  -- Unit Under Test port map
  uut : entity lm_util_lib.lm_util_async_reset
    generic map (
      g_delay_len   => g_delay_len,
      g_rst_lvl     => g_rst_lvl
      )

    port map (
      arst_i  => arst_i,
      clk_i   => clk_i,
      rst_n_o => rst_n_o
      );

  arst_i <= '1', '0' after 133 ns, '1' after 152 ns;

end tb_architecture;



