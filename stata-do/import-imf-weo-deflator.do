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
		rename `v' def_imf`year'
	}
}

keep if weosubjectcode == "NGDP_D"
drop iso weocountrycode weosubjectcode subjectdescriptor subjectnotes units ///
	scale countryseriesspecificnotes

/* 
replace country="Côte d'Ivoire" if country=="C�te d'Ivoire"
replace country="São Tomé and Príncipe" if country=="S�o Tom� and Pr�ncipe"
*/

replace country="Côte d'Ivoire" if country=="Cte d'Ivoire"
replace country="São Tomé and Príncipe" if country=="So Tom and Prncipe"

countrycode country, generate(iso) from("imf weo")
drop country


reshape long def_imf, i(iso) j(year)
drop if def_imf >= .

drop if year>$pastyear

rename def_imf def_weo

label data "Generated by import-imf-weo-deflator.do"
save "$work_data/imf-deflator-weo.dta", replace
