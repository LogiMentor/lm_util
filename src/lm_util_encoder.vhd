--=============================================================================
-- Module Name : lm_util_encoder
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: general purpose encoder
--
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
use ieee.numeric_std.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

-- general purpose encoder
entity lm_util_encoder is
  generic(
    -- input data width
    g_data_w : integer
    );
  port(
    -- input clock
    clk_i   : in  std_logic;
    -- input data valid
    dv_i    : in  std_logic;
    -- input data
    din_i   : in  std_logic_vector(g_data_w - 1 downto 0);
    -- output data valid
    dv_o    : out std_logic;
    -- output encoded data
    dout_o  : out std_logic_vector(f_ceil_log2(g_data_w) - 1 downto 0)
    );
end entity lm_util_encoder;

architecture a_rtl of lm_util_encoder is
--`protect begin
begin
  proc_enc : process(clk_i)
  begin
    if rising_edge(clk_i) then
      dv_o <= dv_i;
      if dv_i = '1' then
        for k in 0 to g_data_w - 1 loop
          if din_i(k) = '1' then
            dout_o <= std_logic_vector(to_unsigned(k, f_ceil_log2(g_data_w)));
          end if;
        end loop;
      end if;
    end if;
  end process proc_enc;
--`protect end
end a_rtl;


