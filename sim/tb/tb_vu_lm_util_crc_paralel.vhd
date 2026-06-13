-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_crc_parallel
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
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
    g_polynomial : string  := "1021"; --* CRC Polynomial
    g_init       : string  := "FFFF"; --* Initialization value
    g_xor_out    : string  := "FFFF";--* Bits for the output XOR
    g_flip_in    : integer := 0;
    g_data_w     : integer := 8;
    --https://reveng.sourceforge.io/crc-catalogue/all.htm#crc.legend
    g_test_str  : string  := "123456789";
    g_crc_check : string  := "d64e"; --* reference value to check crc
    g_refin     : boolean := false; --*false = the characters of the message are read bit-by-bit, MSB first; true = LSB first.
    g_refout    : boolean := false; --*false = the contents of the register after reading the last message bit are unreflected before presentation; if equal to true, it specifies that they are reflected, character-by-character, before presentation. For the purpose of this definition, the reflection is performed by swapping the content of each cell with that of the cell an equal distance from the opposite end of the register; the characters of the CRC are then true images of parts of the reflected register, the character containing the original MSB always appearing first.
    -- Required for VUnit
    runner_cfg : string := ""
  );
end tb_vu_lm_util_crc_parallel;

architecture tb_architecture of tb_vu_lm_util_crc_parallel is
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
  constant C_CRC_ZERO      : std_logic_vector(C_POLYNOMIAL'range) := (others => '0');

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity

  signal clk_i   : std_logic := '1'; --* input clock
  signal rst_n_i : std_logic := '0'; --* synchronous rst, active low
  signal dv_i    : std_logic := '0'; --* data valid

  signal data_i  : std_logic_vector (g_data_w - 1 downto 0); --* data input paralel
  signal flush_i : std_logic := '0'; --* flush crc, when '1' crc is flushed out on crc_o
  -- Observed signals - signals mapped to the output ports of tested entity
  signal match_o : std_logic; --* CRC match flag
  signal crc_o   : std_logic_vector(C_POLY_LEN - 1 downto 0); --* paralle CRC output

  -- auxilary signals
  signal s_crc : std_logic_vector(C_POLY_LEN - 1 downto 0); --* calculated CRC
begin
  assert g_test_str'length > 0 report "g_test_string must be provided" severity error;
  assert C_TOTAL_BITS mod g_data_w = 0 report "C_TOTAL_BITS must be multiple of g_data_w" severity error;
  assert C_POLY_LEN mod g_data_w = 0 report "C_POLY_LEN must be multiple of g_data_w" severity error;

  -- Unit Under Test port map
  uut : entity lm_util_lib.lm_util_crc_par
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
      dv_i    => dv_i,
      data_i  => data_i,
      match_o => match_o,
      crc_o   => crc_o
    );

  -- Clock generation
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  main : process
    variable v_msg     : std_logic_vector(C_TOTAL_BITS - 1 downto 0);
    variable char_val  : std_logic_vector(7 downto 0); -- 8 bits for ASCII character
    variable bit_index : integer := C_TOTAL_BITS - 1;
  begin
    test_runner_setup(runner, runner_cfg);

    --Convert g_test_str to bit vector
    if (g_refin) then
      v_msg := f_string2slv_lsb(g_test_str); -- reflected input bits in bytes
    else
      v_msg := f_string2slv(g_test_str);
    end if;
    info("v_msg=" & f_slv2string(v_msg));
    wait for 1 ps;

    if run("parallel") then
      -- Paralel crc generator test

      -- reset 
      dv_i    <= '0';
      flush_i <= '0';
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
      if (g_refin) then
        s_crc <= f_flip(crc_o xor C_XOR_OUT); -- store crc in unxored form and reversed
      else
        s_crc <= crc_o xor C_XOR_OUT; -- store crc in unxored form
      end if;
      dv_i <= '0';

      -- check crc output against check "reference" value
      check_equal(crc_o, C_CRC_CHECK, "Parallel CRC output (" & f_slv2hex(crc_o) & ") does not match check value (" & f_slv2hex(C_CRC_CHECK) & ")");

      --Check crc 
      -- reset 
      rst_n_i <= '0';
      p_wait_clk(clk_i);
      -- deassert reset
      rst_n_i <= '1';
      p_wait_clk(clk_i);

      -- clock-in data
      dv_i <= '1';
      for i in C_TOTAL_WORDS downto 1 loop
        data_i <= v_msg(i * g_data_w - 1 downto (i - 1) * g_data_w);
        p_wait_clk(clk_i);
      end loop;
      -- clock-in crc (unxored)
      for i in C_POLY_LEN / g_data_w downto 1 loop
        data_i <= s_crc(i * g_data_w - 1 downto (i - 1) * g_data_w);
        p_wait_clk(clk_i);
      end loop;
      wait for 1 ps;

      -- check crc output and match_o
      check_equal(crc_o, C_CRC_ZERO xor C_XOR_OUT, "Parallel CRC output (" & f_slv2hex(crc_o) & ") is not zero after crc check");
      check_equal(match_o, '1', "Parallel match_o was not set");
      dv_i <= '0'; -- Deassert data valid

    end if;

    test_runner_cleanup(runner);
  end process;

end tb_architecture;
