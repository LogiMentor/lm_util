--=============================================================================
-- Module Name : lm_util_pri_arbiter
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: priority arbiter
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
--=============================================================================

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lm_util_pri_arbiter is
	generic ( 
    g_units: integer := 7 -- number of units controlled by the arbiter
  );
	port (
		clk_i   : in    std_logic;
		rst_n_i : in    std_logic;

		req_i   : in    std_logic_vector(g_units-1 downto 0);
		ack_i   : in    std_logic;
		grant_o : out   std_logic_vector(g_units-1 downto 0)
	);
end;

architecture a_rtl of lm_util_pri_arbiter is
	signal s_grant_q  : std_logic_vector(g_units-1 downto 0);
	signal s_sel_gnt  : std_logic_vector(g_units-1 downto 0);
begin
	grant_o    <= s_grant_q;
	s_sel_gnt  <= req_i and      std_logic_vector(unsigned(not(req_i)) + 1);       -- Select new winner

	process (clk_i)
	begin
	  if rising_edge(clk_i) then
      if rst_n_i = '0' then
    		s_grant_q <= (others => '0');
    	else
    		if s_grant_q = (g_units-1 downto 0 => '0') or ack_i = '1' then
    			s_grant_q <= s_sel_gnt;
    		end if;
      end if;
	  end if;
	end process;

end a_rtl;
