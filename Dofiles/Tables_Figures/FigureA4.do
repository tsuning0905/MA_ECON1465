clear
set more off

global user = "augy"

if "$user"=="augy" {
	global root "/Users/augustinbergeron/Dropbox/Taxes 2/Stata"
	global output "/Users/augustinbergeron/Dropbox/Taxes 2/Writing/Papers/CvL Paper/output"
}

********************************************************************************
********************* State Collectors - Panels A, C, and E ********************
********************************************************************************

*************************************
* State Collectors' Characteristics *
*************************************

* Clean Data
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* merge collector code information from polygon level dataset
merge m:1 a7 using "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match)

* state collector code
levelsof col1_colcode if tmt==1 | tmt==3 | tmt==4, local(col1)
levelsof col2_colcode if tmt==1 | tmt==3 , local(col2)
local col: list col1| col2
	
* Keep characteristics of all state collectors
foreach c of local col{
use "${repldir}/Data/01_base/survey_data/collector_baseline_noPII.dta", clear
keep if tot_complete == 1
keep if col_type==1 & colcode==`c'
tempfile col_`c'
save `col_`c''
}
foreach c of local col{
append using `col_`c''
}
duplicates drop
drop code 
		
* Education variables
gen educ_lvl=y9 
gen educ_yrs=3+y10 if educ_lvl==2
replace educ_yrs=3+6+y10 if educ_lvl==3 
replace educ_yrs=3+12+y10 if educ_lvl==4

* Number of possessions (moto, voiture, radio, TV, generator, sewing machine)
egen possessions_nb=rowtotal(possessions_1 possessions_2 possessions_3 possessions_4 possessions_5 possessions_6)
							
* colcode 
gen col1_colcode=colcode
gen col2_colcode=colcode
		
* Tempfile
tempfile state_col
save `state_col'

******************************************************************
* Marge Administrative Data with State Collector Characteristics *
******************************************************************

* Clean Data
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* merge with collector code and characteristics
merge m:1 a7 using "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match)
keep if tmt==1
cap drop _merge
merge m:1 col1_colcode using `state_col', force keepusing(educ_yrs educ_lvl possessions_nb)
rename (educ_yrs educ_lvl possessions_nb) (educ_yrs_col1 educ_lvl_col1 possessions_nb_col1)
drop _merge
merge m:1 col2_colcode using `state_col', force keepusing(educ_yrs educ_lvl possessions_nb)
rename (educ_yrs educ_lvl possessions_nb) (educ_yrs_col2 educ_lvl_col2 possessions_nb_col2)
drop _merge
egen educ_yrs=rowmean(educ_yrs_col1 educ_yrs_col2)
egen educ_lvl=rowmean(educ_lvl_col1 educ_lvl_col2)
egen possessions_nb=rowmean(possessions_nb_col1 possessions_nb_col2)

* Collapse dataset at the neighborhood level
collapse (mean) taxes_paid possessions_nb educ_lvl educ_yrs, by(a7) 

***********
* Figures *
***********

	* Figure A4 - Panel A
	reg taxes_paid educ_lvl
	local coef = round(_b[educ_lvl], .0001)
	local se = round(_se[educ_lvl], .0001)
	twoway (scatter taxes_paid educ_lvl) (lfit taxes_paid educ_lvl), ///
	graphregion(fcolor(white)) plotregion(color(white)) ///
	ytitle("% of Taxpayers") xtitle("Collector's Education Level") legend(off) ///
	note("Slope = `coef', SE = `se'" ) 
	graph export "$reploutdir/taxes_paid_DGRKOC_educ_lvl.pdf", replace

	* Figure A4 - Panel C
	reg taxes_paid educ_yrs
	local coef = round(_b[educ_yrs], .0001)
	local se = round(_se[educ_yrs], .0001)
	twoway (scatter taxes_paid educ_yrs) (lfit taxes_paid educ_yrs), ///
	graphregion(fcolor(white)) plotregion(color(white)) ///
	ytitle("% of Taxpayers") xtitle("Collector's Years of Education ") legend(off) ///
	note("Slope = `coef', SE = `se'" ) 
	graph export "$reploutdir/taxes_paid_DGRKOC_educ_yrs.pdf", replace
	
	* Figure A4 - Panel E
	reg taxes_paid possessions_nb
	local coef = round(_b[possessions_nb], .0001)
	local se = round(_se[possessions_nb], .0001)
	twoway (scatter taxes_paid possessions_nb) (lfit taxes_paid possessions_nb), ///
	graphregion(fcolor(white)) plotregion(color(white)) ///
	ytitle("% of Taxpayers") xtitle("Collector's Possessions") legend(off) ///
	note("Slope = `coef', SE = `se'" ) 
	graph export "$reploutdir/taxes_paid_DGRKOC_possessions_nb.pdf", replace

********************************************************************************
********************** Chief Collectors - Panels B, D, F ***********************
********************************************************************************

*************************************
* Chief Collectors' Characteristics *
*************************************

* Clean Data
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* merge collector code information from neighborhood level dataset
merge m:1 a7 using "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match) nogen

* chief collector code
levelsof col1_chef_code if tmt==2, local(chef1)
levelsof col2_chef_code if tmt==2 | tmt==4, local(chef2)
local chef: list chef1| chef2

* Keep characteristics of all chiefs collectors
foreach c of local chef{
use "${repldir}/Data/01_base/survey_data/collector_baseline_noPII.dta", clear
keep if tot_complete == 1
keep if col_type==2 & chef_code==`c'
tempfile chef_`c'
save `chef_`c''
}	
	
* Append 
use `chef_60920132'
foreach c of local chef{
append using `chef_`c''
}
duplicates drop
drop code 
rename chef_code code

* merge missing info from chief collector survey: education and possessions
merge 1:1 code using "${repldir}/Data/01_base/survey_data/chief_survey_noPII.dta", ///
keepusing(edu edu2 possessions_1 possessions_2 possessions_3 possessions_4 possessions_5 possessions_6 possessions_0) update replace 
keep if _merge>2
	
* Education variables
gen educ_lvl=y9 
replace educ_lvl=edu if educ_lvl==. & edu!=.
		
gen educ_yrs=3+y10 if educ_lvl==2
replace educ_yrs=3+6+y10 if educ_lvl==3 
replace educ_yrs=3+12+y10 if educ_lvl==4
		
replace educ_yrs=3+edu2 if educ_lvl==2 & educ_yrs==. & edu2!=.
replace educ_yrs=3+6+edu2 if educ_lvl==3 & educ_yrs==. & edu2!=.
replace educ_yrs=3+12+edu2 if educ_lvl==4 & educ_yrs==. & edu2!=.

* Number of possessions (moto, voiture, radio, TV, generator, sewing machine)
egen possessions_nb=rowtotal(possessions_1 possessions_2 possessions_3 possessions_4 possessions_5 possessions_6)

* Tempfile
tempfile chief_col
save `chief_col'
	
	* Local Collectors
	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
	* merge collector information from polygon level dataset
	merge m:1 a7 using "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match)
	keep if tmt==2
	cap drop _merge
	gen chief_code=col1_chef_code if tmt==2
	replace chief_code=col2_chef_code if tmt==4
	cap drop code
	rename chief_code code
	merge m:1 code using `chief_col', force nogen
	
	*Merge chief knowledge information (from knowledge test)
	cap drop _m
	merge m:1 a7 using "${repldir}/Data/01_base/survey_data/chief_knowledge_neighborhoods.dta", nogen keep(1 3)

	* Collpase at the neighborhood level 
	collapse (mean) taxes_paid  possessions_nb educ_lvl educ_yrs, by(a7) 
	drop if a7==.
	
	***********
	* Figures *
	***********	

	* Figure A4 - Panel B
	reg taxes_paid educ_lvl
	local coef = round(_b[educ_lvl], .0001)
	local se = round(_se[educ_lvl], .0001)
	twoway (scatter taxes_paid educ_lvl) (lfit taxes_paid educ_lvl), ///
	graphregion(fcolor(white)) plotregion(color(white)) ///
	ytitle("% of Taxpayers") xtitle("Collector's Education Level") legend(off)  ///
	note("Slope = `coef', SE = `se'" )
	graph export "$reploutdir/taxes_paid_chief_educ_lvl.pdf", replace

	* Figure A4 - Panel D
	reg taxes_paid educ_yrs
	local coef = round(_b[educ_yrs], .0001)
	local se = round(_se[educ_yrs], .0001)
	twoway (scatter taxes_paid educ_yrs) (lfit taxes_paid educ_yrs), ///
	graphregion(fcolor(white)) plotregion(color(white)) ///
	ytitle("% of Taxpayers") xtitle("Collector's Years of Education ") legend(off) ///
	note("Slope = `coef', SE = `se'" )
	graph export "$reploutdir/taxes_paid_chief_educ_yrs.pdf", replace
	
	* Figure A4 - Panel F
	reg taxes_paid possessions_nb
	local coef = round(_b[possessions_nb], .0001)
	local se = round(_se[possessions_nb], .0001)
	twoway (scatter taxes_paid possessions_nb) (lfit taxes_paid possessions_nb), ///
	graphregion(fcolor(white)) plotregion(color(white)) ///
	ytitle("% of Taxpayers") xtitle("Collector's Possessions") legend(off) ///
	note("Slope = `coef', SE = `se'" )
	graph export "$reploutdir/taxes_paid_chief_possessions_nb.pdf", replace
	
