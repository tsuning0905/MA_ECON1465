
****************************
* Figure A18 and Table A38 *
****************************

	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
	keep if tmt==1 | tmt==2 | tmt==4
	
	cap drop visit_post_carto
	gen visit_post_carto=0 if visited==0 | (visits!=0 & visits!=.)
	replace visit_post_carto=1 if visits!=. & visits>1
	
	cap drop nb_visit_post_carto
	gen nb_visit_post_carto=0 if visits!=. | visited==0
	replace nb_visit_post_carto=visits-1 if visits!=. & visits>1
	replace nb_visit_post_carto=. if nb_visit_post_carto==99998
	replace nb_visit_post_carto = . if visit_post_carto==.

	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21365.5 21425.5 21485.5 21515.5) icodes
	egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.3 21423.33 21483.3 21520) icodes
	egen time_FE_tdm_2mo_CvCXL = cut(today_alt),at(21358.5 21418.5 21478.5 21531.5) icodes
	egen time_FE_tdm_2mo_CvLvCXL = cut(today_alt),at(21359 21419 21479 21532.66) icodes

**************
* Figure A18 *
**************

		sort tmt today_alt
	
		preserve
			keep if today_alt>=21363.3 & today_alt<=21520
			collapse (mean) taxes_paid (count) n = taxes_paid,by(tmt today_alt)
			drop if taxes_paid>0.25
			twoway (scatter taxes_paid today_alt if tmt==1 [fweight=n],mc(gray*0.25)) ///
			(scatter taxes_paid today_alt if tmt==2  [fweight=n],mc(blue*0.15)) ///
			(scatter taxes_paid today_alt if tmt==4  [fweight=n],mc(orange*0.15)) ///
			(lpoly taxes_paid today_alt if tmt==1 [fweight=n], bw(30) lp(shortdash) lc(gray)) ///
			(lpoly taxes_paid today_alt if tmt==2 [fweight=n], lp(dash) lc(blue) bw(30)) ///
			(lpoly taxes_paid today_alt if tmt==4 [fweight=n], lp(dash) lc(orange) bw(30)), ///
			legend(order(1 4 2 5 3 6) label(1 "Central (Obs)") label(2 "Local (Obs)") label(3 "CXL (Obs)") ///
			label(4 "Central (Poly)") label(5 "Local (Poly)") label(6 "CXL (Poly)") ring(0) position(1)) ///
			xscale(r(21350 21545)) ///
			yscale(range(0(.04).24)) ylab(0(.04).24) ytitle("Percent of HHs who Paid the Property Tax ") ///
			xlabel(21350  "Month 1" 21380  "Month 2" 21410  "Month 3" 21440  "Month 4" 21470 "Month 5" 21500 "Month 6" 21530 "Month 7") ///
			xtitle("")
			graph export "$reploutdir/compliance_over_time_CXL.pdf", replace
		restore
		
*************
* Table A38 *
*************
	
	eststo clear
	label var t_cxl "Central X Local"
	
	* Month FE - Compliance
	eststo: reg taxes_paid t_cxl i.house i.stratum i.time_FE_tdm_2mo_CvCXL if inlist(tmt,1,4), cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvCXL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Revenues
	eststo: reg taxes_paid_amt t_cxl i.house i.stratum i.time_FE_tdm_2mo_CvCXL if inlist(tmt,1,4), cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvCXL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Visited
	eststo: reg visit_post_carto t_cxl i.house i.stratum i.time_FE_tdm_2mo_CvCXL if inlist(tmt,1,4), cl(a7)
	su visit_post_carto if t_c==1 & time_FE_tdm_2mo_CvCXL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Visits
	eststo: reg nb_visit_post_carto t_cxl i.house i.stratum i.time_FE_tdm_2mo_CvCXL if inlist(tmt,1,4), cl(a7)
	su nb_visit_post_carto if t_c==1 & time_FE_tdm_2mo_CvCXL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance Conditional on Visited
	eststo: reg taxes_paid t_cxl i.house i.stratum i.time_FE_tdm_2mo_CvCXL if inlist(tmt,1,4) & visit_post_carto==1, cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvCXL!=. & visit_post_carto==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance CvLvCXL
	eststo: reg taxes_paid t_cxl t_l i.house i.stratum i.time_FE_tdm_2mo_CvLvCXL if inlist(tmt,1,2,4), cl(a7)
	test t_cxl = t_l
	local p_CXLvC = `r(p)'
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvLvCXL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	esttab using "${reploutdir}/centralxlocal_results.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_cxl t_l) ///
	order(t_cxl t_l) ///
	scalar(Clusters Mean CXLvC_p) sfmt(0 3 3 3 3) ///
	nomtitles ///
	mgroups("Tax Compliance" "Tax Amount", pattern(1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	indicate("Time FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
	
	
	

