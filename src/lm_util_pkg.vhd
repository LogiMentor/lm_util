--=============================================================================
-- Module Name : lm_util_pkg
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-- Author      : A.Campera
-------------------------------------------------------------------------------
-- Description:    common package with utility functions, procedures, types and
--                 constants. This package, together with the lm_util_lib
--                 library shoud be re-used as base library in every project
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
use ieee.math_real.all;
use ieee.std_logic_textio.all;

use std.textio.all;

library lm_util_lib;

-- common package with utility functions, procedures, types and
-- constants. This package, togheter with the lm_util_lib
-- library shoud be re-used as base library in every project
package lm_util_pkg is

  -- TYPE DECLARATIONS --------------------------------------------------------
  type t_boolean_arr is array (natural range <>) of boolean;  -- natural left index starts default at 0
  type t_integer_arr is array (natural range <>) of integer;  -- natural left index starts default at 0
  type t_natural_arr is array (natural range <>) of natural;  -- natural left index starts default at 0
  type t_sl_arr is array (natural range <>) of std_logic;

  type t_integer_matrix is array (natural range <>, natural range <>) of integer;
  type t_boolean_matrix is array (natural range <>, natural range <>) of boolean;
  type t_sl_matrix is array (natural range <>, natural range <>) of std_logic;

  -- structure declarations ---------------------------------------------------
  -- define a record with parameters for memory instantiation
  -- read latency (1 is standard, 2 adds a register to the output)
  -- memory address width
  -- memory data width
  -- memory depth (optional, if omitted the depth is assumed to be 2**addr_w)
  -- memory initial value for all cells (i.e. others => init_sl)
  type t_c_mem is record
    latency : natural;
    addr_w  : natural;
    data_w  : natural;
    depth   : natural;
    init_sl : std_logic;
  end record;

  -- END OF TYPE DECLARATIONS -------------------------------------------------
  -- CONSTANT DECLARATIONS ----------------------------------------------------
  -- integer mnemonic constants for circuit type, combinatorial or sequential
  constant C_LM_COMB : integer := 0;
  constant C_LM_SYNC : integer := 1;

  -- integer mnemonic constants for delay architectures
  constant C_LM_SRL   : integer := 0;
  constant C_LM_MEM   : integer := 1;
  constant C_LM_PULSE : integer := 2;

  -- integer mnemonic constants for arithmentical operations
  constant C_LM_ADD    : integer := 0;
  constant C_LM_SUB    : integer := 1;
  constant C_LM_ADDSUB : integer := 2;

  -- integer mnemonic constants for logical operations
  constant C_LM_AND : integer := 0;
  constant C_LM_OR  : integer := 1;
  constant C_LM_XOR : integer := 2;

  -- ASCII characters
  constant C_ASCII_A     : std_logic_vector (7 downto 0) := "01100001";
  constant C_ASCII_A_UC  : std_logic_vector (7 downto 0) := "01000001";
  constant C_ASCII_B     : std_logic_vector (7 downto 0) := "01100010";
  constant C_ASCII_B_UC  : std_logic_vector (7 downto 0) := "01000010";
  constant C_ASCII_C     : std_logic_vector (7 downto 0) := "01100011";
  constant C_ASCII_C_UC  : std_logic_vector (7 downto 0) := "01000011";
  constant C_ASCII_D     : std_logic_vector (7 downto 0) := "01100100";
  constant C_ASCII_D_UC  : std_logic_vector (7 downto 0) := "01000100";
  constant C_ASCII_DP    : std_logic_vector (7 downto 0) := "00111010";
  constant C_ASCII_E     : std_logic_vector (7 downto 0) := "01100101";
  constant C_ASCII_E_UC  : std_logic_vector (7 downto 0) := "01000101";
  constant C_ASCII_8     : std_logic_vector (7 downto 0) := "00111000";
  constant C_ASCII_ESC   : std_logic_vector (7 downto 0) := "00011011";
  constant C_ASCII_F     : std_logic_vector (7 downto 0) := "01100110";
  constant C_ASCII_F_UC  : std_logic_vector (7 downto 0) := "01000110";
  constant C_ASCII_5     : std_logic_vector (7 downto 0) := "00110101";
  constant C_ASCII_4     : std_logic_vector (7 downto 0) := "00110100";
  constant C_ASCII_G     : std_logic_vector (7 downto 0) := "01100111";
  constant C_ASCII_H     : std_logic_vector (7 downto 0) := "01101000";
  constant C_ASCII_H_UC  : std_logic_vector (7 downto 0) := "01001000";
  constant C_ASCII_I     : std_logic_vector (7 downto 0) := "01101001";
  constant C_ASCII_J     : std_logic_vector (7 downto 0) := "01101010";
  constant C_ASCII_K     : std_logic_vector (7 downto 0) := "01101011";
  constant C_ASCII_L     : std_logic_vector (7 downto 0) := "01101100";
  constant C_ASCII_M     : std_logic_vector (7 downto 0) := "01101101";
  constant C_ASCII_MARK  : std_logic_vector (7 downto 0) := "00101101";
  constant C_ASCII_N     : std_logic_vector (7 downto 0) := "01101110";
  constant C_ASCII_9     : std_logic_vector (7 downto 0) := "00111001";
  constant C_ASCII_O     : std_logic_vector (7 downto 0) := "01101111";
  constant C_ASCII_1     : std_logic_vector (7 downto 0) := "00110001";
  constant C_ASCII_P     : std_logic_vector (7 downto 0) := "01110000";
  constant C_ASCII_POINT : std_logic_vector (7 downto 0) := "00101110";
  constant C_ASCII_PV    : std_logic_vector (7 downto 0) := "00111011";
  constant C_ASCII_R     : std_logic_vector (7 downto 0) := "01110010";
  constant C_ASCII_S     : std_logic_vector (7 downto 0) := "01110011";
  constant C_ASCII_SBO   : std_logic_vector (7 downto 0) := "01011011";
  constant C_ASCII_7     : std_logic_vector (7 downto 0) := "00110111";
  constant C_ASCII_6     : std_logic_vector (7 downto 0) := "00110110";
  constant C_ASCII_SPACE : std_logic_vector (7 downto 0) := "00100000";
  constant C_ASCII_T     : std_logic_vector (7 downto 0) := "01110100";
  constant C_ASCII_3     : std_logic_vector (7 downto 0) := "00110011";
  constant C_ASCII_2     : std_logic_vector (7 downto 0) := "00110010";
  constant C_ASCII_U     : std_logic_vector (7 downto 0) := "01110101";
  constant C_ASCII_US    : std_logic_vector (7 downto 0) := "01011111";
  constant C_ASCII_V     : std_logic_vector (7 downto 0) := "01110110";
  constant C_ASCII_X     : std_logic_vector (7 downto 0) := "01111000";
  constant C_ASCII_Y     : std_logic_vector (7 downto 0) := "01111001";
  constant C_ASCII_0     : std_logic_vector (7 downto 0) := "00110000";

  -- integer mnemonic constants
  constant C_ZERO    : natural                        := 0;
  constant C_ONE     : natural                        := 1;
  constant C_TWO     : natural                        := 2;
  constant C_SL0     : std_logic                      := '0';
  constant C_SL1     : std_logic                      := '1';

  --
  constant C_SRL2MEM_THRESH : integer := 512;

  -- rising or falling edge event
  constant C_RISING_EDGE  : integer := 1;
  constant C_FALLING_EDGE : integer := 0;

  -- ff, block ram, fifo
  -- default nof f_flipflops (ff) in meta stability recovery delay line (e.g. for clock domain crossing)
  constant C_META_DELAY_LEN     : natural := 2;
  -- default use 16 word deep fifo to cross clock domain, typically > 2*c_meta_delay_len or >~ 8 is enough
  constant C_META_FIFO_DEPTH    : natural := 16;
  constant C_MEM_RAM_RD_LATENCY : natural := 2;
  --constant c_mem_ram            : t_c_mem := (c_mem_ram_rd_latency, 10, 36, 2 ** 10, 'X');  -- 1 M36K
  constant C_MEM_RAM            : t_c_mem := (1, 10, 32, 1024, '0');   --
  constant C_MEM_RAM_RATIO      : t_c_mem := (1, 12, 128, 3072, '0');  --
  constant C_MEM_RAM_TEST       : t_c_mem := (1, 9, 64, 392, '0');
  constant C_MEM_REG_RD_LATENCY : natural := 1;
  constant C_MEM_REG            : t_c_mem := (C_MEM_REG_RD_LATENCY, 1, 32, 1, 'X');

  -- default or minimal fifo almost full margin
  constant C_FIFO_AFULL_MARGIN : natural := 4;


  -- CONSTANT DECLARATIONS ----------------------------------------------------
  -- FUNCTION DECLARATIONS ----------------------------------------------------
  -- all functions assume [high downto low] input ranges

  -- this function computes ceil(log2(n)), but force ceil(log2(1)) = 1,
  -- which is needed to support the vector width width for 1 address, to
  -- avoid null array for single word register address.
  -- Example: f_ceil_log2(13) = 4
  -- n natural input for the log2 function
  -- natural output, ceil(log2(n))
  function f_ceil_log2(n : natural) return natural;

  -- this function computes floor(log2(n))
  -- Example: f_floor_log2(13) = 3
  -- n natural input for the log2 function
  -- natural output, floor(log2(n))
  function f_floor_log2(n : natural) return natural;

  -------------------------------------------------------------------------------
  -- standard logic to boolean
  -- Example: f_sl2bool('0') = false,
  -- n std_logic input
  -- boolean equivalent to the std_logic input
  -------------------------------------------------------------------------------
  function f_sl2bool(n : in std_logic) return boolean;

  -------------------------------------------------------------------------------
  -- standard logic to character
  -- Example: f_sl2char('0') = '0',
  -- n std_logic input
  -- character representing the std_logic input
  function f_sl2char(n : in std_logic) return character;

  -------------------------------------------------------------------------------
  -- convert hex char to slv
  -- Example: f_hex2slv('f') = "1111"
  -- input character
  -- std_logic_vector(3 downto 0)
  -------------------------------------------------------------------------------
  function f_hex2slv(c: character) return std_logic_vector;

  -- Hex string to standard logic vector conversion
  -- Example: f_hex2slv('12FA') = x"12FA"
  -- - string (slv in hex format) to convert
  -- slv: standard logic vector
  function f_hex2slv(hex : string) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- boolean to integer
  -- Example: f_bool2sl(false) = '0',
  -- n boolean input
  -- integer equivalent to the boolean input
  -------------------------------------------------------------------------------
  function f_bool2int(n : in boolean) return integer;

  -------------------------------------------------------------------------------
  -- boolean to standard logic
  -- Example: f_bool2sl(false) = '0',
  -- n boolean input
  -- std_logic equivalent to the boolean input
  -------------------------------------------------------------------------------
  function f_bool2sl(n : in boolean) return std_logic;

  -------------------------------------------------------------------------------
  -- standard logic to 1 element standard logic vector
  -- Example: f_sl2slv('0') = "0", std_logic_vector(0 downto 0)
  -- n std_logic input
  -- std_logic_vector(0 downto 0) equivalent to the std_logic input
  -------------------------------------------------------------------------------
  function f_sl2slv(n : in std_logic) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- standard logic to integer conversion
  -- Example: f_sl2int('0') = 0, integer
  -- n std_logic input
  -- integer equivalent to the std_logic input
  -------------------------------------------------------------------------------
  function f_sl2int(n : in std_logic) return integer;

  -------------------------------------------------------------------------------
  -- integer to standard logic conversion
  -- Example: f_int2sl(1) = '1', std_logic
  -- n std_logic input (only 0 and 1 are allowed)
  -- std_logic equivalent to the integer input
  -------------------------------------------------------------------------------
  function f_int2sl(n : in integer) return std_logic;

  -------------------------------------------------------------------------------
  -- integer to standard logic vector conversion
  -- Example: f_int2sl(1) = "1", std_logic_vector
  -- n std_logic input (only 0 and 1 are allowed)
  -- std_logic_vector equivalent to the integer input
  -------------------------------------------------------------------------------
  function f_int2slv(n : in integer; dim : in natural) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- 1 element standard logic vector to standard logic
  -- Example: f_sl2slv("0") = '0', std_logic
  -- n std_logic_vector(0 downto 0) input
  -- std_logoc equivalent to the std_logic_vector input
  -------------------------------------------------------------------------------
  function f_slv2sl(n : in std_logic_vector) return std_logic;

  -------------------------------------------------------------------------------
  -- this function converts std_logic_vector into a natural
  -- beware: natural'high = 2**31-1, not 2*32-1, use f_slv2int to avoid warning
  -- Example: f_slv2nat("1000") = 8
  -- vec, input vector
  -- natural
  -------------------------------------------------------------------------------
  function f_slv2nat(vec : std_logic_vector) return natural;

  -------------------------------------------------------------------------------
  -- this function converts std_logic_vector into a integer
  -- Example: f_slv2int("1000") = -8
  -- vec, input vector
  -- integer
  -------------------------------------------------------------------------------
  function f_slv2int(vec : std_logic_vector) return integer;

  -------------------------------------------------------------------------------
  -- this function converts a natural into a std_logic_vector
  -- Example: f_nat2slv("1000") = 8
  -- vec, input vector
  -- natural
  -------------------------------------------------------------------------------
  function f_nat2slv(dec, w : natural) return std_logic_vector;

  ------------------------------------------------------------------------------
  -- Arithmetic conversion functions
  ------------------------------------------------------------------------------
  -------------------------------------------------------------------------------
  -- this function converts a std_logic_vector into a unsigned
  -- Example: trivial
  -- inp, std_logic_vector input vector
  -- unsigned
  -------------------------------------------------------------------------------
  function f_slv2uns(inp : std_logic_vector) return unsigned;

  -------------------------------------------------------------------------------
  -- this function converts a unsigned into a unsigned
  -- Example: trivial
  -- inp, unsigned input vector
  -- std_logic_vector
  -------------------------------------------------------------------------------
  function f_uns2slv(inp : unsigned) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- this function converts a integer into a unsigned (abs if input in negative)
  -- Example: trivial
  -- inp, integer input, width of output
  -- unsigned
  -------------------------------------------------------------------------------
  function f_int2uns(inp : integer; width : integer) return unsigned;

  -------------------------------------------------------------------------------
  -- this function converts a unsigned into a integer
  -- Example: trivial
  -- inp, unsigned
  -- integer
  -------------------------------------------------------------------------------
  function f_uns2int(inp : unsigned) return integer;

  -------------------------------------------------------------------------------
  -- this function converts a integer into a signed
  -- Example: trivial
  -- inp, integer, width of output
  -- signed
  -------------------------------------------------------------------------------
  function f_int2sig(inp : integer; width : integer) return signed;

  -------------------------------------------------------------------------------
  -- this function converts a signed into a signed
  -- Example: trivial
  -- inp, signed
  -- integer
  -------------------------------------------------------------------------------
  function f_sig2int(inp : signed) return integer;

  -------------------------------------------------------------------------------
  -- this function converts a std_logic_vector into a signed
  -- Example: trivial
  -- inp, std_logic_vector
  -- signed
  -------------------------------------------------------------------------------
  function f_slv2sig(inp : std_logic_vector) return signed;

  -------------------------------------------------------------------------------
  -- this function converts a signed into a std_logic_vector
  -- Example: trivial
  -- inp, signed
  -- std_logic_vector
  -------------------------------------------------------------------------------
  function f_sig2slv(inp : signed) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- this function converts a unsigned into a signed
  -- Example: trivial
  -- inp, unsigned, desired output sign
  -- signed
  -------------------------------------------------------------------------------
  function f_uns2sig(inp : unsigned; sign : std_logic) return signed;

  -------------------------------------------------------------------------------
  -- this function converts a signed into a unsigned
  -- Example: trivial
  -- inp, signed, sign of the input
  -- unsigned
  -------------------------------------------------------------------------------
  function f_sig2uns(inp : signed; sign : std_logic) return unsigned;

  -------------------------------------------------------------------------------
  -- binary to gray-code converter
  -- Example: f_bin2gray("1011") =
  -- a std_logic vector binary coded input
  -- std_logic vector gray coded output
  -------------------------------------------------------------------------------
  function f_bin2gray(a : std_logic_vector) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- gray-code to binary converter
  -- Example: f_gray2biny("1011") =
  -- a std_logic vector gray coded input
  -- std_logic vector binary coded output
  -------------------------------------------------------------------------------
  function f_gray2bin(a : std_logic_vector) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- convert an array of integer into an array of natural
  -- Example:
  -- n input integer array
  -- t_natural_arr type natural equivalent array
  -------------------------------------------------------------------------------
  function f_int2nat_arr(n : t_integer_arr) return t_natural_arr;

  -------------------------------------------------------------------------------
  -- convert an array of natural into an array of integer
  -- Example:
  -- n input natural array
  -- t_integer_arr type integer equivalent array
  -------------------------------------------------------------------------------
  function f_nat2int_arr(n : t_natural_arr) return t_integer_arr;

  -------------------------------------------------------------------------------
  -- core operation tree function for vector "and", "or", "xor"
  -- Example: f_vector_tree("111", "and") = '1'
  -- slv std_logic_vector input, logical operation and, or, xor
  -- std_logic
  -------------------------------------------------------------------------------
  function f_vector_tree(slv : std_logic_vector; operation : integer) return std_logic;

  -------------------------------------------------------------------------------
  -- '1' when all slv bits are '1' else '0'
  -- Example: f_vector_and("111") = '1'
  -- slv std_logic_vector input
  -- std_logic
  -------------------------------------------------------------------------------
  function f_vector_and(slv : std_logic_vector) return std_logic;

  -------------------------------------------------------------------------------
  -- '0' when all slv bits are '0' else '1'
  -- Example: f_vector_or("000") = '0'
  -- slv std_logic_vector input
  -- std_logic
  -------------------------------------------------------------------------------
  function f_vector_or(slv : std_logic_vector) return std_logic;

  -------------------------------------------------------------------------------
  -- '1' when the slv has an odd number of '1' bits else '0'
  -- Example: f_vector_xor("010") = '1'
  -- slv std_logic_vector input
  -- std_logic
  -------------------------------------------------------------------------------
  function f_vector_xor(slv : std_logic_vector) return std_logic;

  -------------------------------------------------------------------------------
  -- '1' when all matrix bits are '1' else '0'
  -- Example:
  -- mat t_sl_matrix input
  -- std_logic
  -------------------------------------------------------------------------------
  function f_matrix_and(mat : t_sl_matrix; wi, wj : natural) return std_logic;

  -------------------------------------------------------------------------------
  -- '0' when all matrix bits are '0' else '1'
  -- Example:
  -- mat t_sl_matrix input
  -- std_logic
  -------------------------------------------------------------------------------
  function f_matrix_or(mat : t_sl_matrix; wi, wj : natural) return std_logic;

  -------------------------------------------------------------------------------
  -- return the smallest natural among inputs. The function is overloaded
  -- for 2, 3 or n natural inputs
  -- Example: f_smallest(2,3) = 2
  -- n,m natural input
  -- natural
  -------------------------------------------------------------------------------
  function f_smallest(n, m    : natural) return natural;
  function f_smallest(n, m, l : natural) return natural;
  function f_smallest(n       : t_natural_arr) return natural;
  --  function f_smallest(n       : t_integer_arr) return integer;

  -------------------------------------------------------------------------------
  -- return the largest natural among inputs. The function is overloaded
  -- for 2 or n natural inputs
  -- Example: f_largest(2,3) = 3
  -- n,m natural input
  -- natural
  -------------------------------------------------------------------------------
  function f_largest(n, m : natural) return natural;
  function f_largest(n    : t_natural_arr) return natural;
  --  function f_largest(n    : t_integer_arr) return integer;

  -------------------------------------------------------------------------------
  -- sum of all elements in array
  -- Example:
  -- n, t_natural_arr type array of natural input
  -- natural, sum of all elements of the input array
  -------------------------------------------------------------------------------
  function f_sum_natural_arr(n : t_natural_arr) return natural;
  --  function f_sum_natural_arr(    n : t_integer_arr) return integer;

  -------------------------------------------------------------------------------
  -- product of all elements in array
  -- Example:
  -- n, t_natural_arr type array of natural input
  -- natural, product of all elements of the input array
  -------------------------------------------------------------------------------
  function f_prod_natural_arr(n : t_natural_arr) return natural;
  --  function f_prod_natural_arr(n : t_integer_arr) return integer;

  -------------------------------------------------------------------------------
  -- element wise sum with array of natural. The function is overloaded
  -- to sum 2 array, one array and one integer
  -- Example:
  -- l,r t_natural_arr
  -- t_natural_arr
  -------------------------------------------------------------------------------
  function "+"(l, r : t_natural_arr) return t_natural_arr;
  -- element wise sum
  function "+"(l    : t_natural_arr; r : integer) return t_natural_arr;
  -- element wise sum
  function "+"(l    : integer; r : t_natural_arr) return t_natural_arr;

  -------------------------------------------------------------------------------
  -- element wise subtract with array of natural. The function is
  -- overloaded to subtract 2 array, one array and one integer
  -- Example:
  -- l,r t_natural_arr
  -- t_natural_arr
  -------------------------------------------------------------------------------
  function "-"(l, r : t_natural_arr) return t_natural_arr;
  -- element wise subtract, support negative result
  function "-"(l, r : t_natural_arr) return t_integer_arr;
  -- element wise subtract
  function "-"(l    : t_natural_arr; r : integer) return t_natural_arr;
  -- element wise subtract
  function "-"(l    : integer; r : t_natural_arr) return t_natural_arr;

  -------------------------------------------------------------------------------
  -- element wise product with array of natural. The function is
  -- overloaded to multiply 2 array, one array and one integer
  -- Example:
  -- l,r t_natural_arr
  -- t_natural_arr
  -------------------------------------------------------------------------------
  function "*"(l, r : t_natural_arr) return t_natural_arr;
  -- element wise product
  function "*"(l    : t_natural_arr; r : natural) return t_natural_arr;
  -- element wise product
  function "*"(l    : natural; r : t_natural_arr) return t_natural_arr;

  -------------------------------------------------------------------------------
  -- element wise division with array of natural. The function is
  -- overloaded to divide 2 array, one array and one integer
  -- Example:
  -- l,r t_natural_arr
  -- t_natural_arr
  -------------------------------------------------------------------------------
  function "/"(l, r : t_natural_arr) return t_natural_arr;
  -- element wise division
  function "/"(l    : t_natural_arr; r : positive) return t_natural_arr;
  -- element wise division
  function "/"(l    : natural; r : t_natural_arr) return t_natural_arr;

  -------------------------------------------------------------------------------
  -- this function check if the input data is equivalent to a true
  -- condition and return the results of the check. Input can be boolean,
  -- std_logic ('0' means false, '1' true) or integer (0 means false, 1 true)
  -- The returned value can be boolean, natural or std_logic
  -- Example: f_is_true('0') = false
  -- a, boolean, std_logic or integer
  -- boolean, natural or std_logic
  -------------------------------------------------------------------------------
  function f_is_true(a : std_logic) return boolean;
  function f_is_true(a : std_logic) return natural;
  function f_is_true(a : boolean) return std_logic;
  function f_is_true(a : boolean) return natural;
  -- also covers natural because it is a subtype of integer
  function f_is_true(a : integer) return boolean;
  -- also covers natural because it is a subtype of integer
  function f_is_true(a : integer) return std_logic;

  -------------------------------------------------------------------------------
  -- select among two inputs, depending on another input. It is the
  -- equivalent of a if-then-else function, which can be used also for constants
  -- initialization.
  -- Example: f_sel_a_b(5>2,'0','1') = '0'
  -- sel,a,b sel shall be boolean or integer, a,b are overloaded
  -- overloaded to return all VHDL defined types
  -------------------------------------------------------------------------------
  function f_sel_a_b(sel, a, b : boolean) return boolean;
  function f_sel_a_b(sel, a, b : integer) return integer;
  function f_sel_a_b(sel       : boolean; a, b : integer) return integer;
  function f_sel_a_b(sel       : boolean; a, b : real) return real;
  function f_sel_a_b(sel       : boolean; a, b : std_logic) return std_logic;
  function f_sel_a_b(sel       : integer; a, b : std_logic) return std_logic;
  function f_sel_a_b(sel       : integer; a, b : std_logic_vector) return std_logic_vector;
  function f_sel_a_b(sel       : boolean; a, b : std_logic_vector) return std_logic_vector;
  function f_sel_a_b(sel       : boolean; a, b : signed) return signed;
  function f_sel_a_b(sel       : boolean; a, b : unsigned) return unsigned;
  function f_sel_a_b(sel       : boolean; a, b : t_integer_arr) return t_integer_arr;
  function f_sel_a_b(sel       : boolean; a, b : t_natural_arr) return t_natural_arr;
  function f_sel_a_b(sel       : boolean; a, b : string) return string;
  function f_sel_a_b(sel       : boolean; a, b : time) return time;
  -------------------------------------------------------------------------------
  -- select among n boolean inputs depending on a natural input used as
  -- selector. It is equivalent to a multiplexer of boolean inputs with a
  -- natural selector input
  -- Example: f_sel_n(1,false,true,false) = true
  -- sel natural, a,b,c,... boolean
  -- boolean
  -------------------------------------------------------------------------------
  function f_sel_n(sel : natural; a, b, c : boolean) return boolean;     --  3
  function f_sel_n(sel : natural; a, b, c, d : boolean) return boolean;  --  4
  function f_sel_n(sel : natural; a, b, c, d, e : boolean) return boolean;  --  5
  function f_sel_n(sel : natural; a, b, c, d, e, f : boolean) return boolean;  --  6
  function f_sel_n(sel : natural; a, b, c, d, e, f, g : boolean) return boolean;  --  7
  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h : boolean) return boolean;  --  8
  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h, i : boolean) return boolean;  --  9
  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h, i, j : boolean) return boolean;  -- 10

  -------------------------------------------------------------------------------
  -- select among n integer inputs depending on a natural input used as
  -- selector. It is equivalent to a multiplexer of integer inputs with a
  -- natural selector input
  -- Example: f_sel_n(1,3,5,9) = 5
  -- sel natural, a,b,c,... integer
  -- integer
  -------------------------------------------------------------------------------
  function f_sel_n(sel : natural; a, b, c : integer) return integer;     --  3
  function f_sel_n(sel : natural; a, b, c, d : integer) return integer;  --  4
  function f_sel_n(sel : natural; a, b, c, d, e : integer) return integer;  --  5
  function f_sel_n(sel : natural; a, b, c, d, e, f : integer) return integer;  --  6
  function f_sel_n(sel : natural; a, b, c, d, e, f, g : integer) return integer;  --  7
  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h : integer) return integer;  --  8
  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h, i : integer) return integer;  --  9
  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h, i, j : integer) return integer;  -- 10

  -- useful to init a unconstrained array of size 1
  function f_array_init(init            : std_logic; nof : natural) return std_logic_vector;
  -- useful to init a unconstrained array of size 1
  function f_array_init(init, nof       : natural) return t_natural_arr;
  function f_array_init(init, nof, incr : natural) return t_natural_arr;

  -------------------------------------------------------------------------------
  -- concatenate two or more std_logic_vectors into a single
  -- std_logic_vector. The function is overloaded for up to 7 inputs
  -- Example: f_slv_concat(true, true, "01","10") = "0110"
  -- use_a,use_b boolean to select which inputs to use
  -- a,b input std_logic_vector to be concatenated
  -- std_logic_vector
  -------------------------------------------------------------------------------
  function f_slv_concat(use_a, use_b, use_c, use_d, use_e, use_f, use_g : boolean; a, b, c, d, e, f, g : std_logic_vector) return std_logic_vector;
  function f_slv_concat(use_a, use_b, use_c, use_d, use_e, use_f        : boolean; a, b, c, d, e, f : std_logic_vector) return std_logic_vector;
  function f_slv_concat(use_a, use_b, use_c, use_d, use_e               : boolean; a, b, c, d, e : std_logic_vector) return std_logic_vector;
  function f_slv_concat(use_a, use_b, use_c, use_d                      : boolean; a, b, c, d : std_logic_vector) return std_logic_vector;
  function f_slv_concat(use_a, use_b, use_c                             : boolean; a, b, c : std_logic_vector) return std_logic_vector;
  function f_slv_concat(use_a, use_b                                    : boolean; a, b : std_logic_vector) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- sum the width of concatenated std_logic_vectors into a single
  -- natural. The function is overloaded for up to 7 inputs and shall be used
  -- in conjuntion with f_slv_concat
  -- Example: f_slv_concat(true,true,2,2) = 4
  -- use_a,use_b boolean to select which inputs to use
  -- a_w,b_w input widths to be summed
  -- natural
  -------------------------------------------------------------------------------
  function f_slv_concat_w(use_a, use_b, use_c, use_d, use_e, use_f, use_g : boolean; a_w, b_w, C_W, d_w, e_w, f_w, g_w : natural) return natural;
  function f_slv_concat_w(use_a, use_b, use_c, use_d, use_e, use_f        : boolean; a_w, b_w, C_W, d_w, e_w, f_w : natural) return natural;
  function f_slv_concat_w(use_a, use_b, use_c, use_d, use_e               : boolean; a_w, b_w, C_W, d_w, e_w : natural) return natural;
  function f_slv_concat_w(use_a, use_b, use_c, use_d                      : boolean; a_w, b_w, C_W, d_w : natural) return natural;
  function f_slv_concat_w(use_a, use_b, use_c                             : boolean; a_w, b_w, C_W : natural) return natural;
  function f_slv_concat_w(use_a, use_b                                    : boolean; a_w, b_w : natural) return natural;

  --or extract one of them from a concatenated std_logic_vector
  -------------------------------------------------------------------------------
  -- extract one of them from a concatenated std_logic_vector.
  -- The function is overloaded for up to 7 inputs
  -- Example: f_slv_extract(true,true,2,2,"0111",0) = "01"
  -- use_a,use_b boolean to select which inputs to use
  -- a_w,b_w input widths of the concatenated data
  -- vec, input concatenated std_logic_vector data
  -- sel, select which data to extract
  -- std_logic_vector
  -------------------------------------------------------------------------------
  function f_slv_extract(use_a, use_b, use_c, use_d, use_e, use_f, use_g : boolean; a_w, b_w, C_W, d_w, e_w, f_w, g_w : natural; vec : std_logic_vector; sel : natural) return std_logic_vector;
  function f_slv_extract(use_a, use_b, use_c, use_d, use_e, use_f        : boolean; a_w, b_w, C_W, d_w, e_w, f_w : natural; vec : std_logic_vector; sel : natural) return std_logic_vector;
  function f_slv_extract(use_a, use_b, use_c, use_d, use_e               : boolean; a_w, b_w, C_W, d_w, e_w : natural; vec : std_logic_vector; sel : natural) return std_logic_vector;
  function f_slv_extract(use_a, use_b, use_c, use_d                      : boolean; a_w, b_w, C_W, d_w : natural; vec : std_logic_vector; sel : natural) return std_logic_vector;
  function f_slv_extract(use_a, use_b, use_c                             : boolean; a_w, b_w, C_W : natural; vec : std_logic_vector; sel : natural) return std_logic_vector;
  function f_slv_extract(use_a, use_b                                    : boolean; a_w, b_w : natural; vec : std_logic_vector; sel : natural) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- this function concatenate the vector in n times to form a longer
  -- out vector
  -- Example:
  -- n number of repetition, din input vector
  -- std_logic_vector concatenation of n in vectors
  -------------------------------------------------------------------------------
  function f_concat_repeat(n : natural; din : std_logic_vector) return std_logic_vector;

  -- the resize for signed in ieee.numeric_std extends the sign bit or it keeps the sign bit and ls part. this
  -- behaviour of preserving the sign bit is less suitable for dsp and not necessary in general. a more
  -- appropriate approach is to ignore the msbit sign and just keep the ls part. for too large values this
  -- means that the result gets wrapped, but that is fine for default behaviour, because that is also what
  -- happens for resize of unsigned. therefor this is what the f_lm_resize for signed and the f_resize_svec do
  -- and better not use resize for signed anymore.
  -- Example: define a signed s_a_signal and initialize it with "10101111"
  -- f_resize_svec(s_a_signal,5) returns "01111"
  function f_lm_resize(u    : unsigned; w : natural) return unsigned;  -- left extend with '0' or keep ls part (same as resize for unsigned)
  function f_lm_resize(s    : signed; w : natural) return signed;  -- extend sign bit or keep ls part
  function f_resize_uvec(sl  : std_logic; w : natural) return std_logic_vector;  -- left extend with '0' into slv
  function f_resize_uvec(vec : std_logic_vector; w : natural) return std_logic_vector;  -- left extend with '0' or keep ls part
  function f_resize_svec(vec : std_logic_vector; w : natural) return std_logic_vector;  -- extend sign bit or keep ls part

  -------------------------------------------------------------------------------
  -- this function return the ceil of the division between two integers.
  -- the f_div_ceil_2pwr function return the ceil of the division to the
  -- nearest power of 2
  -- Example:  f_div_ceil (5,3) = 2
  -- f_div_ceil_2pwr(7,2) = 4
  -- n number of repetition, din input vector
  -- std_logic_vector concatenation of n in vectors
  -------------------------------------------------------------------------------
  function f_div_ceil (a      : integer; b : integer) return integer;
  function f_div_ceil (a      : time; b : time) return integer;
  function f_div_ceil_2pwr (a : integer; b : integer) return integer;

  -------------------------------------------------------------------------------
  -- this function return the rounded value of the division between two integers.
  -- Example:  f_div_round (5,4) = 1; f_div_round (7,4) = 2; f_div_round (500,3) = 167;
  -------------------------------------------------------------------------------
  function f_div_round (a : integer; b : integer) return integer;

  -------------------------------------------------------------------------------
  -- this function return the shifted version of the input vector. It is
  -- overloaded for unsigned and signed
  -- < 0 shift left, > 0 shift right
  -- Example:  f_shift_uvec("11001",3) = "00011"
  -- f_shift_svec("11001",-2) = "11110"
  -- shift amount of shift, vec input vector
  -- std_logic_vector
  -------------------------------------------------------------------------------
  function f_shift_uvec(vec : std_logic_vector; shift : integer) return std_logic_vector;
  function f_shift_svec(vec : std_logic_vector; shift : integer) return std_logic_vector;

  function f_rol(arg : std_logic_vector; count : natural) return std_logic_vector;

  function f_ror(arg : std_logic_vector; count : natural) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- this function bit flip a vector, map a[h:0] to [0:h]
  -- Example: f_flip("1100") = "0011"
  -- a, input std_logic_vector data
  -- std_logic_vector
  -------------------------------------------------------------------------------
  function f_flip(a : std_logic_vector) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- transpose a vector, map a[i*row+j] to output index [j*col+i]
  -- Example:
  -- a std_logic_vector input vector; row, col natural
  -- std_logic_vector
  -------------------------------------------------------------------------------
  function f_transpose(a : std_logic_vector; row, col : natural) return std_logic_vector;

  -------------------------------------------------------------------------------
  -- convert digit to char to write into file (.txt)
  -- Example: f_digit_to_char("0000") = '0'
  -- input std_logic_vector(3 downto 0)
  -- character
  -------------------------------------------------------------------------------
  function f_digit_to_char(slv : std_logic_vector(3 downto 0)) return character;

  -------------------------------------------------------------------------------
  -- pad with zeroes a std_logic_vector on the left
  -- Example: f_zero_pad("1100",2) = "001100"
  -- input std_logic_vector, size of pad, to_left ndicates whether to pad on
  -- on the left or on the right, init_val set the value for padding
  -- std_logic_vector
  -------------------------------------------------------------------------------
  function f_zero_pad(vec     : std_logic_vector; size : positive;
                      to_left : boolean := true; init_val : std_logic := '0') return std_logic_vector;

  -------------------------------------------------------------------------------
  -- ectract a value from an input vector which represents an unrolled
  -- matrix. This functions are useful in VHDL 93 where there is less support for
  -- matrix operations on unconstrained arrays. It is overloaded also to extract
  -- a value from a concatenated array
  -- Example:
  -- arr input unrolled array, data_size width of data, row_dim, col_dim
  -- i index of row for extraction, j index of column for extraction
  -- std_logic_vector
  -------------------------------------------------------------------------------
  function f_arr2mat(arr     : std_logic_vector; data_size : natural; row_dim : natural;
                     col_dim : natural; i : natural; j : natural) return std_logic_vector;
  function f_arr2mat(arr : std_logic_vector; data_size : natural; row_dim : natural;
                     i   : natural) return std_logic_vector;
  function f_arr2mat(arr : signed; data_size : natural; row_dim : natural; i : natural) return signed;

  -- counts the number of 1 into std_logic_vector input
  -- - in_slv: std_logic_vector which 1 to be counted
  -- number of 1
  function f_count_ones(in_slv : std_logic_vector) return integer;

  -- check if the integere input if a power of two
  -- input: integer
  -- boolean
  function f_is_power_of_two(input : integer) return boolean;

  -------------------------------------------------------------------------------
  -- Maximum and minimum on integers
  -- Example: f_max(19,3) = 19
  -- l,r input integers
  -- integer
  -------------------------------------------------------------------------------
  function f_max(l, r : integer) return integer;
  function f_min(l, r : integer) return integer;

  -------------------------------------------------------------------------------
  -- the following funtions shall not be directly used by end users,
  -- they contains internal functions used to implement modules in other libraries
  -- N.A.
  -- N.A.
  -------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  -- latency of modules
  ------------------------------------------------------------------------------
  function f_get_bitsum_stages (g_din_w : integer; g_adder_w : integer) return integer;

  -------------------------------------------------------------------------------
  -- pull up
  -- input std_logic
  -- output std_logic
  -------------------------------------------------------------------------------
  function f_pullup(input : std_logic) return std_logic;

  -------------------------------------------------------------------------------
  -- pull down
  -- input std_logic
  -- output std_logic
  -------------------------------------------------------------------------------
  function f_pulldown(input : std_logic) return std_logic;

  -------------------------------------------------------------------------------
  -- log on console
  -- Example:
  -- input string
  -- -------------------------------------------------------------------------------
  procedure p_console_log(
    text_string : in string);

  -- String to std_logic_vector convert in 8-bit format using character'pos(c)
  -- - str: String to convert
  -- std_logic_vector(8 * str'length - 1 downto 0) with left-most
  -- character at MSBs.
  function f_string2slv(str : string) return std_logic_vector;

  -- String to std_logic_vector convert in 8-bit format using character'pos(c)
  -- - str: String to convert
  -- std_logic_vector(8 * str'length - 1 downto 0) with left-most
  -- character at MSBs. starting from characters lsb
  function f_string2slv_lsb(str : string) return std_logic_vector;

  -- std_logic_vector to character convert in ASCII format
  -- - slv8: std_logic_vector to convert
  -- character
  function f_slv2char (slv8 : std_logic_vector (7 downto 0)) return character;

  -- std_logic_vector to character convert in ASCII format
  -- - slv4: std_logic_vector to convert
  -- character
  function f_slv2ascii_hex (slv4 : std_logic_vector(3 downto 0)) return std_logic_vector;

  -- Standard logic vector to hex string conversion
  -- - slv: standard logic vector to convert
  -- string (slv in hex format)
  function f_slv2hex (slv : std_logic_vector) return string;

  -- Standard logic vector to string conversion: print a sequence of 1s or 0s characters
  -- - slv: standard logic vector to convert
  -- string (slv in ascii format)
  function f_slv2string (slv : std_logic_vector) return string;

  function f_char_is_digit(chr           : character) return boolean;
  function f_char_is_lower_hex_digit(chr : character) return boolean;
  function f_char_is_upper_hex_digit(chr : character) return boolean;
  function f_char_is_hex_digit(chr       : character) return boolean;
  function f_char_is_lower(chr           : character) return boolean;
  function f_char_is_lower_alpha(chr     : character) return boolean;
  function f_char_is_upper(chr           : character) return boolean;
  function f_char_is_upper_alpha(chr     : character) return boolean;
  function f_char_is_alpha(chr           : character) return boolean;

  function f_char_to_lower(chr : character) return character;
  function f_char_to_upper(chr : character) return character;

  function f_bin2digit(chr : character) return integer;
  function f_oct2digit(chr : character) return integer;
  function f_dec2digit(chr : character) return integer;
  function f_hex2digit(chr : character) return integer;
  function f_to_digit(chr  : character; base : character := 'd') return integer;

  function f_string_format(value : real; precision : natural                 := 3) return string;
  function f_string_length(str   : string) return natural;
  function f_string_equal(str1   : string; str2 : string) return boolean;
  function f_string_match(str1   : string; str2 : string) return boolean;
  function f_string_imatch(str1  : string; str2 : string) return boolean;
  function f_string_pos(str      : string; chr : character; start : natural  := 0) return integer;
  function f_string_pos(str      : string; pattern : string; start : natural := 0) return integer;
  function f_string_ipos(str     : string; chr : character; start : natural  := 0) return integer;
  function f_string_ipos(str     : string; pattern : string; start : natural := 0) return integer;
  function f_string_find(str     : string; chr : character) return boolean;
  function f_string_find(str     : string; pattern : string) return boolean;
  function f_string_ifind(str    : string; chr : character) return boolean;
  function f_string_ifind(str    : string; pattern : string) return boolean;
  function f_string_replace(str  : string; pattern : string; replace : string) return string;
  function f_string_substr(str   : string; start : integer                   := 0; length : integer := 0) return string;
  function f_string_ltrim(str    : string; char : character                  := ' ') return string;
  function f_string_rtrim(str    : string; char : character                  := ' ') return string;
  function f_string_trim(str     : string) return string;
  function f_string_toLower(str  : string) return string;
  function f_string_toUpper(str  : string) return string;

end lm_util_pkg;

package body lm_util_pkg is

  function f_ceil_log2(n : natural) return natural is
    variable v_i, v_bitcount : natural;
  begin
    assert n > 0 report "f_ceil_log2(0) called!" severity failure;
        -- Natural is kept here to preserve zero-width edge-case handling.
    if n = 1 then
      v_bitcount := 1;
    else
      v_i        := n-1;
      v_bitcount := 0;
      while (v_i > 0) loop
        v_bitcount := v_bitcount + 1;
        v_i        := to_integer(shift_right(to_unsigned(v_i, 32), 1));
      end loop;
    end if;
    return v_bitcount;
  end;

  function f_floor_log2(n : natural) return natural is
    variable v_i, v_bitcount : natural;
  begin
    v_i        := n;
    v_bitcount := 0;
    while (v_i > 1) loop
      v_bitcount := v_bitcount + 1;
      v_i        := to_integer(shift_right(to_unsigned(v_i, 32), 1));
    end loop;
    return v_bitcount;
  end;

  function f_sl2bool(n : in std_logic) return boolean is
    variable v_r : boolean;
  begin
    if n = '1' then
      v_r := true;
    else
      v_r := false;
    end if;
    return v_r;
  end;

  function f_sl2char(n : in std_logic) return character is
  begin
    case n is
      when 'U' => return 'U';  -- Uninitialized
      when 'X' => return 'X';  -- Unknown
      when '0' => return '0';
      when '1' => return '1';
      when 'Z' => return 'Z';  -- High impedance
      when 'W' => return 'W';  -- Weak unknown
      when 'L' => return 'L';  -- Weak 0
      when 'H' => return 'H';  -- Weak 1
      when '-' => return '-';  -- Don't care
      when others => return '?'; -- Just in case
    end case;
  end;

  function f_hex2slv(c: character) return std_logic_vector is
  begin
    case c is
      when '0' => return "0000";
      when '1' => return "0001";
      when '2' => return "0010";
      when '3' => return "0011";
      when '4' => return "0100";
      when '5' => return "0101";
      when '6' => return "0110";
      when '7' => return "0111";
      when '8' => return "1000";
      when '9' => return "1001";
      when 'A' | 'a' => return "1010";
      when 'B' | 'b' => return "1011";
      when 'C' | 'c' => return "1100";
      when 'D' | 'd' => return "1101";
      when 'E' | 'e' => return "1110";
      when 'F' | 'f' => return "1111";
      when others =>
        report "Invalid hex digit: " & c
        severity error;
    end case;
    return "U";
  end function;

  function f_hex2slv (hex : string) return std_logic_vector is
    constant C_NIBBLE_WIDTH : integer := 4;
    variable v_result : std_logic_vector((hex'length * C_NIBBLE_WIDTH) - 1 downto 0);
  begin
    for i in hex'range loop
      v_result((hex'length-i+1)*C_NIBBLE_WIDTH - 1  downto (hex'length-i)*C_NIBBLE_WIDTH) := f_hex2slv(hex(i));
    end loop;
    return v_result;
  end;

  function f_bool2int(n : in boolean) return integer is
  begin
    if n then
      return 1;
    else
      return 0;
    end if;
  end function;

  function f_bool2sl(n : in boolean) return std_logic is
    variable v_r : std_logic;
  begin
    if n = true then
      v_r := '1';
    else
      v_r := '0';
    end if;
    return v_r;
  end;

  function f_sl2slv(n : in std_logic) return std_logic_vector is
    variable v_r : std_logic_vector(0 downto 0);
  begin
    v_r(0) := n;
    return v_r;
  end;

  function f_sl2int(n : in std_logic) return integer is
    variable v_retval : integer;
  begin
    if (n = '1') then
      v_retval := 1;
    else
      v_retval := 0;
    end if;

    return v_retval;
  end;

  function f_int2sl(n : in integer) return std_logic is
    variable v_retval : std_logic;
  begin

    assert n = 0 or n = 1
      report "The f_int2sl function accepts only integer 0 and 1 as input arguments"
      severity failure;

    if n = 0 then
      v_retval := '0';
    elsif n = 1 then
      v_retval := '1';
    else
      v_retval := 'X';
    end if;

    return v_retval;

  end function f_int2sl;


  function f_int2slv(n : in integer; dim : in natural) return std_logic_vector is
    variable v_retval : std_logic_vector(dim - 1 downto 0);
  begin
    v_retval := std_logic_vector(to_signed(n, dim));

    return v_retval;
  end function f_int2slv;

  function f_slv2sl(n : in std_logic_vector) return std_logic is
    variable v_r : std_logic;
  begin
    v_r := n(n'low);
    return v_r;
  end function f_slv2sl;

  function f_slv2nat(vec : std_logic_vector) return natural is
  begin
    return to_integer(unsigned(vec));
  end;

  function f_slv2int(vec : std_logic_vector) return integer is
  begin
    return to_integer(signed(vec));
  end;

  function f_nat2slv(dec, w : natural) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(dec, w));
  end;

  ------------------------------------------------------------------------------
  -- Arithmetic conversion functions
  ------------------------------------------------------------------------------
  -- convert a std_logic_vector to a unsigned type
  function f_slv2uns(inp : std_logic_vector) return unsigned is
  begin
    return unsigned(inp);
  end;  --f_slv2uns


  -- convert an unsigend to a std_logic_vector
  function f_uns2slv(inp : unsigned) return std_logic_vector is
  begin
    return std_logic_vector(inp);
  end;  --f_uns2slv

  -- convert an integer to a unsigned (abs if negative)
  function f_int2uns(inp : integer; width : integer) return unsigned is
  begin
    return to_unsigned(abs(inp), width);
  end;  --f_int2uns

  -- convert an unsigned to a integer
  function f_uns2int(inp : unsigned) return integer is
  begin
    return to_integer(inp);
  end;  --f_uns2int

  -- convert an integer to a signed
  function f_int2sig(inp : integer; width : integer) return signed is
  begin
    return to_signed(inp, width);
  end;  --f_int2sig

  -- convert an signed to a integer
  function f_sig2int(inp : signed) return integer is
  begin
    return to_integer(inp);
  end;  --f_sig2int

  -- convert an std_logic_vector to a signed
  function f_slv2sig(inp : std_logic_vector) return signed is
  begin
    return signed(inp);
  end;  --f_slv2sig


  -- convert an std_logic_vector to a sigend
  function f_sig2slv(inp : signed) return std_logic_vector is
  begin
    return std_logic_vector(inp);
  end;  --f_sig2slv


  -- convert unsigned to signed with sign
  function f_uns2sig(inp : unsigned; sign : std_logic) return signed is
    variable v_res : signed(inp'left+1 downto 0);
  begin  -- unsigned_to_signed
    if sign = '0' then
      v_res := signed('0'& (std_logic_vector(inp(inp'left downto 0))));
    else
      v_res := signed('1'& (not std_logic_vector(unsigned(inp))))+1;
    end if;

    return v_res;
  end;  --f_uns2sig


  -- convert signed to unsigned
  function f_sig2uns(inp : signed; sign : std_logic) return unsigned is
    variable v_res : unsigned(inp'left-1 downto 0);
  begin  -- signed_to_unsigned
    if sign = '0' then
      v_res := unsigned((std_logic_vector(inp(inp'left-1 downto 0))));
    else
      v_res := unsigned(not std_logic_vector(inp(inp'left-1 downto 0))) + to_unsigned(1, inp'length-1);
    end if;

    return v_res;
  end;  --f_sig2uns


  -- binary to gray-code encoder
  function f_bin2gray(a : std_logic_vector) return std_logic_vector is
    variable v_a : std_logic_vector(a'length-1 downto 0) := a;
  begin
    assert v_a'length > 1
      report "lm_util_lib.f_bin2gray error! Input length must be greater than 1!"
      severity failure;
    return v_a xor ("0" & v_a(v_a'length - 1 downto 1));
  end function;
  -- gray-code to binary decoder
  function f_gray2bin(a : std_logic_vector) return std_logic_vector is
    variable v_a   : std_logic_vector(a'length-1 downto 0) := a;
    variable v_bin : std_logic_vector(v_a'range);
    variable v_int : std_logic;
  begin
    assert v_a'length > 1
      report "lm_util_lib.f_gray2bin error! Input length must be greater than 1!"
      severity failure;
    v_int := '0';
    for n in v_a'length - 1 downto 0 loop
      v_bin(n) := v_a(n) xor v_int;
      v_int    := v_bin(n);
    end loop;
    return v_bin;
  end function;

  function f_int2nat_arr(n : t_integer_arr) return t_natural_arr is
    variable v_n : t_integer_arr(n'length - 1 downto 0);
    variable v_r : t_natural_arr(n'length - 1 downto 0);
  begin
    v_n := n;
    for i in v_n'range loop
      v_r(i) := v_n(i);
    end loop;
    return v_r;
  end;

  function f_nat2int_arr(n : t_natural_arr) return t_integer_arr is
    variable v_n : t_natural_arr(n'length - 1 downto 0);
    variable v_r : t_integer_arr(n'length - 1 downto 0);
  begin
    v_n := n;
    for i in v_n'range loop
      v_r(i) := v_n(i);
    end loop;
    return v_r;
  end;


  -- Operation is encoded as an integer to keep the package API compact.
  function f_vector_tree(slv : std_logic_vector; operation : integer) return std_logic is
    -- linear loop to determine result takes combinatorial delay that is proportional to slv'length:
    --   for i in slv'range loop
    --     v_result := v_result operation slv(i);
    --   end loop;
    --   return v_result;
    -- instead use binary tree to determine result with f_smallest combinatorial delay that depends on log2(slv'length)
    constant C_SLV_W      : natural   := slv'length;
    constant C_NOF_STEGES : natural   := f_ceil_log2(C_SLV_W);
    constant C_W          : natural   := 2 ** C_NOF_STEGES;  -- extend the input slv to a vector with length power of 2 to ease using binary tree
    type t_stage_arr is array (-1 to C_NOF_STEGES - 1) of std_logic_vector(C_W - 1 downto 0);
    variable v_stage_arr  : t_stage_arr;
    variable v_result     : std_logic := '0';
  begin
    -- default any unused, the stage results will be kept in the lsbits and the last result in bit 0
    if operation = C_LM_AND then
      v_stage_arr := (others => (others => '1'));
    elsif operation = C_LM_OR then
      v_stage_arr := (others => (others => '0'));
    elsif operation = C_LM_XOR then
      v_stage_arr := (others => (others => '0'));
    else
      assert false report "lm_util_pkg: unsupported f_vector_tree operation" severity failure;
    end if;
    v_stage_arr(-1)(C_SLV_W - 1 downto 0) := slv;  -- any unused input C_W : C_SLV_W bits have void default value
    for j in 0 to C_NOF_STEGES - 1 loop
      for i in 0 to C_W / (2 ** (j + 1)) - 1 loop
        if operation = C_LM_AND then
          v_stage_arr(j)(i) := v_stage_arr(j - 1)(2 * i) and v_stage_arr(j - 1)(2 * i + 1);
        elsif operation = C_LM_OR then
          v_stage_arr(j)(i) := v_stage_arr(j - 1)(2 * i) or v_stage_arr(j - 1)(2 * i + 1);
        elsif operation = C_LM_XOR then
          v_stage_arr(j)(i) := v_stage_arr(j - 1)(2 * i) xor v_stage_arr(j - 1)(2 * i + 1);
        end if;
      end loop;
    end loop;
    v_result := v_stage_arr(C_NOF_STEGES - 1)(0);
    return v_result;
  end;

  function f_vector_and(slv : std_logic_vector) return std_logic is
  begin
    return f_vector_tree(slv, C_LM_AND);
  end;

  function f_vector_or(slv : std_logic_vector) return std_logic is
  begin
    return f_vector_tree(slv, C_LM_OR);
  end;

  function f_vector_xor(slv : std_logic_vector) return std_logic is
  begin
    return f_vector_tree(slv, C_LM_XOR);
  end;

  function f_matrix_and(mat : t_sl_matrix; wi, wj : natural) return std_logic is
    variable v_mat    : t_sl_matrix(0 to wi - 1, 0 to wj - 1) := mat;  -- map to fixed range
    variable v_result : std_logic                             := '1';
  begin
    for i in 0 to wi - 1 loop
      for j in 0 to wj - 1 loop
        v_result := v_result and v_mat(i, j);
      end loop;
    end loop;
    return v_result;
  end;

  function f_matrix_or(mat : t_sl_matrix; wi, wj : natural) return std_logic is
    variable v_mat    : t_sl_matrix(0 to wi - 1, 0 to wj - 1) := mat;  -- map to fixed range
    variable v_result : std_logic                             := '0';
  begin
    for i in 0 to wi - 1 loop
      for j in 0 to wj - 1 loop
        v_result := v_result or v_mat(i, j);
      end loop;
    end loop;
    return v_result;
  end;

  function f_smallest(n, m : natural) return natural is
  begin
    if n < m then
      return n;
    else
      return m;
    end if;
  end;

  function f_smallest(n, m, l : natural) return natural is
    variable v_ret : natural;
  begin
    v_ret := n;
    if v_ret > m then
      v_ret := m;
    end if;
    if v_ret > l then
      v_ret := l;
    end if;
    return v_ret;
  end;

  function f_smallest(n : t_natural_arr) return natural is
    variable v_m : natural := natural'high;
  begin
    for i in n'range loop
      if n(i) < v_m then
        v_m := n(i);
      end if;
    end loop;
    return v_m;
  end;

  function f_largest(n, m : natural) return natural is
  begin
    if n > m then
      return n;
    else
      return m;
    end if;
  end;

  function f_largest(n : t_natural_arr) return natural is
    variable v_m : natural := 0;
  begin
    for i in n'range loop
      if n(i) > v_m then
        v_m := n(i);
      end if;
    end loop;
    return v_m;
  end;

  function f_sum_natural_arr(n : t_natural_arr) return natural is
    variable v_s : natural;
  begin
    v_s := 0;
    for i in n'range loop
      v_s := v_s + n(i);
    end loop;
    return v_s;
  end;

  --  function f_sum_natural_arr(n : t_natural_arr) return natural is
  --    variable vn : t_natural_arr(n'length-1 downto 0);
  --  begin
  --    vn := f_int2nat_arr(n);
  --    return f_sum_natural_arr(vn);
  --  end;

  function f_prod_natural_arr(n : t_natural_arr) return natural is
    variable v_p : natural;
  begin
    v_p := 1;
    for i in n'range loop
      v_p := v_p * n(i);
    end loop;
    return v_p;
  end;

  --  function f_prod_natural_arr(n : t_natural_arr) return natural is
  --    variable vn : t_natural_arr(n'length-1 downto 0);
  --  begin
  --    vn := f_int2nat_arr(n);
  --    return f_prod_natural_arr(vn);
  --  end;

  function "+"(l, r : t_natural_arr) return t_natural_arr is
    variable v_l : t_natural_arr(l'length - 1 downto 0);
    variable v_r : t_natural_arr(l'length - 1 downto 0);
    variable v_p : t_natural_arr(l'length - 1 downto 0);
  begin
    v_l := l;
    v_r := r;
    for i in v_l'range loop
      v_p(i) := v_l(i) + v_r(i);
    end loop;
    return v_p;
  end;

  function "+"(l : t_natural_arr; r : integer) return t_natural_arr is
    variable v_l : t_natural_arr(l'length - 1 downto 0);
    variable v_p : t_natural_arr(l'length - 1 downto 0);
  begin
    v_l := l;
    for i in v_l'range loop
      v_p(i) := v_l(i) + r;
    end loop;
    return v_p;
  end;

  function "+"(l : integer; r : t_natural_arr) return t_natural_arr is
  begin
    return r + l;
  end;

  function "-"(l, r : t_natural_arr) return t_natural_arr is
    variable v_l : t_natural_arr(l'length - 1 downto 0);
    variable v_r : t_natural_arr(l'length - 1 downto 0);
    variable v_p : t_natural_arr(l'length - 1 downto 0);
  begin
    v_l := l;
    v_r := r;
    for i in v_l'range loop
      v_p(i) := v_l(i) - v_r(i);
    end loop;
    return v_p;
  end;

  function "-"(l, r : t_natural_arr) return t_integer_arr is
    variable v_l : t_natural_arr(l'length - 1 downto 0);
    variable v_r : t_natural_arr(l'length - 1 downto 0);
    variable v_p : t_integer_arr(l'length - 1 downto 0);
  begin
    v_l := l;
    v_r := r;
    for i in v_l'range loop
      v_p(i) := v_l(i) - v_r(i);
    end loop;
    return v_p;
  end;

  function "-"(l : t_natural_arr; r : integer) return t_natural_arr is
    variable v_l : t_natural_arr(l'length - 1 downto 0);
    variable v_p : t_natural_arr(l'length - 1 downto 0);
  begin
    v_l := l;
    for i in v_l'range loop
      v_p(i) := v_l(i) - r;
    end loop;
    return v_p;
  end;

  function "-"(l : integer; r : t_natural_arr) return t_natural_arr is
    variable v_r : t_natural_arr(r'length - 1 downto 0);
    variable v_p : t_natural_arr(r'length - 1 downto 0);
  begin
    v_r := r;
    for i in v_r'range loop
      v_p(i) := l - v_r(i);
    end loop;
    return v_p;
  end;

  function "*"(l, r : t_natural_arr) return t_natural_arr is
    variable v_l : t_natural_arr(l'length - 1 downto 0);
    variable v_r : t_natural_arr(l'length - 1 downto 0);
    variable v_p : t_natural_arr(l'length - 1 downto 0);
  begin
    v_l := l;
    v_r := r;
    for i in v_l'range loop
      v_p(i) := v_l(i) * v_r(i);
    end loop;
    return v_p;
  end;

  function "*"(l : t_natural_arr; r : natural) return t_natural_arr is
    variable v_l : t_natural_arr(l'length - 1 downto 0);
    variable v_p : t_natural_arr(l'length - 1 downto 0);
  begin
    v_l := l;
    for i in v_l'range loop
      v_p(i) := v_l(i) * r;
    end loop;
    return v_p;
  end;

  function "*"(l : natural; r : t_natural_arr) return t_natural_arr is
  begin
    return r * l;
  end;

  function "/"(l, r : t_natural_arr) return t_natural_arr is
    variable v_l : t_natural_arr(l'length - 1 downto 0);
    variable v_r : t_natural_arr(l'length - 1 downto 0);
    variable v_p : t_natural_arr(l'length - 1 downto 0);
  begin
    v_l := l;
    v_r := r;
    for i in v_l'range loop
      v_p(i) := v_l(i) / v_r(i);
    end loop;
    return v_p;
  end;

  function "/"(l : t_natural_arr; r : positive) return t_natural_arr is
    variable v_l : t_natural_arr(l'length - 1 downto 0);
    variable v_p : t_natural_arr(l'length - 1 downto 0);
  begin
    v_l := l;
    for i in v_l'range loop
      v_p(i) := v_l(i) / r;
    end loop;
    return v_p;
  end;

  function "/"(l : natural; r : t_natural_arr) return t_natural_arr is
    variable v_r : t_natural_arr(r'length - 1 downto 0);
    variable v_p : t_natural_arr(r'length - 1 downto 0);
  begin
    v_r := r;
    for i in v_r'range loop
      v_p(i) := l / v_r(i);
    end loop;
    return v_p;
  end;

  function f_is_true(a : std_logic) return boolean is
  begin
    if a = '1' then
      return true;
    else
      return false;
    end if;
  end;
  function f_is_true(a : std_logic) return natural is
  begin
    if a = '1' then
      return 1;
    else
      return 0;
    end if;
  end;
  function f_is_true(a : boolean) return std_logic is
  begin
    if a = true then
      return '1';
    else
      return '0';
    end if;
  end;
  function f_is_true(a : boolean) return natural is
  begin
    if a = true then
      return 1;
    else
      return 0;
    end if;
  end;
  function f_is_true(a : integer) return boolean is
  begin
    if a /= 0 then
      return true;
    else
      return false;
    end if;
  end;
  function f_is_true(a : integer) return std_logic is
  begin
    if a /= 0 then
      return '1';
    else
      return '0';
    end if;
  end;

  function f_sel_a_b(sel, a, b : integer) return integer is
  begin
    if sel /= 0 then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel, a, b : boolean) return boolean is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : boolean; a, b : integer) return integer is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : boolean; a, b : real) return real is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : boolean; a, b : std_logic) return std_logic is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : integer; a, b : std_logic) return std_logic is
  begin
    if sel /= 0 then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : integer; a, b : std_logic_vector) return std_logic_vector is
  begin
    if sel /= 0 then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : boolean; a, b : std_logic_vector) return std_logic_vector is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : boolean; a, b : signed) return signed is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : boolean; a, b : unsigned) return unsigned is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  --  function f_sel_a_b(sel : boolean; a, b : t_integer_arr) return t_integer_arr is
  --  begin
  --    if sel = true then
  --      return a;
  --    else
  --      return b;
  --    end if;
  --  end;
  --
  --  function f_sel_a_b(sel : boolean; a, b : t_natural_arr) return t_natural_arr is
  --  begin
  --    if sel = true then
  --      return a;
  --    else
  --      return b;
  --    end if;
  --  end;

  function f_sel_a_b(sel : boolean; a, b : t_integer_arr) return t_integer_arr is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : boolean; a, b : t_natural_arr) return t_natural_arr is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : boolean; a, b : string) return string is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  function f_sel_a_b(sel : boolean; a, b : time) return time is
  begin
    if sel = true then
      return a;
    else
      return b;
    end if;
  end;

  -- f_sel_n : boolean
  function f_sel_n(sel : natural; a, b, c : boolean) return boolean is
    constant C_ARR : t_boolean_arr := (a, b, c);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d : boolean) return boolean is
    constant C_ARR : t_boolean_arr := (a, b, c, d);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e : boolean) return boolean is
    constant C_ARR : t_boolean_arr := (a, b, c, d, e);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e, f : boolean) return boolean is
    constant C_ARR : t_boolean_arr := (a, b, c, d, e, f);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e, f, g : boolean) return boolean is
    constant C_ARR : t_boolean_arr := (a, b, c, d, e, f, g);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h : boolean) return boolean is
    constant C_ARR : t_boolean_arr := (a, b, c, d, e, f, g, h);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h, i : boolean) return boolean is
    constant C_ARR : t_boolean_arr := (a, b, c, d, e, f, g, h, i);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h, i, j : boolean) return boolean is
    constant C_ARR : t_boolean_arr := (a, b, c, d, e, f, g, h, i, j);
  begin
    return C_ARR(sel);
  end;

  -- f_sel_n : integer
  function f_sel_n(sel : natural; a, b, c : integer) return integer is
    constant C_ARR : t_integer_arr := (a, b, c);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d : integer) return integer is
    constant C_ARR : t_integer_arr := (a, b, c, d);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e : integer) return integer is
    constant C_ARR : t_integer_arr := (a, b, c, d, e);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e, f : integer) return integer is
    constant C_ARR : t_integer_arr := (a, b, c, d, e, f);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e, f, g : integer) return integer is
    constant C_ARR : t_integer_arr := (a, b, c, d, e, f, g);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h : integer) return integer is
    constant C_ARR : t_integer_arr := (a, b, c, d, e, f, g, h);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h, i : integer) return integer is
    constant C_ARR : t_integer_arr := (a, b, c, d, e, f, g, h, i);
  begin
    return C_ARR(sel);
  end;

  function f_sel_n(sel : natural; a, b, c, d, e, f, g, h, i, j : integer) return integer is
    constant C_ARR : t_integer_arr := (a, b, c, d, e, f, g, h, i, j);
  begin
    return C_ARR(sel);
  end;

  function f_array_init(init : std_logic; nof : natural) return std_logic_vector is
    variable v_arr : std_logic_vector(natural'left to natural'left + nof - 1);
  begin
    for i in v_arr'range loop
      v_arr(i) := init;
    end loop;
    return v_arr;
  end;

  --  function f_array_init(init, nof : natural) return t_natural_arr is
  --    variable v_arr : t_natural_arr(integer'left to integer'left+nof-1);
  --  begin
  --    for i in v_arr'range loop
  --      v_arr(i) := init;
  --    end loop;
  --    return v_arr;
  --  end;

  function f_array_init(init, nof : natural) return t_natural_arr is
    variable v_arr : t_natural_arr(0 to nof - 1);
  begin
    for i in v_arr'range loop
      v_arr(i) := init;
    end loop;
    return v_arr;
  end;

  --  function f_array_init(init, nof, incr : natural) return t_natural_arr is
  --    variable v_arr : t_natural_arr(integer'left to integer'left+nof-1);
  --    variable v_i   : natural;
  --  begin
  --    v_i := 0;
  --    for i in v_arr'range loop
  --      v_arr(i) := init + v_i * incr;
  --      v_i := v_i + 1;
  --    end loop;
  --    return v_arr;
  --  end;

  function f_array_init(init, nof, incr : natural) return t_natural_arr is
    variable v_arr : t_natural_arr(0 to nof - 1);
    variable v_i   : natural;
  begin
    v_i := 0;
    for i in v_arr'range loop
      v_arr(i) := init + v_i * incr;
      v_i      := v_i + 1;
    end loop;
    return v_arr;
  end;

  -- support concatenation of up to 7 slv into 1 slv
  function f_slv_concat(use_a, use_b, use_c, use_d, use_e, use_f, use_g : boolean; a, b, c, d, e, f, g : std_logic_vector) return std_logic_vector is
    constant C_MAX_W : natural                                := a'length + b'length + c'length + d'length + e'length + f'length + g'length;
    variable v_res   : std_logic_vector(C_MAX_W - 1 downto 0) := (others => '0');
    variable v_len   : natural                                := 0;
  begin
    if use_a = true then
      v_res(a'length - 1 + v_len downto v_len) := a;
      v_len                                    := v_len + a'length;
    end if;
    if use_b = true then
      v_res(b'length - 1 + v_len downto v_len) := b;
      v_len                                    := v_len + b'length;
    end if;
    if use_c = true then
      v_res(c'length - 1 + v_len downto v_len) := c;
      v_len                                    := v_len + c'length;
    end if;
    if use_d = true then
      v_res(d'length - 1 + v_len downto v_len) := d;
      v_len                                    := v_len + d'length;
    end if;
    if use_e = true then
      v_res(e'length - 1 + v_len downto v_len) := e;
      v_len                                    := v_len + e'length;
    end if;
    if use_f = true then
      v_res(f'length - 1 + v_len downto v_len) := f;
      v_len                                    := v_len + f'length;
    end if;
    if use_g = true then
      v_res(g'length - 1 + v_len downto v_len) := g;
      v_len                                    := v_len + g'length;
    end if;
    return v_res(v_len - 1 downto 0);
  end f_slv_concat;

  function f_slv_concat(use_a, use_b, use_c, use_d, use_e, use_f : boolean; a, b, c, d, e, f : std_logic_vector) return std_logic_vector is
  begin
    return f_slv_concat(use_a, use_b, use_c, use_d, use_e, use_f, false, a, b, c, d, e, f, "0");
  end f_slv_concat;

  function f_slv_concat(use_a, use_b, use_c, use_d, use_e : boolean; a, b, c, d, e : std_logic_vector) return std_logic_vector is
  begin
    return f_slv_concat(use_a, use_b, use_c, use_d, use_e, false, false, a, b, c, d, e, "0", "0");
  end f_slv_concat;

  function f_slv_concat(use_a, use_b, use_c, use_d : boolean; a, b, c, d : std_logic_vector) return std_logic_vector is
  begin
    return f_slv_concat(use_a, use_b, use_c, use_d, false, false, false, a, b, c, d, "0", "0", "0");
  end f_slv_concat;

  function f_slv_concat(use_a, use_b, use_c : boolean; a, b, c : std_logic_vector) return std_logic_vector is
  begin
    return f_slv_concat(use_a, use_b, use_c, false, false, false, false, a, b, c, "0", "0", "0", "0");
  end f_slv_concat;

  function f_slv_concat(use_a, use_b : boolean; a, b : std_logic_vector) return std_logic_vector is
  begin
    return f_slv_concat(use_a, use_b, false, false, false, false, false, a, b, "0", "0", "0", "0", "0");
  end f_slv_concat;

  function f_slv_concat_w(use_a, use_b, use_c, use_d, use_e, use_f, use_g : boolean; a_w, b_w, C_W, d_w, e_w, f_w, g_w : natural) return natural is
    variable v_len : natural := 0;
  begin
    if use_a = true then
      v_len := v_len + a_w;
    end if;
    if use_b = true then
      v_len := v_len + b_w;
    end if;
    if use_c = true then
      v_len := v_len + C_W;
    end if;
    if use_d = true then
      v_len := v_len + d_w;
    end if;
    if use_e = true then
      v_len := v_len + e_w;
    end if;
    if use_f = true then
      v_len := v_len + f_w;
    end if;
    if use_g = true then
      v_len := v_len + g_w;
    end if;
    return v_len;
  end f_slv_concat_w;

  function f_slv_concat_w(use_a, use_b, use_c, use_d, use_e, use_f : boolean; a_w, b_w, C_W, d_w, e_w, f_w : natural) return natural is
  begin
    return f_slv_concat_w(use_a, use_b, use_c, use_d, use_e, use_f, false, a_w, b_w, C_W, d_w, e_w, f_w, 0);
  end f_slv_concat_w;

  function f_slv_concat_w(use_a, use_b, use_c, use_d, use_e : boolean; a_w, b_w, C_W, d_w, e_w : natural) return natural is
  begin
    return f_slv_concat_w(use_a, use_b, use_c, use_d, use_e, false, false, a_w, b_w, C_W, d_w, e_w, 0, 0);
  end f_slv_concat_w;

  function f_slv_concat_w(use_a, use_b, use_c, use_d : boolean; a_w, b_w, C_W, d_w : natural) return natural is
  begin
    return f_slv_concat_w(use_a, use_b, use_c, use_d, false, false, false, a_w, b_w, C_W, d_w, 0, 0, 0);
  end f_slv_concat_w;

  function f_slv_concat_w(use_a, use_b, use_c : boolean; a_w, b_w, C_W : natural) return natural is
  begin
    return f_slv_concat_w(use_a, use_b, use_c, false, false, false, false, a_w, b_w, C_W, 0, 0, 0, 0);
  end f_slv_concat_w;

  function f_slv_concat_w(use_a, use_b : boolean; a_w, b_w : natural) return natural is
  begin
    return f_slv_concat_w(use_a, use_b, false, false, false, false, false, a_w, b_w, 0, 0, 0, 0, 0);
  end f_slv_concat_w;

  -- extract slv
  function f_slv_extract(use_a, use_b, use_c, use_d, use_e, use_f, use_g : boolean; a_w, b_w, C_W, d_w, e_w, f_w, g_w : natural; vec : std_logic_vector; sel : natural) return std_logic_vector is
    variable v_w  : natural := 0;
    variable v_lo : natural := 0;
  begin
    -- if the selected slv is not used in vec, then return dummy, else return the selected slv from vec
    case sel is
      when 0 =>
        if use_a = true then
          v_w := a_w;
        else
          return (a_w - 1 downto 0 => '0');
        end if;
      when 1 =>
        if use_b = true then
          v_w := b_w;
        else
          return (b_w - 1 downto 0 => '0');
        end if;
        if use_a = true then
          v_lo := v_lo + a_w;
        end if;
      when 2 =>
        if use_c = true then
          v_w := C_W;
        else
          return (C_W - 1 downto 0 => '0');
        end if;
        if use_a = true then
          v_lo := v_lo + a_w;
        end if;
        if use_b = true then
          v_lo := v_lo + b_w;
        end if;
      when 3 =>
        if use_d = true then
          v_w := d_w;
        else
          return (d_w - 1 downto 0 => '0');
        end if;
        if use_a = true then
          v_lo := v_lo + a_w;
        end if;
        if use_b = true then
          v_lo := v_lo + b_w;
        end if;
        if use_c = true then
          v_lo := v_lo + C_W;
        end if;
      when 4 =>
        if use_e = true then
          v_w := e_w;
        else
          return (e_w - 1 downto 0 => '0');
        end if;
        if use_a = true then
          v_lo := v_lo + a_w;
        end if;
        if use_b = true then
          v_lo := v_lo + b_w;
        end if;
        if use_c = true then
          v_lo := v_lo + C_W;
        end if;
        if use_d = true then
          v_lo := v_lo + d_w;
        end if;
      when 5 =>
        if use_f = true then
          v_w := f_w;
        else
          return (f_w - 1 downto 0 => '0');
        end if;
        if use_a = true then
          v_lo := v_lo + a_w;
        end if;
        if use_b = true then
          v_lo := v_lo + b_w;
        end if;
        if use_c = true then
          v_lo := v_lo + C_W;
        end if;
        if use_d = true then
          v_lo := v_lo + d_w;
        end if;
        if use_e = true then
          v_lo := v_lo + e_w;
        end if;
      when 6 =>
        if use_g = true then
          v_w := g_w;
        else
          return (g_w - 1 downto 0 => '0');
        end if;
        if use_a = true then
          v_lo := v_lo + a_w;
        end if;
        if use_b = true then
          v_lo := v_lo + b_w;
        end if;
        if use_c = true then
          v_lo := v_lo + C_W;
        end if;
        if use_d = true then
          v_lo := v_lo + d_w;
        end if;
        if use_e = true then
          v_lo := v_lo + e_w;
        end if;
        if use_f = true then
          v_lo := v_lo + f_w;
        end if;
      when others => report "unknown common_pkg f_slv_extract argument" severity failure;
    end case;
    return vec(v_w - 1 + v_lo downto v_lo);  -- extracted slv
  end f_slv_extract;

  function f_slv_extract(use_a, use_b, use_c, use_d, use_e, use_f : boolean; a_w, b_w, C_W, d_w, e_w, f_w : natural; vec : std_logic_vector; sel : natural) return std_logic_vector is
  begin
    return f_slv_extract(use_a, use_b, use_c, use_d, use_e, use_f, false, a_w, b_w, C_W, d_w, e_w, f_w, 0, vec, sel);
  end f_slv_extract;

  function f_slv_extract(use_a, use_b, use_c, use_d, use_e : boolean; a_w, b_w, C_W, d_w, e_w : natural; vec : std_logic_vector; sel : natural) return std_logic_vector is
  begin
    return f_slv_extract(use_a, use_b, use_c, use_d, use_e, false, false, a_w, b_w, C_W, d_w, e_w, 0, 0, vec, sel);
  end f_slv_extract;

  function f_slv_extract(use_a, use_b, use_c, use_d : boolean; a_w, b_w, C_W, d_w : natural; vec : std_logic_vector; sel : natural) return std_logic_vector is
  begin
    return f_slv_extract(use_a, use_b, use_c, use_d, false, false, false, a_w, b_w, C_W, d_w, 0, 0, 0, vec, sel);
  end f_slv_extract;

  function f_slv_extract(use_a, use_b, use_c : boolean; a_w, b_w, C_W : natural; vec : std_logic_vector; sel : natural) return std_logic_vector is
  begin
    return f_slv_extract(use_a, use_b, use_c, false, false, false, false, a_w, b_w, C_W, 0, 0, 0, 0, vec, sel);
  end f_slv_extract;

  function f_slv_extract(use_a, use_b : boolean; a_w, b_w : natural; vec : std_logic_vector; sel : natural) return std_logic_vector is
  begin
    return f_slv_extract(use_a, use_b, false, false, false, false, false, a_w, b_w, 0, 0, 0, 0, 0, vec, sel);
  end f_slv_extract;

  function f_concat_repeat(n : natural; din : std_logic_vector) return std_logic_vector is
    variable v_ret : std_logic_vector(n*din'length-1 downto 0);
  begin
    for i in 0 to n-1 loop
      v_ret((i+1)*din'length-1 downto i*din'length) := din;
    end loop;
    return v_ret;
  end f_concat_repeat;

  function f_lm_resize(u : unsigned; w : natural) return unsigned is
  begin
    -- left extend with '0' or keep ls part (same as resize for unsigned)
    return resize(u, w);
  end;

  function f_lm_resize(s : signed; w : natural) return signed is
  begin
    -- extend sign bit or keep ls part
    if w > s'length then
      return resize(s, w);                    -- extend sign bit
    else
      return signed(resize(unsigned(s), w));  -- keep lsbits (= vec[w-1:0])
    end if;
  end;

  function f_resize_uvec(sl : std_logic; w : natural) return std_logic_vector is
    variable v_slv0 : std_logic_vector(w - 2 downto 0) := (others => '0');
  begin
    return v_slv0 & sl;
  end;

  function f_resize_uvec(vec : std_logic_vector; w : natural) return std_logic_vector is
  begin
    return std_logic_vector(f_lm_resize(unsigned(vec), w));
  end;

  function f_resize_svec(vec : std_logic_vector; w : natural) return std_logic_vector is
  begin
    return std_logic_vector(f_lm_resize(signed(vec), w));
  end;

  -- ------------------------------------------------------------------------
  function f_div_ceil(a : integer; b : integer)
    return integer is
    variable v_div_res : integer;
    variable v_div_mod : integer;
    variable v_res     : integer;
  begin
    assert b /= 0
      report "b must be not zero "
      severity error;
    v_div_res := a/b;
    v_div_mod := a mod b;
    if (v_div_mod = 0) then
      v_res := v_div_res;
    else
      v_res := v_div_res + 1;
    end if;
    return v_res;
  end;

  function f_div_ceil(a : time; b : time)
    return integer is
    variable v_div_res : integer;
    variable v_res     : integer;
  begin
    v_div_res := a/b;
    if (v_div_res * b = a) then
      v_res := v_div_res;
    else
      v_res := v_div_res + 1;
    end if;
    return v_res;
  end;


  -- ------------------------------------------------------------------------
  function f_div_ceil_2pwr(a : integer; b : integer)
    return integer is
    variable v_div : integer;
    variable v_res : integer;
  begin
    v_div := f_div_ceil(a, b);
    if v_div <= 1 then
      v_res := 1;
    elsif (2**f_floor_log2(v_div) = v_div) then
      v_res := v_div;
    else
      v_res := 2**(f_floor_log2(v_div) + 1);
    end if;
    return v_res;
  end;
  -- ------------------------------------------------------------------------
  function f_div_round(a : integer; b : integer)
    return integer is
    variable v_floor : integer;
    variable v_ceil  : integer;
    variable v_mid   : integer;
    variable v_tmp   : integer;
    variable v_res   : integer;
  begin
    v_tmp   := a / b;
    v_floor := 10 * v_tmp;
    v_ceil  := 10 * ((a/b) + 1);
    v_mid   := (10 * a) / b;
    if ((v_mid - v_floor) < (v_ceil - v_mid)) then
      v_res := a / b;
    else
      v_res := (a / b) + 1;
    end if;
    return v_res;
  end;

  -- ------------------------------------------------------------------------
  function f_shift_uvec(vec : std_logic_vector; shift : integer) return std_logic_vector is
  begin
    if shift < 0 then
      return std_logic_vector(shift_left(unsigned(vec), -shift));  -- fill zeros from right
    else
      return std_logic_vector(shift_right(unsigned(vec), shift));  -- fill zeros from left
    end if;
  end;

  function f_shift_svec(vec : std_logic_vector; shift : integer) return std_logic_vector is
  begin
    if shift < 0 then
      return std_logic_vector(shift_left(signed(vec), -shift));  -- same as shift_left for unsigned
    else
      return std_logic_vector(shift_right(signed(vec), shift));  -- extend sign
    end if;
  end;

  function f_rol(arg : std_logic_vector; count : natural) return std_logic_vector is
    constant C_ARG_L  : integer                            := arg'length-1;
    alias xarg        : std_logic_vector(C_ARG_L downto 0) is arg;
    variable v_result : std_logic_vector(C_ARG_L downto 0) := xarg;
    variable v_countm : integer;
  begin
    v_countm := count mod (C_ARG_L + 1);
    if v_countm /= 0 then
      v_result(C_ARG_L downto v_countm) := xarg(C_ARG_L-v_countm downto 0);
      v_result(v_countm-1 downto 0)     := xarg(C_ARG_L downto C_ARG_L-v_countm+1);
    end if;
    return v_result;
  end;

  function f_ror(arg : std_logic_vector; count : natural) return std_logic_vector is
    constant C_ARG_L  : integer                            := arg'length-1;
    alias xarg        : std_logic_vector(C_ARG_L downto 0) is arg;
    variable v_result : std_logic_vector(C_ARG_L downto 0) := xarg;
    variable v_countm : integer;
  begin
    v_countm := count mod (C_ARG_L + 1);
    if v_countm /= 0 then
      v_result(C_ARG_L-v_countm downto 0)         := xarg(C_ARG_L downto v_countm);
      v_result(C_ARG_L downto C_ARG_L-v_countm+1) := xarg(v_countm-1 downto 0);
    end if;
    return v_result;
  end;


  function f_flip(a : std_logic_vector) return std_logic_vector is
    variable v_a : std_logic_vector(a'length - 1 downto 0) := a;
    variable v_b : std_logic_vector(a'length - 1 downto 0);
  begin
    for i in v_a'range loop
      v_b(a'length - 1 - i) := v_a(i);
    end loop;
    return v_b;
  end;

  function f_transpose(a : std_logic_vector; row, col : natural) return std_logic_vector is
    variable v_in  : std_logic_vector(a'length - 1 downto 0);
    variable v_out : std_logic_vector(a'length - 1 downto 0);
  begin
    v_in  := a;                         -- map input vector to h:0 range
    v_out := v_in;  -- default leave any unused msbits the same
    for j in 0 to row - 1 loop
      for i in 0 to col - 1 loop
        v_out(j * col + i) := v_in(i * row + j);  -- f_transpose vector, map input index [i*row+j] to output index [j*col+i]
      end loop;
    end loop;
    return v_out;
  end function;


  --convert digit to char to write into file (.txt)
  function f_digit_to_char(slv : std_logic_vector(3 downto 0)) return character is
    variable v_char : character;
  begin
    case slv is
      when "0000" => v_char := '0';
      when "0001" => v_char := '1';
      when "0010" => v_char := '2';
      when "0011" => v_char := '3';
      when "0100" => v_char := '4';
      when "0101" => v_char := '5';
      when "0110" => v_char := '6';
      when "0111" => v_char := '7';
      when "1000" => v_char := '8';
      when "1001" => v_char := '9';
      when "1010" => v_char := 'a';
      when "1011" => v_char := 'b';
      when "1100" => v_char := 'c';
      when "1101" => v_char := 'd';
      when "1110" => v_char := 'e';
      when "1111" => v_char := 'f';
      when others => v_char := 'x';
    end case;

    return v_char;
  end function f_digit_to_char;

  function f_zero_pad(
    vec      : std_logic_vector;
    size     : positive;
    to_left  : boolean   := true;
    init_val : std_logic := '0') return std_logic_vector is
    variable v_zero_pad : std_logic_vector(size - vec'length - 1 downto 0) := (others => init_val);
  begin
    if to_left = true then
      return v_zero_pad & vec;
    else
      return vec & v_zero_pad;
    end if;
  end function;

  function f_arr2mat(
    arr       : std_logic_vector;
    data_size : natural;
    row_dim   : natural;
    col_dim   : natural;
    i         : natural;
    j         : natural
    ) return std_logic_vector is
    variable v_result : std_logic_vector(data_size - 1 downto 0);
  begin
    -- check input parameters **--
    assert arr'length = data_size * col_dim * row_dim report "f_arr2mat: invalid input dimensions"
      severity error;
    assert i <= row_dim report "f_arr2mat: accessing a row index greater than row dimension"
                severity error;
    assert j <= col_dim report "f_arr2mat: accessing a column index greater than column dimension"
                severity error;

    v_result := arr(i * col_dim * data_size + (j + 1) * data_size - 1 downto i * col_dim * data_size + j * data_size);
    return v_result;
  end function;

  function f_arr2mat(
    arr       : std_logic_vector;
    data_size : natural;
    row_dim   : natural;
    i         : natural
    ) return std_logic_vector is
    variable v_result : std_logic_vector(data_size - 1 downto 0);
  begin
    -- check input parameters **--
    assert arr'length = data_size * row_dim report " invalid input dimensions"
      severity error;

    v_result := arr((i + 1) * data_size - 1 downto i * data_size);
    return v_result;
  end function;

  --signed overloading
  function f_arr2mat(
    arr       : signed;
    data_size : natural;
    row_dim   : natural;
    i         : natural
    ) return signed is
    variable v_result : signed(data_size - 1 downto 0);
  begin
    -- check input parameters **--
    assert arr'length = data_size * row_dim report " invalid input dimensions"
      severity error;

    v_result := arr((i + 1) * data_size - 1 downto i * data_size);
    return v_result;
  end function;

  function f_count_ones(in_slv : std_logic_vector) return integer is
    variable v_cnt : natural := 0;
  begin
    for i in in_slv'range loop
      if in_slv(i) = '1' then
        v_cnt := v_cnt + 1;
      end if;
    end loop;
    return v_cnt;
  end function f_count_ones;

  function f_is_power_of_two(input : integer) return boolean is
    variable v_val : integer := input;
  begin
    if (input <= 0) then
      return false;
    end if;
    while v_val mod 2 = 0 loop
      v_val := v_val / 2;
    end loop;
    return v_val = 1;
  end function f_is_power_of_two;


  -------------------------------------------------------------------------------
  -- Comments: f_max and f_min retiurn the maximum and minimum value among two
  --           integers. The function have been overloaded for naturals
  -------------------------------------------------------------------------------
  function f_max(l, r : integer) return integer is
  begin
    if l > r then
      return l;
    else
      return r;
    end if;
  end;

  function f_min(l, r : integer) return integer is
  begin
    if l < r then
      return l;
    else
      return r;
    end if;
  end;

  function f_get_bitsum_stages (g_din_w : integer; g_adder_w : integer) return integer is
    variable v_c_cnt1_1_stage : integer;
    variable v_c_cnt1_stages  : integer;
  begin
    v_c_cnt1_1_stage := f_max(1, f_div_ceil_2pwr(g_din_w, g_adder_w));
    v_c_cnt1_stages  := f_max(1, f_ceil_log2(v_c_cnt1_1_stage+1));
    return v_c_cnt1_stages;
  end f_get_bitsum_stages;

  function f_pullup(input : std_logic) return std_logic is
    variable v_ret : std_logic;
  begin
    case (input) is
      when '1'|'Z' =>
        v_ret := '1';
      when '0' =>
        v_ret := '0';
      when others =>
        v_ret := 'Z';
    end case;
    return v_ret;
  end f_pullup;

  function f_pulldown(input : std_logic) return std_logic is
    variable v_ret : std_logic;
  begin
    case (input) is
      when '0'|'Z' =>
        v_ret := '0';
      when '1' =>
        v_ret := '1';
      when others =>
        v_ret := 'Z';
    end case;
    return v_ret;
  end f_pulldown;

  ------------------------------------------------------------------------------
  -- PROCEDURES
  ------------------------------------------------------------------------------
  --  ************************************************************
  --     Proc : p_console_log
  --     Inputs : Text String
  --     Outputs : None
  --     Description : Displays current simulation time and text string to
  --          standard output.
  --   *************************************************************

  procedure p_console_log(
    text_string : in string) is
    variable v_line : line;

  begin
    write(v_line, string'("[ "));
    write(v_line, now);
    write(v_line, string'(" ] : "));
    write(v_line, text_string);
    writeline(output, v_line);

  end p_console_log;

  function f_string2slv(str : string) return std_logic_vector is
    alias str_norm : string(str'length downto 1) is str;
    variable v_res : std_logic_vector(8 * str'length - 1 downto 0);
  begin
    for idx in str_norm'range loop
      v_res(8 * idx - 1 downto 8 * idx - 8) :=
        std_logic_vector(to_unsigned(character'pos(str_norm(idx)), 8));
    end loop;
    return v_res;
  end function;

  function f_string2slv_lsb(str : string) return std_logic_vector is
    variable v_res : std_logic_vector(8 * str'length - 1 downto 0);
    variable v_char : std_logic_vector(7 downto 0);
  begin
    for idx in str'range loop
      v_char := std_logic_vector(to_unsigned(character'pos(str(idx)), 8));
      for b in 0 to 7 loop
        v_res(8 * (str'length - idx + 1) - b - 1) := v_char(b);
      end loop;
    end loop;
    return v_res;
  end function;

  function f_slv2char (slv8 : std_logic_vector (7 downto 0)) return character is
    constant C_MAP  : integer := 0;
    variable v_temp : integer := 0;
  begin
    for i in slv8'range loop
      v_temp := v_temp*2;
      case slv8(i) is
        when '0' | 'L' => null;
        when '1' | 'H' => v_temp := v_temp+1;
        when others    => v_temp := v_temp+C_MAP;
      end case;
    end loop;
    return character'val(v_temp);
  end f_slv2char;

  function f_slv2ascii_hex (slv4 : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable v_ret : std_logic_vector(7 downto 0);

  begin
    if (slv4(3 downto 0) = x"0") then
      v_ret := C_ASCII_0;
    elsif (slv4(3 downto 0) = x"1") then
      v_ret := C_ASCII_1;
    elsif (slv4(3 downto 0) = x"2") then
      v_ret := C_ASCII_2;
    elsif (slv4(3 downto 0) = x"3") then
      v_ret := C_ASCII_3;
    elsif (slv4(3 downto 0) = x"4") then
      v_ret := C_ASCII_4;
    elsif (slv4(3 downto 0) = x"5") then
      v_ret := C_ASCII_5;
    elsif (slv4(3 downto 0) = x"6") then
      v_ret := C_ASCII_6;
    elsif (slv4(3 downto 0) = x"7") then
      v_ret := C_ASCII_7;
    elsif (slv4(3 downto 0) = x"8") then
      v_ret := C_ASCII_8;
    elsif (slv4(3 downto 0) = x"9") then
      v_ret := C_ASCII_9;
    elsif (slv4(3 downto 0) = x"A") then
      v_ret := C_ASCII_A_UC;
    elsif (slv4(3 downto 0) = x"B") then
      v_ret := C_ASCII_B_UC;
    elsif (slv4(3 downto 0) = x"C") then
      v_ret := C_ASCII_C_UC;
    elsif (slv4(3 downto 0) = x"D") then
      v_ret := C_ASCII_D_UC;
    elsif (slv4(3 downto 0) = x"E") then
      v_ret := C_ASCII_E_UC;
    elsif (slv4(3 downto 0) = x"F") then
      v_ret := C_ASCII_F_UC;
    end if;

    return v_ret;
  end f_slv2ascii_hex;


  function f_slv2hex (slv : std_logic_vector) return string is
    variable v_tmp           : string(1 to slv'length + 2);
    variable v_subdigit      : std_logic_vector(3 downto 0);
    variable v_digits, v_pos : integer;
    variable v_actual_length : integer;
    variable v_ext_val       : std_logic_vector(slv'length + 3 downto 0);
  begin
    v_tmp(1 to 2)                               := "0x";
    v_ext_val(slv'length - 1 downto 0)          := slv;
    v_ext_val(slv'length + 3 downto slv'length) := (others => '0');
    -- pad with zero's if length is not a factor of 4
    if slv'length mod 4 /= 0 then
      v_actual_length := slv'length + 4 - (slv'length mod 4);
    else
      v_actual_length := slv'length;
    end if;
    v_digits := v_actual_length / 4;
    -- convert 4 and 4 bits into hex digits
    for i in v_digits downto 1 loop
      v_subdigit(3 downto 0) := v_ext_val(i * 4 - 1 downto i * 4 - 4);
      v_pos                  := 3 + v_digits - i;
      case v_subdigit is
        when "0000" => v_tmp(v_pos) := '0';
        when "0001" => v_tmp(v_pos) := '1';
        when "0010" => v_tmp(v_pos) := '2';
        when "0011" => v_tmp(v_pos) := '3';
        when "0100" => v_tmp(v_pos) := '4';
        when "0101" => v_tmp(v_pos) := '5';
        when "0110" => v_tmp(v_pos) := '6';
        when "0111" => v_tmp(v_pos) := '7';
        when "1000" => v_tmp(v_pos) := '8';
        when "1001" => v_tmp(v_pos) := '9';
        when "1010" => v_tmp(v_pos) := 'a';
        when "1011" => v_tmp(v_pos) := 'b';
        when "1100" => v_tmp(v_pos) := 'c';
        when "1101" => v_tmp(v_pos) := 'd';
        when "1110" => v_tmp(v_pos) := 'e';
        when "1111" => v_tmp(v_pos) := 'f';
        when others => v_tmp(v_pos) := '?';
      end case;
    end loop;
    return(v_tmp(1 to 2 + v_digits));
  end f_slv2hex;


function f_slv2string (slv : std_logic_vector) return string is
    variable v_tmp           : string(1 to slv'length);
  begin
    for i in slv'range loop
      if slv(i) = '0' then
        v_tmp(slv'left-i+1) := '0';
      elsif slv(i) = '1' then
        v_tmp(slv'left-i+1) := '1';
      else -- all other std_logic_vector values are printed as -
        v_tmp(slv'left-i+1) := '-';
      end if;
    end loop;
    return v_tmp;
  end f_slv2string;




  function f_char_is_digit(chr : character) return boolean is
  begin
    return (character'pos('0') <= character'pos(chr)) and (character'pos(chr) <= character'pos('9'));
  end function;

  function f_char_is_lower_hex_digit(chr : character) return boolean is
  begin
    return (character'pos('a') <= character'pos(chr)) and (character'pos(chr) <= character'pos('f'));
  end function;

  function f_char_is_upper_hex_digit(chr : character) return boolean is
  begin
    return (character'pos('A') <= character'pos(chr)) and (character'pos(chr) <= character'pos('F'));
  end function;

  function f_char_is_hex_digit(chr : character) return boolean is
  begin
    return f_char_is_digit(chr) or f_char_is_lower_hex_digit(chr) or f_char_is_upper_hex_digit(chr);
  end function;

  function f_char_is_lower(chr : character) return boolean is
  begin
    return f_char_is_lower_alpha(chr);
  end function;

  function f_char_is_lower_alpha(chr : character) return boolean is
  begin
    return (character'pos('a') <= character'pos(chr)) and (character'pos(chr) <= character'pos('z'));
  end function;

  function f_char_is_upper(chr : character) return boolean is
  begin
    return f_char_is_upper_alpha(chr);
  end function;

  function f_char_is_upper_alpha(chr : character) return boolean is
  begin
    return (character'pos('A') <= character'pos(chr)) and (character'pos(chr) <= character'pos('Z'));
  end function;

  function f_char_is_alpha(chr : character) return boolean is
  begin
    return f_char_is_lower_alpha(chr) or f_char_is_upper_alpha(chr);
  end function;

  function f_char_to_lower(chr : character) return character is
  begin
    if f_char_is_upper_alpha(chr) then
      return character'val(character'pos(chr) - character'pos('A') + character'pos('a'));
    else
      return chr;
    end if;
  end function;

  function f_char_to_upper(chr : character) return character is
  begin
    if f_char_is_lower_alpha(chr) then
      return character'val(character'pos(chr) - character'pos('a') + character'pos('A'));
    else
      return chr;
    end if;
  end function;

  function f_bin2digit(chr : character) return integer is
  begin
    case chr is
      when '0'    => return 0;
      when '1'    => return 1;
      when others => return -1;
    end case;
  end function;

  function f_oct2digit(chr : character) return integer is
    variable v_dec : integer;
  begin
    v_dec := f_dec2digit(chr);
    return f_sel_a_b((v_dec < 8), v_dec, -1);
  end function;

  function f_dec2digit(chr : character) return integer is
  begin
    if f_char_is_digit(chr) then
      return character'pos(chr) - character'pos('0');
    else
      return -1;
    end if;
  end function;

  function f_hex2digit(chr : character) return integer is
  begin
    if f_char_is_digit(chr) then return character'pos(chr) - character'pos('0');
    elsif f_char_is_lower_hex_digit(chr) then return character'pos(chr) - character'pos('a') + 10;
    elsif f_char_is_upper_hex_digit(chr) then return character'pos(chr) - character'pos('A') + 10;
    else return -1;
    end if;
  end function;

  function f_to_digit(chr : character; base : character := 'd') return integer is
  begin
    case base is
      when 'b'    => return f_bin2digit(chr);
      when 'o'    => return f_oct2digit(chr);
      when 'd'    => return f_dec2digit(chr);
      when 'h'    => return f_hex2digit(chr);
      when others => report "Unknown base character: " & base & "." severity failure;
                     return 0;
    -- return statement is explicitly missing otherwise XST won't stop
    end case;
  end function;

  function f_string_format(value : real; precision : natural := 3) return string is
    constant C_S        : real    := sign(value);
    constant C_VAL      : real    := value * C_S;
    -- round once on the scaled value so a fraction that rounds up to 10**precision
    -- carries into the integer part instead of widening the fraction field
    constant C_SCALE    : integer := integer(10.0**precision);
    constant C_SCALED   : integer := integer(round(C_VAL * real(C_SCALE)));
    constant C_INT      : integer := C_SCALED / C_SCALE;
    constant C_FRAC     : integer := C_SCALED mod C_SCALE;
    constant C_FRAC_STR : string  := integer'image(C_FRAC);
    constant C_RES      : string  := integer'image(C_INT) & "." & (2 to (precision - C_FRAC_STR'length + 1) => '0') & C_FRAC_STR;
  begin
    return f_sel_a_b ((C_S < 0.0), "-" & C_RES, C_RES);
  end function;

  function f_string_length(str : string) return natural is
  begin
    for i in str'range loop
      if (str(i) = NUL) then
        return i - str'low;
      end if;
    end loop;
    return str'length;
  end function;

  function f_string_equal(str1 : string; str2 : string) return boolean is
  begin
    if str1'length /= str2'length then
      return false;
    else
      return (str1 = str2);
    end if;
  end function;

  function f_string_match(str1 : string; str2 : string) return boolean is
    constant C_LEN : natural := f_min(str1'length, str2'length);
  begin
    -- if both strings are empty
    if ((str1'length = 0) and (str2'length = 0)) then return true; end if;
    -- compare char by char
    for i in str1'low to str1'low + C_LEN - 1 loop
      if (str1(i) /= str2(str2'low + (i - str1'low))) then
        return false;
      elsif ((str1(i) = NUL) xor (str2(str2'low + (i - str1'low)) = NUL)) then
        return false;
      elsif ((str1(i) = NUL) and (str2(str2'low + (i - str1'low)) = NUL)) then
        return true;
      end if;
    end loop;
    -- check special cases,
    return (((str1'length = C_LEN) and (str2'length = C_LEN)) or  -- both strings are fully consumed and equal
            ((str1'length > C_LEN) and (str1(str1'low + C_LEN) = NUL)) or  -- str1 is longer, but str_length equals len
            ((str2'length > C_LEN) and (str2(str2'low + C_LEN) = NUL)));  -- str2 is longer, but str_length equals len
  end function;

  function f_string_imatch(str1 : string; str2 : string) return boolean is
  begin
    return f_string_match(f_string_toLower(str1), f_string_toLower(str2));
  end function;

  function f_string_pos(str : string; chr : character; start : natural := 0) return integer is
  begin
    for i in f_max(str'low, start) to str'high loop
      exit when (str(i) = NUL);
      if (str(i) = chr) then
        return i;
      end if;
    end loop;
    return -1;
  end function;

  function f_string_pos(str : string; pattern : string; start : natural := 0) return integer is
  begin
    for i in f_max(str'low, start) to (str'high - pattern'length + 1) loop
      exit when (str(i) = NUL);
      if (str(i to i + pattern'length - 1) = pattern) then
        return i;
      end if;
    end loop;
    return -1;
  end function;

  function f_string_ipos(str : string; chr : character; start : natural := 0) return integer is
  begin
    return f_string_pos(f_string_toLower(str), f_char_to_lower(chr), start);
  end function;

  function f_string_ipos(str : string; pattern : string; start : natural := 0) return integer is
  begin
    return f_string_pos(f_string_toLower(str), f_string_toLower(pattern), start);
  end function;

  --      function str_pos(str1 : STRING; str2 : STRING) return INTEGER is
  --              variable PrefixTable    : T_INTVEC(0 to str2'length);
  --              variable j                                              : INTEGER;
  --      begin
  --              -- construct prefix table for KMP algorithm
  --              j                                                               := -1;
  --              PrefixTable(0)  := -1;
  --              for i in str2'range loop
  --                      while ((j >= 0) and str2(j + 1) /= str2(i)) loop
  --                              j               := PrefixTable(j);
  --                      end loop;
  --
  --                      j                                                                               := j + 1;
  --                      PrefixTable(i - 1)      := j + 1;
  --              end loop;
  --
  --              -- search pattern str2 in text str1
  --              j := 0;
  --              for i in str1'range loop
  --                      while ((j >= 0) and str1(i) /= str2(j + 1)) loop
  --                              j               := PrefixTable(j);
  --                      end loop;
  --
  --                      j := j + 1;
  --                      if ((j + 1) = str2'high) then
  --                              return i - str2'length + 1;
  --                      end if;
  --              end loop;
  --
  --              return -1;
  --      end function;

  function f_string_find(str : string; chr : character) return boolean is
  begin
    return (f_string_pos(str, chr) > 0);
  end function;

  function f_string_find(str : string; pattern : string) return boolean is
  begin
    return (f_string_pos(str, pattern) > 0);
  end function;

  function f_string_ifind(str : string; chr : character) return boolean is
  begin
    return (f_string_ipos(str, chr) > 0);
  end function;

  function f_string_ifind(str : string; pattern : string) return boolean is
  begin
    return (f_string_ipos(str, pattern) > 0);
  end function;

  function f_string_replace(str : string; pattern : string; replace : string) return string is
    variable v_pos : integer;
  begin
    v_pos := f_string_pos(str, pattern);
    if (v_pos > 0) then
      if (v_pos = 1) then
        return replace & str(pattern'length + 1 to str'length);
      elsif (v_pos = str'length - pattern'length + 1) then
        return str(1 to str'length - pattern'length) & replace;
      else
        return str(1 to v_pos - 1) & replace & str(v_pos + pattern'length to str'length);
      end if;
    else
      return str;
    end if;
  end function;

  -- examples:
  --                                                      123456789ABC
  -- input string: "Hello World."
  --    low=1; high=12; length=12
  --
  --    str_substr("Hello World.",      0,      0)      => "Hello World."               - copy all
  --    str_substr("Hello World.",      7,      0)      => "World."                                     - copy from pos 7 to end of string
  --    str_substr("Hello World.",      7,      5)      => "World"                                      - copy from pos 7 for 5 characters
  --    str_substr("Hello World.",      0, -7)  => "Hello World."               - copy all until character 8 from right boundary
  function f_string_substr(str : string; start : integer := 0; length : integer := 0) return string is
    variable v_StartOfString : positive;
    variable v_EndOfString   : positive;
  begin
    if (start < 0) then  -- start is negative -> start substring at right string boundary
      v_StartOfString := str'high + start + 1;
    elsif (start = 0) then  -- start is zero -> start substring at left string boundary
      v_StartOfString := str'low;
    else  -- start is positive -> start substring at left string boundary + offset
      v_StartOfString := start;
    end if;

    if (length < 0) then  -- length is negative -> end substring at length'th character before right string boundary
      v_EndOfString := str'high + length;
    elsif (length = 0) then  -- length is zero -> end substring at right string boundary
      v_EndOfString := str'high;
    else  -- length is positive -> end substring at v_StartOfString + length
      v_EndOfString := v_StartOfString + length - 1;
    end if;

    if (v_StartOfString < str'low) then report "v_StartOfString is out of str's range. (str=" & str & ")" severity error; end if;
    if (v_EndOfString > str'high) then report "v_EndOfString is out of str's range. (str=" & str & ")" severity error; end if;

    return str(v_StartOfString to v_EndOfString);
  end function;

  function f_string_ltrim(str : string; char : character := ' ') return string is
  begin
    for i in str'range loop
      if (str(i) /= char) then
        return str(i to str'high);
      end if;
    end loop;
    return "";
  end function;

  function f_string_rtrim(str : string; char : character := ' ') return string is
  begin
    for i in str'reverse_range loop
      if (str(i) /= char) then
        return str(str'low to i);
      end if;
    end loop;
    return "";
  end function;

  function f_string_trim(str : string) return string is
  begin
    return str(str'low to str'low + f_string_length(str) - 1);
  end function;

  function f_string_toLower(str : string) return string is
    variable v_temp : string(str'range);
  begin
    for i in str'range loop
      v_temp(i) := f_char_to_lower(str(i));
    end loop;
    return v_temp;
  end function;

  function f_string_toUpper(str : string) return string is
    variable v_temp : string(str'range);
  begin
    for i in str'range loop
      v_temp(i) := f_char_to_upper(str(i));
    end loop;
    return v_temp;
  end function;


end lm_util_pkg;

