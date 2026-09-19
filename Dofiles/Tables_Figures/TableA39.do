
* Use clean data
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
drop age
drop edu*

* merge polygon level dataset
merge m:1 a7 using  "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keepusing(col1_colcode col2_colcode) nogen

* keep central tax collection neighborhoods
keep if tmt==1 | tmt==3

* Merge chars of first state collector
rename col1_colcode colcode
merge m:1 colcode using "${repldir}/Data/01_base/survey_data/collector_chars.dta", keepusing(age educ_yrs inc_mo) 
drop if _merge ==2
drop _merge
rename (age educ_yrs inc_mo) (age_col1 educ_yrs_col1 inc_mo_col1)
rename colcode col1_colcode

* Merge chars of second state collector
rename col2_colcode colcode
merge m:1 colcode using "${repldir}/Data/01_base/survey_data/collector_chars.dta", keepusing(age educ_yrs inc_mo) 
drop if _merge ==2
drop _merge
rename (age educ_yrs inc_mo) (age_col2 educ_yrs_col2 inc_mo_col2)
rename colcode col2_colcode

preserve 

use "${repldir}/Data/01_base/survey_data/collector_chars.dta", clear

su age, d
local median_age=`r(p50)'
su educ_yrs, d
local median_educ_yrs=`r(p50)'
su inc_mo, d
local median_inc_mo=`r(p50)'

restore 

forvalue i=1(1)2{
gen age_col`i'_am=(age_col`i'>`median_age') if age_col`i'!=.
gen educ_yrs_col`i'_am=(educ_yrs_col`i'>`median_educ_yrs') if educ_yrs_col`i'!=.
gen inc_mo_col`i'_am=(inc_mo_col`i'>`median_inc_mo') if inc_mo_col`i'!=.

}

* Summarize Categories
su *_am

* Comparison: pairs with similar age 

	* First measure: match in above vs below median years of education
	gen age_similar=0 if age_col1_am!=age_col2_am & age_col1_am!=. & age_col2_am!=.
	replace age_similar=1 if age_col1_am==age_col2_am & age_col1_am!=. & age_col2_am!=.

	* Second measure: difference in number of years of education
	gen age_dist=abs(age_col1-age_col2)

	* Control: average years of educ of the pair 
	egen average_age=rowmean(age_col1 age_col2)

* Comparison: pairs with similar education 

	* First measure: match in above vs below median years of education
	gen educ_similar=0 if educ_yrs_col1_am!=educ_yrs_col2_am & educ_yrs_col1!=. & educ_yrs_col2!=.
	replace educ_similar=1 if educ_yrs_col1_am==educ_yrs_col2_am & educ_yrs_col1!=. & educ_yrs_col2!=.

	* Second measure: difference in number of years of education
	gen educ_dist=abs(educ_yrs_col1-educ_yrs_col2)

	* Control: average years of educ of the pair 
	egen average_educ_yrs=rowmean(educ_yrs_col1 educ_yrs_col2)

* Comparison: pairs with similar income 

	* First measure: match in above vs below median years of education
	gen inc_mo_similar=0 if inc_mo_col1_am!=inc_mo_col2_am & inc_mo_col1_am!=. & inc_mo_col2_am!=.
	replace inc_mo_similar=1 if inc_mo_col1_am==inc_mo_col2_am & inc_mo_col1_am!=. & inc_mo_col2_am!=.

	* Second measure: difference in number of years of education
	gen inc_mo_dist=abs(inc_mo_col1-inc_mo_col2)

	* Control: average years of educ of the pair 
	egen average_inc_mo=rowmean(inc_mo_col1 inc_mo_col2)
	
collapse (mean) taxes_paid taxes_paid_amt (max) age_similar average_age  educ_similar average_educ_yrs inc_mo_similar average_inc_mo age_dist educ_dist inc_mo_dist stratum, by(a7)

eststo clear

eststo: reg taxes_paid age_similar average_age i.stratum, robust
eststo: reg taxes_paid educ_similar average_educ_yrs i.stratum i.stratum, robust 
eststo: reg taxes_paid inc_mo_similar average_inc_mo i.stratum, robust

eststo: reg taxes_paid age_dist average_age i.stratum, robust 
eststo: reg taxes_paid educ_dist average_educ_yrs i.stratum, robust
eststo: reg taxes_paid inc_mo_dist average_inc_mo i.stratum, robust 

eststo: reg taxes_paid_amt age_similar average_age i.stratum, robust 
eststo: reg taxes_paid_amt educ_similar average_educ_yrs i.stratum, robust 
eststo: reg taxes_paid_amt inc_mo_similar average_inc_mo i.stratum, robust

eststo: reg taxes_paid_amt age_dist average_age i.stratum i.stratum, robust
eststo: reg taxes_paid_amt educ_dist average_educ_yrs i.stratum, robust 
eststo: reg taxes_paid_amt inc_mo_dist average_inc_mo i.stratum, robust

esttab using "${reploutdir}/CvL_Teamwork_TeamComp_a7.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (age_similar educ_similar inc_mo_similar age_dist educ_dist inc_mo_dist) ///
order(age_similar educ_similar inc_mo_similar age_dist educ_dist inc_mo_dist) ///
nomtitles ///
mgroups("Tax Compliance - Similarity" "Tax Compliance - Distance" "Tax Revenue - Similarity" "Tax Revenue - Distance", pattern(1 0 0 1 0 0 1 0 0 1 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
indicate("Stratum FE = *stratum*") ///
star(* 0.10 ** 0.05 *** 0.001) ///
nogaps nonotes compress

