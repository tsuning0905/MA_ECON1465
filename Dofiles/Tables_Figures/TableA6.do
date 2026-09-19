
************
* Table A6 *
************

****************
* Prepare Data *
****************

use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes

levelsof rate
local i = 1
foreach r in `r(levels)'{
	g dum`i' = rate==`r'
	g t_lXdum`i' = t_l*dum`i'
	local i = `i'+1
}

g pct = 4 if pct_50==1
replace pct = 3 if pct_66==1
replace pct = 2 if pct_83==1
replace pct = 1 if pct_100==1

g bonus_typ = 1 if bonus_constant==1
replace bonus_typ = 2 if bonus_30pct==1

***********
* Panel A *
***********

	eststo clear
		
	* Month FE - Compliance - Preferred Spec
	eststo: reg taxes_paid t_l i.stratum i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - Preferred Spec + i.rate
	eststo: reg taxes_paid t_l i.stratum i.pct i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & rate!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - Preferred Spec + i.rate + interactions
	eststo: reg taxes_paid t_l i.stratum i.pct i.pct#t_l i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & rate!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - Preferred Spec + i.bonus
	eststo: reg taxes_paid t_l i.stratum i.bonus_typ i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & bonus_typ!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - Preferred Spec + i.bonus + interactions
	eststo: reg taxes_paid t_l i.stratum i.bonus_typ i.bonus_typ#t_l i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & bonus_typ!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - Preferred Spec + +i.rate + interactions + i.bonus + interactions
	eststo: reg taxes_paid t_l i.stratum i.pct i.pct#t_l i.bonus_typ i.bonus_typ#t_l i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & bonus_typ!=. & rate!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'

	
	esttab using "${reploutdir}/compl_results_saturated.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l) ///
	order(t_l) ///
	scalar(Clusters Mean) sfmt(0 3 3) ///
	nomtitles ///
	mgroups("Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance", pattern(1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	indicate("Time FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
	
***********
* Panel B *
***********
	
	eststo clear
	
	
	* Month FE - Compliance - Preferred Spec
	eststo: reg taxes_paid_amt t_l i.stratum i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - Preferred Spec + i.rate
	eststo: reg taxes_paid_amt t_l i.stratum i.pct i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=. & rate!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - Preferred Spec + i.rate + interactions
	eststo: reg taxes_paid_amt t_l i.stratum i.pct i.pct#t_l i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=. & rate!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - Preferred Spec + i.bonus
	eststo: reg taxes_paid_amt t_l i.stratum i.bonus_typ i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=. & bonus_typ!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - Preferred Spec + i.bonus + interactions
	eststo: reg taxes_paid_amt t_l i.stratum i.bonus_typ i.bonus_typ#t_l i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=. & bonus_typ!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - Preferred Spec + +i.rate + interactions + i.bonus + interactions
	eststo: reg taxes_paid_amt t_l i.stratum i.pct i.pct#t_l i.bonus_typ i.bonus_typ#t_l i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=. & bonus_typ!=. & rate!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'

	
	esttab using "${reploutdir}/rev_results_saturated.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l) ///
	order(t_l) ///
	scalar(Clusters Mean) sfmt(0 3 3) ///
	nomtitles ///
	mgroups("Revenues" "Revenues" "Revenues" "Revenues" "Revenues" "Revenues", pattern(1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	indicate("Time FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
