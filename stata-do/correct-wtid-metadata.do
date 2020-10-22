// Identify "wealth" (actually, macro) and "income" (actually, micro) variables
import excel "$codes_dictionary", ///
	sheet("Wealth_Macro_Variables") cellrange(D4:D152) clear allstring
rename D widcode
replace widcode = subinstr(widcode, "*", "", 1)
replace widcode = substr(widcode, 2, 5) if strlen(widcode) == 6
generate type = "wealth"
tempfile types
save "`types'"

import excel "$codes_dictionary", ///
	sheet("Income_Macro_Variables") cellrange(D4:D137) clear allstring
rename D widcode
replace widcode = subinstr(widcode, "*", "", 1)
replace widcode = substr(widcode, 2, 5) if strlen(widcode) == 6
generate type = "wealth"
append using "`types'"
save "`types'", replace 

import excel "$codes_dictionary", ///
	sheet("Income_Distributed_Variables") cellrange(D4:D87) clear allstring
rename D widcode
replace widcode = subinstr(widcode, "*", "", 1)
replace widcode = substr(widcode, 2, 5) if strlen(widcode) == 6
generate type = "income"
append using "`types'"
save "`types'", replace

import excel "$codes_dictionary", ///
	sheet("Other_WTID") cellrange(B4:B123) clear allstring
rename B widcode
drop if widcode == ""
replace widcode = subinstr(widcode, "*", "", 1)
replace widcode = substr(widcode, 2, 5) if strlen(widcode) == 6
generate type = "income"
append using "`types'"
save "`types'", replace

// Remove duplicates: they create problems and serve no purpose
duplicates drop
duplicates tag widcode, generate(duplicate)
drop if duplicate
drop duplicate
save "`types'", replace

label data "Generated by correct-wtid-metadata.do"
use "$work_data/add-new-wid-codes-output-metadata.dta", clear

// Complete sources in Australia
replace source_income = "Atkinson, Anthony B. and Leigh, Andrew (2007). The Distribution " + ///
	"of Top Incomes in Australia; in Atkinson, A. B. and Piketty, T. (editors) Top " + ///
	"Incomes over the Twentieth Century. A Contrast Between Continental European " + ///
	"and English-Speaking Countries, Oxford University Press, chapter 7. " + ///
	"Burkhauser, Richard V. , Hahn, Markus H. and Wilkins, Roger (2013). " + ///
	"Measuring Top Incomes Using Tax Record Data: A Cautionary Tale from Australia. " + ///
	"NBER Working Paper No. 19121. Burkhauser, Richard V. , Hahn, Markus H. and Wilkins, " + ///
	"Roger (2015). Measuring top incomes using tax record data: a cautionary tale from " + ///
	"Australia. Journal of Economic Inequality, 13(2): 181-205. Series updated by Roger Wilkinson." if (iso == "AU")

sort iso sixlet source_income source_wealth

format source_income source_wealth method %80s

generate widcode = substr(sixlet, 2, 5)

merge n:1 widcode using "`types'", nogenerate keep(master match)
replace type = "income" if (widcode == "diinc")
replace type = "income" if substr(widcode, 1, 3) == "pop"
replace type = "income" if substr(widcode, 1, 3) == "tax"
replace type = "income" if substr(widcode, 1, 3) == "cpi"
replace type = "wealth" if substr(widcode, 1, 3) == "nyi"
replace type = "wealth" if (widcode == "nninc")
assert type != ""

// Extract source for inflation
generate source = "Global Financial Data" ///
	if strpos(method, "globalfinancialdata") & inlist(sixlet, "icpixx", "inyixx")
replace method = "" if inlist(sixlet, "icpixx", "inyixx")

replace source = strtrim(cond(type == "income", source_income, source_wealth)) if (source == "")
replace source = strtrim(source_wealth) if (source == "")
drop source_income source_wealth type widcode

format source method %80s
sort iso sixlet source

replace source = source + `"; "'

replace source = source + " Updated by Yang, “Regional DINA Update for Asia” (2020)" if strpos(sixlet, "fiinc") & inlist(iso, "ID", "SG", "TW")

replace method = "Tax units are: individuals aged 15+ minus married females " + ///
	"until 1969; individuals aged 15+ from 1970. Data before 1990 are based " + ///
	"on tabulated tax data, and the unit of analysis is the tax unit. In 1990 " + ///
	"and after, data are based on the Income Distribution Survey, the unit of " + ///
	"analysis is the individual aged 15 and over with non-zero incomes. " + ///
	"Excludes capital gains." if (iso == "FI") & inlist(sixlet, "sfiinc", "afiinc")

label data "Generated by correct-wtid-metadata.do"
save "$work_data/correct-wtid-metadata-output.dta", replace
