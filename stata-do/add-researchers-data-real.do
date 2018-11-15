// -----------------------------------------------------------------------------------------------------------------
// IMPORT ALL FILES

// France inequality 2017 (GGP2017)
use "$france_data/france-ggp2017.dta", clear

// UK wealth 2017 (Alvaredo2017)
append using "$uk_data/uk-wealth-alvaredo2017.dta"

// US inequality 2017 (PSZ2017)
append using "$wid_dir/Country-Updates/US/2017/September/PSZ2017-AppendixII.dta"

// Middle-East 2017 (Assouad2017)
append using "$wid_dir/Country-Updates/Middle-East/2017/October/middle-east-assouad2017.dta"

// World and World Regions 2018 (ChancelGethin2018 from World Inequality Report)
append using "$wid_dir/Country-Updates/World/2018/January/world-chancelgethin2018.dta"

// Germany and subregions
append using "$wid_dir/Country-Updates/Germany/2018/May/bartels2018.dta"

// Korea 2018 (Kim2018), only gdp and nni (rest is in current LCU)
append using "$wid_dir/Country-Updates/Korea/2018_10/korea-kim2018-constant.dta"

tempfile researchers
save "`researchers'"

// ----------------------------------------------------------------------------------------------------------------
// CREATE METADATA
generate sixlet = substr(widcode, 1, 6)
keep iso sixlet source method
order iso sixlet source method
duplicates drop

duplicates tag iso sixlet, gen(dup)
assert dup==0
drop dup

replace method = " " if method == ""
tempfile meta
save "`meta'"

// ----------------------------------------------------------------------------------------------------------------
// ADD DATA TO WID
use "$work_data/aggregate-regions-wir2018-output.dta", clear
gen oldobs=1
append using "`researchers'"
replace oldobs=0 if oldobs!=1

// Germany: drop old fiscal income series
drop if strpos(widcode, "fiinc") & (iso == "DE") & (oldobs == 1)

// France 2017: drop specific widcodes
drop if (inlist(widcode,"ahwbol992j","ahwbus992j","ahwcud992j","ahwdeb992j","ahweal992j") ///
	| inlist(widcode,"ahwequ992j","ahwfie992j","ahwfin992j","ahwfix992j","ahwhou992j") ///
	| inlist(widcode,"ahwnfa992j","ahwpen992j","bhweal992j","ohweal992j","shweal992j","thweal992j") ///
	| substr(widcode, 2, 2) == "fi") ///
	& (iso == "FR") & (oldobs==1)

// US inequality (PSZ 2017 Appendix II): drop g-percentiles except for wealth data (DINA imported before), drop new duplicated wid data
drop if (iso=="US") & (oldobs==0) & (length(p)-length(subinstr(p,"p","",.))==1) & (p!="pall") & !inlist(widcode,"shweal992j","ahweal992j")
duplicates tag iso year p widcode, gen(dupus)
drop if dupus & oldobs==0 & iso=="US"

// Korea: drop old widcodes
drop if iso=="KR" & oldobs==1 & inlist(substr(widcode,2,5),"gdpro","nninc")

replace p="pall" if p=="p0p100"

// Drop old duplicated wid data
duplicates tag iso year p widcode, gen(dup)
drop if dup & oldobs==1

duplicates tag iso year p widcode, gen(duplicate)
assert duplicate==0

keep iso year p widcode currency value

label data "Generated by add-researchers-data-real.do"
save "$work_data/add-researchers-data-real-output.dta", replace


// ----------------------------------------------------------------------------------------------------------------
// ADD METADATA
use "$work_data/na-metadata-no-duplicates.dta", clear
merge 1:1 iso sixlet using "`meta'", nogenerate update replace
replace method = "" if method == " "
replace method = "" if iso == "FR" & substr(sixlet, 2, 5) == "ptinc"

duplicates tag iso sixlet, gen(duplicate)
assert duplicate==0
drop duplicate

label data "Generated by add-researchers-data-real.do"
save "$work_data/add-researchers-data-real-metadata.dta", replace
