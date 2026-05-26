# ==========================================================================
# PrimeTime PX (Power Analysis) Script
# ==========================================================================

set power_enable_analysis TRUE
set power_analysis_mode time_based

set search_path [list "./"]
set link_library [list "*" \
    "fsa0m_a_generic_core_tt1p8v25c.db" \
    "fsa0m_a_generic_core_ss1p62v125c.db" \
    "fsa0m_a_generic_core_ff1p98vm40c.db" \
    "fsa0m_a_t33_generic_io_tt1p8v25c.db" \
    "fsa0m_a_t33_generic_io_ss1p62v125c.db" \
    "fsa0m_a_t33_generic_io_ff1p98vm40c.db" ]


read_file -format verilog ./CHIP.v

current_design CHIP
link

#read_sdc ./CHIP.sdc
read_sdc ./CHIP_pt.sdc
read_sdf -load_delay net ./CHIP.sdf

read_vcd -strip_path tb/uut ./CHIP.vcd

update_timing
update_power
report_power > CHIP_power_report_apr_sdc.rpt
report_timing -delay_type max -max_paths 10 -slack_lesser_than 999 -nosplit > CHIP_setup_timing_apr_sdc.rpt
report_timing -delay_type min -max_paths 10 -slack_lesser_than 999 -nosplit > CHIP_hold_timing_apr_sdc.rpt

exit



