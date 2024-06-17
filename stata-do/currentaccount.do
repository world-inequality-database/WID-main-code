import delimited "$current_account/BOP_05-13-2024 14-41-48-35.csv", clear


//Keep Current accounts variables 

keep if inlist(indicatorcode, "BXIPCE_BP6_USD", "BMIPCE_BP6_USD", "BMCA_BP6_USD", "BXCA_BP6_USD") | ///
inlist(indicatorcode, "BXIPO_BP6_USD", "BMIPO_BP6_USD", "BXIS_BP6_USD", "BMIS_BP6_USD") | ///     
		inlist(indicatorcode, "BOP_BP6_USD","BMGS_BP6_USD", "BXGS_BP6_USD", "BKA_CD_BP6_USD", "BKA_DB_BP6_USD", "BKT_CD_BP6_USD", "BKT_DB_BP6_USD")
		
*Current Account, Primary Income, Compensation of Employees, Credit, US Dollars BXIPCE_BP6_USD 
*Current Account, Primary Income, Compensation of Employees, Debit, US Dollars BMIPCE_BP6_USD


*Current Account, Total, Debit, US Dollars	BMCA_BP6_USD
*Current Account, Total, Credit, US Dollars	BXCA_BP6_USD


*Current Account, Primary Income, Other Primary Income, Credit, US Dollars	BXIPO_BP6_USD
*Current Account, Primary Income, Other Primary Income, Debit, US Dollars	BMIPO_BP6_USD
*Current Account, Secondary Income, Credit, US Dollars	BXIS_BP6_USD
*Current Account, Secondary Income, Debit, US Dollars	BMIS_BP6_USD

*Net Errors and Omissions, US Dollars	BOP_BP6_USD
*Supplementary Items, Errors and Omissions (with Fund Record), US Dollars	BOPFR_BP6_USD

*BMGS_BP6_USD Current Account, Goods and Services, Debit, US Dollars
*BXGS_BP6_USD Current Account, Goods and Services, Credit, US Dollars
*BGS_BP6_USD Current Account, Goods and Services, Net, US Dollars

//Rename the variables

replace indicatorname = "trade_credit" if indicatorcode == "BXGS_BP6_USD"
replace indicatorname = "trade_debit" if indicatorcode == "BMGS_BP6_USD"
replace indicatorname = "compemp_debit" if indicatorcode == "BMIPCE_BP6_USD"
replace indicatorname = "compemp_credit" if indicatorcode == "BXIPCE_BP6_USD"
*replace indicatorname = "total_debit" if indicatorcode == "BMCA_BP6_USD"
*replace indicatorname = "total_credit" if indicatorcode == "BXCA_BP6_USD"
replace indicatorname = "otherpinc_credit" if indicatorcode == "BXIPO_BP6_USD"
replace indicatorname = "otherpinc_debit" if indicatorcode == "BMIPO_BP6_USD"
replace indicatorname = "secinc_credit" if indicatorcode == "BXIS_BP6_USD"
replace indicatorname = "secinc_debit" if indicatorcode == "BMIS_BP6_USD"
replace indicatorname = "errors_net" if indicatorcode == "BOP_BP6_USD"
replace indicatorname = "capital_credit" if indicatorcode == "BKA_CD_BP6_USD" | indicatorcode == "BKT_CD_BP6_USD"
replace indicatorname = "capital_debit" if indicatorcode == "BKA_DB_BP6_USD" | indicatorcode == "BKT_DB_BP6_USD"
collapse (sum) value, by(countryname countrycode indicatorname timeperiod)

ren timeperiod year
drop if countryname == "Australia" & missing(v) & (indicatorname == "capital_credit" | indicatorname == "capital_debit")

greshape wide v, i(countryname countrycode year) j(indicatorname) 

renpfix value

kountry countrycode, from(imfn) to(iso2c)
ren _ISO2C_ iso 

replace iso="AD" if countryname=="Andorra, Principality of"
replace iso="SS" if countryname=="South Sudan, Rep. of"
replace iso="TC" if countryname=="Turks and Caicos Islands"
replace iso="TV" if countryname=="Tuvalu"
replace iso="RS" if countryname=="Serbia, Rep. of"
replace iso="KV" if countryname=="Kosovo, Rep. of"
replace iso="CW" if countryname=="Curaçao, Kingdom of the Netherlands"
replace iso="SX" if countryname=="Sint Maarten, Kingdom of the Netherlands"
replace iso="PS" if countryname=="West Bank and Gaza"

drop if mi(iso)
drop countrycode

//Netherlands Antilles split

merge m:1 iso using "$work_data/ratioCWSX_AN.dta", nogen 

foreach v in compemp_credit compemp_debit otherpinc_credit /// total_debit total_credit errors_net
 otherpinc_debit secinc_credit secinc_debit  trade_credit trade_debit capital_credit capital_debit { 
bys year : gen aux`v' = `v' if iso == "AN" & year<2011
bys year : egen `v'AN = mode(aux`v')
}

foreach v in compemp_credit compemp_debit otherpinc_credit /// total_debit total_credit errors_net
 otherpinc_debit secinc_credit secinc_debit  trade_credit trade_debit capital_credit capital_debit { 
	foreach c in CW SX {
		replace `v' = `v'AN*ratio`c'_ANusd if iso == "`c'" & missing(`v')
	}
}	
drop aux* *AN *ANlcu

drop if mi(iso)

//Keep core countries only
merge 1:1 iso year using "$work_data/country-codes-list-core-year.dta", nogen 
keep if corecountry == 1

// merge with tradebalances 
merge 1:1 iso year using "$current_account/tradebalances.dta", nogen keepusing(tradebalance exports imports)

//	bring GDP in usd
merge 1:1 iso year using "$work_data/retropolate-gdp.dta", nogenerate keepusing(gdp) keep(master matched)
merge 1:1 iso year using "$work_data/USS-exchange-rates.dta", nogen keepusing(exrate_usd) keep(master matched)
merge 1:1 iso year using "$work_data/price-index.dta", nogen keep(master matched)

gen gdp_idx = gdp*index
	gen gdp_usd = gdp_idx/exrate_usd
drop gdp 	
sort iso year 
keep if inrange(year, 1970, $pastyear )

//Express all variables as share of GDP
foreach v in compemp_credit compemp_debit otherpinc_credit /// total_debit total_credit errors_net
 otherpinc_debit secinc_credit secinc_debit  trade_credit trade_debit exports imports tradebalance capital_credit capital_debit {
replace `v' = `v'/gdp_usd
}

// replacing trade balance when it's too big of a GDP share
/*
gen net_trade = trade_credit - trade_debit
replace tradebalance = . if tradebalance < - 1 & net_trade >= -1
replace tradebalance = . if tradebalance > 1 & !mi(tradebalance) & net_trade <= 1 
drop net_trade 
*/

//Interpolate missing values within the series 
foreach v in compemp_credit compemp_debit otherpinc_credit /// total_debit total_credit errors_net
 otherpinc_debit secinc_credit secinc_debit  trade_credit trade_debit capital_credit capital_debit  { 
	replace `v' =. if `v' == 0
	bys iso : egen tot`v' = total(abs(`v')), missing
	gen flagcountry`v' = 1 if tot`v' == .
	replace flagcountry`v' = 0 if missing(flagcountry`v')
	drop tot`v'
}

so iso year
foreach v in compemp_credit compemp_debit otherpinc_credit /// total_debit total_credit errors_net
 otherpinc_debit secinc_credit secinc_debit trade_credit trade_debit capital_credit capital_debit  { 
	by iso : ipolate `v' year if corecountry == 1 & flagcountry`v' == 0, gen(x`v') 
	replace `v' = x`v' if missing(`v') 
	drop x`v'
}

foreach level in undet un {
	kountry iso, from(iso2c) geo(`level')

replace GEO = "Western Asia" 	if iso == "AE" & "`level'" == "undet"
replace GEO = "Caribbean" 		if iso == "CW" & "`level'" == "undet"
replace GEO = "Caribbean"		if iso == "SX" & "`level'" == "undet"
replace GEO = "Caribbean" 		if iso == "BQ" & "`level'" == "undet"
replace GEO = "Southern Europe" if iso == "KS" & "`level'" == "undet"
replace GEO = "Southern Europe" if iso == "ME" & "`level'" == "undet"
replace GEO = "Eastern Asia" 	if iso == "TW" & "`level'" == "undet"
replace GEO = "Northern Europe" if iso == "GG" & "`level'" == "undet"
replace GEO = "Northern Europe" if iso == "JE" & "`level'" == "undet"
replace GEO = "Northern Europe" if iso == "IM" & "`level'" == "undet"

replace GEO = "Asia" if inlist(iso, "AE", "TW") & "`level'" == "un"
replace GEO = "Americas" if inlist(iso, "CW", "SX", "BQ") & "`level'" == "un"
replace GEO = "Europe" if inlist(iso, "KS", "ME", "GG", "JE", "IM") & "`level'" == "un"
ren GEO geo`level'
drop NAMES_STD 
}

gen soviet = 1 if inlist(iso, "AZ", "AM", "BY", "KG", "KZ", "GE") ///
				| inlist(iso, "TJ", "MD", "TM", "UA", "UZ") ///
				| inlist(iso, "EE", "LT", "LV", "RU", "SU")

gen yugosl = 1 if inlist(iso, "BA", "HR", "MK", "RS") ///
				| inlist(iso, "KS", "ME", "SI", "YU")

gen other = 1 if inlist(iso, "ER", "EH", "CS", "CZ", "SK", "SD", "SS", "TL") ///
			   | inlist(iso, "ID", "SX", "CW", "AN", "YE", "ZW", "IQ", "TW")
			   
//Carryforward 
foreach v in compemp_credit compemp_debit otherpinc_credit /// total_debit total_credit errors_net
 otherpinc_debit secinc_credit secinc_debit trade_credit trade_debit capital_credit capital_debit  { 
so iso year
by iso: carryforward `v' if corecountry == 1, replace 

gsort iso -year 
by iso: carryforward `v' if corecountry == 1, replace
}
*IQ has an absurd large amount because it's 2005, just after the war 
// we adjust it
gen aux = capital_credit if iso == "IQ" & year == 2007 
bys iso : egen aux2 = mode(aux)
replace capital_credit = aux2 if iso == "IQ" & year < 2005
drop aux*

*KW presents issues with too low value for secinc_credit due to the gulf war in 1991. we use the value in 1993 rather than 1992 to carrybackwards
gen aux = secinc_credit if iso == "KW" & year == 1993 
bys iso : egen aux2 = mode(aux)
replace secinc_credit = aux2 if iso == "KW" & year < 1992
drop aux*

/*
// Soviet, Yugoslavian and pre-communist China are assumed to earn/pay 0.001 of GDP
foreach v in compemp_credit compemp_debit total_debit total_credit otherpinc_credit ///
 otherpinc_debit secinc_credit secinc_debit errors_net trade_credit trade_debit { 
replace `v' = 0.001 if (soviet == 1 & year <= 1991)  | (yugosl == 1 & year <= 1991) | (iso == "CN" & year <= 1981) | (inlist(iso, "SK", "CZ") & year <= 1992)
}

// Cuba and North Korea will are assumed to earn/pay 0.001 of GDP
foreach v in compemp_credit compemp_debit total_debit total_credit otherpinc_credit ///
 otherpinc_debit secinc_credit secinc_debit errors_net trade_credit trade_debit {
replace `v'= 0.001 if iso == "CU" | iso=="KP"
}
*/
//Fill missing with regional averages for non-tax havens countries 
foreach v in compemp_credit compemp_debit otherpinc_credit ///  total_debit total_credit errors_net
 otherpinc_debit secinc_credit secinc_debit trade_credit trade_debit capital_credit capital_debit  { 
	
 foreach level in undet un {
		
  bys geo`level' year : egen av`level'`v' = mean(`v') if corecountry == 1 & TH == 0 

  }
replace `v' = avundet`v' if missing(`v') & flagcountry`v' == 1 
replace `v' = avun`v' if missing(`v') & flagcountry`v' == 1
}
drop av*
*issues with TL in other_pinc 
bys geoundet year : egen avundetotherpinc_credit = mean(otherpinc_credit) if corecountry == 1 & TH == 0 & iso != "TL" & flagcountryotherpinc_credit == 0
bys year : egen aux = mode(avundetotherpinc_credit)
replace otherpinc_credit = aux if flagcountryotherpinc_credit == 1 & geoundet == "South-Eastern Asia"
drop aux* 

*issues with KW in secinc 1991 
bys geoundet year : egen avundetsecinc_credit = mean(secinc_credit) if corecountry == 1 & TH == 0 & iso != "KW" & flagcountrysecinc_credit == 0 & year == 1991
bys year : egen aux = mode(avundetsecinc_credit)
replace secinc_credit = aux if flagcountrysecinc_credit == 1 & geoundet == "Western Asia" & year == 1991
drop aux* 

bys geoundet year : egen avundetsecinc_debit = mean(secinc_debit) if corecountry == 1 & TH == 0 & iso != "KW" & flagcountrysecinc_debit == 0 & year == 1991
bys year : egen aux = mode(avundetsecinc_debit)
replace secinc_debit = aux if flagcountrysecinc_debit == 1 & geoundet == "Western Asia" & year == 1991
drop aux* 
drop av*

*issues with NA in otherpinc 2009 onward 
bys geoundet year : egen avundetotherpinc_credit = mean(otherpinc_credit) if corecountry == 1 & TH == 0 & iso != "NA" & flagcountryotherpinc_credit == 0
bys year : egen aux = mode(avundetotherpinc_credit)
replace otherpinc_credit = aux if flagcountryotherpinc_credit == 1 & geoundet == "Southern Africa"
drop aux* 

bys geoundet year : egen avundetotherpinc_debit = mean(otherpinc_debit) if corecountry == 1 & TH == 0 & iso != "NA" & flagcountryotherpinc_debit == 0
bys year : egen aux = mode(avundetotherpinc_debit)
replace otherpinc_debit= aux if flagcountryotherpinc_debit == 1 & geoundet == "Southern Africa"
drop aux* 
drop av*

//Fill missing with TH average for TH
foreach v in compemp_credit compemp_debit otherpinc_credit /// total_debit total_credit errors_net
 otherpinc_debit secinc_credit secinc_debit trade_credit trade_debit capital_credit capital_debit  { 
	
bys year : egen av`v' = mean(`v') if corecountry == 1 & TH == 1 

replace `v' = av`v' if missing(`v') & flagcountry`v' == 1

}
drop av*

replace otherpinc_credit =. if year < 1991
replace otherpinc_debit =. if year < 1991

*allocating the difference proportionally
foreach v in compemp otherpinc secinc trade capital {
	replace `v'_credit = `v'_credit*gdp_usd
	replace `v'_debit = `v'_debit*gdp_usd
	gen net_`v' = `v'_credit - `v'_debit

	gen aux`v'_credit = abs(`v'_credit)
	gen aux`v'_debit = abs(`v'_debit)
	bys year : egen tot`v'_credit = total(aux`v'_credit)
	bys year : egen tot`v'_debit = total(aux`v'_debit)
}
drop aux*

gen totnet_compemp = totcompemp_credit - totcompemp_debit 
gen totnet_otherpinc = tototherpinc_credit - tototherpinc_debit 
gen totnet_secinc = totsecinc_credit - totsecinc_debit 
gen totnet_capital = totcapital_credit - totcapital_debit 

foreach v in compemp otherpinc secinc capital {
	gen ratio_`v'_credit = `v'_credit/tot`v'_credit
	gen ratio_`v'_debit = `v'_debit/tot`v'_debit
	
replace `v'_credit = `v'_credit - totnet_`v'*ratio_`v'_credit if totnet_`v' > 0	
replace `v'_debit = `v'_debit + totnet_`v'*ratio_`v'_debit if totnet_`v' < 0	
}
drop ratio* net* tot* 

foreach x in compemp otherpinc secinc capital {
	gen net_`x' = `x'_credit - `x'_debit
}

keep iso year exports imports tradebalance otherpinc_credit otherpinc_debit net_otherpinc secinc_credit secinc_debit net_secinc capital_credit capital_debit net_capital gdp_us

foreach v in otherpinc_credit otherpinc_debit net_otherpinc secinc_credit secinc_debit net_secinc capital_credit capital_debit net_capital {
	replace `v' = `v'/gdp_us
}
drop gdp_us

ren exports 			tbxrx
ren imports 			tbmpx
ren tradebalance 		tbnnx
*ren otherpinc_credit 	opirx
*ren otherpinc_debit 	opipx
*ren net_otherpinc 		opinx
ren secinc_credit 		scirx
ren secinc_debit 		scipx
ren net_secinc 			scinx
ren capital_credit 		fkarx
ren capital_debit 		fkapx
ren net_capital 		fkanx

save "$work_data/bop_currentacc.dta", replace

