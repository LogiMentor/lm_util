--=============================================================================
-- Module Name : lm_util_clock_mux
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: clock mux, this VHDL code is inspired by the clock multiplexing
--              scheme described in Altera HDL Coding Style
--              Selects one clock from multiple inputs clk_i and routes it to
--              the output clk_o, based on a one-hot encoded selection signal
--              clk_sel_i (exactly one bit must be '1').
--              This implementation is glitch-free and does not introduce any
--              timing issues or glitches during clock switching.
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


entity lm_util_clock_mux is
  generic (
    -- Sets the number of clock inputs (must be a positive integer).
    g_num_clocks : positive
    );
  port (
    -- Input clock signals: a vector of clocks, where each clock corresponds to an index in clk_sel_i.
    clk_i     : in  std_logic_vector(g_num_clocks-1 downto 0);
    -- One-hot selection signal to choose which clock to output
    clk_sel_i : in  std_logic_vector(g_num_clocks-1 downto 0);  -- one hot
    -- Output clock signal, which will be one of the input clocks based on clk_sel_i
    clk_o     : out std_logic
    );
end entity lm_util_clock_mux;

architecture a_rtl of lm_util_clock_mux is

  function f_set_mask(n : positive; k : natural) return std_logic_vector is
    variable v_ret : std_logic_vector(n-1 downto 0);
  begin
    for i in 0 to n-1 loop
      if i = k then
        v_ret(i) := '0';
      else
        v_ret(i) := '1';
      end if;
    end loop;
    return v_ret;
  end function f_set_mask;


  -- 3 registers per clock, first 2 clocked on rising edge, last one on falling edge
  signal s_ena_r0        : std_logic_vector(g_num_clocks-1 downto 0) := (others => '0');
  signal s_ena_r1        : std_logic_vector(g_num_clocks-1 downto 0) := (others => '0');
  signal s_ena_r2        : std_logic_vector(g_num_clocks-1 downto 0) := (others => '0');
  signal s_qualified_sel : std_logic_vector(g_num_clocks-1 downto 0);
-- A look-up-table (LUT) can glitch when multiple inputs
-- change simultaneously. Use the keep attribute to
-- insert a hard logic cell buffer and prevent
-- the unrelated clocks from appearing on the same LUT.
  signal s_gated_clks    : std_logic_vector(g_num_clocks-1 downto 0);

--
-- we have to set the attribute synthesis keep (or equivalent) to tell the synthesiser to use
-- different LUTs to implement the clock gating. Vivado expects keep as a
-- string attribute; a boolean-typed one is silently ignored
  attribute keep                 : string;
  attribute keep of s_gated_clks : signal is "true";
  -- the enable resampling flops synchronize the cross-coupled selects
  attribute async_reg : string;
  attribute async_reg of s_ena_r0 : signal is "true";
  attribute async_reg of s_ena_r1 : signal is "true";
begin

  gen_clocks : for k in 0 to g_num_clocks-1 generate
    signal s_tmp_mask : std_logic_vector(g_num_clocks-1 downto 0);
  begin
    -- here we want to select all other branches of the parallel structure, to and all the select signals
    -- so we want a mask like: 1110 on first branch, 1101 on second branch and so on
    s_tmp_mask <= f_set_mask(g_num_clocks, k);

    s_qualified_sel(k) <= clk_sel_i(k) and not (f_vector_or(s_ena_r2 and s_tmp_mask));

    proc_ena_rising : process(clk_i(k))
    begin
      if rising_edge(clk_i(k)) then
        s_ena_r0(k) <= s_qualified_sel(k);
        s_ena_r1(k) <= s_ena_r0(k);
      end if;
    end process proc_ena_rising;

    proc_ena_falling : process(clk_i(k))
    begin
      if falling_edge(clk_i(k)) then
        s_ena_r2(k) <= s_ena_r1(k);
      end if;
    end process proc_ena_falling;

    s_gated_clks(k) <= clk_i(k) and s_ena_r2(k);
  end generate gen_clocks;

  -- These will not exhibit simultaneous toggle by construction

  clk_o <= f_vector_or(s_gated_clks);

end architecture a_rtl;


