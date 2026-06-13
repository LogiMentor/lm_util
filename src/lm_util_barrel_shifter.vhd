--=============================================================================
-- Module Name : lm_util_barrel_shift
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : ACA
-------------------------------------------------------------------------------
-- Descritpion: Structural implementation of a barrel shifter that rotates its 
-- input data to the left.
-- Multile levels of shift units are generated that combine to form a component
-- that shifts input data an arbitrary number of bits.
-- The top most level will shift half of the data width
-- the level below one quarter of the data width, etc.
-- until at the lowest level where just one bit is shifted over.
--
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
-------------------------------------------------------------------------------
-- Revision History:
-- Date         Version Author    Description
-- 04/10/2015   1.0.0   ACA       Initial release
--
--=============================================================================


library ieee;
use ieee.std_logic_1164.all;
library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

entity lm_util_barrel_shifter is
  generic (
    -- input data width
    g_data_w : natural := 32
    );
  port (
    nof_shifts_i : in  std_logic_vector(f_ceil_log2(g_data_w)-1 downto 0);
    din_i        : in  std_logic_vector(g_data_w-1 downto 0);
    dout_o       : out std_logic_vector(g_data_w-1 downto 0)
    );
end entity lm_util_barrel_shifter;

architecture a_struct of lm_util_barrel_shifter is
  type t_app_array is array (f_ceil_log2(g_data_w) downto 0) of
  std_logic_vector(g_data_w-1 downto 0);
  
  -- all the intermediate shifted signals between the multiplexers
  signal s_app_array : t_app_array;
begin
  -- assign the input and output data
  s_app_array(0) <= din_i;
  dout_o         <= s_app_array(f_ceil_log2(g_data_w));
  
  -- generate the different levels of shifters
  gen_tree : for k in 0 to f_ceil_log2(g_data_w)-1 generate
    begin
    -- generate the muxes on each level
    gen_mux : for j in 0 to 2**k-1 generate
      -- constants that describe each mux
      constant C_NOF_MUXES   : natural := 2**k;
      constant C_MUX_WIDTH   : natural := g_data_w/C_NOF_MUXES;
      constant C_MUX_START   : natural := j * C_MUX_WIDTH + C_MUX_WIDTH/2;
      constant C_MUX_END     : natural := C_MUX_START + C_MUX_WIDTH-1;
      constant C_SHIFT_INDEX : natural := f_ceil_log2(g_data_w) - k - 1;
      begin
      -- shift the data when nof_shifts_i(this level) is '1'
      gen_shift : for i in C_MUX_START to C_MUX_END generate
        begin
        -- a 2N to N mux, shifts data to the left when '1'
        -- other wise does not shift the data
        s_app_array(k+1)(i mod g_data_w) <= (s_app_array(k)(i mod g_data_w) and
        (not nof_shifts_i(C_SHIFT_INDEX))) or (s_app_array(k)((i-C_MUX_WIDTH/2) mod g_data_w) and
        nof_shifts_i(C_SHIFT_INDEX));
      end generate gen_shift;
      
    end generate gen_mux;
  end generate gen_tree;
  
end architecture a_struct;

