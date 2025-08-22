library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

entity tb_lm_util_encoder is
end entity;

architecture tb of tb_lm_util_encoder is

  constant c_data_w  : integer := 8;
  constant c_index_w : integer := f_ceil_log2(c_data_w);

  signal clk    : std_logic                               := '0';
  signal dv_i   : std_logic                               := '0';
  signal din_i  : std_logic_vector(c_data_w - 1 downto 0) := (others => '0');
  signal dv_o   : std_logic;
  signal dout_o : std_logic_vector(c_index_w - 1 downto 0);

begin

  -- Instantiate DUT
  dut : entity lm_util_lib.lm_util_encoder
    generic map(
      g_data_w => c_data_w
    )
    port map
    (
      clk_i  => clk,
      dv_i   => dv_i,
      din_i  => din_i,
      dv_o   => dv_o,
      dout_o => dout_o
    );

  -- Clock generation
  clk <= not clk after 5 ns;

  -- Stimulus process
  stim_proc : process
    variable vec : std_logic_vector(c_data_w - 1 downto 0) := (others => '0');
  begin
    -- Initial delay
    wait until rising_edge(clk);
    wait until rising_edge(clk);

    -- One-hot test vectors
    for i in 0 to c_data_w - 1 loop
      din_i <= (others => '0');
      din_i(i) <= '1';
      dv_i  <= '1';
      wait until rising_edge(clk);
      dv_i <= '0';
      wait until rising_edge(clk);
      report "Input  : " & f_slv2string(din_i);
      report "Output : " & integer'image(to_integer(unsigned(dout_o)));
      assert to_integer(unsigned(dout_o)) = i
      report "ERROR: Expected index " & integer'image(i) & ", got " & integer'image(to_integer(unsigned(dout_o)))
        severity failure;
    end loop;

    -- All zeros input
    din_i <= (others => '0');
    dv_i  <= '1';
    wait until rising_edge(clk);
    dv_i <= '0';
    wait until rising_edge(clk);
    report "Test: all-zero input";
    report "Output : " & integer'image(to_integer(unsigned(dout_o)));

    -- Multiple '1's input (expecting highest index = 6)
    din_i <= (0 => '1', 1 => '1', others => '0');
    dv_i  <= '1';
    wait until rising_edge(clk);
    dv_i <= '0';
    wait until rising_edge(clk);
    report "Test: multiple '1's input (expected last index = 6)";
    assert to_integer(unsigned(dout_o)) = 1
    report "ERROR: Expected index 1 for multiple '1's input"
      severity error;

    -- Multiple '1's input (expecting highest index = 6)
    din_i <= (0 => '1', 6 => '1', others => '0');
    dv_i  <= '1';
    wait until rising_edge(clk);
    dv_i <= '0';
    wait until rising_edge(clk);
    report "Test: multiple '1's input (expected last index = 6)";
    assert to_integer(unsigned(dout_o)) = 6
    report "ERROR: Expected index 6 for multiple '1's input"
      severity error;

    -- Multiple '1's input (expecting highest index = 6)
    din_i <= (others => '1');
    dv_i  <= '1';
    wait until rising_edge(clk);
    dv_i <= '0';
    wait until rising_edge(clk);
    report "Test: multiple '1's input (expected last index = 6)";
    assert to_integer(unsigned(dout_o)) = 6
    report "ERROR: Expected index 6 for multiple '1's input"
      severity error;

    -- Done
    report "All tests completed.";
    wait;

  end process;

end architecture;
