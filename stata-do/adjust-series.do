// -------------------------------------------------------------------------- //
// Distribute missing foreign incomes within the national economies
// -------------------------------------------------------------------------- //

use "$work_data/sna-series-finalized.dta", clear

merge 1:1 iso year using "$work_data/reinvested-earnings-portfolio.dta", nogenerate
// merge 1:1 iso year using "$work_data/wealth-tax-havens.dta", nogenerate update replace keepusing(nwgxa nwgxd ptfxa ptfxd fdixa fdixd)

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

// External wealth officially recorded and hidden in Tax Havens
generate nwnxa = nwgxa - nwgxd

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


// -------------------------------------------------------------------------- //
// Ensure that imputations do not distort net national income
// -------------------------------------------------------------------------- //
replace gdpro = 1 if missing(gdpro)
generate nninc = gdpro - confc + cond(missing(nnfin), 0, nnfin)

gen flagnninc = 1 if nninc < .5 & (flagpinrx == 1 | flagpinpx == 1) 
replace flagnninc = 0 if mi(flagnninc)
gen difnninc = .5 - nninc if flagnninc == 1 
gen sh_ptfrx_deb = ptfrx_deb/pinrx 
gen sh_ptfrx_eq = ptfrx_eq/pinrx 
gen sh_ptfrx_res = ptfrx_res/pinrx 
gen sh_fdirx = fdirx/pinrx 
replace ptfrx_deb = ptfrx_deb + sh_ptfrx_deb*difnninc if flagnninc == 1 
replace ptfrx_eq = ptfrx_eq + sh_ptfrx_eq*difnninc if flagnninc == 1 
replace ptfrx_res = ptfrx_res + sh_ptfrx_res*difnninc if flagnninc == 1 
replace fdirx = fdirx + sh_fdirx*difnninc if flagnninc == 1 
drop flagnninc difnninc sh_*

gen flagnninc = 1 if nninc > 1.5 & (flagpinrx == 1 | flagpinpx == 1) 
replace flagnninc = 0 if mi(flagnninc)
gen difnninc = nninc - 1.5 if flagnninc == 1 
gen sh_ptfpx = ptfpx/pinpx 
gen sh_fdipx = fdipx/pinpx 
replace ptfpx = ptfpx + sh_ptfpx*difnninc if flagnninc == 1 
replace fdipx = fdipx + sh_fdipx*difnninc if flagnninc == 1 
drop flagnninc difnninc sh_*
drop nninc 

replace ptfnx = ptfrx - ptfpx 
replace fdinx = fdirx - fdipx 
replace pinnx = fdinx + ptfnx
replace pinrx = fdirx + ptfrx 
replace pinpx = fdipx + ptfpx 

// -------------------------------------------------------------------------- //
// Ensure aggregate 0 for pinnx fdinx ptfnx nwnxa fdixn ptfxn comnx and taxnx
// -------------------------------------------------------------------------- //
ren (ptfrx_deb ptfrx_eq ptfrx_res ptfxa_deb ptfxa_eq ptfxa_res) (ptdrx pterx ptrrx ptdxa ptexa ptrxa)
ren (ptfpx_deb ptfpx_eq ptfxd_deb ptfxd_eq) (ptdpx ptepx ptdxd ptexd)
replace ptdxa = ptdxa + ptfxa_fin
replace ptdxd = ptdxd + ptfxd_fin
drop ptfxa_fin ptfxd_fin miss*

merge m:1 iso using "$work_data/country-codes-list-core.dta", nogen keepusing(corecountry TH) 
replace corecountry = 0 if year < 1970

merge 1:1 iso year using "$work_data/retropolate-gdp.dta", nogen keep(master matched)
merge 1:1 iso year using "$work_data/price-index.dta", nogen keep(master matched)
merge 1:1 iso year using "$work_data/USS-exchange-rates.dta", nogen keepusing(exrate_usd) keep(master matched)

foreach var in gdp {
gen `var'_idx = `var'*index
	gen `var'usd = `var'_idx/exrate_usd
}

foreach v in fdirx fdipx ptfrx ptfpx fdixa fdixd ptfxa ptfxd comrx compx ftaxx fsubx {  
	replace `v' = `v'*gdpusd 
	gen aux = abs(`v')
	bys year : egen tot`v' = total(`v') if corecountry == 1
	bys year : egen totaux`v' = total(aux) if corecountry == 1
	drop aux
}

gen totfdinx = totfdirx - totfdipx 
gen totptfnx = totptfrx - totptfpx 
gen totfdixn = totfdixa - totfdixd 
gen totptfxn = totptfxa - totptfxd 
gen totcomnx = totcomrx - totcompx
gen tottaxnx = totfsubx - totftaxx

gen ratio_fdirx = fdirx/totauxfdirx
gen ratio_fdipx = fdipx/totauxfdipx
replace fdirx = fdirx - totfdinx*ratio_fdirx if totfdinx < 0 & corecountry == 1 & fdirx > 0
replace fdirx = fdirx + totfdinx*ratio_fdirx if totfdinx < 0 & corecountry == 1 & fdirx < 0
replace fdipx = fdipx + totfdinx*ratio_fdipx if totfdinx > 0 & corecountry == 1 & fdipx > 0	
replace fdipx = fdipx - totfdinx*ratio_fdipx if totfdinx > 0 & corecountry == 1 & fdipx < 0	

gen ratio_ptfrx = ptfrx/totauxptfrx
gen ratio_ptfpx = ptfpx/totauxptfpx
replace ptfrx = ptfrx - totptfnx*ratio_ptfrx if totptfnx < 0 & corecountry == 1 & ptfrx > 0
replace ptfrx = ptfrx + totptfnx*ratio_ptfrx if totptfnx < 0 & corecountry == 1 & ptfrx < 0
replace ptfpx = ptfpx + totptfnx*ratio_ptfpx if totptfnx > 0 & corecountry == 1 & ptfpx > 0	
replace ptfpx = ptfpx - totptfnx*ratio_ptfpx if totptfnx > 0 & corecountry == 1 & ptfpx < 0	

gen ratio_fdixa = fdixa/totauxfdixa
gen ratio_fdixd = fdixd/totauxfdixd
replace fdixa = fdixa - totfdixn*ratio_fdixa if totfdixn < 0 & corecountry == 1 & fdixa > 0
replace fdixa = fdixa + totfdixn*ratio_fdixa if totfdixn < 0 & corecountry == 1 & fdixa < 0
replace fdixd = fdixd + totfdixn*ratio_fdixd if totfdixn > 0 & corecountry == 1 & fdixd > 0	
replace fdixd = fdixd - totfdixn*ratio_fdixd if totfdixn > 0 & corecountry == 1 & fdixd < 0	

gen ratio_ptfxa = ptfxa/totauxptfxa
gen ratio_ptfxd = ptfxd/totauxptfxd
replace ptfxa = ptfxa - totptfxn*ratio_ptfxa if totptfxn < 0 & corecountry == 1 & ptfxa > 0
replace ptfxa = ptfxa + totptfxn*ratio_ptfxa if totptfxn < 0 & corecountry == 1 & ptfxa < 0
replace ptfxd = ptfxd + totptfxn*ratio_ptfxd if totptfxn > 0 & corecountry == 1 & ptfxd > 0	
replace ptfxd = ptfxd - totptfxn*ratio_ptfxd if totptfxn > 0 & corecountry == 1 & ptfxd < 0	

gen ratio_comrx = comrx/totauxcomrx
gen ratio_compx = compx/totauxcompx
replace comrx = comrx - totcomnx*ratio_comrx if totcomnx < 0 & corecountry == 1 & comrx > 0
replace comrx = comrx + totcomnx*ratio_comrx if totcomnx < 0 & corecountry == 1 & comrx < 0
replace compx = compx + totcomnx*ratio_compx if totcomnx > 0 & corecountry == 1 & compx > 0	
replace compx = compx - totcomnx*ratio_compx if totcomnx > 0 & corecountry == 1 & compx < 0	

gen ratio_fsubx = fsubx/totfsubx
gen ratio_ftaxx = ftaxx/totftaxx
replace fsubx = fsubx - tottaxnx*ratio_fsubx if tottaxnx > 0 & corecountry == 1	
replace ftaxx = ftaxx + tottaxnx*ratio_ftaxx if tottaxnx < 0 & corecountry == 1		

*drop ptdxar ptdrxr
foreach v in fdirx fdipx ptfrx ptfpx fdixa fdixd ptfxa ptfxd comrx compx ftaxx fsubx {  
	replace `v' = `v'/gdpusd 
}

replace ptfnx = ptfrx - ptfpx 
replace fdinx = fdirx - fdipx 
replace pinnx = fdinx + ptfnx
replace pinrx = fdirx + ptfrx 
replace pinpx = fdipx + ptfpx 
replace comnx = comrx - compx 
replace taxnx = fsubx - ftaxx

gen ptfxn = ptfxa - ptfxd 
gen fdixn = fdixa - fdixd 
replace nwgxa = ptfxa + fdixa 
replace nwgxd = ptfxd + fdixd 
replace nwnxa = nwgxa - nwgxd 

	*rescaling 
	gen ratiocheck = (ptexa + ptdxa + ptrxa)/ptfxa
	foreach var in ptexa ptdxa ptrxa {
		replace `var' = `var'/ratiocheck if !mi(ratiocheck)
	} 
	drop ratiocheck 

	gen ratiocheck = (ptexd + ptdxd)/ptfxd
	foreach var in ptexd ptdxd {
		replace `var' = `var'/ratiocheck if !mi(ratiocheck)
	} 
	drop ratiocheck 

	gen ratiocheck = (pterx + ptdrx + ptrrx)/ptfrx
	foreach var in pterx ptdrx ptrrx {
		replace `var' = `var'/ratiocheck if !mi(ratiocheck)
	} 
	drop ratiocheck 

	gen ratiocheck = (ptepx + ptdpx)/ptfpx
	foreach var in ptepx ptdpx {
		replace `var' = `var'/ratiocheck if !mi(ratiocheck)
	} 
	drop ratiocheck 
	
	
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

replace nnfin = flcin + taxnx if corecountry == 1
	replace series_nnfin = -1 if mi(series_nnfin) & !mi(nnfin) & (series_flcin == -1 | series_taxnx == -1)
	replace series_nnfin = -2 if mi(series_nnfin) & !mi(nnfin) & (series_flcin == -2 | series_taxnx == -2)

*replace nnfin = pinnx if mi(nnfin)
drop ratio* tot* gdpusd corecountry gdp currency level_src level_year growth_src index exrate_usd flag*

// Remove useless variables
drop cap?? cag?? nsmnp

// Finally calculate net national income
replace gdpro = 1 if missing(gdpro)
generate nninc = gdpro - confc + cond(missing(nnfin), 0, nnfin)
generate ndpro = gdpro - confc
generate gninc = gdpro + cond(missing(nnfin), 0, nnfin)

save "$work_data/sna-series-adjusted.dta", replace
