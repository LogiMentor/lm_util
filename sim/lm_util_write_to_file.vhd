--=============================================================================
-- Module Name : lm_util_write_to_file
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : MCO
-------------------------------------------------------------------------------
-- Description  :  Writes a text file, with data in columns. Real data input.
--                 Data can be multiplexed.
--                 Data are written when write_i is high; this signal must be set
--                 for one or few clocks, then the prescribed amount of data is
--                 written.
--                 The output format can be real, integer os SLV; g_spaces must be
--                 large enough as to accomodate the proper number of characters.
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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use ieee.fixed_pkg.all;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

entity lm_util_write_to_file is
  generic(
    g_file_to_write      : string := "";
    g_type_to_write      : integer := 0;--0=real, 1=integer, 2=std_logic_vector, 3=hex
    g_n_columns          : integer := 1;--columns to write
    g_nvalues_to_write   : integer := 5000;--multiply for the column to have the total data
    g_time_mux           : integer := 1;
    g_dout_w             : integer := 16;
    g_fix_length         : integer := 16;
    g_fix_bpoint         : integer := 8;
    g_spaces             : integer := 10
    );
  port(
    clk_i          : in  std_logic;
    write_i        : in  std_logic := '1';
    data_i         : in  std_logic_vector(g_time_mux*g_dout_w-1 downto 0)
    );
end entity lm_util_write_to_file;

architecture a_str of lm_util_write_to_file is


  --type t_real_col is array (0 to g_n_columns-1) of real;
  type t_values is array (0 to g_nvalues_to_write - 1) of real;
  type t_int_values is array (0 to g_nvalues_to_write - 1) of integer;
  type t_slv_values is array (0 to g_nvalues_to_write - 1) of std_logic_vector(g_dout_w-1 downto 0);

  signal s_toggle : std_logic;
  signal s_close : std_logic;
  
  signal s_end_of_capture : std_logic;
  
  signal s_real_temp      : t_values := (others => 0.0);
  signal s_int_temp       : t_int_values := (others => 0);
  signal s_slv_temp     : t_slv_values := (others => (others => '0'));
  
  -- convert an unsigned value(4 bit) to a HEX digit (0-F)
  function f_to_hexchar(value_i : unsigned) return character is
    constant hex : string := "0123456789ABCDEF";
  begin
    if (value_i < 16) then
      return hex(to_integer(value_i)+1);
    else
      return 'x';
    end if;
  end function;
  
  -- return TRUE, if input is a power of 2
  function f_div_ceil(a_i : natural; b_i : positive) return natural is  -- calculates: ceil(a / b)
  begin
    return (a_i + (b_i - 1)) / b_i;
  end function;
  
  -- format a std_logic_vector as hex string
  function f_raw_format_slv_hex(slv_i : std_logic_vector) return string is
    variable v_value                  : std_logic_vector(4*f_div_ceil(slv_i'length, 4) - 1 downto 0);
    variable v_digit                  : std_logic_vector(3 downto 0);
    variable v_result                 : string(1 to f_div_ceil(slv_i'length, 4));
    variable v_j                      : natural;
  begin
    v_value := std_logic_vector(resize(unsigned(slv_i), v_value'length));
    v_j             := 0;
    for i in v_result'reverse_range loop
      v_digit       := v_value((v_j * 4) + 3 downto (v_j * 4));
      v_result(i)   := f_to_hexchar(unsigned(v_digit));
      v_j           := v_j + 1;
    end loop;
    return v_result;
  end function;  

begin


  gen_real : if g_type_to_write = 0 generate--real 
    
    proc_capture_data:process(clk_i) 
      variable v_cnt : natural := 0; 
      variable v_dout_data_real : real;
    begin
      if rising_edge(clk_i) then
        if write_i = '1' and v_cnt < g_nvalues_to_write/g_time_mux-1 then
          -- save data in a vector and write them all at the end  
          for i in 0 to g_time_mux-1 loop
            v_dout_data_real := to_real(to_sfixed(data_i((i+1)*g_dout_w-1 downto i*g_dout_w), (g_fix_length-g_fix_bpoint-1), -(g_fix_bpoint)));
            s_real_temp(v_cnt*g_time_mux+i) <= v_dout_data_real;
          end loop;
          
          v_cnt := v_cnt + 1;                                   
          
          if v_cnt = g_nvalues_to_write/g_time_mux-1 then
            s_end_of_capture <= '1';
          else
            s_end_of_capture <= '0';
          end if;
        end if;
      end if;
    end process proc_capture_data;  
    
    proc_write_data:process 
      variable v_dout_line      : line;
      file dataoutfile          : text open write_mode is g_file_to_write;
    begin
      wait until s_end_of_capture = '1';
      for i in 0 to g_nvalues_to_write/g_n_columns-1 loop
        for c in 0 to g_n_columns-1 loop
          write(v_dout_line, s_real_temp(i*g_n_columns+c), right, g_spaces);
          if g_n_columns > 1 then
            write(v_dout_line, ht);-- ht = 09 ASCI (horizontal tab)
          end if;
        end loop;
        write(v_dout_line, lf);-- lf = 10 ASCI (line feed) --use LF or CR based of the used editor
        --write(v_dout_line, cr);-- cr = 13 ASCI (carriage return) --use LF or CR based of the used editor
      end loop;
      writeline(dataoutfile, v_dout_line);
      wait for 1 ps;
      file_close(dataoutfile);
      wait;
    end process proc_write_data;
          
  end generate gen_real;


  gen_integer : if g_type_to_write = 1 generate--integer 
    
    proc_capture_data:process(clk_i) 
      variable v_cnt : natural := 0; 
      variable v_dout_data_int : integer;
    begin
      if rising_edge(clk_i) then
        if write_i = '1' and v_cnt < g_nvalues_to_write/g_time_mux-1 then
          -- save data in a vector and write them all at the end  
          for i in 0 to g_time_mux-1 loop
            v_dout_data_int := to_integer(to_01(to_sfixed(data_i((i+1)*g_dout_w-1 downto i*g_dout_w), (g_fix_length-g_fix_bpoint-1), -(g_fix_bpoint))));
            s_int_temp(v_cnt*g_time_mux+i) <= v_dout_data_int;
          end loop;
          
          v_cnt := v_cnt + 1;                                   
          
          if v_cnt = g_nvalues_to_write/g_time_mux-1 then
            s_end_of_capture <= '1';
          else
            s_end_of_capture <= '0';
          end if;
        end if;
      end if;
    end process proc_capture_data;  
    
    proc_write_data:process 
      variable v_dout_line      : line;
      file dataoutfile          : text open write_mode is g_file_to_write;
    begin
      wait until s_end_of_capture = '1';
      for i in 0 to g_nvalues_to_write/g_n_columns-1 loop
        for c in 0 to g_n_columns-1 loop
          write(v_dout_line, s_int_temp(i*g_n_columns+c), right, g_spaces);
          if g_n_columns > 1 then
            write(v_dout_line, ht);-- ht = 09 ASCI (horizontal tab)
          end if;
        end loop;
        write(v_dout_line, lf);-- lf = 10 ASCI (line feed) --use LF or CR based of the used editor
        --write(v_dout_line, cr);-- cr = 13 ASCI (carriage return) --use LF or CR based of the used editor
      end loop;
      writeline(dataoutfile, v_dout_line);
      wait for 1 ps;
      file_close(dataoutfile);
      wait;
    end process proc_write_data;

  end generate gen_integer;


  gen_slv : if g_type_to_write = 2 generate--std_logic_vector  
    
    
    proc_capture_data:process(clk_i) 
    variable v_cnt : natural := 0; 
    variable v_dout_data_fi   : sfixed(g_fix_length - g_fix_bpoint -1 downto - g_fix_bpoint);
      variable v_dout_data_int : integer;
    begin
      if rising_edge(clk_i) then
        if write_i = '1' and v_cnt < g_nvalues_to_write/g_time_mux-1 then
          -- save data in a vector and write them all at the end  
          for i in 0 to g_time_mux-1 loop
            v_dout_data_fi := to_sfixed(data_i((i+1)*g_dout_w-1 downto i*g_dout_w), (g_fix_length-g_fix_bpoint-1), -(g_fix_bpoint));
            s_slv_temp(v_cnt*g_time_mux+i) <= std_logic_vector(v_dout_data_fi);
          end loop;
          
          v_cnt := v_cnt + 1;                                   
          
          if v_cnt = g_nvalues_to_write/g_time_mux-1 then
            s_end_of_capture <= '1';
          else
            s_end_of_capture <= '0';
          end if;
        end if;
      end if;
    end process proc_capture_data;  
    
    proc_write_data:process 
      variable v_dout_line      : line;
      file dataoutfile          : text open write_mode is g_file_to_write;
    begin
      wait until s_end_of_capture = '1';
      for i in 0 to g_nvalues_to_write/g_n_columns-1 loop
        for c in 0 to g_n_columns-1 loop
          write(v_dout_line, s_slv_temp(i*g_n_columns+c), right, g_spaces);
          if g_n_columns > 1 then
            write(v_dout_line, ht);-- ht = 09 ASCI (horizontal tab)
          end if;
        end loop;
        write(v_dout_line, lf);-- lf = 10 ASCI (line feed) --use LF or CR based of the used editor
        --write(v_dout_line, cr);-- cr = 13 ASCI (carriage return) --use LF or CR based of the used editor
      end loop;
      writeline(dataoutfile, v_dout_line);
      wait for 1 ps;
      file_close(dataoutfile);
      wait;
    end process proc_write_data;

  end generate gen_slv;        
  
  gen_hex : if g_type_to_write = 3 generate--hexadecimal  
    
    
    proc_capture_data:process(clk_i) 
      variable v_cnt : natural := 0; 
      variable v_dout_data_fi   : sfixed(g_fix_length - g_fix_bpoint -1 downto - g_fix_bpoint);
      variable v_dout_data_int : integer;
    begin
      if rising_edge(clk_i) then
        if write_i = '1' and v_cnt < g_nvalues_to_write/g_time_mux-1 then
          -- save data in a vector and write them all at the end  
          for i in 0 to g_time_mux-1 loop
            v_dout_data_fi := to_sfixed(data_i((i+1)*g_dout_w-1 downto i*g_dout_w), (g_fix_length-g_fix_bpoint-1), -(g_fix_bpoint));
            s_slv_temp(v_cnt*g_time_mux+i) <= std_logic_vector(v_dout_data_fi);
          end loop;
          
          v_cnt := v_cnt + 1;                                   
          
          if v_cnt = g_nvalues_to_write/g_time_mux-1 then
            s_end_of_capture <= '1';
          else
            s_end_of_capture <= '0';
          end if;
        end if;
      end if;
    end process proc_capture_data;  
    
    proc_write_data:process 
      variable v_dout_line      : line;
      file dataoutfile          : text open write_mode is g_file_to_write;
    begin
      wait until s_end_of_capture = '1';
      for i in 0 to g_nvalues_to_write/g_n_columns-1 loop
        for c in 0 to g_n_columns-1 loop
           write(v_dout_line, f_raw_format_slv_hex(s_slv_temp(i*g_n_columns+c)), right, g_spaces);
          if g_n_columns > 1 then
            write(v_dout_line, ht);-- ht = 09 ASCI (horizontal tab)
          end if;
        end loop;
        write(v_dout_line, lf);-- lf = 10 ASCI (line feed) --use LF or CR based of the used editor
        --write(v_dout_line, cr);-- cr = 13 ASCI (carriage return) --use LF or CR based of the used editor
      end loop;
      writeline(dataoutfile, v_dout_line);
      wait for 1 ps;
      file_close(dataoutfile);
      wait;
    end process proc_write_data;
    
  end generate gen_hex;  


end architecture a_str;

