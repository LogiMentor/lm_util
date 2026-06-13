--=============================================================================
-- Module Name : lm_util_debouncer
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : ACA
-------------------------------------------------------------------------------
-- Description  : general purpose debouncer circuit with configurable length
-- 
-- 
-------------------------------------------------------------------------------
-- Copyright 2025 Logimentor Srl
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
use ieee.numeric_std.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

entity lm_util_debouncer is
  generic (
    -- debounce length in clock cycles
    g_debounce_length : natural;
    -- debounce level: 0: std_logic '0', 1: std_logic '1', 2: both ('0', and '1')
    g_debounce_lvl    : natural
    );
  port (
    clk_i   : in  std_logic;
    ce_i    : in  std_logic;
    rst_n_i : in  std_logic;
    din_i   : in  std_logic;
    dout_o  : out std_logic
    );
end lm_util_debouncer;

architecture a_rtl of lm_util_debouncer is

  signal s_din_d     : std_logic;
  signal s_din_d2    : std_logic;
  signal s_cnt       : unsigned(f_ceil_log2(g_debounce_length)-1 downto 0);
  signal s_diff      : std_logic;
  signal s_debounced : std_logic;

begin

  -- sanity checks
  assert g_debounce_lvl <= 2 report "only 0: '0', 1: '1' or 2: both debounce levels are supported" severity failure;

  proc_sample : process (clk_i)
  begin
    if (clk_i'event and clk_i = '1') then
      s_din_d  <= din_i;
      s_din_d2 <= s_din_d;
    end if;
  end process proc_sample;

  --xor 
  gen_debounce_both : if g_debounce_lvl = 2 generate
    s_diff <= s_din_d xor s_din_d2;

    -- this process assign the internal signal s_din_d2 (input sampled twice)
    -- to the output only if the debounce counter reached the debounce dength
    proc_debounce : process (clk_i)
    begin
      if rising_edge(clk_i) then
        if (rst_n_i = '0') then           --sync reset 
          s_debounced <= din_i;
        else  
          if (s_cnt = g_debounce_length - 1) then
            s_debounced <= s_din_d2;
          end if;
        end if;
      end if;
    end process proc_debounce;

  end generate gen_debounce_both;

  -- low level debouncing: falling edge detected
  gen_debounce_low : if g_debounce_lvl = 0 generate
    s_diff <= not s_din_d and s_din_d2;

    -- this process assign the internal signal s_din_d2 (input sampled twice)
    -- to the output only if the debounce counter reached the debounce dength
    proc_debounce : process (clk_i)
    begin
      if rising_edge(clk_i) then
        if (rst_n_i = '0') then           --sync reset 
          s_debounced <= din_i;
        else  
          if (s_cnt = g_debounce_length - 1) then
            s_debounced <= s_din_d2;
          elsif s_din_d2 = '1' then
            s_debounced <= s_din_d2;
          end if;
        end if;
      end if;
    end process proc_debounce;
  end generate gen_debounce_low;

  -- high level debouncing: rising edge detected
  gen_debounce_high : if g_debounce_lvl = 1 generate
    s_diff <= s_din_d and not s_din_d2;

    -- this process assign the internal signal s_din_d2 (input sampled twice)
    -- to the output only if the debounce counter reached the debounce length
    proc_debounce : process (clk_i)
    begin
      if rising_edge(clk_i) then
        if (rst_n_i = '0') then           --sync reset 
          s_debounced <= din_i;
        else  
          if (s_cnt = g_debounce_length - 1) then
            s_debounced <= s_din_d2;
          elsif s_din_d2 = '0' then
            s_debounced <= s_din_d2;
          end if;
        end if;
      end if;
    end process proc_debounce;
  end generate gen_debounce_high;

  -- this process implements a counter, the counter starts when a change is detected
  -- on the input signal (depending on g_debounce_lvl could be falling, rising or both edges)
  proc_counter : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then           --sync reset 
        s_cnt <= (others => '0');
      else
        --change detected or end of counter
        if (s_diff = '1' or s_cnt = g_debounce_length - 1) then
          s_cnt <= (others => '0');
        elsif ce_i = '1' then
          s_cnt <= s_cnt + 1;
        end if;
      end if;
    end if;
  end process proc_counter;



  -- output assignments
  dout_o <= s_debounced;

end a_rtl;

