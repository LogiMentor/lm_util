library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;

-- Add your library and packages declaration here ...

entity tb_lm_util_clock_gen is
  -- Generic declarations of the tested unit
  generic (
    --* input clock frequency divider
    g_clock_div : integer := 10;
    --* output clock phase  
    g_clock_phase : integer := 1;
    --* positive output clock cycles 
    g_pos_duty_cycle : integer := 1
  );
end tb_lm_util_clock_gen;

architecture tb_arch of tb_lm_util_clock_gen is
  constant C_CLK_IN_PERIOD : time := 10 ns;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i   : std_logic := '1'; --* input clock
  signal rst_n_i : std_logic := '0'; --* input reset
  -- Observed signals - signals mapped to the output ports of tested entity
  signal clk_o : std_logic := '0'; --* output pulse
begin

  -- Unit Under Test port map
  uut : entity lm_util_lib.lm_util_clock_gen
    generic map(
      g_clock_div      => g_clock_div,
      g_clock_phase    => g_clock_phase,
      g_pos_duty_cycle => g_pos_duty_cycle
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      clk_o   => clk_o
    );

  clk_i <= not clk_i after C_CLK_IN_PERIOD / 2;

  proc_stim : process
  begin
    rst_n_i <= '0';
    wait for C_CLK_IN_PERIOD * (g_clock_div-1);
    rst_n_i <= '1';
    wait;
  end process proc_stim;

end tb_arch;
