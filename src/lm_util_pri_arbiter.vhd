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
