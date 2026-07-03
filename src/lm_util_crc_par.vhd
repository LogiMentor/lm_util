--=============================================================================
-- Module Name : lm_util_crc_par
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : Calliope-Louisa Sotiropoulou
-------------------------------------------------------------------------------
-- Description  : CRC generator/checker, parallel implementation.
--
--
-------------------------------------------------------------------------------
-- Copyright 2025 LogiMentor Srl
--
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity lm_util_crc_par is
  generic (
    -- CRC Polynomial
    g_polynomial : std_logic_vector       := "0001000000100001";
    -- Initialization value
    g_init_value : std_logic_vector       := x"FFFF";
    -- Data word size
    g_data_w     : integer range 2 to 256 := 8;
    -- Reflect input bits within each byte (0 not to flip)
    g_flip_data_in  : integer range 0 to 1   := 0;
    -- Reflect output CRC bits (0 not to flip)
    g_flip_out      : integer range 0 to 1   := 0;
    -- Bits for the output XOR
    g_xor_out       : std_logic_vector       := x"0000"
    );
  port (
    -- input clock
    clk_i   : in  std_logic;
    -- synchronous rst, active low
    rst_n_i : in  std_logic;
    -- synchronous reload of g_init_value, active high
    init_i  : in  std_logic := '0';
    -- clock enable
    dv_i    : in  std_logic;
    -- data input
    data_i  : in  std_logic_vector(g_data_w - 1 downto 0);
    -- CRC match flag
    match_o : out std_logic;
    -- CRC output
    crc_o   : out std_logic_vector(g_polynomial'length - 1 downto 0)
    );
end entity lm_util_crc_par;

architecture a_rtl of lm_util_crc_par is

  function f_crc_step(
    p_crc        : std_logic_vector;
    p_data       : std_logic;
    p_polynomial : std_logic_vector
    ) return std_logic_vector is
    constant C_STEP_MSB : integer := p_crc'length - 1;
    variable v_crc      : std_logic_vector(C_STEP_MSB downto 0) := p_crc;
    variable v_poly     : std_logic_vector(C_STEP_MSB downto 0) := p_polynomial;
    variable v_next     : std_logic_vector(C_STEP_MSB downto 0);
    variable v_fb       : std_logic;
  begin
    v_fb      := p_data xor v_crc(C_STEP_MSB);
    v_next(0) := v_fb;
    for i in 1 to C_STEP_MSB loop
      v_next(i) := v_crc(i - 1) xor (v_fb and v_poly(i));
    end loop;
    return v_next;
  end function f_crc_step;

  function f_crc_residue(
    p_polynomial : std_logic_vector;
    p_xor_out    : std_logic_vector;
    p_flip_out   : integer
    ) return std_logic_vector is
    constant C_RES_MSB : integer := p_polynomial'length - 1;
    variable v_crc     : std_logic_vector(C_RES_MSB downto 0) := (others => '0');
    variable v_xor     : std_logic_vector(C_RES_MSB downto 0) := p_xor_out;
  begin
    if p_flip_out = 1 then
      for i in 0 to C_RES_MSB loop
        v_crc := f_crc_step(v_crc, v_xor(i), p_polynomial);
      end loop;
    else
      for i in C_RES_MSB downto 0 loop
        v_crc := f_crc_step(v_crc, v_xor(i), p_polynomial);
      end loop;
    end if;
    return v_crc;
  end function f_crc_residue;

  constant C_MSB      : integer                          := g_polynomial'length - 1;
  constant C_INIT_MSB : integer                          := g_init_value'length - 1;
  constant C_XOR_MSB  : integer                          := g_xor_out'length - 1;
  constant C_P        : std_logic_vector(C_MSB downto 0) := g_polynomial;
  constant C_INIT     : std_logic_vector(C_MSB downto 0) := g_init_value;
  constant C_XOR_OUT  : std_logic_vector(C_MSB downto 0) := g_xor_out;
  constant C_RESIDUE  : std_logic_vector(C_MSB downto 0) := f_crc_residue(C_P, C_XOR_OUT, g_flip_out);
  constant C_DW       : integer                          := g_data_w;
  type t_fb_array is array (C_DW downto 1) of std_logic_vector(C_MSB downto 0);
  type t_dmsb_array is array (C_DW downto 1) of std_logic_vector(C_MSB downto 1);
  signal s_crca       : t_fb_array;
  signal s_da         : t_dmsb_array;
  signal s_ma         : t_dmsb_array;
  signal s_crc        : std_logic_vector(C_MSB downto 0);
  signal s_crc_flip   : std_logic_vector(C_MSB downto 0);
  signal s_crc_xor    : std_logic_vector(C_MSB downto 0);

begin

  -- Parameter checking: Invalid generics will abort simulation/synthesis
  -- Check C_MSB and C_INIT_MSB length
  assert C_MSB = C_INIT_MSB
  report "g_polynomial and g_init_value vectors must be equal length!"
  severity failure;

  assert C_MSB = C_XOR_MSB
  report "g_polynomial and g_xor_out vectors must be equal length!"
  severity failure;

  -- Check polynomial size
  assert (C_MSB >= 3) and (C_MSB <= 63)
  report "g_polynomial must be of order 4 to 64!"
  severity failure;

  -- Check that the polynomial MUST have the lsb set to 1
  assert C_P(0) = '1'
  report "g_polynomial must have lsb set to 1!"
  severity failure;

  assert (g_flip_data_in = 0) or (C_DW mod 8 = 0)
  report "g_flip_data_in requires g_data_w to be a multiple of 8!"
  severity failure;

  -- Generate vector of each data bit (input bytes reflected)
  gen_flip_in : if g_flip_data_in = 1 generate
    gen_byte : for byte_idx in 0 to (C_DW / 8) - 1 generate
      gen_bit : for bit_idx in 0 to 7 generate
        gen_dat : for j in 1 to C_MSB generate
          s_da(byte_idx * 8 + bit_idx + 1)(j) <= data_i(data_i'left - byte_idx * 8 - 7 + bit_idx);
        end generate gen_dat;
      end generate gen_bit;
    end generate gen_byte;
  end generate gen_flip_in;

  -- Generate vector of each data bit (straight input)
  gen_not_flip : if g_flip_data_in = 0 generate
    gen_ca : for i in 0 to C_DW-1 generate  -- data bits
      gen_dat : for j in 1 to C_MSB generate
        s_da(i+1)(j) <= data_i(data_i'left-i);
      end generate gen_dat;
    end generate gen_ca;
  end generate gen_not_flip;

  -- Generate vector of each CRC MSB
  gen_ms0 : for j in 1 to C_MSB generate
    s_ma(1)(j) <= s_crc(C_MSB);
  end generate gen_ms0;
  gen_msp : for i in 2 to C_DW generate
    gen_msu : for j in 1 to C_MSB generate
      s_ma(i)(j) <= s_crca(i - 1)(C_MSB);
    end generate gen_msu;
  end generate gen_msp;

  -- Generate feedback matrix
  s_crca(1)(0)              <= s_da(1)(1) xor s_crc(C_MSB);
  s_crca(1)(C_MSB downto 1) <= s_crc(C_MSB - 1 downto 0) xor ((s_da(1) xor s_ma(1)) and C_P(C_MSB downto 1));
  gen_fb : for i in 2 to C_DW generate
    s_crca(i)(0)              <= s_da(i)(1) xor s_crca(i - 1)(C_MSB);
    s_crca(i)(C_MSB downto 1) <= s_crca(i - 1)(C_MSB - 1 downto 0) xor ((s_da(i) xor s_ma(i)) and C_P(C_MSB downto 1));
  end generate gen_fb;

  -- CRC process
  proc_crc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then         -- sync reset
        s_crc   <= C_INIT;
        match_o <= '0';
      elsif init_i = '1' then
        s_crc   <= C_INIT;
        match_o <= '0';
      elsif dv_i = '1' then
        s_crc <= s_crca(C_DW);
        if s_crca(C_DW) = C_RESIDUE then
          match_o <= '1';
        else
          match_o <= '0';
        end if;
      end if;
    end if;
  end process proc_crc;

  -- Reflect the output CRC bits, based on request by generic
  gen_flip_out : if g_flip_out = 1 generate
    gen_flip : for i in 0 to s_crc'left generate
      s_crc_flip(i) <= s_crc(s_crc'left-i);
    end generate gen_flip;
  end generate gen_flip_out;
  --
  gen_flipnot_out : if g_flip_out = 0 generate
    s_crc_flip <= s_crc;
  end generate gen_flipnot_out;

  -- XOR the calculated CRC with a generic value
  gen_xor_out : for i in 0 to s_crc'left generate
    s_crc_xor(i) <= C_XOR_OUT(i) xor s_crc_flip(i);
  end generate gen_xor_out;

  -- output assignments
  crc_o <= s_crc_xor;

end architecture a_rtl;
