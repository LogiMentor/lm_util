--=============================================================================
-- Module Name : lm_util_read_write_file_pkg
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : MCO
-------------------------------------------------------------------------------
-- Description  : Package containing types to be used by the units
--                lm_util_write_to_file
--                lm_util_read_from_file_real
--                lm_util_read_from_file_slv16
--                Also contains a simple procedure to write real data from a single
--                column in a text file.
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
--
--
-------------------------------------------------------------------------------
-- Libraries: At least IEEE numeric,
library ieee;
use ieee.NUMERIC_STD.all;
use ieee.std_logic_1164.all;
use std.textio.all;
use ieee.std_logic_textio.all;

package lm_util_read_write_file_pkg is

  type t_coeffs is array (integer range <>) of real;
  type t_real_data_out is array (integer range <>) of real;
  type t_int_data_out is array (integer range <>) of integer;
  type t_slv8_data_out is array (integer range <>) of std_logic_vector(7 downto 0);
  type t_slv16_data_out is array (integer range <>) of std_logic_vector(15 downto 0);
  type t_slv18_data_out is array (integer range <>) of std_logic_vector(18 downto 0);
  type t_slv32_data_out is array (integer range <>) of std_logic_vector(31 downto 0);

  constant C_MAX_NUM_COLUMNS : integer := 10;--max supported number of columns to read from a text file
  constant C_MAX_COEFFS : integer := 128;--max supported number of columns to read from a text file
  constant C_MAX_DATA_LENGTH : integer := 1024;--max supported number of columns to read from a text file

  procedure p_read_from_file (
  constant C_FILE_TO_READ     : in string;
  constant C_NVALUES_TO_READ  : in integer;
  signal s_data_vec           : out t_coeffs(0 to C_MAX_COEFFS)
  );

end lm_util_read_write_file_pkg;



package body lm_util_read_write_file_pkg is


  -- the procedure reads the first C_NVALUES_TO_READ real values from file C_FILE_TO_READ
  -- and puts them in the array 's_data_vec'
  procedure p_read_from_file (
    constant C_FILE_TO_READ     : in string;
    constant C_NVALUES_TO_READ  : in integer;
    signal s_data_vec           : out t_coeffs(0 to C_MAX_COEFFS)
    ) is
    --type t_coeffs is array (0 to C_NVALUES_TO_READ-1) of real;
    --variable v_data_re       : t_coeffs;
    variable v_din_line      : line;
    --variable v_din_file_data : integer;
    variable v_din_file_data : real;
    file datainfile          : text open read_mode is C_FILE_TO_READ;
  begin
    if (not endfile(datainfile)) then
      for k in 0 to C_NVALUES_TO_READ-1 loop
        readline(datainfile, v_din_line);
        read(v_din_line, v_din_file_data);
        s_data_vec(k) <= v_din_file_data;
      end loop;
    else
      file_close(datainfile);
    end if;
  end;




end package body;

