-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : lm_synth_neg_chain
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-------------------------------------------------------------------------------
-- Description:
--  Negative synthesis case, not part of the library: the same register chain
--  as lm_util_ccd_resync without any synchronizer attribute. The structural
--  checks of tools/synth/run_vendor_synth.py must fail on it (no ASYNC_REG,
--  shift-register packing on Vivado, no synchronizer identification on
--  Quartus).
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lm_synth_neg_chain is
  generic(
    -- number of chained registers
    g_meta_levels : integer
    );
  port(
    -- destination clock
    clk_i     : in  std_logic;
    -- asynchronous input
    ccd_din_i : in  std_logic;
    -- chain output
    ccd_din_o : out std_logic
    );
end lm_synth_neg_chain;

architecture a_rtl of lm_synth_neg_chain is
  signal s_din_meta : std_logic_vector(g_meta_levels-1 downto 0);
begin
  proc_chain : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_din_meta <= s_din_meta(s_din_meta'left-1 downto 0) & ccd_din_i;
    end if;
  end process proc_chain;

  ccd_din_o <= s_din_meta(g_meta_levels-1);
end a_rtl;
