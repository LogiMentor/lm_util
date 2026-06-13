--=============================================================================
-- Module Name : lm_util_delay
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: Fixed delay for std_logic_vector signals.
--              simple counter (for pulses) implementation
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
entity lm_util_delay_pulse is
  generic(
    -- actual delay can be different from a power of 2
    g_delay       : natural;
    -- input pulse active level, used only in "pulse" mode
    g_pulse_level : std_logic
    );
  port(
    -- input clock
    clk_i   : in  std_logic;
    -- input reset
    rst_n_i : in  std_logic;
    -- clock enable
    ce_i    : in  std_logic := '1';
    -- input data
    din_i   : in  std_logic;
    -- output delayed data
    dout_o  : out std_logic
    );
end lm_util_delay_pulse;

-------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------
architecture a_rtl of lm_util_delay_pulse is
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
    -------------------------------------------------------------------------------
    -- Comments: pulse delay architecture
    -------------------------------------------------------------------------------
    constant C_LOG_DELAY : integer := f_ceil_log2(g_delay);

    -- pulse architecture signals
    signal s_pulse_cnt : unsigned(C_LOG_DELAY - 1 downto 0) := (others => '0');
    -- this signal force the cou nter to start after the first sof received
    signal s_cnt_ena   : std_logic;

  begin
    proc_cnt : process(clk_i)
    begin
      if rising_edge(clk_i) then
        if (rst_n_i = '0') then
          dout_o    <= '0';
          s_cnt_ena <= '0';
        elsif ce_i = '1' then
          if din_i = g_pulse_level then
            s_cnt_ena <= '1';
          end if;
          if din_i = g_pulse_level then
            s_pulse_cnt <= to_unsigned(1, s_pulse_cnt'length);
          elsif s_pulse_cnt = (g_delay - 1) then
            s_pulse_cnt <= to_unsigned(0, s_pulse_cnt'length);
            dout_o   <= g_pulse_level;
            s_cnt_ena   <= '0';
          elsif s_cnt_ena = '1' then
            s_pulse_cnt <= s_pulse_cnt + 1;
            dout_o   <= not g_pulse_level;
          else
            s_pulse_cnt <= s_pulse_cnt;
            dout_o   <= not g_pulse_level;
          end if;
        end if;
      end if;
    end process proc_cnt;

  end generate gen_delay;
--`protect end
end architecture a_rtl;

