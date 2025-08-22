--=============================================================================
-- Module Name : tb_vu_lm_util_barrel_shifter
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_barrel_shifter
--              Compares the output of the barrel shifter with the expected
--              output calculated using the rotate_left function.
--              The testbench uses VUnit for running the tests.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_barrel_shifter is
  generic (
    -- Generic parameters for the barrel shifter
    -- Width of the data bus
    g_data_w : natural := 32;
    -- Number of bits to shift
    g_shift  : natural := 5;

    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_barrel_shifter;

architecture tb_architecture of tb_vu_lm_util_barrel_shifter is
  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal nof_shifts_i : std_logic_vector(f_ceil_log2(g_data_w) - 1 downto 0);
  signal din_i        : std_logic_vector(g_data_w - 1 downto 0);
  -- Observed signals - signals mapped to the output ports of tested entity
  signal dout_o : std_logic_vector(g_data_w - 1 downto 0);
  signal s_dout : unsigned(g_data_w - 1 downto 0) := (others => '0');

begin
  uut : entity lm_util_lib.lm_util_barrel_shifter
    generic map(
      g_data_w => g_data_w
    )
    port map
    (
      nof_shifts_i => nof_shifts_i,
      din_i        => din_i,
      dout_o       => dout_o
    );

  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    -- Test case: Check barrel shifter functionality by comparing the output
    -- with the expected output calculated using rotate_left function.
    if run("rotate_left_test") then
      din_i        <= f_random_vector(g_data_w);
      nof_shifts_i <= std_logic_vector(to_unsigned(g_shift, nof_shifts_i'length));
      wait for 1 ps;
      info("din_i = " & to_string(din_i));
      s_dout <= rotate_left(unsigned(din_i), g_shift);
      wait for 1 ps;
      check_equal(dout_o, s_dout, "Wrong shift.");
    end if;

    test_runner_cleanup(runner);
  end process;
end tb_architecture;
