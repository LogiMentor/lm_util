-- SPDX-License-Identifier: Apache-2.0
--=============================================================================
-- Module Name : tb_vu_lm_util_lfsr
-- Library     : lm_util_lib
-- Project     : lm_util
-- Company     : LogiMentor Srl
-------------------------------------------------------------------------------
-- Description: Testbench for lm_util_lfsr
--              Reference model (independent of the RTL, taps transcribed
--              from XAPP052 Table 3, except width 102: the table row
--              102, 101, 36, 35 is not a primitive polynomial and is
--              replaced by 102, 99, 97, 96 from Ward and Molteno, Otago
--              Electronics Technical Report 2012-1):
--              - effective seed: seed_i, or all ones if seed_i is zero;
--              - an edge with reset or load sets rng_o to the effective seed;
--              - any other edge sets rng_o to step(rng_o): shift towards the
--                MSB, XOR of the taps into bit 0. The first value after the
--                release of reset is step(effective seed).
--              Tests:
--              - model_sequence: rng_o equals the model in reset (seed_i
--                changing on every reset edge), for 200 steps after reset and
--                after load, for five seeds including zero;
--              - main_equivalence: rng_o equals the output of lm_ref_lfsr_v010,
--                the unit as released in v0.1.0, driven with the same inputs,
--                in every cycle outside reset, for nonzero seeds (the value
--                during reset, the zero seed and width 102 changed by design);
--              - period: from a nonzero seed, rng_o returns to it after
--                exactly 2^N - 1 steps (run for widths 3 to 16);
--              - w102_long_cycle: a 102-bit seed that repeated every 7 steps
--                with the XAPP052 taps does not repeat within C_W102_STEPS.
--              run.py runs this testbench with vhdl_assert_stop_level =
--              "warning": any VHDL warning (for example a NUMERIC_STD
--              truncation) fails the test.
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

entity tb_vu_lm_util_lfsr is
  generic (
    g_data_w   : integer := 8;  -- LFSR width
    -- Required for VUnit
    runner_cfg : string  := ""
  );
end tb_vu_lm_util_lfsr;

architecture a_tb of tb_vu_lm_util_lfsr is
  -- Constants
  constant C_STEPS : positive := 200;  -- free-running steps after reset and after load
  -- width 102: seed on a 7-step cycle of the XAPP052 taps, and steps checked
  constant C_W102_SEED  : std_logic_vector(103 downto 0) := x"25_CB97_2E5C_B972_E5CB_972E_5CB9";
  constant C_W102_STEPS : positive := 10_000;

  subtype t_word is std_logic_vector(g_data_w - 1 downto 0);
  type t_word_arr is array (natural range <>) of t_word;

  -- 168-bit patterns truncated to g_data_w bits; bit 0 is set, so they are
  -- nonzero at every width
  constant C_PAT_A : std_logic_vector(167 downto 0) := x"5A3C_9E17_D2B4_6F81_0C7A_E395_4B2D_F06E_8193_A5C7_1F";
  constant C_PAT_B : std_logic_vector(167 downto 0) := x"0123_4567_89AB_CDEF_FEDC_BA98_7654_3210_0F0F_F0F0_3D";

  function f_msb_only return t_word is
    variable v_word : t_word;
  begin
    v_word                := (others => '0');
    v_word(g_data_w - 1)  := '1';
    return v_word;
  end function f_msb_only;

  -- taps per width, 1-based as in XAPP052 Table 3 (0: unused)
  type t_taps is array (0 to 5) of natural;
  type t_tap_table is array (3 to 168) of t_taps;
  constant C_TAPS : t_tap_table := (
    3   => (  3,   2,   0,   0,   0,   0),
    4   => (  4,   3,   0,   0,   0,   0),
    5   => (  5,   3,   0,   0,   0,   0),
    6   => (  6,   5,   0,   0,   0,   0),
    7   => (  7,   6,   0,   0,   0,   0),
    8   => (  8,   6,   5,   4,   0,   0),
    9   => (  9,   5,   0,   0,   0,   0),
    10  => ( 10,   7,   0,   0,   0,   0),
    11  => ( 11,   9,   0,   0,   0,   0),
    12  => ( 12,   6,   4,   1,   0,   0),
    13  => ( 13,   4,   3,   1,   0,   0),
    14  => ( 14,   5,   3,   1,   0,   0),
    15  => ( 15,  14,   0,   0,   0,   0),
    16  => ( 16,  15,  13,   4,   0,   0),
    17  => ( 17,  14,   0,   0,   0,   0),
    18  => ( 18,  11,   0,   0,   0,   0),
    19  => ( 19,   6,   2,   1,   0,   0),
    20  => ( 20,  17,   0,   0,   0,   0),
    21  => ( 21,  19,   0,   0,   0,   0),
    22  => ( 22,  21,   0,   0,   0,   0),
    23  => ( 23,  18,   0,   0,   0,   0),
    24  => ( 24,  23,  22,  17,   0,   0),
    25  => ( 25,  22,   0,   0,   0,   0),
    26  => ( 26,   6,   2,   1,   0,   0),
    27  => ( 27,   5,   2,   1,   0,   0),
    28  => ( 28,  25,   0,   0,   0,   0),
    29  => ( 29,  27,   0,   0,   0,   0),
    30  => ( 30,   6,   4,   1,   0,   0),
    31  => ( 31,  28,   0,   0,   0,   0),
    32  => ( 32,  22,   2,   1,   0,   0),
    33  => ( 33,  20,   0,   0,   0,   0),
    34  => ( 34,  27,   2,   1,   0,   0),
    35  => ( 35,  33,   0,   0,   0,   0),
    36  => ( 36,  25,   0,   0,   0,   0),
    37  => ( 37,   5,   4,   3,   2,   1),
    38  => ( 38,   6,   5,   1,   0,   0),
    39  => ( 39,  35,   0,   0,   0,   0),
    40  => ( 40,  38,  21,  19,   0,   0),
    41  => ( 41,  38,   0,   0,   0,   0),
    42  => ( 42,  41,  20,  19,   0,   0),
    43  => ( 43,  42,  38,  37,   0,   0),
    44  => ( 44,  43,  18,  17,   0,   0),
    45  => ( 45,  44,  42,  41,   0,   0),
    46  => ( 46,  45,  26,  25,   0,   0),
    47  => ( 47,  42,   0,   0,   0,   0),
    48  => ( 48,  47,  21,  20,   0,   0),
    49  => ( 49,  40,   0,   0,   0,   0),
    50  => ( 50,  49,  24,  23,   0,   0),
    51  => ( 51,  50,  36,  35,   0,   0),
    52  => ( 52,  49,   0,   0,   0,   0),
    53  => ( 53,  52,  38,  37,   0,   0),
    54  => ( 54,  53,  18,  17,   0,   0),
    55  => ( 55,  31,   0,   0,   0,   0),
    56  => ( 56,  55,  35,  34,   0,   0),
    57  => ( 57,  50,   0,   0,   0,   0),
    58  => ( 58,  39,   0,   0,   0,   0),
    59  => ( 59,  58,  38,  37,   0,   0),
    60  => ( 60,  59,   0,   0,   0,   0),
    61  => ( 61,  60,  46,  45,   0,   0),
    62  => ( 62,  61,   6,   5,   0,   0),
    63  => ( 63,  62,   0,   0,   0,   0),
    64  => ( 64,  63,  61,  60,   0,   0),
    65  => ( 65,  47,   0,   0,   0,   0),
    66  => ( 66,  65,  57,  56,   0,   0),
    67  => ( 67,  66,  58,  57,   0,   0),
    68  => ( 68,  59,   0,   0,   0,   0),
    69  => ( 69,  67,  42,  40,   0,   0),
    70  => ( 70,  69,  55,  54,   0,   0),
    71  => ( 71,  65,   0,   0,   0,   0),
    72  => ( 72,  66,  25,  19,   0,   0),
    73  => ( 73,  48,   0,   0,   0,   0),
    74  => ( 74,  73,  59,  58,   0,   0),
    75  => ( 75,  74,  65,  64,   0,   0),
    76  => ( 76,  75,  41,  40,   0,   0),
    77  => ( 77,  76,  47,  46,   0,   0),
    78  => ( 78,  77,  59,  58,   0,   0),
    79  => ( 79,  70,   0,   0,   0,   0),
    80  => ( 80,  79,  43,  42,   0,   0),
    81  => ( 81,  77,   0,   0,   0,   0),
    82  => ( 82,  79,  47,  44,   0,   0),
    83  => ( 83,  82,  38,  37,   0,   0),
    84  => ( 84,  71,   0,   0,   0,   0),
    85  => ( 85,  84,  58,  57,   0,   0),
    86  => ( 86,  85,  74,  73,   0,   0),
    87  => ( 87,  74,   0,   0,   0,   0),
    88  => ( 88,  87,  17,  16,   0,   0),
    89  => ( 89,  51,   0,   0,   0,   0),
    90  => ( 90,  89,  72,  71,   0,   0),
    91  => ( 91,  90,   8,   7,   0,   0),
    92  => ( 92,  91,  80,  79,   0,   0),
    93  => ( 93,  91,   0,   0,   0,   0),
    94  => ( 94,  73,   0,   0,   0,   0),
    95  => ( 95,  84,   0,   0,   0,   0),
    96  => ( 96,  94,  49,  47,   0,   0),
    97  => ( 97,  91,   0,   0,   0,   0),
    98  => ( 98,  87,   0,   0,   0,   0),
    99  => ( 99,  97,  54,  52,   0,   0),
    100 => (100,  63,   0,   0,   0,   0),
    101 => (101, 100,  95,  94,   0,   0),
    102 => (102,  99,  97,  96,   0,   0),  -- Ward and Molteno; XAPP052: 102, 101, 36, 35 (not primitive)
    103 => (103,  94,   0,   0,   0,   0),
    104 => (104, 103,  94,  93,   0,   0),
    105 => (105,  89,   0,   0,   0,   0),
    106 => (106,  91,   0,   0,   0,   0),
    107 => (107, 105,  44,  42,   0,   0),
    108 => (108,  77,   0,   0,   0,   0),
    109 => (109, 108, 103, 102,   0,   0),
    110 => (110, 109,  98,  97,   0,   0),
    111 => (111, 101,   0,   0,   0,   0),
    112 => (112, 110,  69,  67,   0,   0),
    113 => (113, 104,   0,   0,   0,   0),
    114 => (114, 113,  33,  32,   0,   0),
    115 => (115, 114, 101, 100,   0,   0),
    116 => (116, 115,  46,  45,   0,   0),
    117 => (117, 115,  99,  97,   0,   0),
    118 => (118,  85,   0,   0,   0,   0),
    119 => (119, 111,   0,   0,   0,   0),
    120 => (120, 113,   9,   2,   0,   0),
    121 => (121, 103,   0,   0,   0,   0),
    122 => (122, 121,  63,  62,   0,   0),
    123 => (123, 121,   0,   0,   0,   0),
    124 => (124,  87,   0,   0,   0,   0),
    125 => (125, 124,  18,  17,   0,   0),
    126 => (126, 125,  90,  89,   0,   0),
    127 => (127, 126,   0,   0,   0,   0),
    128 => (128, 126, 101,  99,   0,   0),
    129 => (129, 124,   0,   0,   0,   0),
    130 => (130, 127,   0,   0,   0,   0),
    131 => (131, 130,  84,  83,   0,   0),
    132 => (132, 103,   0,   0,   0,   0),
    133 => (133, 132,  82,  81,   0,   0),
    134 => (134,  77,   0,   0,   0,   0),
    135 => (135, 124,   0,   0,   0,   0),
    136 => (136, 135,  11,  10,   0,   0),
    137 => (137, 116,   0,   0,   0,   0),
    138 => (138, 137, 131, 130,   0,   0),
    139 => (139, 136, 134, 131,   0,   0),
    140 => (140, 111,   0,   0,   0,   0),
    141 => (141, 140, 110, 109,   0,   0),
    142 => (142, 121,   0,   0,   0,   0),
    143 => (143, 142, 123, 122,   0,   0),
    144 => (144, 143,  75,  74,   0,   0),
    145 => (145,  93,   0,   0,   0,   0),
    146 => (146, 145,  87,  86,   0,   0),
    147 => (147, 146, 110, 109,   0,   0),
    148 => (148, 121,   0,   0,   0,   0),
    149 => (149, 148,  40,  39,   0,   0),
    150 => (150,  97,   0,   0,   0,   0),
    151 => (151, 148,   0,   0,   0,   0),
    152 => (152, 151,  87,  86,   0,   0),
    153 => (153, 152,   0,   0,   0,   0),
    154 => (154, 152,  27,  25,   0,   0),
    155 => (155, 154, 124, 123,   0,   0),
    156 => (156, 155,  41,  40,   0,   0),
    157 => (157, 156, 131, 130,   0,   0),
    158 => (158, 157, 132, 131,   0,   0),
    159 => (159, 128,   0,   0,   0,   0),
    160 => (160, 159, 142, 141,   0,   0),
    161 => (161, 143,   0,   0,   0,   0),
    162 => (162, 161,  75,  74,   0,   0),
    163 => (163, 162, 104, 103,   0,   0),
    164 => (164, 163, 151, 150,   0,   0),
    165 => (165, 164, 135, 134,   0,   0),
    166 => (166, 165, 128, 127,   0,   0),
    167 => (167, 161,   0,   0,   0,   0),
    168 => (168, 166, 153, 151,   0,   0)
  );

  -- model: next value
  function f_model_next(s : t_word) return t_word is
    variable v_fb : std_logic;
  begin
    v_fb := '0';
    for k in t_taps'range loop
      if C_TAPS(g_data_w)(k) /= 0 then
        v_fb := v_fb xor s(C_TAPS(g_data_w)(k) - 1);
      end if;
    end loop;
    return s(g_data_w - 2 downto 0) & v_fb;
  end function f_model_next;

  -- model: effective seed
  function f_model_seed(s : t_word) return t_word is
    variable v_seed : t_word;
  begin
    v_seed := s;
    if s = (s'range => '0') then
      v_seed := (others => '1');
    end if;
    return v_seed;
  end function f_model_seed;

  -- nonzero seeds
  constant C_SEEDS : t_word_arr(0 to 3) := (
    C_PAT_A(g_data_w - 1 downto 0),
    C_PAT_B(g_data_w - 1 downto 0),
    (others => '1'),
    f_msb_only
  );
  -- the same, and zero
  constant C_SEEDS_ZERO : t_word_arr(0 to 4) := (C_SEEDS(0), (others => '0'), C_SEEDS(1), C_SEEDS(2), C_SEEDS(3));

  -- Stimulus signals
  signal clk_i   : std_logic := '1';
  signal rst_n_i : std_logic := '0';
  signal load_i  : std_logic := '0';
  signal seed_i  : t_word    := (others => '0');

  -- Observed signals
  signal rng_o     : t_word;
  signal ref_rng_o : t_word;
begin
  -- Unit Under Test port map
  inst_dut : entity lm_util_lib.lm_util_lfsr
    generic map(
      g_data_w => g_data_w
    )
    port map(
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      load_i  => load_i,
      seed_i  => seed_i,
      rng_o   => rng_o
    );

  -- v0.1.0 reference, same inputs
  inst_ref : entity lm_util_lib.lm_ref_lfsr_v010
    generic map(
      g_data_w => g_data_w
    )
    port map(
      clk_i   => clk_i,
      rst_n_i => rst_n_i,
      load_i  => load_i,
      seed_i  => seed_i,
      rng_o   => ref_rng_o
    );

  -- Clock generation
  clk_i <= not clk_i after C_CLK_PERIOD / 2;

  proc_main : process
    variable v_model : t_word;
    variable v_next  : natural;
    variable v_first : t_word;
    variable v_count : natural;

    -- one clock edge, then compare with the v0.1.0 reference
    procedure p_step_check(constant C_WHAT : string) is
    begin
      p_wait_clk(clk_i);
      wait for C_T_EPSILON;
      check_equal(rng_o, ref_rng_o, C_WHAT);
    end procedure p_step_check;

    -- one clock edge, then compare with the model
    procedure p_step_model(constant C_WHAT : string) is
    begin
      p_wait_clk(clk_i);
      wait for C_T_EPSILON;
      check_equal(rng_o, v_model, C_WHAT);
    end procedure p_step_model;
  begin
    test_runner_setup(runner, runner_cfg);
    if run("model_sequence") then
      for i in C_SEEDS_ZERO'range loop
        -- reset with a different seed on each edge: the last one is loaded
        rst_n_i <= '0';
        for k in 0 to 2 loop
          seed_i  <= C_SEEDS_ZERO((i + k) mod C_SEEDS_ZERO'length);
          v_model := f_model_seed(C_SEEDS_ZERO((i + k) mod C_SEEDS_ZERO'length));
          p_step_model("in reset, edge " & to_string(k) & ", seed " & to_string((i + k) mod C_SEEDS_ZERO'length));
        end loop;
        rst_n_i <= '1';
        for k in 1 to C_STEPS loop
          v_model := f_model_next(v_model);
          p_step_model("step " & to_string(k) & " after reset, seed " & to_string((i + 2) mod C_SEEDS_ZERO'length));
        end loop;
        -- load the next seed while running
        v_next  := (i + 3) mod C_SEEDS_ZERO'length;
        seed_i  <= C_SEEDS_ZERO(v_next);
        load_i  <= '1';
        v_model := f_model_seed(C_SEEDS_ZERO(v_next));
        p_step_model("load of seed " & to_string(v_next));
        load_i  <= '0';
        for k in 1 to C_STEPS loop
          v_model := f_model_next(v_model);
          p_step_model("step " & to_string(k) & " after load, seed " & to_string(v_next));
        end loop;
      end loop;
      -- reset and load together
      seed_i  <= C_SEEDS(1);
      rst_n_i <= '0';
      load_i  <= '1';
      v_model := f_model_seed(C_SEEDS(1));
      p_step_model("reset and load together");
      load_i  <= '0';
      rst_n_i <= '1';
    elsif run("period") then
      check_true(g_data_w <= 20, "period test limited to widths up to 20");
      seed_i  <= C_SEEDS(0);
      rst_n_i <= '0';
      p_wait_clk(clk_i);
      rst_n_i <= '1';
      wait for C_T_EPSILON;
      -- reference: the seed (nonzero), not rng_o, which in reset need not
      -- show the loaded state
      v_first := C_SEEDS(0);
      v_count := 0;
      loop
        p_wait_clk(clk_i);
        wait for C_T_EPSILON;
        v_count := v_count + 1;
        exit when rng_o = v_first or v_count = 2**g_data_w;
      end loop;
      check_equal(v_count, 2**g_data_w - 1, "steps until the seed repeats");
    elsif run("w102_long_cycle") then
      check_equal(g_data_w, 102, "test defined for width 102");
      seed_i  <= C_W102_SEED(g_data_w - 1 downto 0);
      rst_n_i <= '0';
      p_wait_clk(clk_i);
      rst_n_i <= '1';
      wait for C_T_EPSILON;
      -- reference: the seed (nonzero), not rng_o, which in reset need not
      -- show the loaded state
      v_first := C_W102_SEED(g_data_w - 1 downto 0);
      v_count := 0;
      for k in 1 to C_W102_STEPS loop
        p_wait_clk(clk_i);
        wait for C_T_EPSILON;
        if rng_o = v_first and v_count = 0 then
          v_count := k;
        end if;
      end loop;
      check_equal(v_count, 0, "step at which the seed repeats (0: no repeat within " & to_string(C_W102_STEPS) & " steps)");
    elsif run("main_equivalence") then
      for i in C_SEEDS'range loop
        -- reset with seed i (the value during reset changed by design)
        seed_i  <= C_SEEDS(i);
        rst_n_i <= '0';
        p_wait_clk(clk_i, 3);
        rst_n_i <= '1';
        for k in 1 to C_STEPS loop
          p_step_check("step " & to_string(k) & " after reset, seed " & to_string(i));
        end loop;
        -- load the next seed while running
        seed_i <= C_SEEDS((i + 1) mod C_SEEDS'length);
        load_i <= '1';
        p_step_check("load of seed " & to_string((i + 1) mod C_SEEDS'length));
        load_i <= '0';
        for k in 1 to C_STEPS loop
          p_step_check("step " & to_string(k) & " after load, seed " & to_string((i + 1) mod C_SEEDS'length));
        end loop;
      end loop;
    end if;
    test_runner_cleanup(runner);
  end process;

end architecture;
