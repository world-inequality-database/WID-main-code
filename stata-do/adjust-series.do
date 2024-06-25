// -------------------------------------------------------------------------- //
// Distribute missing foreign incomes within the national economies
// -------------------------------------------------------------------------- //

use "$work_data/sna-series-finalized.dta", clear

merge 1:1 iso year using "$work_data/income-tax-havens.dta", nogenerate
merge 1:1 iso year using "$work_data/reinvested-earnings-portfolio.dta", nogenerate
merge 1:1 iso year using "$work_data/wealth-tax-havens.dta", nogenerate update replace keepusing(nwgxa nwgxd nwoff ptfxa ptfxd fdixa fdixd)

// Foreign portfolio income officially recorded
generate ptfor = ptfrx
generate ptfop = ptfpx
generate ptfon = ptfnx

generate series_ptfor = series_ptfrx
generate series_ptfop = series_ptfpx
generate series_ptfon = series_ptfnx

generate series_ptfhr = -3
generate series_ptfrr = -3
generate series_ptfrp = -3
generate series_ptfrn = -3

// Foreign direct investment income officially recorded
generate fdior = fdirx
generate fdiop = fdipx
generate fdion = fdinx
merge 1:1 iso year using "$work_data/missing-profits-havens.dta", nogenerate replace update
replace fdimp = 0 if mi(fdimp)

generate series_fdior = series_fdirx
generate series_fdiop = series_fdipx
generate series_fdion = series_fdinx

generate series_fdimp = -3

*taking fdirx from missingprofits correction out of nninc
generate diff_fdirx = fdirx - fdiorx
replace diff_fdirx = 0 if mi(diff_fdirx)

// External wealth officially recorded and hidden in Tax Havens
replace nwgxa = nwgxa + nwoff 
generate nwnxa = nwgxa - nwgxd
replace ptfxa = ptfxa + nwoff

generate series_nwoff = -3

// Distribute missing property income from tax havens to housholds
foreach v of varlist ptfrx ptfnx pinrx pinnx flcir flcin finrx nnfin prpho prphn prgho prghn ///
	capho caphn cagho caghn priho prihn segho seghn secho sechn savho savhn sagho saghn fkpin {

	replace `v' = `v' + ptfhr if !missing(ptfhr)
}

// Distribute reinvested earnings on portfolio investment to
// non-financial corporations
foreach v of varlist ptfrx ptfnx pinrx pinnx flcir flcin finrx nnfin prpco prpnf prgco prgnf ///
	prico prinf segco segnf secco secnf fkpin {

	replace `v' = `v' + ptfrr if !missing(ptfrr)
}

foreach v of varlist ptfpx pinpx flcip finpx {
	replace `v' = `v' + ptfrp if !missing(ptfrp)
}

foreach v of varlist ptfnx pinnx flcin nnfin prpco prpnf prgco prgnf ///
	prico prinf segco segnf secco secnf fkpin {

	replace `v' = `v' - ptfrp if !missing(ptfrp)
}

// Distribute missing profits to non-financial corporations
 foreach v of varlist fdipx pinpx flcip finpx {
 	replace `v' = `v' + fdimp if !missing(fdimp)
 }

foreach v of varlist fdinx pinnx { // flcin nnfin prpco prpnf prgco prgnf /// prico prinf segco segnf secco secnf fkpin
	replace `v' = `v' - fdimp if !missing(fdimp)
}

replace pinnx = fdinx + ptfnx
replace pinrx = fdirx + ptfrx 
replace pinpx = fdipx + ptfpx 

// -------------------------------------------------------------------------- //
// Ensure aggregate 0 for comnx and taxnx
// -------------------------------------------------------------------------- //
merge m:1 iso using "$work_data/country-codes-list-core.dta", nogen keepusing(corecountry) 
replace corecountry = 0 if year < 1970

merge 1:1 iso year using "$work_data/retropolate-gdp.dta", nogen keep(master matched)
merge 1:1 iso year using "$work_data/price-index.dta", nogen keep(master matched)
merge 1:1 iso year using "$work_data/USS-exchange-rates.dta", nogen keepusing(exrate_usd) keep(master matched)

foreach var in gdp {
gen `var'_idx = `var'*index
	gen `var'usd = `var'_idx/exrate_usd
}

foreach v in comrx compx ftaxx fsubx { // comhn fkpin nmxho ptxgo
	replace `v' = `v'*gdpusd 
	gen aux = abs(`v')
	bys year : egen tot`v' = total(`v') if corecountry == 1
	bys year : egen totaux`v' = total(aux) if corecountry == 1
	drop aux
}
gen totcomnx = totcomrx - totcompx
gen tottaxnx = totfsubx - totftaxx

gen ratio_comrx = comrx/totauxcomrx
gen ratio_compx = compx/totauxcompx
replace comrx = comrx - totcomnx*ratio_comrx if totcomnx > 0 & corecountry == 1 & comrx > 0
replace comrx = comrx + totcomnx*ratio_comrx if totcomnx > 0 & corecountry == 1 & comrx < 0
replace compx = compx + totcomnx*ratio_compx if totcomnx < 0 & corecountry == 1 & compx > 0	
replace compx = compx - totcomnx*ratio_compx if totcomnx < 0 & corecountry == 1 & compx < 0	

gen ratio_fsubx = fsubx/totfsubx
gen ratio_ftaxx = ftaxx/totftaxx
replace fsubx = fsubx - tottaxnx*ratio_fsubx if tottaxnx > 0 & corecountry == 1	
replace ftaxx = ftaxx + tottaxnx*ratio_ftaxx if tottaxnx < 0 & corecountry == 1		

replace comnx = comrx - compx 
replace taxnx = fsubx - ftaxx

foreach v in comrx compx comnx fsubx ftaxx taxnx {
	replace `v' = `v'/gdpusd 
}

replace comnx = comrx - compx if corecountry == 1
	replace series_comnx = -1 if mi(series_comnx) & !mi(comnx) & (series_comrx == -1 | series_compx == -1)
	replace series_comnx = -2 if mi(series_comnx) & !mi(comnx) & (series_comrx == -2 | series_compx == -2)
	
replace flcir = comrx + pinrx if corecountry == 1
	replace series_flcir = -1 if mi(series_flcir) & !mi(flcir) & (series_comrx == -1 | series_pinrx == -1)
	replace series_flcir = -2 if mi(series_flcir) & !mi(flcir) & (series_comrx == -2 | series_pinrx == -2)
	
replace flcip = compx + pinpx if corecountry == 1
	replace series_flcip = -1 if mi(series_flcip) & !mi(flcip) & (series_compx == -1 | series_pinpx == -1)
	replace series_flcip = -2 if mi(series_flcip) & !mi(flcip) & (series_compx == -2 | series_pinpx == -2)
	
replace flcin = flcir - flcip if corecountry == 1
	replace series_flcin = -1 if mi(series_flcin) & !mi(flcin) & (series_flcir == -1 | series_flcip == -1)
	replace series_flcin = -2 if mi(series_flcin) & !mi(flcin) & (series_flcir == -2 | series_flcip == -2)
	
replace finrx = comrx + pinrx + fsubx if corecountry == 1
	replace series_finrx = -1 if mi(series_finrx) & !mi(finrx) & (series_comrx == -1 | series_pinrx == -1 | series_fsubx == -1)
	replace series_finrx = -2 if mi(series_finrx) & !mi(finrx) & (series_comrx == -2 | series_pinrx == -2 | series_fsubx == -2)
	
replace finpx = compx + pinpx + ftaxx if corecountry == 1
	replace series_finpx = -1 if mi(series_finpx) & !mi(finpx) & (series_compx == -1 | series_pinpx == -1 | series_ftaxx == -1)
	replace series_finpx = -2 if mi(series_finpx) & !mi(finpx) & (series_compx == -2 | series_pinpx == -2 | series_ftaxx == -2)

replace taxnx = fsubx - ftaxx if corecountry == 1
	replace series_taxnx = -1 if mi(series_taxnx) & !mi(taxnx) & (series_ftaxx == -1 | series_flcip == -1)
	replace series_taxnx = -2 if mi(series_taxnx) & !mi(taxnx) & (series_ftaxx == -2 | series_flcip == -2)

replace nnfin = flcin + taxnx + fdimp if corecountry == 1
	replace series_nnfin = -1 if mi(series_nnfin) & !mi(nnfin) & (series_flcin == -1 | series_taxnx == -1)
	replace series_nnfin = -2 if mi(series_nnfin) & !mi(nnfin) & (series_flcin == -2 | series_taxnx == -2)

*replace nnfin = pinnx if mi(nnfin)
drop ratio* tot* gdpusd corecountry gdp currency level_src level_year growth_src index exrate_usd

// Remove useless variables
drop cap?? cag?? nsmnp

// Finally calculate net national income
replace gdpro = 1 if missing(gdpro)
generate nninc = gdpro - confc + cond(missing(nnfin), 0, nnfin)
replace nninc = nninc - diff_fdirx if iso == "KY" & year >= 2016
generate ndpro = gdpro - confc
generate gninc = gdpro + cond(missing(nnfin), 0, nnfin)

drop diff_fdirx 

save "$work_data/sna-series-adjusted.dta", replace
