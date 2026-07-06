--=============================================================================
-- Module Name : lm_util_ccd_sync_bus
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description: cross clock domain re-synchronizer circuit
--              the secondary clock domain raises the request signal. this is
--              resynced in the primary clock domain, used to sample the data in
--              and to raise the rdy. when the secondary latches the rdy it
--              deasserts the request
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

-- cross clock domain re-synchronizer circuit

entity lm_util_ccd_sync_bus is
  generic(
    -- bus width
    g_bus_width : natural;
    -- number of resync stage to reduce metastability in internal signals
    g_meta_levels : natural
  );
  port(
    -- input clock
    in_clk_i : in std_logic;
    -- input reset (sync)
    in_rst_n_i : in std_logic;
    -- input data
    in_data_i : in std_logic_vector(g_bus_width-1 downto 0);
    -- data ready
    out_rdy_o  : out std_logic;
    -- output clock
    out_clk_i : in std_logic;
    -- data request: from the secondary clock domain
    out_req_i : in std_logic;
    -- output data
    out_data_o : out std_logic_vector(g_bus_width-1 downto 0)
  );
end lm_util_ccd_sync_bus;

architecture a_rtl of lm_util_ccd_sync_bus is

  -- request resynced in the primary clock domain
  signal s_req_prim       : std_logic;
  signal s_req_prim_d1    : std_logic;
  -- latched input data bus in primary clock domain, to ease the constraint declaration
  signal s_lm_ccd_bus_data_prim_xil  : std_logic_vector(g_bus_width-1 downto 0);
  -- latched input data bus in secondary clock domain
  signal s_lm_ccd_bus_data_secn_xil  : std_logic_vector(g_bus_width-1 downto 0);
  -- internal data valid, used to mark the valid data latched on the rising of the request
  signal s_in_data_dv     : std_logic;
  -- internal data valid, resynced on secondary clock domain
  signal s_in_data_dv_secn    : std_logic;
  signal s_in_data_dv_secn_d1 : std_logic;
  --
  signal s_out_rdy        : std_logic;

begin


    -- sample the request in the primary clock domain
    inst_resync_req : entity lm_util_lib.lm_util_ccd_resync
    generic map(
      g_meta_levels => g_meta_levels
    )
    port map(
      clk_i => in_clk_i,
      ccd_din_i => out_req_i,
      ccd_din_o => s_req_prim
    );

    -- here we latch the input data bus, on the rising of the resynced request
    -- we also toggle a signal for sampling in the secondary clock domain
    proc_latch: process(in_clk_i)
    begin
      if rising_edge(in_clk_i) then
        if in_rst_n_i = '0' then
          s_in_data_dv    <= '0';
          -- park the edge detector high so a request held asserted across the
          -- reset release is not seen as a new rising edge
          s_req_prim_d1   <= '1';
        else
          s_req_prim_d1 <= s_req_prim;
          if s_req_prim = '1' and s_req_prim_d1 = '0' then
            s_lm_ccd_bus_data_prim_xil <= in_data_i;
            s_in_data_dv    <= not s_in_data_dv;
          end if;
        end if;
      end if;
    end process proc_latch;

    -- the data valid is resynced in the secondary domain
    inst_resync_dv : entity lm_util_lib.lm_util_ccd_resync
    generic map(
      g_meta_levels => g_meta_levels
    )
    port map(
      clk_i => out_clk_i,
      ccd_din_i => s_in_data_dv,
      ccd_din_o => s_in_data_dv_secn
    );

    -- the data is sampled on the secondary domain
    proc_ccd_bus: process(out_clk_i)
    begin
      if rising_edge(out_clk_i) then
        s_in_data_dv_secn_d1 <= s_in_data_dv_secn;
        if s_in_data_dv_secn /= s_in_data_dv_secn_d1 then
          s_lm_ccd_bus_data_secn_xil <= s_lm_ccd_bus_data_prim_xil;
          s_out_rdy  <= '1';
        else
          s_out_rdy  <= '0';
        end if;
      end if;
    end process proc_ccd_bus;

    out_rdy_o     <= s_out_rdy;
    out_data_o    <= s_lm_ccd_bus_data_secn_xil;
end a_rtl;

