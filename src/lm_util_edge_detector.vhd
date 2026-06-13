--==============================================================================
-- Module Name : lm_util_edge_detector
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : G. Dalle Mura
--------------------------------------------------------------------------------
-- Description  : the module detect the edge of a signal based on the generic
-- g_level_edge. If g_level_edge = C_CES_RISING the module detect the rising
-- edge of the signal. If g_level_edge = C_CES_FALLING the module detect the
-- falling edge of the signal. 
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
--==============================================================================

library ieee;
use ieee.std_logic_1164.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------
--* @brief the module detect the edge of a signal based on the generic
--* g_level_edge. If g_level_edge = C_CES_RISING the module detect the rising
--* edge of the signal. If g_level_edge = C_CES_FALLING the module detect the
--* falling edge of the signal.
--* @version 1.0.0
entity lm_util_edge_detector is
  generic(
    --* Rising or falling edge event to be detected
    --* g_event_edge can be C_RISING_EDGE or C_FALLING_EDGE
    g_event_edge : integer
    );
  port(
    --* input clcok
    clk_i   : in  std_logic;
    --* signal which edge has to be detected
    din_i   : in  std_logic;
    --* detected edge
    dout_o  : out std_logic
    );
end lm_util_edge_detector;

architecture a_rtl of lm_util_edge_detector is
  signal s_din_d  : std_logic;
  signal s_strobe : std_logic := '0';

begin

  --* process to register input signal. xor operation detect both rising and
  --* falling edge. the internal condition (din_i = g_event_edge) allows to select
  --* the desired edge event
  proc_reg : process(clk_i)
  begin
    if rising_edge(clk_i) then
      s_din_d <= din_i;
      --
      if din_i = f_int2sl(g_event_edge) then
        s_strobe <= din_i xor s_din_d;
      else
        s_strobe <= '0';
      end if;
    --
    end if;
  end process proc_reg;

  dout_o <= s_strobe;

end a_rtl;

