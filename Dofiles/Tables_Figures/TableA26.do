
*************
* Table A26 *
*************

	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
// CvL Compliance and revenues - Figures and Tables
		
	keep if tmt==1 | tmt==2 | tmt==3
	
	* Outcome
	g taxes_paid_carto = 0 if taxes_paid!=.
	replace taxes_paid_carto = 1 if collect_success==1
	
	g taxes_paid_amt_carto = amt_paid
	replace taxes_paid_amt_carto = 0 if taxes_paid_carto==0
	
	* Define FE
	sum today_alt
	local tdm_min = `r(min)'
	local tdm_max = `r(max)'+1
	
	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
	egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
	egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
	egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
	
	eststo clear
	label var t_l "Local"
	
	* No House FE - Compliance during Carto
	eststo: reg taxes_paid_carto t_l i.stratum if inlist(tmt,1,2), cl(a7)
	su taxes_paid_carto if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Normal - Compliance during Carto
	eststo: reg taxes_paid_carto t_l i.house i.stratum if inlist(tmt,1,2), cl(a7)
	su taxes_paid_carto if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance
	eststo: reg taxes_paid_carto t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
	su taxes_paid_carto if t_c==1 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* No House FE - Revenues
	eststo: reg taxes_paid_amt_carto t_l i.stratum if inlist(tmt,1,2), cl(a7)
	su taxes_paid_amt_carto if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Normal - Revenues
	eststo: reg taxes_paid_amt_carto t_l i.house i.stratum if inlist(tmt,1,2), cl(a7)
	su taxes_paid_amt_carto if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Revenues
	eststo: reg taxes_paid_amt_carto t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
	su taxes_paid_amt_carto if t_c==1 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	esttab using "${reploutdir}/pay_registration.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l) ///
	order(t_l) ///
	scalar(Clusters Mean) sfmt(0 3 3) ///
	nomtitles ///
	mgroups("Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Amount" "Tax Amount" "Tax Amount", pattern(1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	indicate("Month FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
