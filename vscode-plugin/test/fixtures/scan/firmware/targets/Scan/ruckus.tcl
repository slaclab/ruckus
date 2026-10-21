# Fixture of test/unit.ts (one case per line, see the assertions there)
loadSource -dir "$::DIR_PATH/rtl"
loadSource -dir "rtl"
source -encoding utf-8 "$::DIR_PATH/helper_ruckus/helper_proc.tcl"
helperLoad
loadSource -path "$::DIR_PATH/tok/Tok_[info exists ::env(RUCKUS_TEST_TOKEN)].vhd"
loadRuckusTcl "$::DIR_PATH/stop"
loadRuckusTcl "$::DIR_PATH/sub"
