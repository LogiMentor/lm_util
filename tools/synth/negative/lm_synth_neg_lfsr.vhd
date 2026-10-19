-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : lm_synth_neg_lfsr
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-------------------------------------------------------------------------------
-- Description:
--  Negative synthesis case, not part of the library: the ports of
--  lm_util_lfsr with a separate output register (2 * g_data_w registers, as
--  lm_util_lfsr v0.1.0) and a combinational process whose sensitivity list
--  leaves out seed_i and load_i on purpose, so that both Vivado and Quartus
--  report a warning naming this file. The registers and no_warnings checks
--  of tools/synth/run_vendor_synth.py must fail on it.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lm_synth_neg_lfsr is
  generic(
    -- data width
    g_data_w : integer
    );
  port(
    clk_i   : in  std_logic;
    rst_n_i : in  std_logic;
    load_i  : in  std_logic;
    seed_i  : in  std_logic_vector(g_data_w - 1 downto 0);
    rng_o   : out std_logic_vector(g_data_w - 1 downto 0)
    );
end lm_synth_neg_lfsr;

architecture a_rtl of lm_synth_neg_lfsr is
  signal s_state   : std_logic_vector(g_data_w - 1 downto 0);
  signal s_next    : std_logic_vector(g_data_w - 1 downto 0);
  signal s_rng_reg : std_logic_vector(g_data_w - 1 downto 0);
begin
  -- incomplete sensitivity list on purpose (seed_i and load_i missing)
  proc_next : process (s_state)
  begin
    if load_i = '1' then
      s_next <= seed_i;
    else
      s_next <= s_state(g_data_w - 2 downto 0) & (s_state(g_data_w - 1) xor s_state(g_data_w - 2));
    end if;
  end process proc_next;

  proc_reg : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        s_state   <= seed_i;
        s_rng_reg <= (others => '0');
      else
        s_state   <= s_next;
        s_rng_reg <= s_state;
      end if;
    end if;
  end process proc_reg;

  rng_o <= s_rng_reg;
end a_rtl;
