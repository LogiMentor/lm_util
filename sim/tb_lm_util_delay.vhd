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



entity tb_lm_util_delay is

end tb_lm_util_delay;

architecture tb of tb_lm_util_delay is
  
  
  -- constant data width
  constant C_DATA_W    : integer := 32;
  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i         : std_logic := '0';
  signal rst_n_i         : std_logic;
  signal din_i         : std_logic_vector(C_DATA_W-1 downto 0);
  -- Observed signals - signals mapped to the output ports of tested entity
  --signal dout_o        : std_logic_vector(C_DATA_W-1 downto 0);
  signal dout_o_2      : std_logic_vector(C_DATA_W-1 downto 0);
  signal dout_o_1      : std_logic_vector(C_DATA_W-1 downto 0);
  signal dout_o_23     : std_logic_vector(C_DATA_W-1 downto 0);
  -- Add your code here ...
  
begin
  

  clk_i <= not clk_i after 5 ns;
  
  -- Unit Under Test port map
  uut_inst_2: entity lm_util_lib.lm_util_delay
  generic map (
    g_delay         => 2,
    g_data_w        => C_DATA_W
    )
  port map (
    clk_i  => clk_i,
    ce_i  => '1',
    din_i  => din_i,
    dout_o => dout_o_2
    );
  
  uut_inst_1: entity lm_util_lib.lm_util_delay_mem
  generic map (
    g_delay         => 1,
    g_data_w        => C_DATA_W
    )
  port map (
    clk_i  => clk_i,
    ce_i  => '1',
    din_i  => din_i,
    dout_o => dout_o_1
    );
  
  uut_inst_23: entity lm_util_lib.lm_util_delay_srl
  generic map (
    g_delay         => 23,
    g_data_w        => C_DATA_W,
    g_srl_depth     => 5 --todo????
    )
  port map (
    clk_i  => clk_i,
    ce_i  => '1',
    din_i  => din_i,
    dout_o => dout_o_23
    );
  
  stim_proc : process
    
  begin
    rst_n_i <= '0';
    din_i <= (others => '0');
    wait for 100 ns;
    wait until clk_i = '1';
    rst_n_i <= '1';
    --
    wait for 100 ns;
    --
    assert false report "Sending value to be delayed." severity error;
    wait until clk_i = '1';
    din_i <= (others => '1');
    --
    wait until rising_edge(clk_i);
    wait for 1 ps;
    --assert dout_o_1 = din_i report "Delayed valaue not as expected." severity failure;
    assert false report "Value correctly delayed." severity error;
    --
    wait until rising_edge(clk_i);
    wait for 1 ps;
    --assert dout_o_2 = din_i report "Delayed valaue not as expected." severity failure;
    assert false report "Value correctly delayed." severity error;
    --
    for i in 0 to 21 loop
      wait until rising_edge(clk_i);
    end loop;
    wait for 1 ps;
    --assert dout_o_1 = din_i report "Delayed valaue not as expected." severity failure;
    assert false report "Value correctly delayed." severity error;
    --
    wait for 100 ns;
    assert false report "TEST PASSED." severity failure;
    
    
    wait;
  end process;
  
  
  
  
end tb;



