--=============================================================================
-- Module Name : tb_lm_util_edge_detector
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : GDM
-------------------------------------------------------------------------------
-- Description  : this is the testbench for the tb_lm_util_edge_detector 
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
library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;


entity tb_lm_util_edge_detector is
  -- Generic declarations of the tested unit
  generic(
    g_event_edge : integer   := C_RISING_EDGE
    );
end tb_lm_util_edge_detector;

architecture tb of tb_lm_util_edge_detector is
  
  constant C_WAIT : integer := 7;
  
  signal s_cnt  : unsigned(9 downto 0) := (others => '0');
  -- Stimulus signals - signals mapped to the input and inout ports of tested entity
  signal clk_i  : std_logic := '0';
  signal ce_i   : std_logic;
  signal din_i  : std_logic := '0';
  -- Observed signals - signals mapped to the output ports of tested entity
  signal dout_o : std_logic;
  -- Add your code here ...
  
begin
  
  clk_i <= not clk_i after 5 ns;
  
  UUT : entity lm_util_lib.lm_util_edge_detector
  generic map(
    g_event_edge => g_event_edge
    )
  port map(
    clk_i  => clk_i,
    din_i  => din_i,
    dout_o => dout_o
    );
  
  
  stim_proc : process
  begin
    --
    wait for 100 ns;
    --
    assert false report "Sending a pulse not matching any clk rising edge." severity error;
    --
    wait until clk_i = '1';
    wait for 1 ps;    
    din_i <= '1';
    wait until clk_i = '0';
    wait for 4 ns;
    din_i <= '0';
    for i in 0 to 40 loop
      wait until clk_i = '1';
      if dout_o /= '1' then
        if s_cnt < 20 then
          s_cnt <= s_cnt +1;
        end if;
      else
        assert dout_o = '0' report "Unexpected pulse has been output; wrong process." severity failure;  
      end if;
    end loop;
    --
    assert false report "Time has elapsed, and no pulse was output; the input pulse was too short." severity error;
    --
    wait for 100 ns;
    --
    assert false report "Sending a pulse matching a clk rising edge." severity error;
    --
    wait until clk_i = '1';
    wait for 1 ps;    
    din_i <= '1';
    wait until clk_i = '0';
    wait for 7 ns;
    din_i <= '0';
    --
    for i in 0 to 20 loop
      wait until clk_i = '1';
      if dout_o /= '1' then
        if s_cnt < 20 then
          s_cnt <= s_cnt +1;
        end if;
      else
        assert dout_o = '1' report "A pulse was missing." severity failure;  
      end if;
    end loop;
    --
    assert false report "A pulse was output; the input pulse lasted for the prescribed time." severity error;
    --
    wait for 100 ns;
    assert false report "TEST PASSED" severity failure;
    
    
    
    wait;
  end process;
  
  
  
end tb;



