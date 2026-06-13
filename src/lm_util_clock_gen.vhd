--==============================================================================
-- Module Name : lm_util_clock_gen
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : Andrea Campera
--------------------------------------------------------------------------------
-- Description: clock generator, generate an output clock with programmable duty cycle
--            only if g_clock_div is even. If odd the duty cycle is less than
--            50% ( e.g. g_clock_div 7, high for 3 clock cycles and low for 4 )
--            the phase of the output clock can also be configured
--------------------------------------------------------------------------------
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
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

-------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------
-- generate an output clock with 50 % duty cycle
-- only if g_clock_div is even. If odd the duty cycle is less than
-- 50% ( e.g. g_clock_div 7, high for 3 clock cycles and low for 4
entity lm_util_clock_gen is
  generic(
    -- input clock frequency divider
    g_clock_div      : integer;
    -- output clock phase
    g_clock_phase    : integer;
    -- positive output clock cycles
    g_pos_duty_cycle : integer
    );
  port(
    clk_i   : in  std_logic;            -- input clock
    rst_n_i : in  std_logic;            -- input reset
    clk_o   : out std_logic             -- output pulse
    );
end lm_util_clock_gen;

architecture a_rtl of lm_util_clock_gen is
  signal s_count_delay : unsigned(f_ceil_log2(g_clock_div) - 1 downto 0);
  signal s_count       : unsigned(f_ceil_log2(g_clock_div) - 1 downto 0);
  -- internal divided clock, pre phase-adjustment
  signal s_clk_div     : std_logic;
  signal s_div_ena     : std_logic;
begin

  assert (g_pos_duty_cycle > 0) and (g_pos_duty_cycle < g_clock_div)
    report "g_pos_duty_cycle must be in range 1 to " & integer'image(g_clock_div-1) & ", but is " & integer'image(g_pos_duty_cycle)
    severity failure;

  assert (g_clock_phase >= 0) and (g_clock_phase < g_clock_div)
    report "g_clock_phase must be in range 0 to " & integer'image(g_clock_div-1) & ", but is " & integer'image(g_clock_phase)
    severity failure;

  -- generate delay if phase is greater than 0
  gen_delay : if g_clock_phase > 0 generate
    -----------------------------------------------------------------------------
    -- delay on the output clock to adjust output phase
    -----------------------------------------------------------------------------
    proc_delay : process(clk_i)
    begin
      if (clk_i'event and clk_i = '1') then
        if (rst_n_i = '0') then
          s_count_delay <= (others => '0');
          s_div_ena     <= '0';
        else
          if (s_count_delay < g_clock_phase-1) and s_div_ena = '0' then
            s_count_delay <= s_count_delay + 1;
          elsif (s_count_delay = g_clock_phase-1) then
            s_div_ena <= '1';
          end if;
        end if;
      end if;
    end process proc_delay;
  end generate gen_delay;

  -- generate wire for 0 phase adjustment
  gen_wire : if g_clock_phase = 0 generate
    s_div_ena <= '1';
  end generate gen_wire;

  -----------------------------------------------------------------------------
  -- this process divides the input frequency to generate the
  -- desired output clock rate
  -----------------------------------------------------------------------------
  proc_m_counter : process(clk_i)
  begin
    if (clk_i'event and clk_i = '1') then
      if (rst_n_i = '0') then
        s_count   <= (others => '0');
        s_clk_div <= '0';
      elsif s_div_ena = '1' then
        if (s_count < g_pos_duty_cycle) then
          s_clk_div <= '1';
          s_count   <= s_count + 1;
        elsif (s_count < g_clock_div - 1) then
          s_clk_div <= '0';
          s_count   <= s_count + 1;
        else
          s_clk_div <= '0';
          s_count   <= (others => '0');
        end if;
      end if;
    end if;
  end process proc_m_counter;

  clk_o <= s_clk_div;

end a_rtl;

