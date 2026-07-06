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
--              the clock domain crossing not implemented. Vendor-specific HDL
--              attributes are applied on the chain (see the architecture);
--              each tool ignores the attributes it does not know.
--              The crossing path itself must be constrained at project level;
--              adapt hierarchy/names to the instance:
--                Vivado (XDC):
--                  set_false_path -to [get_cells -hier -filter \
--                    {NAME =~ */inst_resync*/s_din_meta_reg[0]}]
--                Quartus (SDC):
--                  set_false_path -to [get_registers *s_din_meta[0]]
--                Diamond, Synplify/LSE (SDC/LDC):
--                  set_false_path -to [get_cells */s_din_meta[0]]
--              To bound the crossing latency instead of cutting it, use
--              set_max_delay (Vivado: add -datapath_only) with the same
--              -from/-to targets.
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

  -- Keep the synchronizer flops discrete and adjacent: without these the
  -- chain can be mapped to an SRL primitive, losing the metastability
  -- filtering. Attributes are per synthesis tool; unknown ones are ignored.
  -- Xilinx Vivado
  attribute async_reg     : string;
  attribute shreg_extract : string;
  attribute async_reg of s_din_meta     : signal is "true";
  attribute shreg_extract of s_din_meta : signal is "no";
  -- Synplify Pro / Lattice LSE
  attribute syn_srlstyle : string;
  attribute syn_preserve : boolean;
  attribute syn_srlstyle of s_din_meta : signal is "registers";
  attribute syn_preserve of s_din_meta : signal is true;
  -- Intel Quartus
  attribute altera_attribute : string;
  attribute altera_attribute of s_din_meta : signal is
    "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF";

begin
  -- Safety check on input generic
  assert g_meta_levels >= 2
    report "lm_util_ccd_resync: g_meta_levels must be at least 2 to combat metastability"
    severity failure;
  proc_resync : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_din_meta <= s_din_meta(s_din_meta'left-1 downto 0) & ccd_din_i;
    end if;
  end process proc_resync;

  ccd_din_o <= s_din_meta(g_meta_levels-1);

end a_rtl;

