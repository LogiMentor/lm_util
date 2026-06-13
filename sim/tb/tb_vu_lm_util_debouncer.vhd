-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_debouncer
-- Library     : lm_util_lib
-- Project     : UTILITY
-- Company     : Logimentor Srl
-- Author      : A.C.
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_debouncer
--
--              This testbench verifies the debouncing behavior
--              of the input signal by simulating a bouncing input and
--              checking the output response.
--              Test checks include:
--              - Output remains stable during input bounce
--              - Output updates correctly after stable input
--              - Module debounces input signal based on specified debounce length and level
--
--=============================================================================


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library lm_util_lib;
use lm_util_lib.lm_util_pkg.all;
use lm_util_lib.tb_vu_lm_pkg.all;

entity tb_vu_lm_util_debouncer is
  generic (
    g_debounce_length : natural := 10;
    g_debounce_lvl    : integer := 2;
    runner_cfg        : string
  );
end;

architecture tb of tb_vu_lm_util_debouncer is

  constant C_CLK_PERIOD : time := 10 ns;
  constant C_T0         : time := C_CLK_PERIOD * 2;
  constant C_T1_0       : time := C_CLK_PERIOD * 5; -- 0  
  constant C_T2_1       : time := C_CLK_PERIOD * 7; -- 1
  constant C_T3_0       : time := C_CLK_PERIOD * 100; -- 0
  constant C_T4_1       : time := C_CLK_PERIOD * 200; -- 1
  constant C_T5_0       : time := C_CLK_PERIOD * 201; -- 0
  constant C_T6_1       : time := C_CLK_PERIOD * 300; -- 1
  -- bouncing pattern
  --------+   +-------...---+              +-+                   +--------------------
  --      +---+             +-----...------+ +-------------...---+
  --T0    T1  T2            T3            T4 T5                  T6

  --Stimuli
  signal clk_i   : std_logic := '0';
  signal rst_n_i : std_logic := '0';
  signal ce_i    : std_logic := '1';
  signal din_i   : std_logic := '0';
  --Observed signal
  signal dout_o : std_logic;
begin

  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  -- Unit under test
  uut : entity lm_util_lib.lm_util_debouncer
    generic map(
      g_debounce_length => g_debounce_length,
      g_debounce_lvl    => g_debounce_lvl
    )
    port map
    (
      clk_i   => clk_i,
      ce_i    => ce_i,
      rst_n_i => rst_n_i,
      din_i   => din_i,
      dout_o  => dout_o
    );

  test_runner : process
  begin
    test_runner_setup(runner, runner_cfg);

    if run("length") then
      -- Tests reaction for unstable input, stable input taking into account debounce length

      rst_n_i <= '0';
      din_i   <= '0';
      p_wait_clk(clk_i, 2);
      rst_n_i <= '1';

      -- simulate bouncing input (oscillates but not stable for g_debounce_length cycles)
      for i in 0 to g_debounce_length - 2 loop
        din_i <= not din_i;
        p_wait_clk(clk_i, 1);
      end loop;
      check_equal(dout_o, '0', "Output should remain '0' during bounce");

      -- stable high input for g_debounce_length cycles
      din_i <= '1';
      p_wait_clk(clk_i, g_debounce_length + 2);
      wait for 1 ps;
      check_equal(dout_o, '1', "Output should update after stable high");

      -- simulate bounce down
      for i in 0 to g_debounce_length - 2 loop
        din_i <= not din_i;
        p_wait_clk(clk_i, 1);
      end loop;
      check_equal(dout_o, '1', "Output should still be '1' during bounce");

      -- stable low
      din_i <= '0';
      p_wait_clk(clk_i, g_debounce_length + 2);
      wait for 1 ps;
      check_equal(dout_o, '0', "Output should update after stable low");

    elsif run("length_level") then
      -- Tests reaction for unstable input, stable input taking into account debounce length and debounce level

      -- simulate bouncing input (oscillates but not stable for g_debounce_length cycles)
      din_i <= '1', '0' after C_T1_0, '1' after C_T2_1, '0' after C_T3_0, '1' after C_T4_1, '0' after C_T5_0, '1' after C_T6_1;

      rst_n_i <= '0';
      wait for C_T0;
      rst_n_i <= '1';

      wait for 1 ps;
      check_equal(dout_o, '1', "Output should become '1' after the reset");

      if (g_debounce_lvl = 0) or (g_debounce_lvl = 2) then
        p_check_held_for(dout_o, '1', C_T3_0 + C_CLK_PERIOD * g_debounce_length - now, "Output should remain '1' during bounce");
        p_wait_clk(clk_i, 3);
        wait for 1 ps;
        check_equal(dout_o, '0', "Output should become '0' after g_debounce_length+2 cycles");
      elsif g_debounce_lvl = 1 then
        wait for C_T1_0 - now;
        p_wait_clk(clk_i, 3);
        wait for 1 ps;
        check_equal(dout_o, '0', "Output should become '0' after two cycles if g_debounce_lvl=1");
        p_check_held_for(dout_o, '0', C_T2_1 + C_CLK_PERIOD * g_debounce_length - now, "Output should remain '0' during stable");
        p_wait_signal(dout_o, '1', C_CLK_PERIOD * 2, "Output shoud go '1'");
        p_check_held_for(dout_o, '1', C_T3_0 + C_CLK_PERIOD * 2 - now, "Output should remain '1' afterwards");
        p_wait_signal(dout_o, '0', C_CLK_PERIOD, "Output shoud go '0'");
      end if;
      p_check_held_for(dout_o, '0', C_T4_1 - now, "Output should remain '0' during stable");

      if (g_debounce_lvl = 1) or (g_debounce_lvl = 2) then
        p_check_held_for(dout_o, '0', C_T6_1 + C_CLK_PERIOD * g_debounce_length - now, "Output should remain '0' during bounce");
        p_wait_clk(clk_i, 3);
        wait for 1 ps;
        check_equal(dout_o, '1', "Output should become '1' after g_debounce_length+2 cycles");
      elsif g_debounce_lvl = 0 then
        p_wait_clk(clk_i, 3);
        wait for 1 ps;
        check_equal(dout_o, '1', "Output should become '1' after two cycles if g_debounce_lvl=0");
        p_check_held_for(dout_o, '1', C_CLK_PERIOD * g_debounce_length - 1 ps, "Output should remain '1' during stable");
        p_wait_signal(dout_o, '0', C_CLK_PERIOD * 2 - 1 ps, "Output shoud go '0'");
        p_check_held_for(dout_o, '0', C_T6_1 + C_CLK_PERIOD * 2 - now, "Output should remain '0' afterwards");
        p_wait_signal(dout_o, '1', C_CLK_PERIOD, "Output shoud go '1'");
      end if;

    end if;

    test_runner_cleanup(runner);
  end process;

end architecture;
