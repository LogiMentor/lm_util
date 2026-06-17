-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_encoder
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_encoder
--
--              This testbench verifies the encoding functionality of the
--              lm_util_encoder module. It tests the encoding of one-hot
--              inputs (din_i, dv_i) into binary indices, ensuring correct behavior
--              of dv_o, dout_o across various input patterns.

--              The testbench checks:
--              - Correct encoding of one-hot inputs
--              - Handling of all-zero inputs is not covered yet.
--              - Behavior with multiple '1's in the input is not covered yet.
--
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;
entity tb_vu_lm_util_encoder is
  generic (
    g_data_w : natural := 16; -- input data width

    runner_cfg : string
  );
end;

architecture a_tb of tb_vu_lm_util_encoder is

  constant C_CLK_PERIOD : time    := 10 ns;
  constant C_INDEX_W    : integer := f_ceil_log2(g_data_w);

  --Stimulus signals
  signal clk_i : std_logic                               := '0';
  signal dv_i  : std_logic                               := '0';
  signal din_i : std_logic_vector(g_data_w - 1 downto 0) := (others => '0');
  --Observed signal
  signal dv_o   : std_logic;
  signal dout_o : std_logic_vector(C_INDEX_W - 1 downto 0);
begin

  -- Clock generation
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  -- Unit under test
  inst_dut : entity lm_util_lib.lm_util_encoder
    generic map(
      g_data_w => g_data_w
    )
    port map
    (
      clk_i  => clk_i,
      dv_i   => dv_i,
      din_i  => din_i,
      dv_o   => dv_o,
      dout_o => dout_o
    );

  proc_test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    -- Wait for reset period
    p_wait_clk(clk_i, 2);

    -- Loop through one-hot inputs
    for i in 0 to g_data_w - 1 loop
      din_i    <= (others => '0');
      din_i(i) <= '1';
      dv_i     <= '1';
      p_wait_clk(clk_i, 1);
      dv_i <= '0';
      p_wait_clk(clk_i, 1);

      check_equal(dv_o, '1', "dv_o should be '1' for valid input");

      check_equal(unsigned(dout_o), to_unsigned(i, C_INDEX_W),
      "Incorrect encoding for input index " & integer'image(i)
      );
    end loop;

    -- All-zero input
    din_i <= (others => '0');
    dv_i  <= '1';
    p_wait_clk(clk_i, 1);
    dv_i <= '0';
    p_wait_clk(clk_i, 1);

    check_equal(dv_o, '1', "dv_o should still be '1' for zero input");
    -- Expected dout_o behavior for this case still needs definition.

    -- Multiple '1's input
    din_i    <= (others => '0');
    din_i(2) <= '1';
    din_i(5) <= '1'; -- since DUT encodes LAST '1', we expect index 5
    dv_i     <= '1';
    p_wait_clk(clk_i, 1);
    dv_i <= '0';
    p_wait_clk(clk_i, 1);

    check_equal(
    unsigned(dout_o),
    to_unsigned(5, C_INDEX_W),
    "Encoder should return index of last '1' (5)"
    );

    test_runner_cleanup(runner);
  end process;

end architecture;
