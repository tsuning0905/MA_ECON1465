
********************************************************************************
****************** How much Information do City Chiefs have? *******************
********************************************************************************

* Chief's Information about citizens
use "${repldir}/Data/01_base/survey_data/chief_knowledge.dta", clear
keep a7 person*
forvalue i=1(1)15{
rename person`i'_need person_need`i'
rename person`i'_edu person_edu`i'
rename person`i'_job person_job`i'
rename person`i'_realname person_realname`i'
rename person`i'_showname person_showname`i'
rename person`i'_know person_know`i'
}
reshape long person_need person_edu person_job person_realname person_showname person_know, i(a7) j(photo_num)
tempfile chief_goods
save `chief_goods'

* Info on respondents 
forvalue i=1(1)15{
insheet using "${repldir}/Data/01_base/survey_data/resident_info_quiz.csv", clear
keep a7 photo`i'
replace photo`i'=subinstr(photo`i',"."," ",.)
rename photo`i' photo
split photo
drop photo photo2
rename photo1 photo
destring photo, replace force
gen photo_num=`i'
tempfile obs_`i'
save `obs_`i''
}
use `obs_1', clear
forvalue i=1(1)15{
append using `obs_`i''
}
duplicates drop
rename photo code
tempfile photos_all
save `photos_all'

* Baseline survey
u "${repldir}/Data/01_base/survey_data/baseline_noPII.dta",clear
keep if tot_complete==1 
keep code edu job1 
tempfile baseline
save `baseline'

* merge
use `photos_all', clear
merge 1:1 a7 photo_num using `chief_goods', nogen
drop if code==. 
merge 1:1 code using `baseline'
drop photo_num _merge

* Knows Name
gen name_knows= person_realname
replace name_knows=0 if person_know==0

* knows Education
replace edu=. if edu==888
gen edu_knows=0 if edu!=. 
replace edu_knows=1 if edu==person_edu

* Knows job
gen job_knows=0 if job1!=. 
replace job_knows=1 if job1==person_job

* Generate knowledge index
	global L_knows = "name_knows edu_knows job_knows"
		
		foreach index in L_knows{ 
		foreach var in $`index'{
		cap replace `var' = `var'_orig
		cap gen `var'_orig = `var'
		sum `var'
		replace `var' = (`var'-`r(mean)')/(`r(sd)') //standardize
		}
		egen `index' = rowtotal($`index'), missing
		sum `index'
		replace `index' = (`index' -`r(mean)')/(`r(sd)')  //standardize index
		}
 
		foreach var in L_knows{
		sum `var', d
		g `var'_norm = (`var'-`r(min)')/(`r(max)'-`r(min)') //normalize variables
		}

collapse (mean) name_knows edu_knows job_knows L_knows L_knows_norm , by(a7) 



tempfile	chief_info
save `chief_info'

********************************************************************************
*************** City Chiefs' Information and Collection in L? ****************
********************************************************************************

use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
keep if tmt==2
replace house=0 if house==1 
replace house=1 if house==2
collapse (mean) taxes_paid visit_post_carto stratum house (rawsum) taxes_paid_amt, by(a7)

* merge with chief knowledge
merge m:1 a7 using "`chief_info'", keep(match)

* Figure A7 - Panel A 
binscatter visit_post_carto L_knows_norm, n(20) yscale(range(0 0.8)) ylab(0(0.2)0.8) ytitle("% of Citizens Visited") xtitle("% Knowledge Index (Normalized)") graphregion(fcolor(white)) plotregion(color(white)) 
graph export "$reploutdir/visits_chefknowindex_L_binned.pdf", replace

* Figure A7 - Panel B
binscatter taxes_paid L_knows_norm, n(20) yscale(range(0 0.2)) ylab(0(0.05)0.2)  ytitle("% of Taxpayers") xtitle("% Knowledge Index (Normalized)") graphregion(fcolor(white)) plotregion(color(white)) 
graph export "$reploutdir/taxes_paid_chefknowindex_L_binned.pdf", replace

********************************************************************************
*************** City Chiefs' Information and Collection in CwI? ****************
********************************************************************************

use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
keep if tmt==3
collapse (mean) taxes_paid visit_post_carto stratum  (rawsum) taxes_paid_amt , by(a7)

* merge with chief knowledge
merge m:1 a7 using "`chief_info'", keep(match)

* Figure A7 - Panel C 
binscatter visit_post_carto L_knows_norm, n(20) yscale(range(0 0.8)) ylab(0(0.2)0.8)  ytitle("% of Citizens Visited") xtitle("% Knowledge Index (Normalized)") graphregion(fcolor(white)) plotregion(color(white)) 
graph export "$reploutdir/visits_chefknowindex_CwI_binned.pdf", replace

* Figure A7 - Panel D
binscatter taxes_paid L_knows_norm, n(20) yscale(range(0 0.2)) ylab(0(0.05)0.2) ytitle("% of Taxpayers") xtitle("% Knowledge Index (Normalized)") graphregion(fcolor(white)) plotregion(color(white)) 
graph export "$reploutdir/taxes_paid_chefknowindex_CwI_binned.pdf", replace

********************************************************************************
*************** City Chiefs' Information and Collection in C? ****************
********************************************************************************

use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
keep if tmt==1
replace house=0 if house==1 
replace house=1 if house==2
collapse (mean) taxes_paid visit_post_carto stratum house (rawsum) taxes_paid_amt, by(a7)

* merge with chief knowledge
merge m:1 a7 using "`chief_info'", keep(match)

* Figure A7 - Panel E
binscatter taxes_paid L_knows_norm, n(20) yscale(range(0 0.2)) ylab(0(0.05)0.2)  ytitle("% of Taxpayers") xtitle("% Knowledge Index (Normalized)") graphregion(fcolor(white)) plotregion(color(white)) 
graph export "$reploutdir/taxes_paid_chefknowindex_C_binned.pdf", replace

* Figure A7 - Panel F
binscatter visit_post_carto L_knows_norm, n(20) yscale(range(0 0.8)) ylab(0(0.2)0.8)  ytitle("% of Citizens Visited") xtitle("% Knowledge Index (Normalized)") graphregion(fcolor(white)) plotregion(color(white)) 
graph export "$reploutdir/visits_chefknowindex_C_binned.pdf", replace

**************************************************
*************** Regression Table  ****************
**************************************************

eststo clear

* CLI
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
keep if tmt==3
collapse (mean) taxes_paid visit_post_carto stratum  (rawsum) taxes_paid_amt , by(a7)

* merge with chief knowledge
merge m:1 a7 using "`chief_info'", keep(match)

xtile med_L_knows_norm=L_knows_norm, n(2)
replace med_L_knows_norm=0 if med_L_knows_norm==1
replace med_L_knows_norm=1 if med_L_knows_norm==2

eststo: reg visit_post_carto  med_L_knows_norm, robust
su visit_post_carto 
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	
eststo: reg taxes_paid  med_L_knows_norm, robust
su taxes_paid 
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	
* Central
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
keep if tmt==1
collapse (mean) taxes_paid visit_post_carto stratum  (rawsum) taxes_paid_amt , by(a7)

* merge with chief knowledge
merge m:1 a7 using "`chief_info'", keep(match)

xtile med_L_knows_norm=L_knows_norm, n(2)
replace med_L_knows_norm=0 if med_L_knows_norm==1
replace med_L_knows_norm=1 if med_L_knows_norm==2


eststo: reg visit_post_carto  med_L_knows_norm, robust
su visit_post_carto 
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	
eststo: reg taxes_paid  med_L_knows_norm, robust
su taxes_paid 
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'

* Local
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
keep if tmt==2
collapse (mean) taxes_paid visit_post_carto stratum  (rawsum) taxes_paid_amt , by(a7)

* merge with chief knowledge
merge m:1 a7 using "`chief_info'", keep(match)

xtile med_L_knows_norm=L_knows_norm, n(2)
replace med_L_knows_norm=0 if med_L_knows_norm==1
replace med_L_knows_norm=1 if med_L_knows_norm==2

eststo: reg visit_post_carto  med_L_knows_norm, robust
su visit_post_carto 
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	
eststo: reg taxes_paid  med_L_knows_norm, robust
su taxes_paid 
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'

	label var med_L_knows_norm "Chief Info Above Median"
	
	esttab using "${reploutdir}/tablechefknowindex.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (med_L_knows_norm) ///
	order(med_L_knows_norm) ///
	scalar(Clusters Mean) sfmt(0 3 3) ///
	nomtitles ///
	mgroups("CLI" "Central" "Local", pattern(1 0 1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
