--=============================================================================
-- Module Name : lm_util_counter
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: general-purpose synchronous counter with optional load,
--              direction, and watchdog capabilities.
--              Counting up, the counter runs 0 .. g_wd_timer-1, then wraps to
--              zero and generates a pulse on timer_o. Counting down it runs
--              g_wd_timer-1 .. 0 (reset loads g_wd_timer-1), then wraps to
--              g_wd_timer-1 and generates a pulse on timer_o.
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
use ieee.numeric_std.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

-- general purpose counter
entity lm_util_counter is
  generic(
    -- counter data width
    g_data_w   : integer;
    -- watchdog timer value:
    g_wd_timer : integer;
    -- counter direction, 1: up, 0 : down
    g_dir      : integer
    );
  port(
    -- input clock
    clk_i      : in  std_logic;
    -- input reset
    rst_n_i    : in  std_logic;
    -- clock enable
    ce_i       : in  std_logic;
    -- active high strobe for counter loading
    load_i     : in  std_logic;
    -- data to be loaded
    load_dat_i : in  std_logic_vector(g_data_w - 1 downto 0);
    -- output counter
    cnt_o      : out std_logic_vector(g_data_w - 1 downto 0);
    -- timer output
    timer_o    : out std_logic
    );
end entity lm_util_counter;

architecture a_rtl of lm_util_counter is
  -- terminal count generating the watchdog pulse and the value reloaded after
  -- it (also the reset value), per direction
  constant C_CNT_TERMINAL : integer := f_sel_a_b(g_dir = 1, g_wd_timer - 1, 0);
  constant C_CNT_RELOAD   : integer := f_sel_a_b(g_dir = 1, 0, g_wd_timer - 1);

  signal s_cnt   : unsigned(g_data_w - 1 downto 0);
  signal s_timer : std_logic;
begin

  -- check direction
  assert g_dir = 1 or g_dir = 0 report "direction should be an integer 1: up, 0:down" severity failure;

  -- check watchdog range against the counter width; the log2 form avoids the
  -- integer overflow of 2**g_data_w for g_data_w >= 31. VHDL boolean 'and'
  -- short-circuits, so f_ceil_log2 is not called when g_wd_timer < 1
  assert (g_wd_timer >= 1) and (f_ceil_log2(g_wd_timer) <= g_data_w)
  report "g_wd_timer must be in range 1 to 2**g_data_w!"
  severity failure;

  proc_count : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        s_cnt <= to_unsigned(C_CNT_RELOAD, s_cnt'length);
      elsif (ce_i = '1') then
        if load_i = '1' then
          s_cnt <= unsigned(load_dat_i);
        elsif (s_cnt = to_unsigned(C_CNT_TERMINAL, s_cnt'length)) then
          s_cnt <= to_unsigned(C_CNT_RELOAD, s_cnt'length);
        elsif g_dir = 1 then
          s_cnt <= s_cnt + 1;
        else
          s_cnt <= s_cnt - 1;
        end if;
      end if;
    end if;
  end process proc_count;

  -- watchdog control process
  proc_timer : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if (rst_n_i = '0') then
        s_timer <= '0';
      elsif (ce_i = '1') then
        -- check the watchdog
        if s_cnt = to_unsigned(C_CNT_TERMINAL, s_cnt'length) then
          s_timer <= '1';
        else
          s_timer <= '0';
        end if;
      end if;
    end if;
  end process proc_timer;

  -- output assignments
  cnt_o   <= std_logic_vector(s_cnt);
  timer_o <= s_timer;
end architecture a_rtl;

