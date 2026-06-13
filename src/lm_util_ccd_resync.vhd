--=============================================================================
-- Module Name : lm_util_ccd_resync
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: this module implements a re-synchronizer circuit, used in cross
--              clock domain for std_logic signals. The circuit is done with
--              g_meta_levels (usually 2) registers in the destination clock
--              domain.
--              Synthesis tools might infer SRL and not true registers, making
--              the clock domain crossing no implemented. To prevent this
--              special attributes shall be used. One way to use those
--              attributes is via HDL attribute keyword, another way would be to
--              include the constraint in a specific contraint file.
--              In both cases this process is vendor dependent
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

-------------------------------------------------------------------------------
-- ENTITY
-------------------------------------------------------------------------------
-- this module implements a re-synchronizer circuit, used in cross
-- clock domain for std_logic signals. The circuit is done with
-- g_meta_levels (usually 2) registers in the destination clock domain
entity lm_util_ccd_resync is
  generic(
    -- default nof flipflops (ff) in meta stability recovery delay line
    g_meta_levels : integer
    );
  port(
    -- input clock
    clk_i     : in  std_logic;
    -- input signal on the source clock domain
    ccd_din_i : in  std_logic;
    -- output signal on the destination clock domain
    ccd_din_o : out std_logic
    );
end lm_util_ccd_resync;

-------------------------------------------------------------------------------
-- ARCHITECTURE
-------------------------------------------------------------------------------
architecture a_rtl of lm_util_ccd_resync is
  signal s_din_meta : std_logic_vector(g_meta_levels-1 downto 0);

begin
  -- Safety check on input generic
  assert g_meta_levels >= 2
    report "lm_util_ccd_resync: g_meta_levels must be at least 2 to combat metastability"
    severity error;
  proc_resync : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_din_meta <= s_din_meta(s_din_meta'left-1 downto 0) & ccd_din_i;
    end if;
  end process proc_resync;

  ccd_din_o <= s_din_meta(g_meta_levels-1);

end a_rtl;

