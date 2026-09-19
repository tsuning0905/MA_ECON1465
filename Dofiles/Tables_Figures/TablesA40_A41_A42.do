
	
	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
	cap drop visit_post_carto
	gen visit_post_carto=0 if visited==0 | (visits!=0 & visits!=.)
	replace visit_post_carto=1 if visits!=. & visits>1
	
	cap drop nb_visit_post_carto
	gen nb_visit_post_carto=0 if visits!=. | visited==0
	replace nb_visit_post_carto=visits-1 if visits!=. & visits>1
	replace nb_visit_post_carto=. if nb_visit_post_carto==99998
	replace nb_visit_post_carto = . if visit_post_carto==.
	
	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
	egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
	egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
	egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
	
		sum today_alt
		local tdm_min = `r(min)'
		local tdm_max = `r(max)'+1
		
		egen time_FE_tdm_1mo = cut(today_alt),at(21350 21380 21410 21440 21470 21500 `tdm_max') icodes
			
			keep if time_FE_tdm_2mo_CvLvCLI!=.
			
*************
* Table A41 *
*************

	* Keep chiefs who work in multiple polygons
	
		preserve
			u "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta",clear
			keep a7 chief_code1 chief_code2
			tempfile poly_col
			sa `poly_col'
		restore
		
		preserve
	
			collapse (min) month_min = month month_min_tdm = time_FE_tdm_1mo tmt (mean) month_mean = month,by(a7)
			assert month_min==month_mean
			drop month_mean
			ren month_min month
			
			merge 1:1 a7 using `poly_col'
			assert _merge!=1
			drop if _merge==2
			drop _merge
			
			reshape long chief_code,i(a7) j(typ)
			ren chief_code chief_code
			keep if tmt==2
			bys chief_code: egen count_poly = count(a7)
			
			
			
			
			
				* Identify polygons in where chief working there only worked there
				keep if count_poly<2
				duplicates drop a7,force
				keep a7
				g chief_col_drop = 1
				
			tempfile chief_col_drop
			sa `chief_col_drop'
	
		restore
		
		* Merge with data
		merge m:1 a7 using `chief_col_drop'
		assert _merge!=2
		drop _merge
		
			* Figures
			
			*Payment
			
			preserve
			
			drop if chief_col_drop==1
			
			eststo clear
			
			eststo: reg taxes_paid t_l i.stratum i.house i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2) & pilot==0, cl(a7)
			su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `e(N_clust)'
			
			eststo: reg taxes_paid t_l t_cli i.stratum i.house i.time_FE_tdm_2mo_CvLvCLI if inlist(tmt,1,2,3) & pilot==0, cl(a7)
			su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvLvCLI!=. & pilot==0
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `e(N_clust)'
			
			restore
			
	* Keep chiefs who work in multiple polygons and months - keep only those in second month
	
		preserve
			u "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta",clear
			keep a7 Month chief_code1 chief_code2
			tempfile poly_col
			sa `poly_col'
		restore
		
		preserve
	
			collapse (min) month_min = month month_min_tdm = time_FE_tdm_1mo tmt (mean) month_mean = month,by(a7)
			assert month_min==month_mean
			drop month_mean
			ren month_min month
			
			merge 1:1 a7 using `poly_col'
			assert _merge!=1
			drop if _merge==2
			drop _merge
			
			reshape long chief_code,i(a7) j(typ)
			ren chief_code chief_code
			keep if tmt==2
			bys chief_code: egen count_poly = count(a7)
			
			bys chief_code: egen min_Month = min(Month)		
			
				* Identify polygons in where chief working there only worked there
				drop if min_Month==Month
				drop if chief_code==.
				duplicates drop a7,force
				keep a7
				g chief_col_keep = 1
				
			tempfile chief_col_drop
			sa `chief_col_drop'
	
		restore
		
		* Merge with data
		merge m:1 a7 using `chief_col_drop'
		assert _merge!=2
		drop _merge
		
			* Figures
			
			*Payment
			
			preserve
			
			keep if (chief_col_keep==1 & tmt==2)|tmt==1|tmt==3
			
			eststo: reg taxes_paid t_l i.stratum i.house i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2) & pilot==0, cl(a7)
			su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `e(N_clust)'
			
			eststo: reg taxes_paid t_l t_cli i.stratum i.house i.time_FE_tdm_2mo_CvLvCLI if inlist(tmt,1,2,3) & pilot==0, cl(a7)
			su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvLvCLI!=. & pilot==0
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `e(N_clust)'	
			
			restore
			
	* Keep Central collectors who are working for first time
	
		preserve
			u "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta",clear
			keep a7 Month col_code_1 col_code_2
			tempfile poly_col
			sa `poly_col'
		restore
		
		preserve
	
			collapse (min) month_min = month month_min_tdm = time_FE_tdm_1mo tmt (mean) month_mean = month,by(a7)
			assert month_min==month_mean
			drop month_mean
			ren month_min month
			
			merge 1:1 a7 using `poly_col'
			assert _merge!=1
			drop if _merge==2
			drop _merge
			
			reshape long col_code_,i(a7) j(typ)
			ren col_code_ col_code
			keep if tmt==1
			
			bys col_code: egen min_Month = min(Month)

				* Identify polygons in where chief working there only worked there
				keep if min_Month==Month
				drop if col_code==.
				duplicates drop a7,force
				keep a7
				g central_col_keep = 1
				
			tempfile central_col_keep
			sa `central_col_keep'
	
		restore
		
		* Merge with data
		merge m:1 a7 using `central_col_keep'
		assert _merge!=2
		drop _merge
		
			* Figures
			
			preserve
			
			keep if (central_col_keep==1 & tmt==1)|tmt==2|tmt==3
			
			eststo: reg taxes_paid t_l i.stratum i.house i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2) & pilot==0, cl(a7)
			su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `e(N_clust)'
			
			eststo: reg taxes_paid t_l t_cli i.stratum i.house i.time_FE_tdm_2mo_CvLvCLI if inlist(tmt,1,2,3) & pilot==0, cl(a7)
			su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvLvCLI!=. & pilot==0
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			estadd scalar Clusters = `e(N_clust)'
			
			restore
			
	* Export table of above comparisons
	
		label var t_l "Local"
		label var t_cli "CLI"
	
		esttab using "${reploutdir}/demoralization_checks.tex", ///
		replace label b(%9.3f) se(%9.3f) ///
		keep (t_l t_cli) ///
		order(t_l t_cli) ///
		scalar(Clusters Mean) sfmt(0 3 3) ///
		nomtitles ///
		mgroups("Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance", pattern(1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
		indicate("Time FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
		star(* 0.10 ** 0.05 *** 0.001) ///
		nogaps nonotes compress
		
*************
* Table A40 *
*************
		
	* Table interaction with time
	
		use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
		
		keep if tmt==1|tmt==2|tmt==3
	
		cap drop visit_post_carto
		gen visit_post_carto=0 if visited==0 | (visits!=0 & visits!=.)
		replace visit_post_carto=1 if visits!=. & visits>1
		
		cap drop nb_visit_post_carto
		gen nb_visit_post_carto=0 if visits!=. | visited==0
		replace nb_visit_post_carto=visits-1 if visits!=. & visits>1
		replace nb_visit_post_carto=. if nb_visit_post_carto==99998
		replace nb_visit_post_carto = . if visit_post_carto==.
		
		egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
		egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
		egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
		egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
	
		* Variable
		preserve
		
		keep if time_FE_tdm_2mo_CvL!=.
		
		xtile time_dec = today_alt,nq(10)
		g t_lXtime_dec = t_l*time_dec
	
		eststo clear
		label var t_l "Local"
		label var t_lXtime_dec "Local X Time Decile"
		label var time_dec "Time Decile"
		
		* Normal - Visited
		eststo: reg visit_post_carto t_l t_lXtime_dec time_dec i.house i.stratum if inlist(tmt,1,2) & time_FE_tdm_2mo_CvL!=., cl(a7)
		su visit_post_carto if t_c==1 & time_FE_tdm_2mo_CvL!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		* Normal - Number of visits
		eststo: reg nb_visit_post_carto t_l t_lXtime_dec time_dec i.house i.stratum if inlist(tmt,1,2) & time_FE_tdm_2mo_CvL!=., cl(a7)
		su nb_visit_post_carto if t_c==1 & time_FE_tdm_2mo_CvL!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		esttab using "${reploutdir}/visits_time_deciles.tex", ///
		replace label b(%9.3f) se(%9.3f) ///
		keep ( t_l t_lXtime_dec time_dec) ///
		order( t_l t_lXtime_dec time_dec) ///
		scalar(Clusters Mean) sfmt(0 3 3) ///
		nomtitles ///
		mgroups("Visited" "N Visits", pattern(1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
		indicate("House FE = *house*""Stratum FE = *stratum*") ///
		star(* 0.10 ** 0.05 *** 0.001) ///
		nogaps nonotes compress
		
		restore
		
*************
* Table A42 *
*************
		
	* CLI Exposure
	
		use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
			
		keep if tmt==1|tmt==2|tmt==3
		
		cap drop visit_post_carto
		gen visit_post_carto=0 if visited==0 | (visits!=0 & visits!=.)
		replace visit_post_carto=1 if visits!=. & visits>1
		
		cap drop nb_visit_post_carto
		gen nb_visit_post_carto=0 if visits!=. | visited==0
		replace nb_visit_post_carto=visits-1 if visits!=. & visits>1
		replace nb_visit_post_carto=. if nb_visit_post_carto==99998
		replace nb_visit_post_carto = . if visit_post_carto==.
		
		egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
		egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
		egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
		egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
	
		sum today_alt
		local tdm_min = `r(min)'
		local tdm_max = `r(max)'+1
		
		egen time_FE_tdm_1mo = cut(today_alt),at(21350 21380 21410 21440 21470 21500 `tdm_max') icodes

		reg visit_post_carto t_l i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cluster(a7)
	
		* split into periods around each CLI interval (month 1-3, and 3-5, and 5-7), then stack
			* estimate trend in compliance for each separately before stacking
		
		* Month 1-3
			
			* Keep Central collectors who are working in CLI in month 2
			preserve
				u "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta",clear
				keep a7 Month col_code_1 col_code_2
				tempfile poly_col
				sa `poly_col'
			restore
			
			preserve
		
				collapse (min) month_min = month month_min_tdm = time_FE_tdm_1mo tmt (mean) month_mean = month,by(a7)
				assert month_min==month_mean
				drop month_mean
				ren month_min month
				
				merge 1:1 a7 using `poly_col'
				assert _merge!=1
				drop if _merge==2
				drop _merge
				
				reshape long col_code_,i(a7) j(typ)
				ren col_code_ col_code
				keep if tmt==1|tmt==3
				
				keep if Month<4
				
				bys col_code: egen min_Month = min(Month)
				bys col_code: egen max_Month = max(Month)
				
				* CLI collectors
				egen max_tmt = max(tmt)
				
				
					* Identify polygons in where chief working there only worked there
					keep if min_Month==1 & max_Month==3 & max_tmt==3
					drop if col_code==.
					duplicates drop a7,force
					ren col_code col_code_fe
					keep a7 col_code_fe
					g central_col_keep = 1
					
					
				tempfile central_col_keep1
				sa `central_col_keep1'
		
			restore
			preserve
				keep if month<4
				keep if tmt==1|tmt==2
				
				* Predict trend
				cap drop local_trend
				reg taxes_paid today_alt i.house if tmt==2,cl(a7)
				predict local_trend
				reg taxes_paid_amt today_alt i.house if tmt==2,cl(a7)
				predict local_trend_amt
				
				g afterCLI = 0 if month==1
				replace afterCLI = 1 if month==3
				drop if month==2
				
				* Merge in collectors who worked in CLI in month 2
				merge m:1 a7 using `central_col_keep1'
				keep if _merge==3
				drop _merge
				
				g period = 1
				tempfile month1to3
				sa `month1to3'
			restore
		
		* Month 3-5
			
			* Keep Central collectors who are working in CLI in month 2
			preserve
				u "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta",clear
				keep a7 Month col_code_1 col_code_2
				tempfile poly_col
				sa `poly_col'
			restore
			
			preserve
		
				collapse (min) month_min = month month_min_tdm = time_FE_tdm_1mo tmt (mean) month_mean = month,by(a7)
				assert month_min==month_mean
				drop month_mean
				ren month_min month
				
				merge 1:1 a7 using `poly_col'
				assert _merge!=1
				drop if _merge==2
				drop _merge
				
				reshape long col_code_,i(a7) j(typ)
				ren col_code_ col_code
				keep if tmt==1|tmt==3
				
				keep if Month>2 & month<6
				
				bys col_code: egen min_Month = min(Month)
				bys col_code: egen max_Month = max(Month)
				
				* CLI collectors
				egen max_tmt = max(tmt)
				
				
					* Identify polygons in where chief working there only worked there
					keep if min_Month==3 & max_Month==5 & max_tmt==3
					drop if col_code==.
					duplicates drop a7,force
					ren col_code col_code_fe
					keep a7 col_code_fe
					g central_col_keep = 1
					
				tempfile central_col_keep2
				sa `central_col_keep2'
		
			restore
			preserve
				keep if month>2 & month<6
				keep if tmt==1|tmt==2
				
				* Predict trend
				cap drop local_trend
				reg taxes_paid today_alt i.house if tmt==2,cl(a7)
				predict local_trend
				reg taxes_paid_amt today_alt i.house if tmt==2,cl(a7)
				predict local_trend_amt
				
				g afterCLI = 0 if month==3
				replace afterCLI = 1 if month==5
				drop if month==4
				
				* Merge in collectors who worked in CLI in month 2
				merge m:1 a7 using `central_col_keep2'
				keep if _merge==3
				drop _merge
				
				g period = 2
				tempfile month3to5
				sa `month3to5'
			restore
			
		* Month 5-7
			
			* Keep Central collectors who are working in CLI in month 2
			preserve
				u "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta",clear
				keep a7 Month col_code_1 col_code_2
				tempfile poly_col
				sa `poly_col'
			restore
			
			preserve
		
				collapse (min) month_min = month month_min_tdm = time_FE_tdm_1mo tmt (mean) month_mean = month,by(a7)
				assert month_min==month_mean
				drop month_mean
				ren month_min month
				
				merge 1:1 a7 using `poly_col'
				assert _merge!=1
				drop if _merge==2
				drop _merge
				
				reshape long col_code_,i(a7) j(typ)
				ren col_code_ col_code
				keep if tmt==1|tmt==3
				
				keep if Month>4 & month<8
				
				bys col_code: egen min_Month = min(Month)
				bys col_code: egen max_Month = max(Month)
				
				* CLI collectors
				egen max_tmt = max(tmt)
				
				
					* Identify polygons in where chief working there only worked there
					keep if min_Month==5 & max_Month==7 & max_tmt==3
					drop if col_code==.
					duplicates drop a7,force
					ren col_code col_code_fe
					keep a7 col_code_fe
					g central_col_keep = 1
					
					
				tempfile central_col_keep3
				sa `central_col_keep3'
		
			restore
			preserve
				keep if month>4 & month<8
				keep if tmt==1|tmt==2
				
				* Predict trend
				cap drop local_trend
				reg taxes_paid today_alt i.house if tmt==2,cl(a7)
				predict local_trend
				reg taxes_paid_amt today_alt i.house if tmt==2,cl(a7)
				predict local_trend_amt
				
				g afterCLI = 0 if month==5
				replace afterCLI = 1 if month==7
				drop if month==6
				
				* Merge in collectors who worked in CLI in month 2
				merge m:1 a7 using `central_col_keep3'
				keep if _merge==3
				drop _merge
				
				g period = 3
				tempfile month5to7
				sa `month5to7'
			restore
		
		clear
		append using `month1to3'
		append using `month3to5'
		append using `month5to7'
		
	* Tables
	
		* Why only focus on months 1--5? (excluding CLI in month 6)? Answer below:
	
		// 93% treated in first CLI month (27 collectors, only 5 treated later, with 3 at month 4 and 2 at month 6)
				// of those 2 in month 4, 2 of them started in month 3, and 1 started in month 4
				// of those in month 6 - both started in month 6
	
		eststo clear
		
		label var afterCLI "Post CLI Exposure"
		label var local_trend "Local Trend (Compliance)"
		label var local_trend_amt "Local Trend (Revenues)
	
	* Compliance
		* Period 1
		eststo: reg taxes_paid afterCLI local_trend i.house if tmt==1 & period==1,cl(a7)
		su taxes_paid if t_c==1 & afterCLI==0 & period==1
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		* Periods 1 and 2
		eststo: reg taxes_paid afterCLI local_trend i.house i.period if tmt==1 & inlist(period,1,2),cl(a7)
		su taxes_paid if t_c==1 & afterCLI==0 & inlist(period,1,2)
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
	* Revenues
		* Period 1
		eststo: reg taxes_paid_amt afterCLI local_trend_amt i.house if tmt==1 & period==1,cl(a7)
		su taxes_paid_amt if t_c==1 & afterCLI==0 & period==1
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		* Periods 1 and 2
		eststo: reg taxes_paid_amt afterCLI local_trend_amt i.house i.period if tmt==1 & inlist(period,1,2),cl(a7)
		su taxes_paid_amt if t_c==1 & afterCLI==0 & inlist(period,1,2)
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'

		esttab using "${reploutdir}/centralwinfo_exposure.tex", ///
		replace label b(%9.3f) se(%9.3f) ///
		keep (afterCLI local_trend local_trend_amt) ///
		order(afterCLI local_trend local_trend_amt) ///
		scalar(Clusters Mean) sfmt(0 3 3) ///
		nomtitles ///
		mgroups("Compliance" "Compliance" "Revenues" "Revenues", pattern(1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
		indicate("House FE = *house*""Period FE = *period*") ///
		star(* 0.10 ** 0.05 *** 0.001) ///
		nogaps nonotes compress
