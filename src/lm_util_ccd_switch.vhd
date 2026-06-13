--=============================================================================
-- Module Name : lm_util_ccd_switch
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description:
-- The output goes high when switch_high_i='1' and low when
--    switch_low_i='1'.
--    If g_or_high is true then the output follows the switch_high_i immediately,
--    else it goes high in the next clk cycle.
--    If g_and_low is true then the output follows the switch_low_i immediately,
--    else it goes low in the next clk cycle.
--    The g_priority_lo defines which input has priority when switch_high_i and
--    switch_low_i are active simultaneously.
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

-------------------------------------------------------------------------------
-- LIBRARIES
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

-------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------
-- The output goes high when switch_high_i='1' and low when
-- switch_low_i='1'.
-- If g_or_high is true then the output follows the switch_high_i immediately,
-- else it goes high in the next clk cycle.
-- If g_and_low is true then the output follows the switch_low_i immediately,
-- else it goes low in the next clk cycle.
-- The g_priority_lo defines which input has priority when switch_high_i and
-- switch_low_i are active simultaneously.
entity lm_util_ccd_switch is
  generic(
    -- When TRUE then input switch_low_i has priority, else switch_high_i.
    -- Don't care when switch_high_i and switch_low_i are pulses that do not occur
    -- simultaneously.
    g_priority_lo : boolean;
    -- When TRUE and priority hi then the registered switch_level is OR-ed with the
    -- input switch_high_i to get out_level_o, else out_level_o is the registered
    -- switch_level
    g_or_high     : boolean;
    -- When TRUE and priority lo then the registered switch_level is AND-ed with the
    -- input switch_low_i to get out_level_o, else out_level_o is the registered
    -- switch_level
    g_and_low     : boolean
    );
  port(
    -- input clock
    clk_i         : in  std_logic;
    -- input reset
    rst_n_i       : in  std_logic;
    -- A pulse on switch_high_i makes the out_level go high
    switch_high_i : in  std_logic;
    -- A pulse on switch_low_i makes the out_level go low
    switch_low_i  : in  std_logic;
    -- output data
    out_level_o   : out std_logic
    );
end lm_util_ccd_switch;

-------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------
architecture a_rtl of lm_util_ccd_switch is
  --`protect begin
  signal s_switch_level      : std_logic;
  signal s_next_switch_level : std_logic;

begin
  gen_wire : if g_or_high = false and g_and_low = false generate
    out_level_o <= s_switch_level;
  end generate gen_wire;

  gen_or : if g_or_high = true and g_and_low = false generate
    out_level_o <= s_switch_level or switch_high_i;
  end generate gen_or;

  gen_and : if g_or_high = false and g_and_low = true generate
    out_level_o <= s_switch_level and (not switch_low_i);
  end generate gen_and;

  gen_or_and : if g_or_high = true and g_and_low = true generate
    gen_or_and_priority_lo : if g_priority_lo generate
      out_level_o <= (s_switch_level or switch_high_i) and (not switch_low_i);
    end generate gen_or_and_priority_lo;
    gen_or_and_priority_high : if not g_priority_lo generate
      out_level_o <= switch_high_i or (s_switch_level and not switch_low_i);
    end generate gen_or_and_priority_high;
  end generate gen_or_and;

  proc_reg : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        s_switch_level <= '0';
      else
        s_switch_level <= s_next_switch_level;
      end if;
    end if;
  end process proc_reg;

  proc_switch_level : process(s_switch_level, switch_low_i, switch_high_i)
  begin
    s_next_switch_level <= s_switch_level;
    if g_priority_lo = true then
      if switch_low_i = '1' then
        s_next_switch_level <= '0';
      elsif switch_high_i = '1' then
        s_next_switch_level <= '1';
      end if;
    else
      if switch_high_i = '1' then
        s_next_switch_level <= '1';
      elsif switch_low_i = '1' then
        s_next_switch_level <= '0';
      end if;
    end if;
  end process proc_switch_level;
--`protect end
end a_rtl;

