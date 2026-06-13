--=============================================================================
-- Module Name : lm_util_delay
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: Fixed delay for std_logic_vector signals.
--              Shift register implementation
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

-- Variable delay for std_logic_vector signals
-- Input signal is delayed by a specific amount
-- The input is valid and is entered in the delay FIFO when ce_i is true
entity lm_util_delay is
  generic(
    -- actual delay can be different from a power of 2
    g_delay : natural;
    -- input data width
    g_data_w : natural
  );
  port(
    -- input clock
    clk_i : in std_logic;
    -- clock enable
    ce_i : in std_logic := '1';
    -- input data
    din_i : in std_logic_vector(g_data_w - 1 downto 0);
    -- output delayed data
    dout_o : out std_logic_vector(g_data_w - 1 downto 0)
  );
end lm_util_delay;

-------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------
architecture a_rtl of lm_util_delay is
--`protect begin
begin

  gen_no_delay : if g_delay = 0 generate
    dout_o <= din_i;
  end generate gen_no_delay;

  -- in case of unitary delay a single register is instantiated
  gen_unit_delay : if g_delay = 1 generate
    proc_unit_delay : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if (ce_i = '1') then
          dout_o <= din_i;
        end if;
      end if;
    end process proc_unit_delay;
  end generate gen_unit_delay;

  -- delay greater than one
  gen_delay : if g_delay > 1 generate
      -- srl architecture signals
      type t_mem_srl is array (0 to g_delay - 1) of std_logic_vector(din_i'range);
      signal s_mem_ary_srl : t_mem_srl := (others => (others => '0'));

    begin
        ------------------------------------------------------------------------------
        -- Comments: srl delay architecture
        -------------------------------------------------------------------------------
        proc_srl_delay : process(clk_i)
        begin
          if rising_edge(clk_i) then
            if ce_i = '1' then
              s_mem_ary_srl(0) <= din_i;
              for i in 1 to g_delay - 1 loop
                s_mem_ary_srl(i) <= s_mem_ary_srl(i - 1);
              end loop;
            end if;
          end if;
        end process proc_srl_delay;
        dout_o <= s_mem_ary_srl(g_delay - 1);

  end generate gen_delay;
--`protect end
end architecture a_rtl;

