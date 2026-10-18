-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : lm_elab_string_format
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-------------------------------------------------------------------------------
-- Description: Elaboration check of the f_string_format range guards (test
--              only, used by sim/scripts/check_elab_failures.py).
--              The constant is evaluated at elaboration: an input that cannot
--              be formatted must stop elaboration, never give a wrong string.
--              g_case 0 is the positive control.
--=============================================================================

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;

entity lm_elab_string_format is
  generic (
    g_case : natural := 0
  );
end lm_elab_string_format;

architecture a_tb of lm_elab_string_format is
  type t_real_arr is array (natural range <>) of real;
  -- 0: largest integer part; 1: integer part above integer'high; 2: carry
  -- above integer'high; 3: integer'low; 4: 10**precision above integer'high
  constant C_VALUES     : t_real_arr    := (2147483647.4, 2147483648.0, 2147483647.9996, -2147483648.0, 1.0);
  constant C_PRECISIONS : t_natural_arr := (3, 3, 3, 3, 10);
  constant C_TEXT       : string        := f_string_format(C_VALUES(g_case), C_PRECISIONS(g_case));
begin
  assert false report "f_string_format result: " & C_TEXT severity note;
end a_tb;
