--==============================================================================
-- Module Name : lm_util_clock_measure
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : Andrea Campera
--------------------------------------------------------------------------------
-- Description: clock measurement module, count the number of transition of an 
--              input clock in 1 sec with a reference clock, known frequency.
--------------------------------------------------------------------------------
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
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

-------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------
--* @brief count the number of transition of an 
--*        input clock in 1 sec with a reference clock, known frequency.
entity lm_util_clock_measure is
  generic(
    --* reference clock frequency Herts
    g_ref_clock_freq : integer;
    --* clock count width, number of bits of the clock cycles counter  
    g_clock_width : integer
  );
  port(
    --* reference input known clock
    ref_clk_i : in std_logic;
    --* input reset, active low, synchronous with ref_clk_i
    rst_n_i : in std_logic;
    --* input, clock to be measured
    clock_to_measure_i : in std_logic;
    --* output pulse
    output_frequency_hz_o : out std_logic_vector(g_clock_width-1 downto 0)
  );
end lm_util_clock_measure;

architecture a_rtl of lm_util_clock_measure is
  signal s_counter : unsigned(g_clock_width - 1 downto 0) := (others => '0');
  -- internal 1 second tick, generated with reference clock
  signal s_1s_tick : std_logic;
  -- toggling signal in reference clock domain
  signal s_1s_tick_tgl : std_logic := '0';
  -- reset in the measure clock domain
  signal s_rst_n_resync : std_logic;
  -- shift register
  type t_meta_regs is array (1 downto 0) of std_logic;
  signal s_resync_reg                 : t_meta_regs := (others => '0');  
  -- measured clock domain
  signal s_1s_tick_tgl_d  : std_logic;
  signal s_1s_tick_tgl_d2 : std_logic;
  signal s_1s_tick_tgl_d3 : std_logic;
  signal s_1s_tick_ccd    : std_logic;

  signal s_output_frequency_hz : std_logic_vector(g_clock_width-1 downto 0);
  -- output frequency ready, and ccd signals
  signal s_out_freq_rdy     : std_logic; -- in clock_to_measure_i domain
  signal s_out_freq_rdy_d   : std_logic;
  signal s_out_freq_rdy_d2  : std_logic; -- in ref_clk_i domain
  signal s_out_freq_rdy_d3  : std_logic;
begin

  inst_1s_tick : entity lm_util_lib.lm_util_tick_gen
    generic map(
      g_clock_div => g_ref_clock_freq
    )
    port map(
      clk_i   => ref_clk_i,
      rst_n_i => rst_n_i,
      pulse_o => s_1s_tick
    );

  -- pass the 1 sec tick to the measured clock domain: toggling
  proc_ccd_toggle : process(ref_clk_i)
  begin
    if rising_edge(ref_clk_i) then
      if s_1s_tick = '1' then
        s_1s_tick_tgl <= not s_1s_tick_tgl;
      end if;
    end if;
  end process proc_ccd_toggle;

  --###########################################################################
  -- measured clock domain

  proc_tgl_resample : process(clock_to_measure_i)
  begin
    if rising_edge(clock_to_measure_i) then
      s_1s_tick_tgl_d  <= s_1s_tick_tgl;
      s_1s_tick_tgl_d2 <= s_1s_tick_tgl_d;
      s_1s_tick_tgl_d3 <= s_1s_tick_tgl_d;
      s_1s_tick_ccd    <= s_1s_tick_tgl_d3 xor s_1s_tick_tgl_d;
    end if;
  end process proc_tgl_resample;

  -- When rst_n_i becomes '0' then rst_n_o follows immediately (asynchronous reset apply).
  -- When rst_n_i becomes '1' then rst_n_o follows after g_delay_len cycles (synchronous reset release).
  -- This block can also synchronise other signals than reset
  proc_resync : process(clock_to_measure_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      s_resync_reg(0) <= '0';
      s_resync_reg(1) <= '0';
    else
      if rising_edge(clock_to_measure_i) then
        s_resync_reg(0) <= '1';
        s_resync_reg(1) <= s_resync_reg(0);
      end if;
    end if;
  end process proc_resync; 
  
  s_rst_n_resync <= s_resync_reg(1);

  -----------------------------------------------------------------------------
  --* this process count with the measured clock and is reset every second
  -----------------------------------------------------------------------------
  proc_1s_counter : process(clock_to_measure_i)
  begin
    if (clock_to_measure_i'event and clock_to_measure_i = '1') then
      if s_rst_n_resync = '0' then
        s_out_freq_rdy <= '0';
        s_counter      <= (others => '0');
      elsif (s_1s_tick_ccd = '1') then
        s_counter             <= (others => '0');
        s_output_frequency_hz <= std_logic_vector(s_counter);
        s_out_freq_rdy        <= not s_out_freq_rdy;
      else
        s_counter             <= s_counter + 1;
      end if;
    end if;
  end process proc_1s_counter;
  
  --###########################################################################
  -- back to ref_clk clock domain

  proc_rdy_resample : process(ref_clk_i)
  begin
    if rising_edge(ref_clk_i) then
      s_out_freq_rdy_d  <= s_out_freq_rdy;
      s_out_freq_rdy_d2 <= s_out_freq_rdy_d;
      s_out_freq_rdy_d3 <= s_out_freq_rdy_d2;
    end if;
  end process proc_rdy_resample; 

  -----------------------------------------------------------------------------
  --* this process samples the output frequency in the reference clock domain
  -----------------------------------------------------------------------------
  proc_out_freq : process(ref_clk_i)
  begin
    if (ref_clk_i'event and ref_clk_i = '1') then
      if s_out_freq_rdy_d3 /= s_out_freq_rdy_d2 then
        output_frequency_hz_o <= s_output_frequency_hz;
      end if;
    end if;
  end process proc_out_freq;

end a_rtl;
