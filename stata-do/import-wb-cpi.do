import delimited "$wb_data/cpi/API_FP.CPI.TOTL_DS2_en_csv_v2_$pastyear.csv", ///
	rowrange(3) varnames(4) clear encoding("utf8")
	
cap dropmiss
cap dropmiss, force

foreach v of varlist v*{
	local year: var label `v'
	if ("`year'" == "") {
		drop `v'
	}
	else {
		rename `v' year`year'
	}
}

drop indicatorname indicatorcode

reshape long year, i(countryname countrycode) j(j)
rename year value
rename j year

// Identify countries
replace countryname = "Macedonia, FYR" if countryname == "North Macedonia"
replace countryname = "Swaziland"      if countryname == "Eswatini"
replace countryname = "Korea, Dem. People's Rep." if countryname == "Korea, Dem. People’s Rep."
replace countryname = "Vietnam" if countryname == "Viet Nam"
countrycode countryname, generate(iso) from("wb")
drop countrycode

// Add currency from the metadata
merge n:1 countryname using "$work_data/wb-metadata.dta", ///
	keep(master match)  nogenerate keepusing(currency) // Regions are dropped
drop countryname
	
// Identify currencies
replace currency = "turkmenistan manat" if currency == "New Turkmen manat"
replace currency = "u.s. dollar" if currency == "Liberian dollar"

currencycode currency, generate(currency_iso) iso2c(iso) from("wb")
drop currency
rename currency_iso currency

keep if value < .
rename value cpi_wb

label data "Generated by import-wb-cpi.do"
save "$work_data/wb-cpi.dta", replace
