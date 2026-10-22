# Fixture of test/unit.ts (one case per line, see the assertions there)
loadSource -dir "$::DIR_PATH/rtl"
loadSource -dir "rtl"
source -encoding utf-8 "$::DIR_PATH/helper_ruckus/helper_proc.tcl"
helperLoad
loadSource -path "$::DIR_PATH/tok/Tok_[info exists ::env(RUCKUS_TEST_TOKEN)].vhd"
loadSource -path "$::DIR_PATH/clock/Clock_[clock format [clock scan 1970-01-01 -format %Y-%m-%d -gmt 1] -format %Y -gmt 1].vhd"
loadRuckusTcl "$::DIR_PATH/stop"
loadRuckusTcl "$::DIR_PATH/sub"
