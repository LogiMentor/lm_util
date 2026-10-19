-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_lfsr
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_lfsr
--              - main_equivalence: rng_o equals the output of lm_ref_lfsr_v010,
--                the unit as released in v0.1.0, driven with the same reset,
--                load and seeds, in every cycle.
--              run.py runs this testbench with vhdl_assert_stop_level =
--              "warning": any VHDL warning (for example a NUMERIC_STD
--              truncation) fails the test.
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

entity tb_vu_lm_util_lfsr is
  generic (
    g_data_w   : integer := 8;  -- LFSR width
    -- Required for VUnit
    runner_cfg : string  := ""
  );
end tb_vu_lm_util_lfsr;

architecture a_tb of tb_vu_lm_util_lfsr is
  -- Constants
  constant C_STEPS : positive := 200;  -- free-running steps after reset and after load

  subtype t_word is std_logic_vector(g_data_w - 1 downto 0);
  type t_word_arr is array (natural range <>) of t_word;

  -- 168-bit patterns truncated to g_data_w bits; bit 0 is set, so they are
  -- nonzero at every width
  constant C_PAT_A : std_logic_vector(167 downto 0) := x"5A3C_9E17_D2B4_6F81_0C7A_E395_4B2D_F06E_8193_A5C7_1F";
  constant C_PAT_B : std_logic_vector(167 downto 0) := x"0123_4567_89AB_CDEF_FEDC_BA98_7654_3210_0F0F_F0F0_3D";

  function f_msb_only return t_word is
    variable v_word : t_word;
  begin
    v_word                := (others => '0');
    v_word(g_data_w - 1)  := '1';
    return v_word;
  end function f_msb_only;

  -- nonzero seeds
  constant C_SEEDS : t_word_arr(0 to 3) := (
    C_PAT_A(g_data_w - 1 downto 0),
    C_PAT_B(g_data_w - 1 downto 0),
    (others => '1'),
    f_msb_only
  );

  -- Stimulus signals
  signal clk_i   : std_logic := '1';
  signal rst_n_i : std_logic := '0';
  signal load_i  : std_logic := '0';
  signal seed_i  : t_word    := (others => '0');

  -- Observed signals
  signal rng_o     : t_word;
  signal ref_rng_o : t_word;
begin
  -- Unit Under Test port map
  inst_dut : entity lm_util_lib.lm_util_lfsr
    generic map(
      g_data_w => g_data_w
    )
    port map(
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      load_i  => load_i,
      seed_i  => seed_i,
      rng_o   => rng_o
    );

  -- v0.1.0 reference, same inputs
  inst_ref : entity lm_util_lib.lm_ref_lfsr_v010
    generic map(
      g_data_w => g_data_w
    )
    port map(
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      load_i  => load_i,
      seed_i  => seed_i,
      rng_o   => ref_rng_o
    );

  -- Clock generation
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  proc_main : process
    -- one clock edge, then compare with the reference
    procedure p_step_check(constant C_WHAT : string) is
    begin
      p_wait_clk(clk_i);
      wait for C_T_EPSILON;
      check_equal(rng_o, ref_rng_o, C_WHAT);
    end procedure p_step_check;
  begin
    test_runner_setup(runner, runner_cfg);
    if run("main_equivalence") then
      for i in C_SEEDS'range loop
        -- reset with seed i
        seed_i  <= C_SEEDS(i);
        rst_n_i <= '0';
        for k in 1 to 3 loop
          p_step_check("in reset, seed " & to_string(i));
        end loop;
        rst_n_i <= '1';
        for k in 1 to C_STEPS loop
          p_step_check("step " & to_string(k) & " after reset, seed " & to_string(i));
        end loop;
        -- load the next seed while running
        seed_i <= C_SEEDS((i + 1) mod C_SEEDS'length);
        load_i <= '1';
        p_step_check("load of seed " & to_string((i + 1) mod C_SEEDS'length));
        load_i <= '0';
        for k in 1 to C_STEPS loop
          p_step_check("step " & to_string(k) & " after load, seed " & to_string((i + 1) mod C_SEEDS'length));
        end loop;
      end loop;
    end if;
    test_runner_cleanup(runner);
  end process;

end architecture;
