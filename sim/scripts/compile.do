# SPDX-License-Identifier: Apache-2.0

# Questasim design settings
set worklib lm_util_lib
set vhdl_ver 2008
set src_dir ../../src

vlib $worklib
vmap $worklib $worklib

vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_pkg.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_async_reset.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_bitsum.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_ccd_resync.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_ccd_switch.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_ccd_sync_pulse.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_clock_gen.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_counter.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_debouncer.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_tick_gen.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_pulse_stretch.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_edge_detector.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_delay.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_delay_srl.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_delay_pulse.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_delay_var.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_mux.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_encoder.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_lfsr.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_barrel_shifter.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_ccd_sync_bus.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_clock_measure.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_clock_mux.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_crc_par.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_crc_ser.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_mux_or.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_pri_arbiter.vhd"
vcom -work $worklib -$vhdl_ver -explicit "$src_dir/lm_util_rr_arbiter.vhd"


