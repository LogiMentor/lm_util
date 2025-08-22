--=============================================================================
-- Module Name : lm_util_read_from_file_real
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : MCO
-------------------------------------------------------------------------------
-- Description  :  Reads a text file, taking data in columns. Real data.
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

entity lm_util_read_from_file_real is
  generic(
    g_file_to_read     : string := "";
    g_n_columns        : integer := 1;--columns to read
    g_nvalues_to_read  : integer := 1000--0: whole file
    );
  port(
    clk_i          : in  std_logic;
    ena_i          : in  std_logic := '1';
    mux_data_o     : out t_real_data_out(0 to g_n_columns-1);
    dv_o           : out std_logic;
    cnt_o          : out std_logic_vector(15 downto 0)
    );
end entity lm_util_read_from_file_real;

architecture a_str of lm_util_read_from_file_real is


  type t_real_col is array (0 to g_n_columns-1) of real;

  signal s_cnt : unsigned(15 downto 0) := (others => '0');


begin



  --proc_calc : process(clk_i)
  --  variable v_din_line      : line;
  --  variable v_eol           : boolean;
  --  variable v_real_data     : t_real_col;
  --  variable v_d             : integer := 0;
  --  file datainfile          : text open read_mode is g_file_to_read;
  --begin
  --  if rising_edge(clk_i) then
  --    if ena_i = '1' then
  --      --
  --      if g_nvalues_to_read = 0 then--read the file all the way through
  --        while (not endfile(datainfile)) loop
  --          readline(datainfile, v_din_line);--read item
  --          for c in 0 to g_n_columns-1 loop
  --            read(v_din_line, v_real_data(c), v_eol);--transform item into real, all the columns
  --            mux_data_o(c) <= v_real_data(c);
  --          end loop;
  --        end loop;
  --        file_close(datainfile);
  --      else
  --        for d in 0 to g_nvalues_to_read-1 loop--repeating for the wanted number of muxed blocks
  --          readline(datainfile, v_din_line);--read item
  --          for c in 0 to g_n_columns-1 loop
  --            read(v_din_line, v_real_data(c), v_eol);--transform item into real, all the columns
  --            mux_data_o(c) <= v_real_data(c);
  --          end loop;
  --        end loop;
  --        file_close(datainfile);
  --      end if;
  --      --
  --    else
  --      file_close(datainfile);
  --      v_d := 0;
  --    end if;
  --  end if;
  --end process proc_calc;


  proc_read : process
    variable v_din_line      : line;
    variable v_eol           : boolean;
    variable v_real_data     : t_real_col;
    file datainfile          : text open read_mode is g_file_to_read;
  begin
    --
    if g_nvalues_to_read = 0 then--read the file all the way through
      while (not endfile(datainfile)) loop
        wait until clk_i = '1';
        if ena_i = '1' then
          readline(datainfile, v_din_line);--read item
          for c in 0 to g_n_columns-1 loop
            read(v_din_line, v_real_data(c), v_eol);--transform item into real, all the columns
            mux_data_o(c) <= v_real_data(c);
            dv_o <= '1';
            s_cnt <= s_cnt+1;
            cnt_o <= std_logic_vector(s_cnt);
          end loop;
        else
          dv_o <= '0';
          s_cnt <= (others => '0');
        end if;
      end loop;
      file_close(datainfile);
    else
      for d in 0 to g_nvalues_to_read-1 loop--repeating for the wanted number of muxed blocks
        wait until clk_i = '1';
        if ena_i = '1' then
          readline(datainfile, v_din_line);--read item
          for c in 0 to g_n_columns-1 loop
            read(v_din_line, v_real_data(c), v_eol);--transform item into real, all the columns
            mux_data_o(c) <= v_real_data(c);
            dv_o <= '1';
            s_cnt <= s_cnt+1;
            cnt_o <= std_logic_vector(s_cnt);
          end loop;
        else
          dv_o <= '0';
          s_cnt <= (others => '0');
        end if;
      end loop;
      file_close(datainfile);
    end if;
    --
  end process proc_read;




end architecture a_str;

