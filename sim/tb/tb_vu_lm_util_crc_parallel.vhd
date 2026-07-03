-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_crc_parallel
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_crc_parallel
--
--              Verifies the CRC calculation for a given polynomial,
--              initialization value, and XOR output by comparing the
--              calculated CRC value with a known good value from the CRC
--              reference database.
--              see: https://reveng.sourceforge.io/crc-catalogue/all.htm
--
--              Reference crc parameters, test messages and expected results
--              are provided as generics.
--              The CRC-16/GENIBUS is used as an example.
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

entity tb_vu_lm_util_crc_parallel is
  generic (
    -- CRC-16/GENIBUS
    -- width=16 poly=0x1021 init=0xffff refin=false refout=false xorout=0xffff check=0xd64e residue=0x1d0f name="CRC-16/GENIBUS"
    g_polynomial : string  := "1021"; -- CRC Polynomial
    g_init       : string  := "FFFF"; -- Initialization value
    g_xor_out    : string  := "FFFF";-- Bits for the output XOR
    g_flip_in    : integer := 0;
    g_data_w     : integer := 8;
    --https://reveng.sourceforge.io/crc-catalogue/all.htm#crc.legend
    g_test_str  : string  := "123456789";
    g_crc_check : string  := "d64e"; -- reference value to check crc
    g_refin     : boolean := false; -- false = the characters of the message are read bit-by-bit, MSB first; true = LSB first.
    g_refout    : boolean := false; -- false = the contents of the register after reading the last message bit are unreflected before presentation; if equal to true, it specifies that they are reflected, character-by-character, before presentation. For the purpose of this definition, the reflection is performed by swapping the content of each cell with that of the cell an equal distance from the opposite end of the register; the characters of the CRC are then true images of parts of the reflected register, the character containing the original MSB always appearing first.
    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_crc_parallel;

architecture a_tb of tb_vu_lm_util_crc_parallel is
  -- Constants
  constant C_CLK_PERIOD    : time                                 := 10 ns;
  constant C_BITS_PER_CHAR : integer                              := 8;
  constant C_TOTAL_BITS    : integer                              := g_test_str'length * C_BITS_PER_CHAR;
  constant C_TOTAL_WORDS   : integer                              := C_TOTAL_BITS / g_data_w;
  constant C_POLYNOMIAL    : std_logic_vector                     := f_hex2slv(g_polynomial);
  constant C_INIT_VALUE    : std_logic_vector                     := f_hex2slv(g_init);
  constant C_XOR_OUT       : std_logic_vector                     := f_hex2slv(g_xor_out);
  constant C_CRC_CHECK     : std_logic_vector                     := f_hex2slv(g_crc_check);
  constant C_FLIP_OUT      : integer                              := f_bool2int(g_refout);
  constant C_POLY_LEN      : integer                              := C_POLYNOMIAL'length;

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity

  signal clk_i   : std_logic := '1'; -- input clock
  signal rst_n_i : std_logic := '0'; -- synchronous rst, active low
  signal init_i  : std_logic := '0'; -- synchronous crc initialization
  signal dv_i    : std_logic := '0'; -- data valid

  signal data_i  : std_logic_vector (g_data_w - 1 downto 0); -- data input parallel
  -- Observed signals - signals mapped to the output ports of tested entity
  signal match_o : std_logic; -- CRC match flag
  signal crc_o   : std_logic_vector(C_POLY_LEN - 1 downto 0); -- paralle CRC output

  function f_crc_word(
    p_crc       : std_logic_vector;
    p_word_idx  : natural;
    p_word_w    : positive;
    p_flip_in   : integer;
    p_refout    : boolean
    ) return std_logic_vector is
    constant C_CRC_W : integer := p_crc'length;
    variable v_crc   : std_logic_vector(C_CRC_W - 1 downto 0) := p_crc;
    variable v_word  : std_logic_vector(p_word_w - 1 downto 0);
    variable v_seq   : integer;
    variable v_src   : integer;
    variable v_dst   : integer;
  begin
    for bit_idx in 0 to p_word_w - 1 loop
      v_seq := p_word_idx * p_word_w + bit_idx;
      if p_refout then
        v_src := v_seq;
      else
        v_src := C_CRC_W - 1 - v_seq;
      end if;

      if p_flip_in = 1 then
        v_dst := p_word_w - 1 - (bit_idx / 8) * 8 - 7 + (bit_idx mod 8);
      else
        v_dst := p_word_w - 1 - bit_idx;
      end if;

      v_word(v_dst) := v_crc(v_src);
    end loop;
    return v_word;
  end function f_crc_word;
begin
  assert g_test_str'length > 0 report "g_test_string must be provided" severity error;
  assert C_TOTAL_BITS mod g_data_w = 0 report "C_TOTAL_BITS must be multiple of g_data_w" severity error;
  assert C_POLY_LEN mod g_data_w = 0 report "C_POLY_LEN must be multiple of g_data_w" severity error;
  assert (g_flip_in = 0) or (g_data_w mod 8 = 0) report "g_flip_in requires g_data_w to be a multiple of 8" severity error;

  -- Unit Under Test port map
  inst_dut : entity lm_util_lib.lm_util_crc_par
    generic map(
      g_polynomial   => C_POLYNOMIAL,
      g_init_value   => C_INIT_VALUE,
      g_data_w       => g_data_w,
      g_flip_data_in => g_flip_in,
      g_flip_out     => C_FLIP_OUT,
      g_xor_out      => C_XOR_OUT
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      init_i  => init_i,
      dv_i    => dv_i,
      data_i  => data_i,
      match_o => match_o,
      crc_o   => crc_o
    );

  -- Clock generation
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  proc_main : process
    variable v_msg     : std_logic_vector(C_TOTAL_BITS - 1 downto 0);
    variable v_crc     : std_logic_vector(C_POLY_LEN - 1 downto 0);
  begin
    test_runner_setup(runner, runner_cfg);

    --Convert g_test_str to bit vector
    if (g_refin and (g_flip_in = 0)) then
      v_msg := f_string2slv_lsb(g_test_str); -- reflected input bits in bytes
    else
      v_msg := f_string2slv(g_test_str);
    end if;
    info("v_msg=" & f_slv2string(v_msg));
    wait for 1 ps;

    if run("parallel") then
      -- Parallel crc generator test

      -- reset
      dv_i    <= '0';
      init_i  <= '0';
      p_wait_clk(clk_i);
      rst_n_i <= '0';
      -- deassert reset
      rst_n_i <= '1';
      p_wait_clk(clk_i);

      -- clock-in data
      dv_i <= '1';
      for i in C_TOTAL_WORDS downto 1 loop
        data_i <= v_msg(i * g_data_w - 1 downto (i - 1) * g_data_w);
        p_wait_clk(clk_i);
      end loop;
      dv_i <= '0'; -- Deassert data valid
      wait for 1 ps;
      v_crc := crc_o; -- transmitted CRC, including refout/xorout

      -- check crc output against check "reference" value
      check_equal(crc_o, C_CRC_CHECK, "Parallel CRC output (" & f_slv2hex(crc_o) & ") does not match check value (" & f_slv2hex(C_CRC_CHECK) & ")");

      --Check crc
      -- reload initial value without pulsing reset
      init_i <= '1';
      p_wait_clk(clk_i);
      init_i <= '0';
      p_wait_clk(clk_i);
      wait for 1 ps;
      check_equal(match_o, '0', "Parallel init_i did not clear match_o");

      -- clock-in data
      dv_i <= '1';
      for i in C_TOTAL_WORDS downto 1 loop
        data_i <= v_msg(i * g_data_w - 1 downto (i - 1) * g_data_w);
        p_wait_clk(clk_i);
      end loop;

      -- clock-in transmitted crc
      for word_idx in 0 to C_POLY_LEN / g_data_w - 1 loop
        data_i <= f_crc_word(v_crc, word_idx, g_data_w, g_flip_in, g_refout);
        p_wait_clk(clk_i);
      end loop;
      wait for 1 ps;

      -- check match_o, hold while dv_i is low, and clear through init_i
      check_equal(match_o, '1', "Parallel match_o was not set");
      dv_i <= '0'; -- Deassert data valid
      p_wait_clk(clk_i);
      wait for 1 ps;
      check_equal(match_o, '1', "Parallel match_o was not held when dv_i was low");

      init_i <= '1';
      p_wait_clk(clk_i);
      init_i <= '0';
      wait for 1 ps;
      check_equal(match_o, '0', "Parallel init_i did not clear match_o after a match");

    end if;

    test_runner_cleanup(runner);
  end process;

end a_tb;
