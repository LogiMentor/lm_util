library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;

-- Add your library and packages declaration here ...

entity tb_lm_util_clock_measure is
  -- Generic declarations of the tested unit
  generic (
    --* reference clock frequency Herts
    g_ref_clock_freq : integer := 1_000_000;
    --* clock count width, number of bits of the clock cycles counter  
    g_clock_width : integer := 32;

    --* clock frequency
    g_clock_freq : integer := 1_00_000
  );
end tb_lm_util_clock_measure;

architecture tb_arch of tb_lm_util_clock_measure is
  constant C_CLK_REF_PERIOD : time := 1 sec / g_ref_clock_freq;
  constant C_CLK_IN_PERIOD  : time := 1 sec / g_clock_freq;
  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal ref_clk_i          : std_logic := '1'; --* reference input known clock
  signal rst_n_i            : std_logic := '0'; --* input reset, active low, synchronous with ref_clk_i
  signal clock_to_measure_i : std_logic := '1'; --* input, clock to be measured
  -- Observed signals - signals mapped to the output ports of tested entity
  signal output_frequency_hz_o : std_logic_vector(g_clock_width - 1 downto 0); --* output pulse

begin

  -- Unit Under Test port map
  uut : entity lm_util_lib.lm_util_clock_measure
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

  ref_clk_i <= not ref_clk_i after C_CLK_REF_PERIOD / 2;
  clock_to_measure_i <= not clock_to_measure_i after C_CLK_IN_PERIOD / 2;

  proc_stim : process
  begin
    rst_n_i <= '0';
    wait for C_CLK_IN_PERIOD;
    wait for C_CLK_REF_PERIOD;
    rst_n_i <= '1';
    wait;
  end process proc_stim;

end tb_arch;
