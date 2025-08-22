library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Add your library and packages declaration here ...

entity tb_lm_util_barrel_shifter is
  -- Generic declarations of the tested unit
  generic(
    g_data_w : natural := 32
    );
end tb_lm_util_barrel_shifter;

architecture tb_arch of tb_lm_util_barrel_shifter is
  -- Component declaration of the tested unit
  component lm_util_barrel_shifter
    generic(
      g_data_w : natural := 32
      );
    port(
      nof_shifts_i : in  std_logic_vector(f_ceil_log2(g_data_w)-1 downto 0);
      din_i        : in  std_logic_vector(g_data_w-1 downto 0);
      dout_o       : out std_logic_vector(g_data_w-1 downto 0));
  end component;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal nof_shifts_i : std_logic_vector(f_ceil_log2(g_data_w)-1 downto 0);
  signal din_i        : std_logic_vector(g_data_w-1 downto 0);
  -- Observed signals - signals mapped to the output ports of tested entity
  signal dout_o       : std_logic_vector(g_data_w-1 downto 0);
  signal s_dout       : unsigned(g_data_w-1 downto 0) := (others => '0');

  -- Add your code here ...

begin

  -- Unit Under Test port map
  UUT : lm_util_barrel_shifter
    generic map (
      g_data_w => g_data_w
      )
    port map (
      nof_shifts_i => nof_shifts_i,
      din_i        => din_i,
      dout_o       => dout_o
      );

  proc_stim : process
  begin
    wait for 30 ns;
    din_i        <= x"00112233";
    --
    assert false report "Applying shift." severity error;
    nof_shifts_i <= std_logic_vector(to_unsigned(5, nof_shifts_i'length));
    wait for 1 ps;
    s_dout <= shift_left(unsigned(din_i),5);
    s_dout(4 downto 0) <= unsigned(din_i(g_data_w-1 downto g_data_w-1-4));
    wait for 1 ps;
    assert s_dout = unsigned(dout_o) report "Wrong shift." severity failure;
    assert false report "Good shift." severity error;
    --
    wait for 30 ns;
    din_i        <= x"00112233";
    nof_shifts_i <= std_logic_vector(to_unsigned(1, nof_shifts_i'length));
    wait for 1 ps;
    s_dout <= shift_left(unsigned(din_i),1);
    s_dout(0 downto 0) <= unsigned(din_i(g_data_w-1 downto g_data_w-1-0));
    wait for 1 ps;
    assert s_dout = unsigned(dout_o) report "Wrong shift." severity failure;
    assert false report "Good shift." severity error;
    --
    wait for 30 ns;
    din_i        <= x"00112233";
    nof_shifts_i <= std_logic_vector(to_unsigned(2, nof_shifts_i'length)); 
    wait for 1 ps;
    s_dout <= shift_left(unsigned(din_i),2);
    s_dout(1 downto 0) <= unsigned(din_i(g_data_w-1 downto g_data_w-1-1));
    wait for 1 ps;
    assert s_dout = unsigned(dout_o) report "Wrong shift." severity failure;
    assert false report "Good shift." severity error;
    --
    wait for 30 ns;
    din_i        <= x"00112233";
    nof_shifts_i <= std_logic_vector(to_unsigned(3, nof_shifts_i'length));
    wait for 1 ps;
    s_dout <= shift_left(unsigned(din_i),3);
    s_dout(2 downto 0) <= unsigned(din_i(g_data_w-1 downto g_data_w-1-2));
    wait for 1 ps;
    assert s_dout = unsigned(dout_o) report "Wrong shift." severity failure;
    assert false report "Good shift." severity error;
    --
    wait for 30 ns;
    din_i        <= x"00112233";
    nof_shifts_i <= std_logic_vector(to_unsigned(11, nof_shifts_i'length));
    wait for 1 ps;
    s_dout <= shift_left(unsigned(din_i),11);
    s_dout(10 downto 0) <= unsigned(din_i(g_data_w-1 downto g_data_w-1-10));
    wait for 1 ps;
    assert s_dout = unsigned(dout_o) report "Wrong shift." severity failure;
    assert false report "Good shift." severity error;
    --
    wait for 30 ns;
    din_i        <= x"00112233";
    nof_shifts_i <= std_logic_vector(to_unsigned(12, nof_shifts_i'length));
    wait for 1 ps;
    s_dout <= shift_left(unsigned(din_i),12);
    s_dout(11 downto 0) <= unsigned(din_i(g_data_w-1 downto g_data_w-1-11));
    wait for 1 ps;
    assert s_dout = unsigned(dout_o) report "Wrong shift." severity failure;
    assert false report "Good shift." severity error;
    --
    wait for 30 ns;
    din_i        <= x"00112233";
    nof_shifts_i <= std_logic_vector(to_unsigned(13, nof_shifts_i'length));
    wait for 1 ps;
    s_dout <= shift_left(unsigned(din_i),13);
    s_dout(12 downto 0) <= unsigned(din_i(g_data_w-1 downto g_data_w-1-12));
    wait for 1 ps;
    assert s_dout = unsigned(dout_o) report "Wrong shift." severity failure;
    assert false report "Good shift." severity error;
    --
    wait for 30 ns;
    din_i        <= x"00112233";
    nof_shifts_i <= std_logic_vector(to_unsigned(14, nof_shifts_i'length));
    wait for 1 ps;
    s_dout <= shift_left(unsigned(din_i),14);
    s_dout(2 downto 0) <= unsigned(din_i(g_data_w-1-11 downto g_data_w-1-13));
    wait for 1 ps;
    assert s_dout = unsigned(dout_o) report "Wrong shift." severity failure;
    assert false report "Good shift." severity error;
    --
    wait for 100 ns;
    --
    assert false report "TEST PASSED." severity failure;
    
    
    wait;
  end process;

end tb_arch;


