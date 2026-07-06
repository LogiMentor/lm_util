--==============================================================================
-- Module Name : lm_util_pulse_stretch
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.Campera
--------------------------------------------------------------------------------
-- Description: Stretch a pulse from an edge defining a fixed length or an overlength
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
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

--pulse stretcher: the input pulse is active high, the output pulse is active
--at g_out_level
entity lm_util_pulse_stretch is
  generic (
    -- 1: out pulse shall have fixed length specified by the g_pulse_length generic
    -- 0: out pulse shall be stretched of g_pulse_overlength clock cycles
    g_has_fixed_length : natural;
    -- defines the length of the output pulse in clock cycles when g_has_fixed_length = 1
    g_pulse_length     : natural;
    -- defines the pulse lengthening in clock cycles when g_has_fixed_length = 0
    -- out pulse is stretched for additional g_pulse_overlength clock cycles when g_has_fixed_length = 0
    g_pulse_overlength : natural;
    -- 0: do not include a 2-FFD resync stage on the input pulse
    -- 1: include a 2-FFD resync stage on the input pulse
    g_has_resync_stage : natural;
    -- defines the logic level ('1' or '0') that represents the active state of the output pulse
    g_out_level        : std_logic
    );
  port (
    clk_i   : in  std_logic;
    rst_n_i : in  std_logic;
    pulse_i : in  std_logic;
    pulse_o : out std_logic
    );
end lm_util_pulse_stretch;

architecture a_rtl of lm_util_pulse_stretch is
  constant C_MAX_LENGTH : integer := f_max(g_pulse_length, g_pulse_overlength);
  --
  signal s_pulse_d      : std_logic;
  signal s_pulse_d2     : std_logic;
  signal s_pulse_d3     : std_logic;
  -- the stretch counter counts up to C_MAX_LENGTH included
  signal s_cnt          : unsigned(f_ceil_log2(C_MAX_LENGTH + 1)-1 downto 0);
  signal s_cnt_ena      : std_logic;

begin

  assert (g_has_fixed_length = 0) or (g_pulse_length > 0)
  report "g_pulse_length must be greater than 0 when g_has_fixed_length = 1!"
  severity failure;

  gen_resync_stage : if g_has_resync_stage = 1 generate
    --resample input async signal in the clock domain
    proc_buff : process (clk_i)
    begin
      if (rising_edge(clk_i)) then
        s_pulse_d  <= pulse_i;
        s_pulse_d2 <= s_pulse_d;
        s_pulse_d3 <= s_pulse_d2;
      end if;
    end process proc_buff;
  end generate gen_resync_stage;

  gen_input_stage : if g_has_resync_stage = 0 generate
    s_pulse_d2 <= pulse_i;
    --resample input async signal in the clock domain
    proc_buff : process (clk_i)
    begin
      if (rising_edge(clk_i)) then
        s_pulse_d3 <= pulse_i;
      end if;
    end process proc_buff;
  end generate gen_input_stage;

  -- generate fixed length
  gen_fixed_length : if g_has_fixed_length = 1 generate
    proc_cnt_ena : process (clk_i)
    begin
      if (rising_edge(clk_i)) then
        if (rst_n_i = '0') then
          s_cnt_ena <= '0';
        else
          --enable the counter on rising edge of input signal; edges arriving
          --while the fixed-length window is running are ignored
          if (s_pulse_d2 = '1' and s_pulse_d3 = '0' and s_cnt_ena = '0') then
            s_cnt_ena <= '1';
          elsif (s_cnt = g_pulse_length-1) then  --pulse complete
            s_cnt_ena <= '0';
          end if;
        end if;
      end if;
    end process proc_cnt_ena;

    proc_stretch : process (clk_i)
    begin
      if (rising_edge(clk_i)) then
        if (rst_n_i = '0') then
          s_cnt   <= (others => '0');
          pulse_o <= not g_out_level;
        else
          if (s_cnt_ena = '1') then     -- counter enabled
            -- output is active for the whole enable window, so a length of 1
            -- still produces a one-cycle pulse
            pulse_o <= g_out_level;
            if (s_cnt < g_pulse_length-1) then  --count g_pulse_length* clk_i period
              s_cnt <= s_cnt + 1;
            else
              s_cnt <= (others => '0');
            end if;
          else
            pulse_o <= not g_out_level;
            s_cnt   <= (others => '0');
          end if;
        end if;
      end if;
    end process proc_stretch;
  end generate gen_fixed_length;

  -- generate pulse stretch
  gen_stretched_pulse : if (g_has_fixed_length = 0 and g_pulse_overlength /= 0) generate
    signal s_pulse_rise_edge : std_logic;
  begin
    proc_cnt_ena : process (clk_i)
    begin
      if (rising_edge(clk_i)) then
        if (rst_n_i = '0') then
          s_cnt_ena         <= '0';
          s_pulse_rise_edge <= '0';
        else
          if (s_pulse_d2 = '1' and s_pulse_d3 = '0') then  -- rising edge
            s_pulse_rise_edge <= '1';
          else
            s_pulse_rise_edge <= '0';
          end if;

          if (s_pulse_d2 = '1' and s_pulse_d3 = '0') then     -- rising edge: cancel a running stretch window
            s_cnt_ena <= '0';
          elsif (s_pulse_d2 = '0' and s_pulse_d3 = '1') then  -- falling edge: start the stretch window
            s_cnt_ena <= '1';
          elsif (s_cnt = g_pulse_overlength) then             -- extra length elapsed
            s_cnt_ena <= '0';
          end if;
        end if;
      end if;
    end process proc_cnt_ena;

    proc_counter : process (clk_i)
    begin
      if rising_edge(clk_i) then
        if (rst_n_i = '0') then
          s_cnt <= (others => '0');
        else
          if (s_pulse_d2 = '1' and s_pulse_d3 = '0') then  -- rising edge: restart
            s_cnt <= (others => '0');
          elsif (s_cnt_ena = '1') then
            if (s_cnt < g_pulse_overlength) then
              s_cnt <= s_cnt + 1;
            else
              s_cnt <= (others => '0');
            end if;
          end if;
        end if;
      end if;
    end process proc_counter;

    proc_stretch : process (clk_i)
    begin
      if (rising_edge(clk_i)) then
        if (rst_n_i = '0') then
          pulse_o <= not g_out_level;
        else
          if s_pulse_rise_edge = '1' then
            pulse_o <= g_out_level;
          elsif (s_cnt_ena = '1' and s_cnt = g_pulse_overlength) then
            -- qualified by the enable so an idle counter (0) cannot end the
            -- pulse when g_pulse_overlength = 1
            pulse_o <= not g_out_level;
          end if;
        end if;
      end if;
    end process proc_stretch;
  end generate gen_stretched_pulse;

  gen_stretched_pulse_zero : if (g_has_fixed_length = 0 and g_pulse_overlength = 0) generate
    -- no stretch: forward the input pulse at the configured output level
    pulse_o <= pulse_i xnor g_out_level;
  end generate gen_stretched_pulse_zero;


end a_rtl;

