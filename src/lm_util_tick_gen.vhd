--==============================================================================
-- Module Name : lm_util_tick_gen
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : Andrea Campera
--------------------------------------------------------------------------------
-- Description: pulse generator, generate an output pulse for one clock cycle
--              every g_clock_div clock pulses. Ideal to generate a clock enable
--              pulse
--------------------------------------------------------------------------------
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
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

-------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------
-- pulse generator, generate a pulse of one clock cycle every
-- g_clock_div clock cycles
entity lm_util_tick_gen is
  generic(
    -- input clock frequency divider,  must be >= 1
    g_clock_div : positive
  );
  port(
    clk_i   : in  std_logic; -- input clock
    rst_n_i : in  std_logic; -- input reset, synchronous active low
    pulse_o : out std_logic  -- output pulse
  );
end lm_util_tick_gen;

architecture a_rtl of lm_util_tick_gen is
  signal s_count : unsigned(f_ceil_log2(g_clock_div) - 1 downto 0) := (others => '0');
begin

  assert g_clock_div > 1 report "g_clock_div must be > 1"  severity FAILURE;
  -----------------------------------------------------------------------------
  -- this process divides the input frequency to generate the
  -- desired output clock rate
  -----------------------------------------------------------------------------
  proc_m_counter : process(clk_i)
  begin
    if (clk_i'event and clk_i = '1') then
      if (rst_n_i = '0') then
        s_count <= (others => '0');
        pulse_o <= '0';
      else
        if (s_count < g_clock_div - 1) then
          pulse_o <= '0';
          s_count <= s_count + 1;
        else
          pulse_o <= '1';
          s_count <= (others => '0');
        end if;
      end if;
    end if;
  end process proc_m_counter;

end a_rtl;

