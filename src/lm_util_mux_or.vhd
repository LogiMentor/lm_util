--=============================================================================
-- Module Name : lm_util_mux_or
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : Mauro Osvaldella
-------------------------------------------------------------------------------
-- Description: It generates the logic OR among the input channels . The inactive
--              inputs are supposed to be at zero value. In this case the
--              or mux can be used instead or a full multiplexer.
--              The module is designed with a frame input channel structure,
--              with data valid dv, start of frame sof and end of frame eof
--              For other types of interface change accordingly removing
--              unnecessary inputs or adding new ones
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
use ieee.numeric_std.all;


-- It generates the logic OR for data and write enable
--   signals coming from the input modules.

entity lm_util_mux_or is
  generic(
    -- number of inputs
    g_num_inputs   : integer;
    -- data width
    g_data_width   : natural
    );
  port(
    clk_i         : in std_logic;
    --
    data_i        : in std_logic_vector(g_num_inputs*g_data_width - 1 downto 0);
    data_dv_i     : in std_logic_vector(g_num_inputs - 1 downto 0);
    data_sof_i    : in std_logic_vector(g_num_inputs - 1 downto 0);
    data_eof_i    : in std_logic_vector(g_num_inputs - 1 downto 0);
    --
    dout_dv_o     : out std_logic;
    dout_sof_o    : out std_logic;
    dout_eof_o    : out std_logic;
    dout_o        : out std_logic_vector(g_data_width-1 downto 0)
    );
end lm_util_mux_or;

architecture a_rtl of lm_util_mux_or is

  signal s_muxor_tmp : std_logic_vector(g_num_inputs*g_data_width-1 downto 0);
  signal s_dout      : std_logic_vector(g_data_width-1 downto 0);
  signal s_dout_we   : std_logic;
  signal s_dout_sof  : std_logic;
  signal s_dout_eof  : std_logic;

begin

  assert g_num_inputs >= 2 report "the number of inputs shall be at least 2" severity failure;

  -- assign lower part of the or
  s_muxor_tmp(g_data_width-1 downto 0) <= data_i(g_data_width-1 downto 0);

  -- OR function for output data
  gen_or : for i in 2 to g_num_inputs generate -- OR structure
    s_muxor_tmp(i*g_data_width-1 downto (i-1)*g_data_width) <= data_i(i*g_data_width-1 downto (i-1)*g_data_width) or
                                       s_muxor_tmp((i-1)*g_data_width-1 downto (i-2)*g_data_width);
  end generate gen_or;

  -- data output assignment
  s_dout <= s_muxor_tmp(g_num_inputs*g_data_width-1 downto (g_num_inputs-1)*g_data_width); -- last data contains the OR result.

  -- OR for output data valid
  s_dout_we <= '0' when unsigned(data_dv_i) = 0 else '1';

  -- OR for output Start Of Frame
  s_dout_sof <= '0' when unsigned(data_sof_i) = 0 else '1';

  -- OR for output End Of Frame
  s_dout_eof <= '0' when unsigned(data_eof_i) = 0 else '1';

-- outputs are registered
proc_reg_out : process(clk_i)
begin
  if rising_edge(clk_i) then
    dout_o    <= s_dout;
    dout_dv_o <= s_dout_we;
    dout_sof_o  <= s_dout_sof;
    dout_eof_o  <= s_dout_eof;
  end if;
end process proc_reg_out;

end a_rtl;

