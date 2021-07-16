import delimited "$imf_data/world-economic-outlook/WEO-$pastyear.csv", ///
	clear delimiter(";") varnames(1) encoding("utf8")

dropmiss, obs force

foreach v of varlist v* {
	local year: var label `v'
	if ("`year'" == "") {
		drop `v'
	}
	else {
		destring `v', replace force ignore(",")
		rename `v' value`year'
	}
}

keep if weosubjectcode == "NGDP" | weosubjectcode == "PPPEX"
drop iso weocountrycode subjectdescriptor units ///
	scale countryseriesspecificnotes
/**/ 
replace country = "Côte d'Ivoire"         if country == "C�te d'Ivoire"
replace country = "São Tomé and Príncipe" if country == "S�o Tom� and Pr�ncipe"
/**/ 
/*
replace country="Côte d'Ivoire"         if country=="Cte d'Ivoire"
replace country="São Tomé and Príncipe" if country=="So Tom and Prncipe"
*/
replace country = "Swaziland"             if country == "Eswatini"


countrycode country, generate(iso) from("imf weo")
drop country

reshape long value, i(iso weosubjectcode) j(year)
reshape wide value, i(iso year) j(weosubjectcode) string

// Zimbabwe: IMF moved to RTGS dollars unlike other databases: convert back to USD
replace valueNGDP = valueNGDP/valuePPPEX if iso == "ZW"
drop valuePPPEX


drop if value >= .

qui sum estimatesstartafter
drop if year > `r(max)'

replace value = value*1e9
rename value gdp_lcu_weo

*drop if year==$year // we are taking 2021 estimates

label data "Generated by import-imf-weo-gdp.do"
save "$work_data/imf-weo-gdp.dta", replace
