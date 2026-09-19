
*************
* Figure A5 *
*************
	
	// Load data and define variables

	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
	keep if tmt==1 | tmt==2 | tmt==3
	
	cap drop visit_post_carto
	gen visit_post_carto=0 if visited==0 | (visits!=0 & visits!=.)
	replace visit_post_carto=1 if visits!=. & visits>1
	
	cap drop nb_visit_post_carto
	gen nb_visit_post_carto=0 if visits!=. | visited==0
	replace nb_visit_post_carto=visits-1 if visits!=. & visits>1
	replace nb_visit_post_carto=. if nb_visit_post_carto==99998
	replace nb_visit_post_carto = . if visit_post_carto==.

	egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
	egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
	egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes

	* Treatment plot
	
		sort tmt today_alt

		preserve
			keep if today_alt>=21363.3 & today_alt<=21524.3
			collapse (mean) taxes_paid (count) n = taxes_paid,by(tmt today_alt)
			drop if taxes_paid>0.25
			twoway (scatter taxes_paid today_alt if tmt==1 [fweight=n],mc(gray*0.25)) ///
			(scatter taxes_paid today_alt if tmt==2  [fweight=n],mc(blue*0.15)) ///
			(scatter taxes_paid today_alt if tmt==3  [fweight=n],mc(green*0.15)) ///
			(lpoly taxes_paid today_alt if tmt==1 [fweight=n], bw(30) lp(shortdash) lc(gray)) ///
			(lpoly taxes_paid today_alt if tmt==2 [fweight=n], lp(dash) lc(blue) bw(30)) ///
			(lpoly taxes_paid today_alt if tmt==3 [fweight=n], lp(dash) lc(green) bw(30)), ///
			legend(order(1 4 2 5 3 6) label(1 "Central (Obs)") label(2 "Local (Obs)") label(3 "CLI (Obs)") ///
			label(4 "Central (Poly)") label(5 "Local (Poly)") label(6 "CLI (Poly)") ring(0) position(1)) ///
			xscale(r(21350 21545)) ///
			yscale(range(0(.04).24)) ylab(0(.04).24) ytitle("Percent of HHs who Paid the Property Tax ") ///
			xlabel(21350  "Month 1" 21380  "Month 2" 21410  "Month 3" 21440  "Month 4" 21470 "Month 5" 21500 "Month 6" 21530 "Month 7") ///
			xtitle("")
			graph export "$reploutdir/compliance_over_time.pdf", replace
		restore
		

