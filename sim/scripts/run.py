# SPDX-License-Identifier: Apache-2.0

import argparse
import os
from itertools import product
from pathlib import Path

from vunit import VUnit


ROOT_DIR = Path(__file__).resolve().parents[2]
SRC_DIR = ROOT_DIR / "src"
TB_DIR = ROOT_DIR / "sim" / "tb"


def generate_tests(test, **param_lists):
    """
    Generate tests by varying combinations of all provided parameter lists.

    Example usage:
    generate_tests(test, sign=['signed', 'unsigned'], data_width=[8, 16, 32])
    """

    # Get parameter names and their lists
    keys = list(param_lists.keys())
    values = list(param_lists.values())

    # Iterate over the Cartesian product of all values
    for combination in product(*values):
        # Create dictionary of generics for current combination
        generics = dict(zip(keys, combination))

        # Create a readable config name
        config_name = ",".join(f"{k}={v}" for k, v in generics.items())

        # Add the configuration to the object
        test.add_config(
            name=config_name,
            generics=generics
        )

parser = argparse.ArgumentParser(add_help=False)
parser.add_argument('--level', choices=['fast', 'full'], default='fast')

# Use parse_known_args to let VUnit handle the rest
args, remaining_argv = parser.parse_known_args()

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv(argv=remaining_argv, compile_builtins=False)

# Optionally add VUnit's builtin HDL utilities for checking, logging, communication...
vu.add_vhdl_builtins()

# Create library 'lib'
lib = vu.add_library("lm_util_lib")

# Add source and testbench files using paths relative to this script, so the
# runner works from the repository root and from sim/scripts alike.
lib.add_source_files(str(SRC_DIR / "lm_util_pkg.vhd"))
lib.add_source_files([
    str(path)
    for path in sorted(SRC_DIR.glob("*.vhd"))
    if path.name != "lm_util_pkg.vhd"
])
lib.add_source_files([
    str(path)
    for path in sorted(TB_DIR.glob("*.vhd"))
])

if os.environ.get("VUNIT_SIMULATOR") == "ghdl":
    vu.set_compile_option("ghdl.a_flags", ["--std=08", "-fsynopsys", "-frelaxed"])
    vu.set_sim_option("ghdl.elab_flags", ["--std=08", "-fsynopsys", "-frelaxed"])

# Manual test handling

# lm_util_async_reset
test = lib.test_bench("tb_vu_lm_util_async_reset").test("reset_pulse_check_waits")
generate_tests(test, g_delay_len = [2, 3, 4], g_rst_lvl = [0, 1])

# lm_util_barrel_shifter
test = lib.test_bench("tb_vu_lm_util_barrel_shifter").test("rotate_left_test")
#generate_tests(test, g_data_w = [32], g_shift = range(0,31))
generate_tests(test, g_data_w = [32], g_shift = [0, 2, 5, 7, 11, 15, 31])
if args.level == 'full':
    generate_tests(test, g_data_w = [64], g_shift = [0, 2, 5, 7, 11, 15, 31, 32, 48, 63])
    #generate_tests(test, g_data_w = [24], g_shift = [0, 3, 8, 15, 23])  todo: temporary disabled. Test fails with 24 bits. [issue #1]
    generate_tests(test, g_data_w = [16], g_shift = [0, 3, 8, 15])
    #generate_tests(test, g_data_w = [15], g_shift = [0, 3, 8, 14]) todo: temporary disabled. Test fails with 15 bits [issue #1]
    generate_tests(test, g_data_w = [8], g_shift = [0, 3, 7])
    generate_tests(test, g_data_w = [4], g_shift = [0, 3])

# lm_util_bitsum
test = lib.test_bench("tb_vu_lm_util_bitsum").test("check_sum")
generate_tests(test, g_nof_first_stage_chunk = [3], g_din_w=[28], g_d_in=[111500])
if args.level == 'full':
    generate_tests(test, g_nof_first_stage_chunk = [2, 3   ], g_din_w=[15], g_d_in=[15, 1024, 65535])
    generate_tests(test, g_nof_first_stage_chunk = [2, 3   ], g_din_w=[28], g_d_in=[15, 1024, 65535, 65536, 115200, 1000000])
    generate_tests(test, g_nof_first_stage_chunk = [   3, 4], g_din_w=[32], g_d_in=[          65535, 65536, 115200, 1000000, 1000_000_023])

# lm_util_ccd_resync
test = lib.test_bench("tb_vu_lm_util_ccd_resync")
generate_tests(test, g_meta_levels = [2, 3])

# lm_util_ccd_switch
test = lib.test_bench("tb_vu_lm_util_ccd_switch")
generate_tests(test, g_priority_lo = [False, True], g_or_high = [False, True], g_and_low = [False, True])

# lm_util_ccd_sync_pulse
test = lib.test_bench("tb_vu_lm_util_ccd_sync_pulse").test("check")
generate_tests(test, g_delay_len = [2, 3, 4])

# lm_util_clock_gen
test = lib.test_bench("tb_vu_lm_util_clock_gen").test("check")
generate_tests(test, g_clock_div = [10], g_clock_phase = [0, 1, 9],  g_pos_duty_cycle = [1, 5, 9])
if args.level == 'full':
    generate_tests(test, g_clock_div = [16], g_clock_phase = [0, 1, 8, 15],  g_pos_duty_cycle = [1, 8, 15])
    generate_tests(test, g_clock_div = [5], g_clock_phase = [0, 1, 2, 3],  g_pos_duty_cycle = [1, 2, 3, 4])

# lm_util_clock_measure
test = lib.test_bench("tb_vu_lm_util_clock_measure").test("check")
if args.level == 'full':
    generate_tests(test, g_ref_clock_freq = [1_000_000], g_clock_width = [32], g_clock_freq = [100_000])

# lm_util_counter
test = lib.test_bench("tb_vu_lm_util_counter").test("counter")
generate_tests(test, g_data_w = [16], g_wd_timer = [1, 5], g_dir = [1], g_load_dat = [0])
#generate_tests(test, g_data_w = [16], g_wd_timer = [5],    g_dir = [0], g_load_dat = [0]) [issue #10]


# lm_util_crc_serial
# https://reveng.sourceforge.io/crc-catalogue/all.htm
test = lib.test_bench("tb_vu_lm_util_crc_serial").test("serial")
generate_tests(test, g_polynomial = ["1021"], g_init = ["FFFF"], g_refin  = [False], g_refout = [False], g_xor_out = ["FFFF"], g_crc_check = ["d64e"]) #CRC-16/GENIBUS
generate_tests(test, g_polynomial = ["1021"], g_init = ["0000"], g_refin  = [False], g_refout = [False], g_xor_out = ["FFFF"], g_crc_check = ["ce3c"]) #CRC-16/GSM
generate_tests(test, g_polynomial = ["1021"], g_init = ["FFFF"], g_refin  = [False], g_refout = [False], g_xor_out = ["0000"], g_crc_check = ["29b1"]) #CRC-16/IBM-3740
generate_tests(test, g_polynomial = ["1021"], g_init = ["FFFF"], g_refin  = [True],  g_refout = [True],  g_xor_out = ["FFFF"], g_crc_check = ["906e"]) #CRC-16/IBM-SDLC
generate_tests(test, g_polynomial = ["1021"], g_init = ["c6c6"], g_refin  = [True],  g_refout = [True],  g_xor_out = ["0000"], g_crc_check = ["bf05"]) #CRC-16/ISO-IEC-14443-3-A
generate_tests(test, g_polynomial = ["0589"], g_init = ["0000"], g_refin  = [False], g_refout = [False], g_xor_out = ["0001"], g_crc_check = ["007e"]) #CRC-16/DECT-R
generate_tests(test, g_polynomial = ["8005"], g_init = ["800d"], g_refin  = [False], g_refout = [False], g_xor_out = ["0000"], g_crc_check = ["9ecf"]) #CRC-16/DDS-110

# lm_util_crc_parallel
test = lib.test_bench("tb_vu_lm_util_crc_parallel").test("parallel")
generate_tests(test, g_polynomial = ["1021"], g_init = ["FFFF"], g_refin  = [False], g_refout = [False], g_xor_out = ["FFFF"], g_crc_check = ["d64e"]) #CRC-16/GENIBUS
generate_tests(test, g_polynomial = ["1021"], g_init = ["0000"], g_refin  = [False], g_refout = [False], g_xor_out = ["FFFF"], g_crc_check = ["ce3c"]) #CRC-16/GSM
generate_tests(test, g_polynomial = ["1021"], g_init = ["FFFF"], g_refin  = [False], g_refout = [False], g_xor_out = ["0000"], g_crc_check = ["29b1"]) #CRC-16/IBM-3740
generate_tests(test, g_polynomial = ["1021"], g_init = ["FFFF"], g_refin  = [True],  g_refout = [True],  g_xor_out = ["FFFF"], g_crc_check = ["906e"]) #CRC-16/IBM-SDLC
generate_tests(test, g_polynomial = ["1021"], g_init = ["c6c6"], g_refin  = [True],  g_refout = [True],  g_xor_out = ["0000"], g_crc_check = ["bf05"]) #CRC-16/ISO-IEC-14443-3-A
generate_tests(test, g_polynomial = ["0589"], g_init = ["0000"], g_refin  = [False], g_refout = [False], g_xor_out = ["0001"], g_crc_check = ["007e"]) #CRC-16/DECT-R
generate_tests(test, g_polynomial = ["8005"], g_init = ["800d"], g_refin  = [False], g_refout = [False], g_xor_out = ["0000"], g_crc_check = ["9ecf"]) #CRC-16/DDS-110

# lm_util_debouncer
test = lib.test_bench("tb_vu_lm_util_debouncer").test("length")
generate_tests(test, g_debounce_length = [10], g_debounce_lvl = [2])

test = lib.test_bench("tb_vu_lm_util_debouncer").test("length_level")
generate_tests(test, g_debounce_length = [10, 11], g_debounce_lvl = [0, 1, 2])

# lm_util_delay
test = lib.test_bench("tb_vu_lm_util_delay").test("sequence")
generate_tests(test, g_delay = [0, 1, 2, 3, 8], g_data_w = [10, 32])

# lm_util_delay_srl
test = lib.test_bench("tb_vu_lm_util_delay_srl").test("sequence")
generate_tests(test, g_delay = [0, 1, 2, 3, 8], g_data_w = [10, 32])

# lm_util_delay_pulse
test = lib.test_bench("tb_vu_lm_util_delay_pulse").test("pulse")
generate_tests(test, g_delay = [0, 1, 2, 3, 4, 5], g_pulse_width = [1])
#todo: fails generate_tests(test, g_delay = [0, 1, 2, 3, 4, 5], g_pulse_width = [2])

# lm_util_delay_var
test = lib.test_bench("tb_vu_lm_util_delay_var").test("sequence")
generate_tests(test, g_delay = [1, 2, 3, 4, 7, 8], g_delay_max = [8], g_arch_type = [0])
#generate_tests(test, g_delay = [1, 2, 3, 4, 7, 8], g_delay_max = [8], g_arch_type = [1])

test = lib.test_bench("tb_vu_lm_util_delay_var").test("pulse")
generate_tests(test, g_delay = [2, 3, 4, 7, 8], g_delay_max = [8], g_arch_type = [2], g_data_w = [1])
#todo fails:generate_tests(test, g_delay = [1], g_delay_max = [8], g_arch_type = [2], g_data_w = [1])

#lm_util_edge_detector
test = lib.test_bench("tb_vu_lm_util_edge_detector").test("rising_edge_detect")
generate_tests(test, g_event_edge = [1])

test = lib.test_bench("tb_vu_lm_util_edge_detector").test("falling_edge_detect")
generate_tests(test, g_event_edge = [0])


#lm_util_tick_gen
test = lib.test_bench("tb_vu_lm_util_tick_gen")
generate_tests(test, g_event_edge = [1])

#lm_util_pulse_stretch
test = lib.test_bench("tb_vu_lm_util_pulse_stretch")
generate_tests(test, g_pulse_length = [2, 5], g_has_fixed_length = [0, 1], g_has_resync_stage=[0, 1], g_out_level = [1])
#todo: seems to fail with g_out_level = ['0']

# Run vunit function
vu.main()
