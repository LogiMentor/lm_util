--=============================================================================
-- Module Name : tb_lm_util_crc 
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : Calliope-Louisa Sotiropoulou
-------------------------------------------------------------------------------
-- Description  :  CRC test bench
-- 
-- 
-------------------------------------------------------------------------------
-- Copyright (c) 2025 Logimentor Srl

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-------------------------------------------------------------------------------
-- Revision History:
-- Date        Version  Author         Description
-- 30/1/2019   1.0.0     CLS           Initial Version
-- 
--=============================================================================

library ieee;
use ieee.MATH_REAL.all;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use std.textio.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_lm_pkg.all;

entity tb_lm_util_crc is

end entity tb_lm_util_crc;

architecture a_behav of tb_lm_util_crc is

  --* Polynomial under testing
  constant C_POL_SIZE   : integer := 16;
  constant C_POLYNOMIAL : std_logic_vector(C_POL_SIZE-1 downto 0) :=
    "0001000000100001";                 -- x^16 + x^12 + x^5 + 1
  --* Initialization value
  constant C_INIT_VALUE   : std_logic_vector(C_POL_SIZE-1 downto 0)   := (others => '1');
  --* Data width for the parallel implementation
  constant C_DATA_WIDTH   : integer                                   := 8;
  --* Number of bits 
  constant C_CODE_LENGTH  : integer                                   := 128 / C_DATA_WIDTH;
  constant C_EXPECTED_CRC : std_logic_vector(C_POL_SIZE - 1 downto 0) := x"5045";
  constant C_TIME_WIDTH   : integer                                   := 15;  -- Number of chars for time field
  constant C_ZERO         : std_logic                                 := '0';

  signal s_clk      : std_logic                                        := '0';
  signal s_rst_n    : std_logic;
  signal s_flush    : std_logic                                        := '0';
  signal s_ce       : std_logic                                        := '0';
  signal s_pd_in    : std_logic;
  signal s_lsfr_reg : std_logic_vector(31 downto 0)                    := (others => '1');
  signal s_cnt      : integer range 0 to C_CODE_LENGTH*C_DATA_WIDTH+10 := 0;
  signal s_match_s  : std_logic;
  signal s_match_p  : std_logic;
  signal s_chk_in   : std_logic;
  signal s_par_ce3  : std_logic;
  signal s_par_in   : std_logic_vector(C_DATA_WIDTH - 1 downto 0);
  signal s_crc_s    : std_logic_vector(C_POL_SIZE- 1 downto 0);
  signal s_crc_sc   : std_logic_vector(C_POL_SIZE- 1 downto 0);
  signal s_crc_p    : std_logic_vector(C_POL_SIZE- 1 downto 0);
  signal s_pcnt     : integer range 0 to C_DATA_WIDTH - 1              := 0;
  
  signal s_par_ce   : std_logic := '0';
  signal s_par_ce2  : std_logic;
  signal s_match_p2 : std_logic;
  signal s_crc_p2   : std_logic_vector(31 downto 0);
  signal s_data3    : std_logic_vector(159 downto 0);  
  
  -- debug signals
  signal s_ce_dbg : std_logic;                    
  signal s_rst_dbg  : std_logic;
  signal s_data_dbg : std_logic_vector(C_DATA_WIDTH - 1 downto 0); 
  signal s_crc_dbg  : std_logic_vector(C_POL_SIZE-1 downto 0);


  shared variable v_errors : integer := 0;  -- error counter during simulation
  signal s_errors : integer := 0;  -- error counter during simulation

  procedure p_signal_check (
    constant C_MSG   : in string;        -- signal name
    constant C_VALUE : in std_logic;     -- expected value
    signal s_sig     : in std_logic) is  -- signal to check
    variable v_txt : line;
  begin
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" "));
    write(v_txt, C_MSG);
    write(v_txt, string'(" "));
    if s_sig = C_VALUE then
      write(v_txt, string'("verified to be "));
    else
      write(v_txt, string'("has incorrect value! Expected "));
      v_errors := v_errors + 1;
    end if;
    if C_VALUE = '1' then
      write(v_txt, string'("1!"));
    else
      write(v_txt, string'("0!"));
    end if;
    writeline(OUTPUT, v_txt);
  end;

  procedure p_message (
    constant C_MSG : in string) is
    variable v_txt : line;
  begin
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" -- ") & C_MSG);
    writeline(OUTPUT, v_txt);
  end;

--  procedure p_vector_check (
--    constant C_MSG   : in string;               -- signal name
--    constant C_VALUE : in std_logic_vector;     -- expected value
--    signal s_sig     : in std_logic_vector) is  -- signal to check
--    variable v_txt : line;
--  begin
--    write(v_txt, string'("@"));
--    write(v_txt, now, right, C_TIME_WIDTH);
--    write(v_txt, string'(" "));
--    write(v_txt, C_MSG);
--    write(v_txt, string'(" "));
--    if s_sig = C_VALUE then
--      write(v_txt, string'("verified to be "));
--    else
--      write(v_txt, string'("has incorrect value! Expected "));
--      write(v_txt, f_slv2hex(C_VALUE));
--      write(v_txt, string'(", but got "));
--      v_errors := v_errors + 1;
--    end if;
--    write(v_txt, f_slv2hex(s_sig));
--    writeline(OUTPUT, v_txt);
--  end;

  procedure p_wait_for_event (
    constant C_MSG     : in string;        -- message
    constant C_TIMEOUT : in time;          -- timeout
    signal s_trigger   : in std_logic) is  -- trigger signal
    variable v_txt : line;
    variable v_t1  : time;
  begin
    v_t1 := now;
    wait on s_trigger for C_TIMEOUT;
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" "));
    write(v_txt, C_MSG);
    if now - v_t1 >= C_TIMEOUT then
      write(v_txt, string'(" - Timed out!"));
      v_errors := v_errors + 1;
    else
      write(v_txt, string'(" - OK!"));
    end if;
    writeline(OUTPUT, v_txt);
  end;

  --* Report number of errors encountered during simulation
  procedure p_sim_report (
    constant C_MSG : in string) is
    variable v_txt : line;
  begin
    write(v_txt, string'("@"));
    write(v_txt, now, right, C_TIME_WIDTH);
    write(v_txt, string'(" Simulation completed with "));
    write(v_txt, v_errors);
    write(v_txt, string'(" errors!"));
    writeline(OUTPUT, v_txt);
  end;


begin


  ----------------------------------------------------------------------------
  --* Clock
  ----------------------------------------------------------------------------
  s_clk <= not s_clk after 5 ns;

  ----------------------------------------------------------------------------
  --* LFSR generates random bits as input to the CRC generators
  ----------------------------------------------------------------------------
  proc_lsfr : process (s_clk)
  begin
    if rising_edge(s_clk) then
      if s_flush = '0' then
        s_lsfr_reg(0) <= s_lsfr_reg(31) xor s_lsfr_reg(6) xor s_lsfr_reg(4)
                         xor s_lsfr_reg(2) xor s_lsfr_reg(1) xor s_lsfr_reg(0);
        s_lsfr_reg(31 downto 1) <= s_lsfr_reg(30 downto 0);
      end if;
    end if;
  end process proc_lsfr;

  ----------------------------------------------------------------------------
  --* Serial to parallel data register, used to feed the parallel implementation
  ----------------------------------------------------------------------------
  s_pd_in                    <= s_chk_in;  -- Data plus CRC 
  s_par_in(C_DATA_WIDTH - 1) <= s_pd_in;
  proc_s2p : process (s_clk)
  begin
    if rising_edge(s_clk) then
      if s_ce = '1' then
        s_par_in(C_DATA_WIDTH - 2)          <= s_pd_in;
        s_par_in(C_DATA_WIDTH - 3 downto 0) <= s_par_in(C_DATA_WIDTH - 2 downto 1);
        if s_pcnt < C_DATA_WIDTH - 1 then
          s_pcnt <= s_pcnt + 1;
        else
          s_pcnt <= 0;
        end if;
        if s_pcnt = C_DATA_WIDTH - 2 then
          s_par_ce <= '1';
        else
          s_par_ce <= '0';
        end if;
      else
        s_par_ce <= '0';
      end if;
    end if;
  end process proc_s2p;



  ----------------------------------------------------------------------------
  --* Bit counter and CRC control. Generates clken and flush signals for the
  --* serial generator.
  ---------------------------------------------------------------------------- 
  proc_bcnt : process (s_clk)
  begin
    if rising_edge(s_clk) then
      if s_cnt < C_CODE_LENGTH*C_DATA_WIDTH+10 then
        s_cnt <= s_cnt+ 1;
      end if;
      if s_cnt >= C_DATA_WIDTH and s_cnt < C_CODE_LENGTH*C_DATA_WIDTH then
        s_ce <= '1';
      else
        s_ce <= '0';
      end if;
      if (s_cnt >= C_CODE_LENGTH*C_DATA_WIDTH- C_POLYNOMIAL'length) and
        (s_cnt < C_CODE_LENGTH*C_DATA_WIDTH) then
        s_flush <= '1';
      else
        s_flush <= '0';
      end if;
    end if;
  end process proc_bcnt;

  ----------------------------------------------------------------------------
  --* Serial CRC generator. CRC is flushed out after the data block
  ---------------------------------------------------------------------------- 
  inst_uut_gen : entity lm_util_lib.lm_util_crc_ser
    generic map (
      g_polynomial => C_POLYNOMIAL,
      g_init_value => C_INIT_VALUE)
    port map (
      clk_i   => s_clk,
      rst_n_i => s_rst_n,
      dv_i    => s_ce,
      data_i  => s_lsfr_reg(0),
      flush_i => s_flush,
      match_o => open,
      crc_o   => s_crc_s);

  ----------------------------------------------------------------------------
  --* Serial CRC checker. Takes input from the serial generator, incl. CRC
  ----------------------------------------------------------------------------
  s_chk_in <= s_lsfr_reg(0) when s_flush = '0' else s_crc_s(C_POLYNOMIAL'length - 1); 
    
  inst_uut_chk : entity lm_util_lib.lm_util_crc_ser
    generic map (
      g_polynomial => C_POLYNOMIAL,
      g_init_value => C_INIT_VALUE)
    port map (
      clk_i   => s_clk,
      rst_n_i => s_rst_n,
      dv_i    => s_ce,
      data_i  => s_chk_in,
      flush_i => C_ZERO,
      match_o => s_match_s,
      crc_o   => s_crc_sc);

  ----------------------------------------------------------------------------
  --* Parallel CRC generator/checker. Takes input from the serial generator,
  --* including the CRC
  ----------------------------------------------------------------------------
  
    proc_dbg: process
    begin       
      s_ce_dbg <= '0'; 
      s_rst_dbg <= '0';
      wait for 100 ns;
      wait until rising_edge(s_clk);      
      s_rst_dbg <= '1';
      wait until rising_edge(s_clk);      
      for k in 0 to 4 loop
        wait until rising_edge(s_clk);
        s_ce_dbg <= '1';
        s_data_dbg <= x"01"; 
      end loop;
      wait until rising_edge(s_clk);
      
      --2nd run
      s_ce_dbg <= '0'; 
      s_rst_dbg <= '0';
      wait for 100 ns;
      wait until rising_edge(s_clk);      
      s_rst_dbg <= '1';
      wait until rising_edge(s_clk);      
      for k in 0 to 4 loop
        wait until rising_edge(s_clk);
        s_ce_dbg <= '1';
        s_data_dbg <= x"01"; 
      end loop;
      wait until rising_edge(s_clk);
      s_ce_dbg <= '0'; 
      
      wait;
    end process proc_dbg;
    
  inst_uut_par_gen : entity lm_util_lib.lm_util_crc_par
    generic map (
      g_polynomial => C_POLYNOMIAL,
      g_init_value => C_INIT_VALUE,
      g_data_w     => C_DATA_WIDTH)
    port map (
      clk_i   => s_clk,
      rst_n_i => s_rst_dbg,
      dv_i    => s_ce_dbg, --s_par_ce,
      data_i  => s_data_dbg, -- s_par_in,
      match_o => s_match_p,
      crc_o   => s_crc_p); 
      
      s_crc_dbg <= not s_crc_p;

  ----------------------------------------------------------------------------
  --* 128bit wide CRC generator
  ----------------------------------------------------------------------------
  inst_uut_par_chk1 : entity lm_util_lib.lm_util_crc_par
    generic map (
      g_polynomial => x"00018bb7",
      g_init_value => x"00000000",
      g_data_w     => 128,
      g_xor_out    => x"00000000")
    port map (
      clk_i   => s_clk,
      rst_n_i => s_rst_n,
      dv_i    => s_par_ce2,
      data_i  => (others => '1'),
      match_o => open,
      crc_o   => s_crc_p2);

  ----------------------------------------------------------------------------
  --* 160bit wide CRC checker
  ----------------------------------------------------------------------------
  inst_uut_par_chk2 : entity lm_util_lib.lm_util_crc_par
    generic map (
      g_polynomial => x"00018bb7",
      g_init_value => x"00000000",
      g_data_w     => 160,
      g_xor_out    => x"00000000")
    port map (
      clk_i   => s_clk,
      rst_n_i => s_rst_n,
      dv_i    => s_par_ce3,
      data_i  => s_data3,
      match_o => s_match_p2,
      crc_o   => open);

  s_data3(127 downto 0) <= (others => '1');
  gen_lcpy : for i in 0 to 31 generate  -- CRC must be MSB first!
    s_data3(128 + i) <= s_crc_p2(31 - i);
  end generate gen_lcpy;



  ----------------------------------------------------------------------------
  --* Main test process
  ----------------------------------------------------------------------------
  proc_main : process
  begin
    s_par_ce2 <= '0';
    s_par_ce3 <= '0';
    p_message("Simulation starts with a reset.");
    s_rst_n     <= '0';
    wait for 29 ns;
    s_rst_n     <= '1';
    p_wait_for_event("Wait for flushing of serial CRC generator", 1 ms, s_flush);
    wait for 2 ns;
    p_vector_check("CRC of serial generator", C_EXPECTED_CRC, s_crc_s,s_errors);
    p_vector_check("CRC of parallel generator", C_EXPECTED_CRC, s_crc_p,s_errors);
    p_wait_for_event("Wait for flush to finish", 500 ns, s_flush);
    wait for 2 ns;
    p_signal_check("Serial CRC match signal", '1', s_match_s);
    p_signal_check("Parallel CRC match signal", '1', s_match_p);
    p_message("Check 128bit crc:");
    wait until rising_edge(s_clk);
    s_par_ce2 <= '1';
    wait until rising_edge(s_clk);
    s_par_ce2 <= '0';
    wait until rising_edge(s_clk);
    s_par_ce3 <= '1';
    wait until rising_edge(s_clk);
    s_par_ce3 <= '0';
    wait for 1 ps;
    p_signal_check("Parallel 128bit CRC check", '1', s_match_p2);
    p_sim_report("");
    wait for 100 ns;
    report "End of simulation! (ignore this failure)"
      severity failure;
    wait;
  end process proc_main;


end architecture a_behav;  -- of entity tb_crc


