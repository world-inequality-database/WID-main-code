

// -----------------------------------------------------------------------------------------------------------------
use "$wid_dir/Country-Updates/Middle-East/2017/October/middle-east-assouad2017.dta", clear // middle-east

tempfile researchers
save "`researchers'"


// -----------------------------------------------------------------------------------------------------------------
// Clean up
replace p="pall" if p=="p0p100"

// ----------------------------------------------------------------------------------------------------------------
// Create metadata
generate sixlet = substr(widcode, 1, 6)
keep iso sixlet source method
order iso sixlet source method
duplicates drop
tempfile meta
save "`meta'"

// Add data to WID
use "$work_data/add-uk-data-output.dta", clear
gen oldobs=1
append using "`researchers'"
drop source method
duplicates tag iso year p widcode, gen(dup)
drop if oldobs==1 & dup==1
drop oldobs dup

label data "Generated by add-researchers-data-real.do"
save "$work_data/add-researchers-data-real-output.dta", replace

// Add metadata
use "$work_data/add-uk-data-metadata.dta", clear
merge 1:1 iso sixlet using "`meta'", nogenerate update replace

label data "Generated by add-researchers-data-real.do"
save "$work_data/add-researchers-data-real-metadata.dta", replace
