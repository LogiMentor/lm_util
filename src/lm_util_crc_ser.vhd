--=============================================================================
-- Module Name : lm_util_crc_ser
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : Calliope-Louisa Sotiropoulou
-------------------------------------------------------------------------------
-- Description  : CRC generator/checker, serial implementation.
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
-- Date        Version  Author        Description
-- 30/1/2019    1.0.0   CLS           Initial Version
--
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;

entity lm_util_crc_ser is
  generic (
    --* CRC Polynomial
    g_polynomial : std_logic_vector := "0001000000100001";
    --* Initialization value
    g_init_value : std_logic_vector         := x"FFFF";
    --* Output bytes issued on reverse (0 not to flip)
    g_flip_out      : integer range 0 to 1  := 0;
    --* Bits for the output XOR
    g_xor_out       : std_logic_vector      := x"0000"
    );
  port (
    --* input clock
    clk_i   : in  std_logic;
    --* synchronous rst, active low
    rst_n_i : in  std_logic;
    --* data valid
    dv_i    : in  std_logic;
    --* data input
    data_i  : in  std_logic;
    --* flush crc, when '1' crc is flushed out on crc_o
    flush_i : in  std_logic;
    --* CRC match flag
    match_o : out std_logic;
    --* CRC output
    crc_o   : out std_logic_vector(g_polynomial'length - 1 downto 0)
    );
end entity lm_util_crc_ser;

architecture a_rtl of lm_util_crc_ser is

  constant C_MSB      : integer                          := g_polynomial'length - 1;
  constant C_INIT_MSB : integer                          := g_init_value'length - 1;
  constant C_P        : std_logic_vector(C_MSB downto 0) := g_polynomial;
  constant C_ZERO     : std_logic_vector(C_MSB downto 0) := (others => '0');
  signal s_din        : std_logic_vector(C_MSB downto 1);
  signal s_crc_msb    : std_logic_vector(C_MSB downto 1);
  signal s_crc        : std_logic_vector(C_MSB downto 0);
  signal s_crc_flip   : std_logic_vector(C_MSB downto 0);
  signal s_crc_xor    : std_logic_vector(C_MSB downto 0);
  signal s_fb         : std_logic_vector(C_MSB downto 0);

begin

  --* Parameter checking: Invalid generics will abort simulation/synthesis
  --* Check C_MSB and C_INIT_MSB length
  assert C_MSB = C_INIT_MSB report "g_polynomial and g_init_value vectors must be equal length!" severity failure;

  --* Check polynomial size
  assert (C_MSB >= 3) and (C_MSB <= 31) report "g_polynomial must be of order 4 to 32!" severity failure;

  --* Check that the polynomial MUST have the lsb set to 1 (why? this is worthless in principle)
  assert C_P(0) = '1' report "g_polynomial must have lsb set to 1!" severity failure;


  --* Create vectors of data input and C_MSB of CRC
  gen_di : for i in 1 to C_MSB generate
    s_din(i)     <= data_i;
    s_crc_msb(i) <= s_crc(C_MSB);
  end generate gen_di;

  --* Feedback signals
  s_fb(0)              <= data_i xor s_crc(C_MSB);
  s_fb(C_MSB downto 1) <= s_crc(C_MSB-1 downto 0) xor ((s_din xor s_crc_msb) and C_P(C_MSB downto 1));


  --* CRC process
  proc_crc : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then         --* sync. reset
        s_crc   <= g_init_value;
        match_o <= '0';
      else
        if dv_i = '1' then
          if flush_i = '1' then
            s_crc(0)              <= '0';
            s_crc(C_MSB downto 1) <= s_crc(C_MSB - 1 downto 0);
          else
            --* CRC generation
            s_crc <= s_fb;  
          end if;
          --* CRC match checker (if data plus CRC is clocked in without errors,
          --* the CRC register ends up with all zeroes)
          if s_fb = C_ZERO then
            match_o <= '1';
          else
            match_o <= '0';
          end if;
        end if; 
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

