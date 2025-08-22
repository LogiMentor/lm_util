--=============================================================================
-- Module Name : tb_lm_util_delay
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description  : this is the testbench for the lm_util_delay module, which is
--                a genric module that implements delay using shift registers
--                or a memory if the delay has too be high
--
-------------------------------------------------------------------------------
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
-------------------------------------------------------------------------------
-- Revision History:
-- Last revised:
--
--
--=============================================================================
library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

entity tb_lm_util_delay_pulse is
  -- Generic declarations of the tested unit
  generic (
    g_delay       : integer   := 3;
    g_pulse_level : std_logic := '1'
  );
end tb_lm_util_delay_pulse;

architecture tb of tb_lm_util_delay_pulse is

  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i   : std_logic := '0';
  signal rst_n_i : std_logic;
  signal din_i   : std_logic;
  -- Observed signals - signals mapped to the output ports of tested entity
  --signal dout_o        : std_logic_vector(C_DATA_W-1 downto 0);
  signal dout_o : std_logic;

begin
  clk_i <= not clk_i after 5 ns;

  -- Unit Under Test port map
  uut_inst : entity lm_util_lib.lm_util_delay_pulse
    generic map(
      g_delay       => g_delay,
      g_pulse_level => g_pulse_level
    )
    port map
    (
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      ce_i    => '1',
      din_i   => din_i,
      dout_o  => dout_o
    );
  stim_proc : process

  begin
    rst_n_i <= '0';
    din_i   <= not g_pulse_level;
    wait for 100 ns;
    wait until rising_edge(clk_i);
    rst_n_i <= '1';
    --
    wait until rising_edge(clk_i);
    din_i <= g_pulse_level;
    for i in 1 to 1 loop
      wait until rising_edge(clk_i);
    end loop;
    din_i <= not g_pulse_level;
    wait;
  end process;
end tb;
