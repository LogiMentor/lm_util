--=============================================================================
-- Module Name : lm_util_ccd_sync_pulse
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: cross clock domain re-synchronizer circuit
--   The in_pulse is captured in the in_clk domain and then transfered to the
--   out_clk domain. The out_pulse is also only one cycle wide and transfered
--   back to the in_clk domain to serve as an acknowledge signal to ensure
--   that the in_pulse was recognized also in case the in_clk is faster than
--   the out_clk. The in_busy is active during the entire transfer. Hence the
--   rate of pulses that can be transfered is limited by g_delay_len and by
--   the out_clk rate.
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

-- cross clock domain re-synchronizer circuit
-- The in_pulse is captured in the in_clk_i domain and then transfered to the
-- out_clk_i domain. The out_pulse_o is also only one cycle wide and transfered
-- back to the in_clk_i domain to serve as an acknowledge signal to ensure
-- that the in_pulse was recognized also in case the in_clk_i is faster than
-- the out_clk_i. The in_busy_o is active during the entire transfer. Hence the
-- rate of pulses that can be transfered is limited by g_delay_len and by
-- the out_clk_i rate.
entity lm_util_ccd_sync_pulse is
  generic(
    -- number of resync stage to reduce metastability
    g_delay_len : natural
  );
  port(
    -- input clock
    in_clk_i : in std_logic;
    -- input reset
    in_rst_n_i : in std_logic;
    -- input pulse
    in_pulse_i : in std_logic;
    -- indicates whether the module is busy
    in_busy_o : out std_logic;
    -- output reset
    out_rst_n_i : in std_logic;
    -- output clock
    out_clk_i : in std_logic;
    -- output clock enable
    out_ce_i : in std_logic;
    -- outpu pulse
    out_pulse_o : out std_logic
  );
end lm_util_ccd_sync_pulse;

architecture a_rtl of lm_util_ccd_sync_pulse is
  signal s_in_level       : std_logic;
  signal s_meta_level     : std_logic_vector(g_delay_len-1 downto 0);
  signal s_out_level      : std_logic;
  signal s_prev_out_level : std_logic;
  signal s_meta_ack       : std_logic_vector(g_delay_len-1 downto 0);
  signal s_pulse_ack      : std_logic;
  signal s_next_out_pulse : std_logic;

  -- keep the synchronizer flops discrete and adjacent: without these the
  -- chains can be mapped to SRL primitives, losing the metastability filtering
  attribute async_reg     : string;
  attribute shreg_extract : string;
  attribute async_reg of s_meta_level     : signal is "true";
  attribute shreg_extract of s_meta_level : signal is "no";
  attribute async_reg of s_meta_ack       : signal is "true";
  attribute shreg_extract of s_meta_ack   : signal is "no";

begin

  assert g_delay_len >= 2
  report "g_delay_len must be at least 2 to combat metastability!"
  severity failure;
  inst_capture_in_pulse : entity lm_util_lib.lm_util_ccd_switch
    generic map(
      g_priority_lo => true,
      g_or_high     => false,
      g_and_low     => false
    )
    port map(
      clk_i         => in_clk_i,
      rst_n_i       => in_rst_n_i,
      switch_high_i => in_pulse_i,
      switch_low_i  => s_pulse_ack,
      out_level_o   => s_in_level
    );

  in_busy_o <= s_in_level or s_pulse_ack;

  proc_out_clk : process(out_clk_i)
  begin
    if rising_edge(out_clk_i) then
      if (out_rst_n_i = '0') then
        s_meta_level     <= (others => '0');
        s_out_level      <= '0';
        s_prev_out_level <= '0';
        out_pulse_o      <= '0';
      elsif out_ce_i = '1' then
        s_meta_level     <= s_meta_level(s_meta_level'high-1 downto 0) & s_in_level;
        s_out_level      <= s_meta_level(s_meta_level'high);
        s_prev_out_level <= s_out_level;
        out_pulse_o      <= s_next_out_pulse;
      end if;
    end if;
  end process proc_out_clk;

  proc_in_clk : process(in_clk_i)
  begin
    if rising_edge(in_clk_i) then
      if (in_rst_n_i = '0') then
        s_meta_ack  <= (others => '0');
        s_pulse_ack <= '0';
      else
        s_meta_ack  <= s_meta_ack(s_meta_ack'high-1 downto 0) & s_out_level;
        s_pulse_ack <= s_meta_ack(s_meta_ack'high);
      end if;
    end if;
  end process proc_in_clk;

  s_next_out_pulse <= s_out_level and not s_prev_out_level;
end a_rtl;

