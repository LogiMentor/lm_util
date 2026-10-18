-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : lm_synth_neg_renamed
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-------------------------------------------------------------------------------
-- Description:
--  Negative synthesis case, not part of the library: a correctly attributed
--  synchronizer chain whose register signal is named s_sync_ff instead of
--  s_din_meta. Checks and constraints written for s_din_meta must report an
--  empty match instead of passing.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lm_synth_neg_renamed is
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
end lm_synth_neg_renamed;

architecture a_rtl of lm_synth_neg_renamed is
  signal s_sync_ff : std_logic_vector(g_meta_levels-1 downto 0);

  attribute async_reg     : string;
  attribute shreg_extract : string;
  attribute async_reg of s_sync_ff     : signal is "true";
  attribute shreg_extract of s_sync_ff : signal is "no";
  attribute altera_attribute : string;
  attribute altera_attribute of s_sync_ff : signal is
    "-name SYNCHRONIZER_IDENTIFICATION FORCED_IF_ASYNCHRONOUS; -name AUTO_SHIFT_REGISTER_RECOGNITION OFF";
begin
  proc_chain : process (clk_i)
  begin
    if rising_edge(clk_i) then
      s_sync_ff <= s_sync_ff(s_sync_ff'left-1 downto 0) & ccd_din_i;
    end if;
  end process proc_chain;

  ccd_din_o <= s_sync_ff(g_meta_levels-1);
end a_rtl;
