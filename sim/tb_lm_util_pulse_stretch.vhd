library ieee;
use ieee.NUMERIC_STD.all;
use ieee.std_logic_1164.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

-- Add your library and packages declaration here ...

entity tb_lm_util_pulse_stretch is
  -- Generic declarations of the tested unit
  generic (
    g_has_fixed_length : natural := 0;
    g_pulse_overlength : natural := 5;
    g_pulse_length     : natural := 5;
    --* 0: do not include a 2-FFD resync stage on the input pulse
    --* 1: include a 2-FFD resync stage on the input pulse
    g_has_resync_stage : natural   := 0;
    g_out_level        : std_logic := '1'
  );
end tb_lm_util_pulse_stretch;

architecture tb_arch of tb_lm_util_pulse_stretch is

  constant C_CLK_TIME : time := 10 ns;

  constant C_PULSE_LEN : integer := f_sel_a_b(g_has_fixed_length, g_pulse_length, g_pulse_overlength);
  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i   : std_logic := '1';
  signal rst_n_i : std_logic := '0';
  signal pulse_i : std_logic := '0';
  signal s_pulse : time      := 1 ns;
  -- Observed signals - signals mapped to the output ports of tested entity
  signal pulse_o : std_logic;

  -- Procedure to generate two consecutive pulses with a configurable delay
  procedure p_two_pulses(signal pulse_i : out std_logic; delay_cycles : natural) is
  begin
    -- Synchronize to clock
    wait until rising_edge(clk_i);
    -- First pulse
    pulse_i <= g_out_level;
    wait until rising_edge(clk_i);
    pulse_i <= not g_out_level;
    -- Delay between pulses
    for i in 1 to delay_cycles loop
      wait until rising_edge(clk_i);
    end loop;
    -- Second pulse
    pulse_i <= g_out_level;
    wait until rising_edge(clk_i);
    pulse_i <= not g_out_level;

    -- Pause
    wait for C_CLK_TIME * (C_PULSE_LEN + 5);
  end procedure;

begin

  -- Clock generation
  clk_i <= not clk_i after C_CLK_TIME/2;

  -- Unit Under Test port map
  inst_uut : entity lm_util_lib.lm_util_pulse_stretch
    generic map(
      g_has_fixed_length => g_has_fixed_length,
      g_pulse_overlength => g_pulse_overlength,
      g_has_resync_stage => g_has_resync_stage,
      g_out_level        => g_out_level,
      g_pulse_length     => g_pulse_length
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      pulse_i => pulse_i,
      pulse_o => pulse_o
    );

  -- Add your stimulus here ... 

  process
  begin
    -- reset sequence
    pulse_i <= not g_out_level;
    rst_n_i <= '0';
    wait until rising_edge(clk_i);
    rst_n_i <= '1';
    wait until rising_edge(clk_i);

    -- Single pulse
    pulse_i <= g_out_level;
    wait until rising_edge(clk_i);
    pulse_i <= not g_out_level;
    -- Pause
    wait for C_CLK_TIME * (C_PULSE_LEN + 10);

    p_two_pulses(pulse_i, 1); -- Two consecutive pulses (1 cycle delay)
    p_two_pulses(pulse_i, 2); -- Two consecutive pulses (2 cycles delay)
    p_two_pulses(pulse_i, C_PULSE_LEN - 1); -- Two consecutive pulses (C_PULSE_LEN-1 cycles delay)
    p_two_pulses(pulse_i, C_PULSE_LEN); -- Two consecutive pulses (C_PULSE_LEN cycles delay)
    p_two_pulses(pulse_i, C_PULSE_LEN + 1); -- Two consecutive pulses (C_PULSE_LEN+1 cycles delay)

    -- Long pulse
    wait until rising_edge(clk_i);
    pulse_i <= g_out_level;
    wait for C_CLK_TIME * 5;
    pulse_i <= not g_out_level;
    -- Pause
    wait for C_CLK_TIME * (C_PULSE_LEN + 5);

    wait;
  end process;
end tb_arch;
