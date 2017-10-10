//Table G2
import excel "$uk_data/UK_WealthShares.xlsx", ///
	clear sheet("Table G2") cellrange(A8:M126)

rename A year
rename B pall
rename C p0p90
rename D p90p100
rename E p95p100
rename F p99p100
rename G p995p100
rename H p999p100
rename J p90p95
rename K p95p99
rename L p99p995
rename M p995p999
drop I

foreach x of var p*{
	rename `x' ahweal992i`x'
}
 
reshape long ahweal992i, i(year) j(p2) string

drop if missing(ahweal992i)

replace p2=subinstr(p2, "995", "99.5", .)
replace p2=subinstr(p2, "999", "99.9", .)

gen id=string(year, "%02.0f")+p2
sort p2 year

tempfile UKave
save "`UKave'",replace

//Table G1
clear
import excel "$uk_data/UK_WealthShares.xlsx", ///
	clear sheet("Table G1") cellrange(A8:M126)
	
rename A year
rename C p0p90
rename D p90p100
rename E p95p100
rename F p99p100
rename G p995p100
rename H p999p100
rename J p90p95
rename K p95p99
rename L p99p995
rename M p995p999
drop B I

foreach x of var p*{
	rename `x' shweal992i`x'
}

reshape long shweal992i, i(year) j(p2) string

drop if missing(shweal992i)

replace p2=subinstr(p2, "995", "99.5", .)
replace p2=subinstr(p2, "999", "99.9", .)

gen id=string(year, "%02.0f")+p2

//combine 
merge 1:1 id using "`UKave'", nogenerate

drop id

//
replace shweal992i=shweal992i/100

gen alpha2="GB"
order alpha2 

sort alpha2 p2 year
rename alpha2 iso
rename p2 p

foreach v of varlist shweal992i ahweal992i{
rename `v' value`v'
}
reshape long value, i(iso year p) j(widcode) string
drop if mi(value)

generate source = `"[URL][URL_LINK]http://wid.world/document/f-alvaredo-b-atkinson-s-morelli-2017-top-wealth-shares-uk-century-wid-world-working-paper/[/URL_LINK][URL_TEXT]"' ///
	+ `"Alvaredo, Facundo; Atkinson, Anthony B. and Morelli, Salvatore (2016). "' ///
	+ `"Top Wealth Shares in the UK over more than a century[/URL_TEXT][/URL]; "'
generate method = ""

gen author="alvaredo2017"

save "$uk_data/uk-wealth-alvaredo2017.dta", replace






