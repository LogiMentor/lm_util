--=============================================================================
-- Module Name : lm_util_async_reset
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: Immediately apply reset and synchronously release it at rising clk_i
--              The first reason for recommending synchronous resets is for big
--              blocks like DSPs and block RAMs which by architecture support only
--              synchronous resets. The inference of DSPs and block RAMs is possible
--              if synchronous resets are used. Use of asynchronous resets might
--              result in these structures getting inferred in the fabric which
--              might hurt performance. In the DSP blocks, the pipeline registers
--              only support synchronous resets. In block RAMs, the output
--              registers support only synchronous resets and using output
--              registers is an advantage as it reduces the clock-to-out (Tco).
--              The rule of thumb with reset is to use synchronous reset inside
--              the FPGA, as it is automaticcally timed and need no special
--              constraint
--              The input asynchronous reset is active on g_rst_lvl, the output
--              is active low
--
--              Constrain the asynchronous input at project level (adapt
--              hierarchy/names):
--                Vivado (XDC):
--                  set_false_path -from [get_ports arst_i] -to \
--                    [get_cells -hier -filter {NAME =~ */s_resync_reg_reg[*]}]
--                Quartus (SDC):
--                  set_false_path -from [get_ports arst_i] -to [get_registers *s_resync_reg*]
--                Diamond, Synplify/LSE (SDC/LDC):
--                  set_false_path -from [get_ports arst_i] -to [get_cells */s_resync_reg*]
--              Reset release is timed by recovery/removal analysis on the
--              synchronized chain, which needs no extra constraint.
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

library ieee;
use ieee.std_logic_1164.all;
library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

-- Immediately apply reset and synchronously release it at an edge of
-- clk_i.
entity lm_util_async_reset is
  generic (
    -- number of resync stage to reduce metastability
    g_delay_len : integer;
    -- asynchronous reset level
    g_rst_lvl : std_logic
  );
  port (
    -- input reset, asynchronous, active state at generic g_rst_lvl
    arst_i : in std_logic;
    -- input clock
    clk_i : in std_logic;
    -- output resynced reset, active low
    rst_n_o : out std_logic
  );
end lm_util_async_reset;

architecture a_rtl of lm_util_async_reset is
  -- active low output reset
  constant C_OUT_RESET_LEVEL : std_logic := '0';
  -- shift register
  type t_meta_regs is array (g_delay_len - 1 downto 0) of std_logic;
  signal s_resync_reg : t_meta_regs := (others => '0');

  -- Keep the synchronizer flops discrete and adjacent for metastability
  -- hardening. Attributes are per synthesis tool; unknown ones are ignored.
  -- Xilinx Vivado
  attribute async_reg     : string;
  attribute shreg_extract : string;
  attribute async_reg of s_resync_reg     : signal is "true";
  attribute shreg_extract of s_resync_reg : signal is "no";
  -- Synplify Pro / Lattice LSE
  attribute syn_srlstyle : string;
  attribute syn_preserve : boolean;
  attribute syn_srlstyle of s_resync_reg : signal is "registers";
  attribute syn_preserve of s_resync_reg : signal is true;
  -- Intel Quartus
  attribute altera_attribute : string;
  attribute altera_attribute of s_resync_reg : signal is
    "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF";

begin

  assert g_delay_len >= 2 report "g_delay_len must be >= 2" severity failure;

  -- VENDOR INDEPENDENT

  -- When rst_n_i becomes '0' then rst_n_o follows immediately (asynchronous reset apply).
  -- When rst_n_i becomes '1' then rst_n_o follows after g_delay_len cycles (synchronous reset release).
  -- This block can also synchronise other signals than reset
  proc_resync : process (clk_i, arst_i)
  begin
    if arst_i = g_rst_lvl then
      s_resync_reg <= (others => C_OUT_RESET_LEVEL);
    else
      if rising_edge(clk_i) then
        s_resync_reg(0)                        <= not C_OUT_RESET_LEVEL;
        s_resync_reg(g_delay_len - 1 downto 1) <= s_resync_reg(g_delay_len - 2 downto 0);
      end if;
    end if;
  end process proc_resync;

  rst_n_o <= s_resync_reg(g_delay_len - 1);
end a_rtl;
