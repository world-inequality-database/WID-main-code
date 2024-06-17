clear all
tempfile combined
save `combined', emptyok

// Start with the WID data
use "$work_data/correct-widcodes-output.dta", clear

keep if widcode == "mgdpro999i"
drop p widcode

rename value gdp_lcu_wid

// Add other data sources
*merge 1:1 iso year using "$work_data/un-sna-detailed-tables.dta", ///
*	nogenerate update assert(using master match) keepusing(gdp*)
merge 1:1 iso year using "$work_data/un-sna-summary-tables.dta", ///
	nogenerate update assert(using master match) keepusing(gdp*)
merge 1:1 iso year using "$work_data/wb-macro-data.dta", ///
	nogenerate update assert(using master match) keepusing(gdp*)
merge 1:1 iso year using "$work_data/wb-gem-gdp.dta", ///
	nogenerate update assert(using master match) keepusing(gdp*)
merge 1:1 iso year using "$work_data/imf-weo-gdp.dta", ///
	nogenerate update assert(using master match) keepusing(gdp* estimatesstartafter)
merge 1:1 iso year using "$work_data/maddison-wu-gdp.dta", ///
	nogenerate update assert(using master match) keepusing(gdp*)
merge 1:1 iso year using "$input_data_dir/taxhavens-data/GDP-selected_countries.dta", ///
	nogenerate update assert(using master match) keepusing(gdp*)
	
// Drop problematic data in UN data for Yugoslavia
replace gdp_lcu_un2 = . if iso == "YU" & year > 1990
replace gdp_usd_un2 = . if iso == "YU" & year > 1990

// correcting UN data for USSR. This is not needed, USSR data is in Russian Rubles (1:1000)
*replace gdp_lcu_un2 = 1000*gdp_lcu_un2 if iso == "SU"

// Palestine we use the USD as UN SNA and WB
replace gdp_lcu_un2 = gdp_usd_un2 if iso == "PS"

// drop UN gdp for ZW so that the level is WB
replace gdp_lcu_un2 = . if iso == "ZW" & year == $pastyear & $pastyear == 2023
replace gdp_usd_un2 = . if iso == "ZW" & year == $pastyear & $pastyear == 2023

// drop WB gdp for CU so that the level is UN
replace gdp_lcu_wb = . if iso == "CU" & year >= 2021 & $pastyear == 2023
replace gdp_usd_wb = . if iso == "CU" & year >= 2021 & $pastyear == 2023

// Calculate the GDP

// Drop Iraq before 1968 because of holes in the data: better to have
// the Maddison data handle everything from there.
drop if (iso == "IQ") & (year < 1968)

// Identify reference year (and reference GDP level)
// First case: there are some WID values, we use the last one
sort iso year
egen haswid = total(gdp_lcu_wid < .), by(iso)
egen refyear = lastnm(year) if haswid & (gdp_lcu_wid < .), by(iso)
egen refyear2 = mode(refyear) if haswid, by(iso)
drop refyear
rename refyear2 refyear
generate reflev = log(gdp_lcu_wid) if (year == refyear)
generate notelev = "Piketty and Zucman (2014)" if (year == refyear)
// Other case: there are no WID values, we use the last value available from
// Maddison & Wu (China only), the UN, the World Bank or the IMF
generate gdp_lcu_weo_noest = gdp_lcu_weo if (year < estimatesstartafter)
foreach v in mw wb un2 weo_noest cbs lmf {
	egen refyear_`v' = lastnm(year) if (gdp_lcu_`v' < .) & !haswid, by(iso)
	egen refyear_`v'2 = mode(refyear_`v'), by(iso)
	drop refyear_`v'
	rename refyear_`v'2 refyear_`v'
	
	replace notelev = "`v'" ///
		if (refyear_`v' < .) & ((refyear_`v' > refyear) | refyear >= .)
	replace reflev = log(gdp_lcu_`v') ///
		if (refyear_`v' < .) & ((refyear_`v' > refyear) | refyear >= .)
	replace refyear = refyear_`v' ///
		if (refyear_`v' < .) & ((refyear_`v' > refyear) | refyear >= .)
	
	*drop refyear_`v'
}
*problems with Somalia
replace notelev = "un2" if iso == "SO"
replace refyear = refyear_un2 if iso == "SO"
	replace reflev = log(gdp_lcu_un2) ///
		if (refyear_un2 < .) & iso == "SO"
drop refyear_* 
		
// Special case for VE: 2014 is the last year where sources agree
// replace refyear = 2014 if iso == "VE"
// replace notelev = "wb" if iso == "VE"
/*
foreach i of numlist 1000 600 500 400 300 200 100 50 40 30 20 10 {
	egen refyear_un1_`i' = lastnm(year) ///
		if (gdp_lcu_un1_serie`i' < .) & !haswid, by(iso)
	egen refyear_un1_`i'2 = mode(refyear_un1_`i'), by(iso)
	drop refyear_un1_`i'
	rename refyear_un1_`i'2 refyear_un1_`i'
	
	replace notelev = "the UN SNA detailed tables (series `i')" ///
		if (refyear_un1_`i' < .) & ((refyear_un1_`i' > refyear) | refyear >= .)
	replace reflev = log(gdp_lcu_un1_serie`i') ///
		if (refyear_un1_`i' < .) & ((refyear_un1_`i' > refyear) | refyear >= .)
	replace refyear = refyear_un1_`i' ///
		if (refyear_un1_`i' < .) & ((refyear_un1_`i' > refyear) | refyear >= .)
	
	drop refyear_un1_`i'
}
*/
replace notelev = "" if (year != refyear)
replace reflev = . if (year != refyear)
replace notelev = "Piketty and Zucman (2014)" if (notelev == "wid") & (iso != "SE")
replace notelev = "Waldenstrom" if (notelev == "wid") & (iso == "SE")
replace notelev = "the UN SNA main tables" if (notelev == "un2")
replace notelev = "the World Bank" if (notelev == "wb")
replace notelev = "Maddison and Wu (2007)" if (notelev == "mw")
replace notelev = "the IMF World Economic Outlook 04/$year" if (notelev == "weo_noest")
replace notelev = "Lane and Milesi-Ferretti (2022)" if (notelev == "lmf")
replace notelev = "Statistics Netherlands" if (notelev == "cbs")
drop gdp_lcu_weo_noest	

/* storing shares of gdp in USD for former Yugoslavia
preserve
gen yugosl = 1 if inlist(iso, "BA", "HR", "MK", "RS", "YU", "KS", "SI", "ME")
gen yugosl = 1 if inlist(iso, "BA", "HR", "MK", "RS", "YU", "KS", "SI", "ME")
keep if yugosl == 1 & year >= 1970
keep iso year gdp_usd_un2
ren gdp_usd_un2 gdp 
greshape wide gdp, i(year) j(iso) string

foreach c in BA HR MK RS KS SI ME {
	gen ratio`c'YU = gdp`c'/gdpYU if year == 1990
	egen x2 = mode(ratio`c'YU) 
	replace gdp`c' = gdpYU*x2 if missing(gdp`c') & year >= 1970
	drop ratio`c'YU x2
}
greshape long gdp, i(year) j(iso) string
ren gdp gdp_usd_YUratio

sa "$input_data_dir/currency-rates/gdp_usd_YUratio", replace
restore
*/
/* storing shares of gdp in USD for former USSR
preserve
gen soviet = 1 if iso == "AM"
replace soviet = 1 if inlist(iso, "AZ", "BY", "KG", "KZ", "TJ", "TM")
replace soviet = 1 if inlist(iso, "UZ", "EE", "LT", "LV", "MD", "GE")
replace soviet = 1 if iso == "RU" | iso == "UA" | iso == "SU"
keep if soviet == 1 & year >= 1970

keep iso year gdp_usd_un2
ren gdp_usd_un2 gdp 
greshape wide gdp, i(year) j(iso) string
foreach c in AM AZ BY KG KZ TJ TM UZ EE LT LV MD GE RU UA {
	gen ratio`c'SU = gdp`c'/gdpSU if year == 1990
	egen x2 = mode(ratio`c'SU) 
	replace gdp`c' = gdpSU*x2 if missing(gdp`c') & year >= 1970
	drop ratio`c'SU x2
}
greshape long gdp, i(year) j(iso) string
ren gdp gdp_usd_SUratio

sa "$input_data_dir/currency-rates/gdp_usd_SUratio", replace
restore
*/

// Curacao and Sint Marteen as share of Former Netherlands Antilles
drop if iso == "CW" & year < 2005
expand 2 if (iso == "AN") & inrange(year, 1970, 2004), generate(newobsCW)
replace iso = "CW" if newobsCW
expand 2 if (iso == "AN") & inrange(year, 1970, 2004), generate(newobsSX)
replace iso = "SX" if newobsSX

foreach x in lcu usd {	
gen aux_`x'05 = gdp_`x'_un2 if iso == "AN" & year == 2005
egen gdpan`x'05 = mode(aux_`x'05)

foreach c in CW SX {
	gen aux`c'_AN`x' = gdp_`x'_un2/gdpan`x' if iso == "`c'" & year == 2005
	egen ratio`c'_AN`x' = mode(aux`c'_AN`x')
}
foreach c in CW SX {
replace gdp_`x'_un2 = ratio`c'_AN`x'*gdp_`x'_un2 if iso == "`c'" & year < 2005 
}
}
 
preserve
	keep if inlist(iso, "CW", "SX")
	keep iso ratio* 
	gduplicates drop 
	sa "$work_data/ratioCWSX_AN.dta", replace
restore 
drop gdpanlcu gdpanlcu05 gdpanusd05 aux* ratio* newobs*

// Generate growth rates
sort iso year
foreach v in wid mw wb un2 lmf cbs {
	by iso: generate growth_`v' = log(gdp_lcu_`v'[_n + 1]) - log(gdp_lcu_`v')
}

// Bonaire, Sint Eustatius and Saba will get the growth rate of the Netherlands Antilles
sort iso year
	by iso: replace growth_cbs = log(gdp_usd_un2[_n + 1]) - log(gdp_usd_un2) if iso == "AN"
expand 2 if (iso == "AN") & year < 2009, generate(newobsBQ)
replace iso = "BQ" if newobsBQ

foreach var in reflev refyear gdp_usd_un2 gdp_lcu_un2 {
	replace `var' =. if newobsBQ
}
replace growth_cbs =. if iso == "AN"
replace growth_un2 =. if iso == "BQ"
drop newobsBQ 
*then CW
sort iso year
	by iso: replace growth_cbs = log(gdp_usd_un2[_n + 1]) - log(gdp_usd_un2) if iso == "CW"
expand 2 if (iso == "CW") & year < 2012 & year > 2008, generate(newobsBQ)
replace iso = "BQ" if newobsBQ

foreach var in reflev refyear gdp_usd_un2 gdp_lcu_un2 {
	replace `var' =. if newobsBQ
}
replace growth_cbs =. if iso == "CW"
replace growth_un2 =. if iso == "BQ"
drop newobsBQ 


/*
foreach i of numlist 1000 600 500 400 300 200 100 50 40 30 20 10 {
	by iso: generate growth_un1_serie`i' = log(gdp_lcu_un1_serie`i'[_n + 1]) - log(gdp_lcu_un1_serie`i')
}
*/
sort iso year
foreach v in gem weo {
	by iso: generate growth_`v' = log(gdp_lcu_`v'[_n + 1]) - log(gdp_lcu_`v')
}

// For IMF: separate forecasts for the rest
generate growth_weo_forecast = growth_weo if (year >= estimatesstartafter)
replace growth_weo = . if (year >= estimatesstartafter)

// Keep preferred growth rate
generate growth = .
generate growth_src = ""
foreach v of varlist growth_wid growth_mw growth_wb growth_un2 /*growth_un1**/ ///
		growth_weo /*growth_gem*/ growth_weo_forecast growth_lmf growth_cbs {
	replace growth_src = "`v'" if (growth >= .) & (`v' < .)
	replace growth = `v' if (growth >= .) & (`v' < .)
}
// Issues with Somalia, Palestine and Mongolia
replace growth = growth_un2 if inlist(iso, "SO", "PS", "MN") & year >= 1970
	replace growth_src = "growth_un2" if inlist(iso, "SO", "PS", "MN") & year >= 1970

replace growth_src = "Piketty and Zucman (2014)" if (growth_src == "growth_wid") & (iso != "SE")
replace growth_src = "Waldenstrom" if (growth_src == "growth_wid") & (iso == "SE")
replace growth_src = "the UN SNA main tables" if (growth_src == "growth_un2")
replace growth_src = "the World Bank" if (growth_src == "growth_wb")
replace growth_src = "the World Bank Global Economic Monitor" if (growth_src == "growth_gem")
replace growth_src = "the IMF World Economic Outlook" if (growth_src == "growth_weo")
replace growth_src = "the IMF World Economic Outlook (forecast)" if (growth_src == "growth_weo_forecast")
replace growth_src = "Maddison and Wu (2007)" if (growth_src == "growth_mw")
replace growth_src = "Lane and Milesi-Ferretti (2022)" if (growth_src == "growth_lmf")
replace growth_src = "Statistics Netherlands" if (growth_src == "growth_cbs")
replace growth_src = "Statistics Netherlands. Extrapolated using AN growth rate" if (growth_src == "growth_cbs") & year <= 2009

// South Sudan projection in WEO is too high
so iso year
replace growth = growth[_n - 1] if iso == "SS" & year == 2021
replace growth_src = "Last year growth rate from UN SNA main tables" if iso == "SS" & year == 2021

/*
foreach i of numlist 1000 600 500 400 300 200 100 50 40 30 20 10 {
	replace growth_src = "the UN SNA detailed tables (series `i')" ///
		if (growth_src == "growth_un1_serie`i'")
}
*/

// As a last resort: extrapoalte from previous years
fillin iso year
sort iso year
by iso: carryforward growth if (year >= 2010), cfindic(cf) gen(growth_cf)
replace growth_src = "the value for the previous year" if cf & year < $pastyear
replace growth = growth_cf if cf & year < $pastyear
drop if _fillin & !cf & year < $pastyear 
drop _fillin cf growth_cf

sort iso year
by iso: carryforward refyear, replace
// -->
// TO BE REVISED - 09/06/2022 RM
*	drop if iso == "VE" & year >= $pastyear
// <--
/*
// As a last resort: use 2014 growth rate in 2015. 2017 update: 19 changes made, 2018 update: 0 changes
egen lastyear = max(year), by(iso)
expand 2 if (lastyear == 2014) & (year == 2014), generate(newobs)
replace year = 2015 if newobs
sort iso year
replace growth_src = "the value for the previous year" if (growth >= .) & (year == 2014)
replace growth = growth[_n - 1] if (growth >= .) & (year == 2014)
drop newobs lastyear

// As a last resort: use (pastyear - 2) growth rate in (pastyear - 1). 2017 update: 25 changes made, 2018 update: 3 changes 
egen lastyear = max(year), by(iso)
expand 2 if (lastyear == $pastyear - 2) & (year == $pastyear - 2), generate(newobs)
replace year = $pastyear - 1 if newobs
sort iso year
replace growth_src = "the value for the previous year" if (growth >= .) & (year ==  $pastyear - 2)
replace growth = growth[_n - 1] if (growth >= .) & (year ==  $pastyear - 2)
drop newobs lastyear

// As a last resort use (pastyear-1) growth rate in pastyear. 2018 update: 27 changes
egen lastyear = max(year), by(iso)
expand 2 if (lastyear == $pastyear - 1) & (year == $pastyear - 1), generate(newobs)
replace year = $pastyear if newobs
sort iso year
replace growth_src = "the value for the previous year" if (growth >= .) & (year == $pastyear - 1)
replace growth = growth[_n - 1] if (growth >= .) & (year == $pastyear - 1)
drop newobs lastyear
*/

generate growth_after = growth[_n - 1] if (year > refyear)
generate growth_before = -growth if (year < refyear)

generate growth_src_after = growth_src[_n - 1] if (year > refyear)
generate growth_src_before = growth_src if (year < refyear)

generate growth2 = cond(growth_after < ., growth_after, growth_before)
generate growth2_src = cond(growth_src_after != "", growth_src_after, growth_src_before)

drop if (growth2 >= .) & (reflev >= .)

generate gdp = cond(growth2 < ., growth2, reflev)

// Chain growth rates
gsort iso year
by iso: replace gdp = sum(gdp) if (year >= refyear)
gsort iso -year
by iso: replace gdp = sum(gdp) if (year <= refyear)
replace gdp = exp(gdp)

// Identify junction problems and drop problematic observations
sort iso year
by iso: generate seriebreak = (year[_n - 1] != year - 1) ///
	& (growth2_src[_n - 1] != growth2_src) ///
	& (_n != 1)
by iso: generate catbreak = sum(seriebreak)
egen hasbreak = total(seriebreak), by(iso)
drop if hasbreak & catbreak == 0

// Generate note for level
generate level_src = notelev if (year == refyear)
generate level_year = refyear

// Add Maddison real series for East Germany
merge 1:1 iso year using "$work_data/east-germany-gdp.dta", ///
	nogenerate
replace level_src = "OECD" if (year == 1991) & (iso == "DD")
replace level_year = 1991 if (year == 1991) & (iso == "DD")
replace growth2_src = "Maddison (1995)" if (year != 1991) & (iso == "DD")

// Add price index and convert to real
merge 1:1 iso year using "$work_data/price-index.dta", ///
	nogenerate update keep(master match match_update match_conflict) ///
	assert(using master match match_update)
replace gdp = gdp/index if (iso != "DD")
// For East Germany, the serie is already in real. We just change the base year.
quietly levelsof index if (year == 1991) & (iso == "DD"), local(index_ddr)
replace gdp = gdp/`index_ddr' if (iso == "DD")

// Add GDP from Maddison
merge 1:1 iso year using "$work_data/maddison-gdp.dta", ///
	nogenerate update assert(using master match)

// Remove Maddison when we have long-term WID data
replace gdp_maddison = . if inlist(iso, "US", "FR", "DE", "GB")

// Housekeeping
keep iso year currency gdp gdp_maddison *_src level_year

// Drop former countries after separation
drop if (iso == "CS") & (year > 1990)
drop if (iso == "SU") & (year > 1990)
drop if (iso == "YU") & (year > 1989)
drop if (iso == "YA") | (iso == "YD")

// GDP growth rates from Maddison
sort iso year
by iso: generate growth_other = log(gdp[_n + 1]) - log(gdp)
by iso: generate growth_maddison = log(gdp_maddison[_n + 1]) - log(gdp_maddison)

replace growth2_src = "Maddison (2007)" if (growth_other >= .) & (growth_maddison < .)
generate growth = cond(growth_other < ., -growth_other, -growth_maddison)

gsort iso -year
egen firstyear = first(year) if (gdp < .), by(iso)
replace growth = log(gdp) if (year == firstyear)
by iso: generate gdp2 = exp(sum(growth))

assert (gdp - gdp2)/gdp < 1e-3 if (gdp < .)

// Apply growth rates from Blanchet, Chancel & Gethin (2018) to expand East to 1980
preserve
	use "$wid_dir/Country-Updates/Europe/2019_03/europe-bcg2019-macro.dta", clear
	keep if inlist(iso,"SI","HR", "RS", "KS", "BA", "MK", "ME") ///
		| inlist(iso,"MD","EE","LT","LV","CZ","SK")
	gen gdp=agdp*npop
	bys iso (year): gen gr_bcg=gdp[_n+1]/gdp
	keep if year<1990
	keep iso year gr_bcg
	tempfile bcg
	save `bcg'
restore
merge m:m iso year using `bcg', nogen
gsort iso -year
by iso: replace gdp2=gdp2[_n-1]/gr_bcg if !mi(gr_bcg) & mi(gdp2)
replace growth2_src="Maddison (2007)" if !mi(gr_bcg)

// Check that there is no country with only Maddison data
egen hasmaddison = total(gdp_maddison < . | !mi(gr_bcg)), by(iso)
egen hasother = total(gdp < .), by(iso)
assert hasother if hasmaddison

replace gdp = gdp2 if (hasmaddison)
drop gdp2
keep if gdp < .

// Expand the currency
egen currency2 = mode(currency), by(iso)
drop currency
rename currency2 currency

keep iso year gdp growth2_src level_src level_year currency
rename growth2_src growth_src

// South Sudan should start from 2012
drop if iso == "SS" & year <2012


label data "Generated by calculate-gdp.do"
save "$work_data/gdp.dta", replace
