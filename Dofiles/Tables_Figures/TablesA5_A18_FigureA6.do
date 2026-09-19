**************************************
* Table A5, Table A18, and Figure A6 *
**************************************

*****************************************
* Table A5 Panel A and Figure 6 Panel A *
*****************************************

	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	keep if tmt==1 | tmt==2 | tmt==3
	
	* Tax effects table

		eststo clear
		label var t_l "Local"
			
		// (1) Normal - Compliance
		eststo: reg taxes_paid t_l i.house i.stratum if inlist(tmt,1,2), cl(a7)
		su taxes_paid if t_c==1
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (2) 2 Month FE - Compliance
		sum today_alt
		local tdm_min = `r(min)'
		local tdm_max = `r(max)'+1
		
		egen time_FE_tdm_1mo = cut(today_alt),at(21350 21380 21410 21440 21470 21500 `tdm_max') icodes
		egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
		egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
		egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
		egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
		
		
		eststo: reg taxes_paid t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
		su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (3) Shift two month definition -15/+15 and pick median estimate
		
			// Create graph and find median
				preserve
					use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
					keep if tmt==1 | tmt==2 | tmt==3
					
					* Define FE
					sum today_alt
					local tdm_min = `r(min)'
					local tdm_max = `r(max)'+1
					
					mat A = J(31,2,.)
					
					forval i = -15/15{
					local j = `i'+16

					local c1 = 21355+`i'         
					local c2 = 21415+`i'
					local c3 = 21475+`i'
					local c4 = 21529+`i'

					egen time_FE_tdm_2mo = cut(today_alt),at(`c1' `c2' `c3' `c4') icodes
						
					reg taxes_paid t_l i.house i.stratum i.time_FE_tdm_2mo if inlist(tmt,1,2), cl(a7)
					mat A[`j',1] = _b[t_l]
					mat A[`j',2] = _se[t_l]
					
					cap drop time_FE_tdm_2mo
					
					}
					
					clear
					svmat A
					g n = _n
					replace n = n-16
					ren A1 b
					ren A2 se
					g lb = b-1.96*se
					g ub = b+1.96*se
					
					* Median
					g b_alt = b if n!=1
					sort b_alt
					g n_alt = _n
					
					sum n if n_alt==15
					global CvL_p50_pick = `r(mean)'
					
					sum ub
					local ymax = round(`r(max)',0.01)
					sum lb
					local ymin = round(`r(min)',0.01)
					
					sum b if n==0
					local b_base = `r(mean)'
					
					tw (rcap lb ub n if n==0,lc(red%40) lp(longdash)) (scatter b n if n==0,mlc(red) m(circle) mfc(white)) ///
					(rcap lb ub n if n!=0 & n_alt!=15,lc(gray)) (scatter b n if n!=0 & n_alt!=15,mlc(black) m(circle) mfc(white)) ///
					(rcap lb ub n if n_alt==15,lc(blue%40) lp(dash)) (scatter b n if n_alt==15,mlc(blue) m(circle) mfc(white)), ///
						xtitle("Days shifted month definition forward") ytitle("Coefficient") yscale(range(-0.01 0.06)) ylab(-0.01(0.01)0.06) ///
						legend(order(2 6) label(2 "Actual 2-Mon Definition") label(6 "Median Estimate") ring(0) position(5) size(small)) ///
						yline(`b_base',lc(red) lp(solid)) xscale(range(-15 15)) xlab(-15(5)15) yline(0,lc(black) lp(dash))
					graph export "$reploutdir/shiftFE_compl_CvL.pdf", replace
				restore
			
			// Regression estimate using p50 version
				preserve
					cap drop time_FE_tdm_2mo_CvL
					local c1 = 21355+${CvL_p50_pick}
					local c2 = 21415+${CvL_p50_pick}
					local c3 = 21475+${CvL_p50_pick}
					local c4 = 21529+${CvL_p50_pick}
					egen time_FE_tdm_2mo_CvL = cut(today_alt),at(`c1' `c2' `c3' `c4') icodes
					
					eststo: reg taxes_paid t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
					su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=.
					estadd local Mean=abs(round(`r(mean)',.001))
					estadd scalar Observations = `e(N)'
					estadd scalar Clusters = `e(N_clust)'
				restore
				
		// (4) GSSU 2 Month FE - Compliance
		preserve
		keep if inlist(tmt,1,2)
		duplicates drop a7,force
		count
		local clust_CvL = `r(N)'
		restore
		preserve
		
		eststo: xi: GSSUtest taxes_paid t_l i.house i.time_FE_tdm_2mo_CvL i.stratum,vce(robust) cluster(a7)
			su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `clust_CvL'
		restore
		
		// (5) Month FE
		eststo: reg taxes_paid t_l i.house i.stratum i.time_FE_tdm_1mo if inlist(tmt,1,2), cl(a7)
		su taxes_paid if t_c==1 & time_FE_tdm_1mo!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (6) Time Restrict - Compliance
		
		* Period when both Local and CLI are active
		su today_alt if tmt==2
		local minimum_cvl=`r(min)'
		su today_alt if tmt==1
		local maximum_cvl=`r(max)'
	
		eststo: reg taxes_paid t_l i.house i.stratum if today_alt>=`minimum_cvl' & today_alt<`maximum_cvl' & inlist(tmt,1,2), cl(a7)
		su taxes_paid if t_c==1 & today_alt>=`minimum_cvl' & today_alt<`maximum_cvl'
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (7) CEM - Compliance
		keep if inlist(tmt,1,2)
		cem today_alt,treatment(t_l)
		preserve
		restore
		eststo: reg taxes_paid t_l i.house i.stratum [iw=cem_w],cl(a7)
			su taxes_paid if t_c==1 & cem_w!=0
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `e(N_clust)'
			
		esttab using "${reploutdir}/compl_CvL_results_timeimbal.tex", ///
		replace label b(%9.3f) se(%9.3f) ///
		keep (t_l) ///
		order(t_l) ///
		scalar(Clusters Mean) sfmt(0 3 3) ///
		nomtitles ///
		mgroups("Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance" ///
		"Tax Compliance" "Tax Compliance" ///
		, pattern(1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
		indicate("Month FE = *1mo*""House FE = *house*""Stratum FE = *stratum*") ///
		star(* 0.10 ** 0.05 *** 0.001) ///
		nogaps nonotes compress
		
*****************************************
* Table A5 Panel B and Figure 6 Panel B *
*****************************************	
		
	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	keep if tmt==1 | tmt==2 | tmt==3
		
	* Tax effects table

		eststo clear
		label var t_l "Local"
			
		// (1) Normal - Revenues
		eststo: reg taxes_paid_amt t_l i.house i.stratum if inlist(tmt,1,2), cl(a7)
		su taxes_paid_amt if t_c==1
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (2) 2 Month FE - Revenues
		sum today_alt
		local tdm_min = `r(min)'
		local tdm_max = `r(max)'+1
		
		egen time_FE_tdm_1mo = cut(today_alt),at(21350 21380 21410 21440 21470 21500 `tdm_max') icodes
		egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21529) icodes
		
		eststo: reg taxes_paid_amt t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
		su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (3) Shift two month definition -15/+15 and pick median estimate
		
			// Create graph and find median
				preserve
					use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
					keep if tmt==1 | tmt==2 | tmt==3
					
					* Define FE
					sum today_alt
					local tdm_min = `r(min)'
					local tdm_max = `r(max)'+1
					
					mat A = J(31,2,.)
					
					forval i = -15/15{
					local j = `i'+16

					local c1 = 21355+`i'         
					local c2 = 21415+`i'
					local c3 = 21475+`i'
					local c4 = 21529+`i'

					egen time_FE_tdm_2mo = cut(today_alt),at(`c1' `c2' `c3' `c4') icodes
						
					reg taxes_paid_amt t_l i.house i.stratum i.time_FE_tdm_2mo if inlist(tmt,1,2), cl(a7)
					mat A[`j',1] = _b[t_l]
					mat A[`j',2] = _se[t_l]
					
					cap drop time_FE_tdm_2mo
					
					}
					
					clear
					svmat A
					g n = _n
					replace n = n-16
					ren A1 b
					ren A2 se
					g lb = b-1.96*se
					g ub = b+1.96*se
					
					* Median
					g b_alt = b if n!=1
					sort b_alt
					g n_alt = _n
					
					sum n if n_alt==15
					global CvL_p50_pick = `r(mean)'
					
					sum ub
					local ymax = round(`r(max)',10)
					sum lb
					local ymin = round(`r(min)',10)
					
					sum b if n==0
					local b_base = `r(mean)'
					
					tw (rcap lb ub n if n==0,lc(red%40) lp(longdash)) (scatter b n if n==0,mlc(red) m(circle) mfc(white)) ///
					(rcap lb ub n if n!=0 & n_alt!=15,lc(gray)) (scatter b n if n!=0 & n_alt!=15,mlc(black) m(circle) mfc(white)) ///
					(rcap lb ub n if n_alt==15,lc(blue%40) lp(dash)) (scatter b n if n_alt==15,mlc(blue) m(circle) mfc(white)), ///
						xtitle("Days shifted month definition forward") ytitle("Coefficient") yscale(range(-10 `ymax')) ylab(-10(10)`ymax') ///
						legend(order(2 6) label(2 "Actual 2-Mon Definition") label(6 "Median Estimate") ring(0) position(5) size(small)) ///
						yline(`b_base',lc(red) lp(solid)) xscale(range(-15 15)) xlab(-15(5)15) yline(0,lc(black) lp(dash))
					graph export "$reploutdir/shiftFE_rev_CvL.pdf", replace
				restore
			
			// Regression estimate using p50 version
				preserve
					cap drop time_FE_tdm_2mo_CvL
					local c1 = 21355+${CvL_p50_pick}
					local c2 = 21415+${CvL_p50_pick}
					local c3 = 21475+${CvL_p50_pick}
					local c4 = 21529+${CvL_p50_pick}
					egen time_FE_tdm_2mo_CvL = cut(today_alt),at(`c1' `c2' `c3' `c4') icodes
						
					eststo: reg taxes_paid_amt t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
					su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=.
					estadd local Mean=abs(round(`r(mean)',.001))
					estadd scalar Observations = `e(N)'
					estadd scalar Clusters = `e(N_clust)'
				restore
				
		// (4) GSSU 2 Month FE - Revenues
		preserve
		keep if inlist(tmt,1,2)
		duplicates drop a7,force
		count
		local clust_CvL = `r(N)'
		restore
		preserve

		eststo: xi: GSSUtest taxes_paid_amt t_l i.house i.time_FE_tdm_2mo_CvL i.stratum,vce(robust) cluster(a7)
			su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `clust_CvL'
		restore
		
		// (5) Month FE
		eststo: reg taxes_paid_amt t_l i.house i.stratum i.time_FE_tdm_1mo if inlist(tmt,1,2), cl(a7)
		su taxes_paid_amt if t_c==1 & time_FE_tdm_1mo!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (6) Time Restrict - Revenues
		
		* Period when both Local and CLI are active
		su today_alt if tmt==2
		local minimum_cvl=`r(min)'
		su today_alt if tmt==1
		local maximum_cvl=`r(max)'
			
		eststo: reg taxes_paid_amt t_l i.house i.stratum if today_alt>=`minimum_cvl' & today_alt<`maximum_cvl' & inlist(tmt,1,2), cl(a7)
		su taxes_paid_amt if t_c==1 & today_alt>=`minimum_cvl' & today_alt<`maximum_cvl'
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (7) CEM - Revenues
		keep if inlist(tmt,1,2)
		cem today_alt,treatment(t_l)
		preserve
		restore
		eststo: reg taxes_paid_amt t_l i.house i.stratum [iw=cem_w],cl(a7)
			su taxes_paid_amt if t_c==1 & cem_w!=0
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `e(N_clust)'
			
		esttab using "${reploutdir}/rev_CvL_results_timeimbal.tex", ///
		replace label b(%9.3f) se(%9.3f) ///
		keep (t_l) ///
		order(t_l) ///
		scalar(Clusters Mean) sfmt(0 3 3) ///
		nomtitles ///
		mgroups("Tax Revenues" "Tax Revenues" "Tax Revenues" "Tax Revenues" "Tax Revenues" ///
		"Tax Revenues" "Tax Revenues" ///
		, pattern(1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
		indicate("Month FE = *1mo*""House FE = *house*""Stratum FE = *stratum*") ///
		star(* 0.10 ** 0.05 *** 0.001) ///
		nogaps nonotes compress
		
******************************************
* Table A18 Panel A and Figure 6 Panel C *
******************************************

	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	keep if tmt==1 | tmt==2 | tmt==3
	
	* Tax effects table

		eststo clear
		label var t_cli "Central Plus Local Info"
			
		// (1) Normal - Compliance
		eststo: reg taxes_paid t_cli i.house i.stratum if inlist(tmt,1,3), cl(a7)
		su taxes_paid if t_c==1
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (2) 2 Month FE - Compliance
		sum today_alt
		local tdm_min = `r(min)'
		local tdm_max = `r(max)'+1
		
		egen time_FE_tdm_1mo = cut(today_alt),at(21350 21380 21410 21440 21470 21500 `tdm_max') icodes
		egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
		egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
		egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
		egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes

		eststo: reg taxes_paid t_cli i.house i.stratum i.time_FE_tdm_2mo_CvCLI if inlist(tmt,1,3), cl(a7)
		su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvCLI!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (3) Shift two month definition -15/+15 and pick median estimate
		
			// Create graph and find median
				preserve
					use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
					keep if tmt==1 | tmt==2 | tmt==3
					
					* Define FE
					sum today_alt
					local tdm_min = `r(min)'
					local tdm_max = `r(max)'+1
					
					mat A = J(31,2,.)
					
					forval i = -15/15{
					local j = `i'+16

					local c1 = 21365.5+`i'         
					local c2 = 21425.5+`i'
					local c3 = 21485.5+`i'
					local c4 = 21515.5+`i'

					egen time_FE_tdm_2mo = cut(today_alt),at(`c1' `c2' `c3' `c4') icodes
						
					reg taxes_paid t_cli i.house i.stratum i.time_FE_tdm_2mo if inlist(tmt,1,3), cl(a7)
					mat A[`j',1] = _b[t_cli]
					mat A[`j',2] = _se[t_cli]
					
					cap drop time_FE_tdm_2mo
					
					}
					
					clear
					svmat A
					g n = _n
					replace n = n-16
					ren A1 b
					ren A2 se
					g lb = b-1.96*se
					g ub = b+1.96*se
					
					* Median
					g b_alt = b if n!=1
					sort b_alt
					g n_alt = _n
					
					sum n if n_alt==15
					global CvCLI_p50_pick = `r(mean)'
					
					sum ub
					local ymax = round(`r(max)',0.01)
					sum lb
					local ymin = round(`r(min)',0.01)
					
					sum b if n==0
					local b_base = `r(mean)'
					
					tw (rcap lb ub n if n==0,lc(red%40) lp(longdash)) (scatter b n if n==0,mlc(red) m(circle) mfc(white)) ///
					(rcap lb ub n if n!=0 & n_alt!=15,lc(gray)) (scatter b n if n!=0 & n_alt!=15,mlc(black) m(circle) mfc(white)) ///
					(rcap lb ub n if n_alt==15,lc(blue%40) lp(dash)) (scatter b n if n_alt==15,mlc(blue) m(circle) mfc(white)), ///
						xtitle("Days shifted month definition forward") ytitle("Coefficient") yscale(range(`ymin' `ymax')) ylab(`ymin'(0.01)`ymax') ///
						legend(order(2 6) label(2 "Actual 2-Mon Definition") label(6 "Median Estimate") ring(0) position(5) size(small)) ///
						yline(`b_base',lc(red) lp(solid)) xscale(range(-15 15)) xlab(-15(5)15) yline(0,lc(black) lp(dash))
					graph export "$reploutdir/shiftFE_compl_CvCLI.pdf", replace
				restore
			
			// Regression estimate using p50 version
				preserve
					cap drop time_FE_tdm_2mo_CvCLI
					local c1 = 21365.5+${CvCLI_p50_pick}
					local c2 = 21415+${CvCLI_p50_pick}
					local c3 = 21485.5+${CvCLI_p50_pick}
					local c4 = 21515.5+${CvCLI_p50_pick}
					egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(`c1' `c2' `c3' `c4') icodes
		
					eststo: reg taxes_paid t_cli i.house i.stratum i.time_FE_tdm_2mo_CvCLI if inlist(tmt,1,3), cl(a7)
					su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvCLI!=.
					estadd local Mean=abs(round(`r(mean)',.001))
					estadd scalar Observations = `e(N)'
					estadd scalar Clusters = `e(N_clust)'
				restore
				
		// (4) GSSU 2 Month FE - Compliance
		preserve
		keep if inlist(tmt,1,3)
		duplicates drop a7,force
		count
		local clust_CvCLI = `r(N)'
		restore
		preserve
		drop if time_FE_tdm_2mo_CvCLI==.

		eststo: xi: GSSUtest taxes_paid t_cli i.house i.time_FE_tdm_2mo_CvCLI i.stratum,vce(robust) cluster(a7)
			su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvCLI!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `clust_CvCLI'
		restore
		
		// (5) Month FE
		eststo: reg taxes_paid t_cli i.house i.stratum i.time_FE_tdm_1mo if inlist(tmt,1,3), cl(a7)
		su taxes_paid if t_c==1 & time_FE_tdm_1mo!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (6) Time Restrict - Compliance
		
		* Period when both Local and CLI are active
		su today_alt if tmt==3
		local minimum_CvCLI=`r(min)'
		su today_alt if tmt==3
		local maximum_CvCLI=`r(max)'
		
		eststo: reg taxes_paid t_cli i.house i.stratum if today_alt>=`minimum_CvCLI' & today_alt<`maximum_CvCLI' & inlist(tmt,1,3), cl(a7)
		su taxes_paid if t_c==1 & today_alt>=`minimum_CvCLI' & today_alt<`maximum_CvCLI'
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (7) CEM - Compliance
		keep if inlist(tmt,1,3)
		cem today_alt,treatment(t_cli)
		preserve
		restore
		eststo: reg taxes_paid t_cli i.house i.stratum [iw=cem_w],cl(a7)
			su taxes_paid if t_c==1 & cem_w!=0
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `e(N_clust)'
			
		esttab using "${reploutdir}/compl_CvCLI_results_timeimbal.tex", ///
		replace label b(%9.3f) se(%9.3f) ///
		keep (t_cli) ///
		order(t_cli) ///
		scalar(Clusters Mean) sfmt(0 3 3) ///
		nomtitles ///
		mgroups("Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance" ///
		"Tax Compliance" "Tax Compliance" ///
		, pattern(1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
		indicate("Month FE = *1mo*""House FE = *house*""Stratum FE = *stratum*") ///
		star(* 0.10 ** 0.05 *** 0.001) ///
		nogaps nonotes compress
		
******************************************
* Table A18 Panel B and Figure 6 Panel D *
******************************************		
		
	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	keep if tmt==1 | tmt==2 | tmt==3
		
	* Tax effects table

		eststo clear
		label var t_cli "Central Plus Local Info"
			
		// (1) Normal - Revenues
		eststo: reg taxes_paid_amt t_cli i.house i.stratum if inlist(tmt,1,3), cl(a7)
		su taxes_paid_amt if t_c==1
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (2) 2 Month FE - Revenues
		sum today_alt
		local tdm_min = `r(min)'
		local tdm_max = `r(max)'+1
		
		egen time_FE_tdm_1mo = cut(today_alt),at(21350 21380 21410 21440 21470 21500 `tdm_max') icodes
		egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21515.5) icodes
		
		eststo: reg taxes_paid_amt t_cli i.house i.stratum i.time_FE_tdm_2mo_CvCLI if inlist(tmt,1,3), cl(a7)
		su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvCLI!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (3) Shift two month definition -15/+15 and pick median estimate
		
			// Create graph and find median
				preserve
					use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
					keep if tmt==1 | tmt==2 | tmt==3
					
					* Define FE
					sum today_alt
					local tdm_min = `r(min)'
					local tdm_max = `r(max)'+1
					
					mat A = J(31,2,.)
					
					forval i = -15/15{
					local j = `i'+16

					local c1 = 21365.5+`i'         
					local c2 = 21425.5+`i'
					local c3 = 21485.5+`i'
					local c4 = 21515.5+`i'

					egen time_FE_tdm_2mo = cut(today_alt),at(`c1' `c2' `c3' `c4') icodes
						
					reg taxes_paid_amt t_cli i.house i.stratum i.time_FE_tdm_2mo if inlist(tmt,1,3), cl(a7)
					mat A[`j',1] = _b[t_cli]
					mat A[`j',2] = _se[t_cli]
					
					cap drop time_FE_tdm_2mo
					
					}
					
					clear
					svmat A
					g n = _n
					replace n = n-16
					ren A1 b
					ren A2 se
					g lb = b-1.96*se
					g ub = b+1.96*se
					
					* Median
					g b_alt = b if n!=1
					sort b_alt
					g n_alt = _n
					
					sum n if n_alt==15
					global CvCLI_p50_pick = `r(mean)'
					
					sum ub
					local ymax = round(`r(max)',10)
					sum lb
					local ymin = round(`r(min)',10)
					
					sum b if n==0
					local b_base = `r(mean)'
					
					tw (rcap lb ub n if n==0,lc(red%40) lp(longdash)) (scatter b n if n==0,mlc(red) m(circle) mfc(white)) ///
					(rcap lb ub n if n!=0 & n_alt!=15,lc(gray)) (scatter b n if n!=0 & n_alt!=15,mlc(black) m(circle) mfc(white)) ///
					(rcap lb ub n if n_alt==15,lc(blue%40) lp(dash)) (scatter b n if n_alt==15,mlc(blue) m(circle) mfc(white)), ///
						xtitle("Days shifted month definition forward") ytitle("Coefficient") yscale(range(`ymin' `ymax')) ylab(`ymin'(10)`ymax') ///
						legend(order(2 6) label(2 "Actual 2-Mon Definition") label(6 "Median Estimate") ring(0) position(5) size(small)) ///
						yline(`b_base',lc(red) lp(solid)) xscale(range(-15 15)) xlab(-15(5)15) yline(0,lc(black) lp(dash))
					graph export "$reploutdir/shiftFE_rev_CvCLI.pdf", replace
				restore
			
			// Regression estimate using p50 version
				preserve
					cap drop time_FE_tdm_2mo_CvCLI
					local c1 = 21365.5+${CvCLI_p50_pick}
					local c2 = 21425.5+${CvCLI_p50_pick}
					local c3 = 21485.5+${CvCLI_p50_pick}
					local c4 = 21515.5+${CvCLI_p50_pick}
					egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(`c1' `c2' `c3' `c4') icodes
		
					eststo: reg taxes_paid_amt t_cli i.house i.stratum i.time_FE_tdm_2mo_CvCLI if inlist(tmt,1,3), cl(a7)
					su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvCLI!=.
					estadd local Mean=abs(round(`r(mean)',.001))
					estadd scalar Observations = `e(N)'
					estadd scalar Clusters = `e(N_clust)'
				restore
				
		// (4) GSSU 2 Month FE - Revenues
		preserve
		keep if inlist(tmt,1,3)
		duplicates drop a7,force
		count
		local clust_CvCLI = `r(N)'
		restore
		preserve
		drop if time_FE_tdm_2mo_CvCLI==.

		eststo: xi: GSSUtest taxes_paid_amt t_cli i.house i.time_FE_tdm_2mo_CvCLI i.stratum,vce(robust) cluster(a7)
			su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvCLI!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `clust_CvCLI'
		restore
		
		// (5) Month FE
		eststo: reg taxes_paid_amt t_cli i.house i.stratum i.time_FE_tdm_1mo if inlist(tmt,1,3), cl(a7)
		su taxes_paid_amt if t_c==1 & time_FE_tdm_1mo!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (6) Time Restrict - Revenues
		
		* Period when both Local and CLI are active
		su today_alt if tmt==3
		local minimum_CvCLI=`r(min)'
		su today_alt if tmt==3
		local maximum_CvCLI=`r(max)'
		
		eststo: reg taxes_paid_amt t_cli i.house i.stratum if today_alt>=`minimum_CvCLI' & today_alt<`maximum_CvCLI' & inlist(tmt,1,3), cl(a7)
		su taxes_paid_amt if t_c==1 & today_alt>=`minimum_CvCLI' & today_alt<`maximum_CvCLI'
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		// (7) CEM - Revenues
		keep if inlist(tmt,1,3)
		cem today_alt,treatment(t_cli)
		preserve
		restore
		eststo: reg taxes_paid_amt t_cli i.house i.stratum [iw=cem_w],cl(a7)
			su taxes_paid_amt if t_c==1 & cem_w!=0
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `e(N_clust)'
			
		esttab using "${reploutdir}/rev_CvCLI_results_timeimbal.tex", ///
		replace label b(%9.3f) se(%9.3f) ///
		keep (t_cli) ///
		order(t_cli) ///
		scalar(Clusters Mean) sfmt(0 3 3) ///
		nomtitles ///
		mgroups("Tax Revenues" "Tax Revenues" "Tax Revenues" "Tax Revenues" "Tax Revenues" ///
		"Tax Revenues" "Tax Revenues" ///
		, pattern(1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
		indicate("Month FE = *1mo*""House FE = *house*""Stratum FE = *stratum*") ///
		star(* 0.10 ** 0.05 *** 0.001) ///
		nogaps nonotes compress

