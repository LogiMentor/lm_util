--=============================================================================
-- Module Name : lm_util_mux
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description : general purpose multiplexer
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

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

--* @brief general purpose multiplexer
--* @version 1.0.0
entity lm_util_mux is
  generic(
    --* input data width
    g_data_w     : integer;
    --* implementation type, C_CES_COMB: combinatorial mux, C_CES_SYNC: synchronuous mux
    g_arch_type  : integer;
    --* number of inputs
    g_nof_inputs : integer
    );
  port(
    --* input clock
    clk_i  : in  std_logic;
    --* mux select control input
    sel_i  : in  std_logic_vector(f_ceil_log2(g_nof_inputs) - 1 downto 0);
    --* mux input data as concatenation of g_nof_inputs inputs of data width g_data_w
    din_i  : in  std_logic_vector(g_nof_inputs * g_data_w - 1 downto 0);
    -- output selected data
    dout_o : out std_logic_vector(g_data_w - 1 downto 0)
    );
end entity lm_util_mux;

architecture a_rtl of lm_util_mux is
  --`protect begin
  type t_mux_array is array (natural range 0 to g_nof_inputs - 1) of std_logic_vector(g_data_w - 1 downto 0);
  signal s_array_val : t_mux_array;

begin
  assert g_arch_type = C_CES_COMB or g_arch_type = C_CES_SYNC
    report "lm_util_mux: architecture could only be 0:comb or 1: sync"
    severity failure;

  gen_comb : if g_arch_type = C_CES_COMB generate
    gen_mux : for i in s_array_val'range generate
      s_array_val(i) <= din_i(dout_o'left + (i * g_data_w) downto i * g_data_w);
    end generate;

    dout_o <= s_array_val(f_slv2nat(sel_i));
  end generate gen_comb;

  gen_sync : if g_arch_type = C_CES_SYNC generate
    gen_mux : for i in s_array_val'range generate
      proc_mux : process(clk_i)
      begin
        if rising_edge(clk_i) then
          s_array_val(i) <= din_i(dout_o'left + (i * g_data_w) downto i * g_data_w);
        end if;
      end process proc_mux;
    end generate;

    dout_o <= s_array_val(f_slv2nat(sel_i));
  end generate gen_sync;
--`protect end
end architecture a_rtl;


