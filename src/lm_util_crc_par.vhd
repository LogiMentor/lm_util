--=============================================================================
-- Module Name : lm_util_crc_par
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : Calliope-Louisa Sotiropoulou
-------------------------------------------------------------------------------
-- Description  : CRC generator/checker, parallel implementation.
--
--
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Logimentor Srl

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-------------------------------------------------------------------------------
-- Revision History:
-- Date        Version  Author         Description
-- 25/1/2019   1.0.0    CLS           Initial Version
--
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity lm_util_crc_par is
  generic (
    --* CRC Polynomial
    g_polynomial : std_logic_vector       := "0001000000100001";
    --* Initialization value
    g_init_value : std_logic_vector       := x"FFFF";
    --* Data word size
    g_data_w     : integer range 2 to 256 := 8;
    --* Input bytes sent on reverse (0 not to flip)
    g_flip_data_in  : integer range 0 to 1   := 0;
    --* Output bytes issued on reverse (0 not to flip)
    g_flip_out      : integer range 0 to 1   := 0;
    --* Bits for the output XOR
    g_xor_out       : std_logic_vector       := x"0000"
    );
  port (
    --* input clock
    clk_i   : in  std_logic;
    --* synchronous rst, active low
    rst_n_i : in  std_logic;
    --* clock enable
    dv_i    : in  std_logic;
    --* data input
    data_i  : in  std_logic_vector(g_data_w - 1 downto 0);
    --* CRC match flag
    match_o : out std_logic;
    --* CRC output
    crc_o   : out std_logic_vector(g_polynomial'length - 1 downto 0)
    );
end entity lm_util_crc_par;

architecture a_rtl of lm_util_crc_par is

  constant C_MSB      : integer                          := g_polynomial'length - 1;
  constant C_INIT_MSB : integer                          := g_init_value'length - 1;
  constant C_P        : std_logic_vector(C_MSB downto 0) := g_polynomial;
  constant C_DW       : integer                          := g_data_w;
  constant C_ZERO     : std_logic_vector(C_MSB downto 0) := (others => '0');
  type t_fb_array is array (C_DW downto 1) of std_logic_vector(C_MSB downto 0);
  type t_dmsb_array is array (C_DW downto 1) of std_logic_vector(C_MSB downto 1);
  signal s_crca       : t_fb_array;
  signal s_da         : t_dmsb_array;
  signal s_ma         : t_dmsb_array;
  signal s_crc        : std_logic_vector(C_MSB downto 0);
  signal s_crc_flip   : std_logic_vector(C_MSB downto 0);
  signal s_crc_xor    : std_logic_vector(C_MSB downto 0);

begin

  --* Parameter checking: Invalid generics will abort simulation/synthesis
  --* Check C_MSB and C_INIT_MSB length
  assert C_MSB = C_INIT_MSB
  report "g_polynomial and g_init_value vectors must be equal length!"
  severity failure;

  --* Check polynomial size
  assert (C_MSB >= 3) and (C_MSB <= 31)
  report "g_polynomial must be of order 4 to 32!"
  severity failure;

  --* Check that the polynomial MUST have the lsb set to 1
  assert C_P(0) = '1'
  report "g_polynomial must have lsb set to 1!"
  severity failure;

  --* Generate vector of each data bit (flipped input)
  gen_not_flip : if g_flip_data_in = 1 generate
    gen_ca : for i in 1 to C_DW generate  -- data bits
      gen_dat : for j in 1 to C_MSB generate
        s_da(i)(j) <= data_i(i - 1);
      end generate gen_dat;
    end generate gen_ca;
  end generate gen_not_flip;

  --* Generate vector of each data bit (straight input)
  gen_flip_in : if g_flip_data_in = 0 generate
    gen_ca : for i in 0 to C_DW-1 generate  -- data bits
      gen_dat : for j in 1 to C_MSB generate
        s_da(i+1)(j) <= data_i(data_i'left-i);
      end generate gen_dat;
    end generate gen_ca;
  end generate gen_flip_in;

  --* Generate vector of each CRC MSB
  gen_ms0 : for j in 1 to C_MSB generate
    s_ma(1)(j) <= s_crc(C_MSB);
  end generate gen_ms0;
  gen_msp : for i in 2 to C_DW generate
    gen_msu : for j in 1 to C_MSB generate
      s_ma(i)(j) <= s_crca(i - 1)(C_MSB);
    end generate gen_msu;
  end generate gen_msp;

  --* Generate feedback matrix
  s_crca(1)(0)              <= s_da(1)(1) xor s_crc(C_MSB);
  s_crca(1)(C_MSB downto 1) <= s_crc(C_MSB - 1 downto 0) xor ((s_da(1) xor s_ma(1)) and C_P(C_MSB downto 1));
  gen_fb : for i in 2 to C_DW generate
    s_crca(i)(0)              <= s_da(i)(1) xor s_crca(i - 1)(C_MSB);
    s_crca(i)(C_MSB downto 1) <= s_crca(i - 1)(C_MSB - 1 downto 0) xor ((s_da(i) xor s_ma(i)) and C_P(C_MSB downto 1));
  end generate gen_fb;

  --* CRC process
  proc_crc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then         -- sync reset
        s_crc   <= g_init_value;
        match_o <= '0';
      elsif dv_i = '1' then
        s_crc <= s_crca(C_DW);
        if s_crca(C_DW) = C_ZERO then
          match_o <= '1';
        else
          match_o <= '0';
        end if;
      else
        match_o <= '0';
      end if;
    end if;
  end process proc_crc;

  -- flip or not flip the output CRC, based on request by generic
  gen_flip_out : if g_flip_out = 1 generate--
    gen_flip : for i in 0 to s_crc'left generate
      s_crc_flip(i) <= s_crc(s_crc'left-i);
    end generate gen_flip;
  end generate gen_flip_out;
  --
  gen_flipnot_out : if g_flip_out = 0 generate
    s_crc_flip <= s_crc;
  end generate gen_flipnot_out;

  -- makes the XOR of the calculated CRC with a generic value
  gen_xor_out : for i in 0 to s_crc'left generate
    s_crc_xor(i) <= g_xor_out(i) xor s_crc_flip(i);
  end generate gen_xor_out;

  --* output assignments
  crc_o <= s_crc_xor;

end architecture a_rtl;


