--=============================================================================
-- Module Name : lm_util_read_from_file_slv
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : MCO
-------------------------------------------------------------------------------
-- Description  :  Reads a data from a text file, taking them in columns.
--                 The first column is accumulated in a string (clocked), and sent
--                 out in parallel; the data sent in parallel are g_time_mux.
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
-- SOFTWARE..
-------------------------------------------------------------------------------
-- Revision History:
-- Date        Version  Author         Description
-- 22/09/2020  1.0.0    MCO            first issue
--
-------------------------------------------------------------------------------
-- Libraries:

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use ieee.fixed_pkg.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

use lm_util_lib.lm_util_read_write_file_pkg.all;

entity lm_util_read_from_file_slv is
  generic(
    g_file_to_read     : string := "";
    g_n_columns        : integer := 1;--columns to read
    g_nvalues_to_read  : integer := 1000;--0: whole file
    g_time_mux         : integer := 16;
    g_fix_length       : integer := 16;--to modify this, use a different type of t_slv16_data_out (from read_write_file_pkg) for data_o
    g_fix_bpoint       : integer := 8
    );
  port(
    clk_i          : in  std_logic;
    ena_i          : in  std_logic := '1';--start reading
    -- one value at a time
    dv_o           : out std_logic;
    data_o         : out t_slv16_data_out(0 to g_n_columns-1);
    cnt_o          : out std_logic_vector(g_time_mux-1 downto 0);--out data counter
    -- g_time_mux values at a time
    dv_mux_o       : out std_logic;
    mux_data_o     : out std_logic_vector(g_time_mux*g_fix_length-1 downto 0)
    );
end entity lm_util_read_from_file_slv;

architecture a_str of lm_util_read_from_file_slv is


  type t_real_col is array (0 to g_n_columns-1) of real;

  type t_slv_col is array (0 to g_n_columns-1) of std_logic_vector(g_fix_length-1 downto 0);

  signal s_cnt : unsigned(g_time_mux-1 downto 0) := (others => '0');


begin




  proc_read : process
    variable v_din_line      : line;
    variable v_eol           : boolean;
    variable v_real_data     : t_real_col;
    variable v_slv_data      : t_slv_col;
    file datainfile          : text open read_mode is g_file_to_read;
    --
    variable v_cnt : integer := -1;
    variable v_mux_data : std_logic_vector(g_time_mux*g_fix_length-1 downto 0);
  begin
    --
    if g_nvalues_to_read = 0 then--read the file all the way through
      while (not endfile(datainfile)) loop
        wait until clk_i = '1';
        if ena_i = '1' then
          --
          if v_cnt = g_time_mux-1 then
            v_cnt := 0;
          else
            v_cnt := v_cnt+1;
          end if;
          --
          readline(datainfile, v_din_line);--read item
          for c in 0 to g_n_columns-1 loop
            read(v_din_line, v_real_data(c), v_eol);--transform item into real, all the columns
            v_slv_data(c) := std_logic_vector(to_sfixed(v_real_data(c), (g_fix_length-g_fix_bpoint-1), -(g_fix_bpoint)));--real to fixed to slv
            data_o(c) <= v_slv_data(c);
            dv_o <= '1';
            s_cnt <= s_cnt+1;
            cnt_o <= std_logic_vector(s_cnt);
          end loop;
          --v_mux_data((v_cnt+1)*g_fix_length-1 downto v_cnt*g_fix_length) := v_slv_data(0);--only the first column is sent out multiplexed
          v_mux_data(g_time_mux*g_fix_length-v_cnt*g_fix_length-1 downto g_time_mux*g_fix_length-(v_cnt+1)*g_fix_length) := v_slv_data(0);--only the first column is sent out multiplexed
          if v_cnt = g_time_mux-1 then
            dv_mux_o <= '1';
            mux_data_o <= v_mux_data;--send multiplexed data
          end if;
        else
          dv_o <= '0';
          dv_mux_o <= '0';
          s_cnt <= (others => '0');
          file_close(datainfile);
        end if;
      end loop;
      --file_close(datainfile);
    else
      for d in 0 to g_nvalues_to_read-1 loop--repeating for the wanted number of muxed blocks
        wait until clk_i = '1';
        if ena_i = '1' then
          --
          if v_cnt = g_time_mux-1 then
            v_cnt := 0;
          else
            v_cnt := v_cnt+1;
          end if;
          --
          readline(datainfile, v_din_line);--read item
          for c in 0 to g_n_columns-1 loop
            read(v_din_line, v_real_data(c), v_eol);--transform item into real, all the columns
            v_slv_data(c) := std_logic_vector(to_sfixed(v_real_data(c), (g_fix_length-g_fix_bpoint-1), -(g_fix_bpoint)));--real to fixed to slv
            data_o(c) <= v_slv_data(c);
            dv_o <= '1';
            s_cnt <= s_cnt+1;
            cnt_o <= std_logic_vector(s_cnt);
          end loop;
          --v_mux_data((v_cnt+1)*g_fix_length-1 downto v_cnt*g_fix_length) := v_slv_data(0);--only the first column is sent out multiplexed
          v_mux_data(g_time_mux*g_fix_length-v_cnt*g_fix_length-1 downto g_time_mux*g_fix_length-(v_cnt+1)*g_fix_length) := v_slv_data(0);--only the first column is sent out multiplexed
          if v_cnt = g_time_mux-1 then
            dv_mux_o <= '1';
            mux_data_o <= v_mux_data;--send multiplexed data
          end if;
        else
          dv_o <= '0';
          dv_mux_o <= '0';
          s_cnt <= (others => '0');
          file_close(datainfile);
        end if;
      end loop;
      --file_close(datainfile);
    end if;
    --
  end process proc_read;





end architecture a_str;

