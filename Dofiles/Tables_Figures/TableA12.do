
*************
* Table A12 *
*************

***********
* Panel A *
***********

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
	
	gen visits_other_dummy=visits_other1a
	replace visits_other_dummy=visits_other2a if visits_other1a==. & visits_other2a!=. 
	label var visits_other_dummy "Talked to collectors about Property Tax"
	gen visits_other_nb=visits_other1b
	replace visits_other_nb= visits_other2b if visits_other_nb==.
	replace visits_other_nb=0 if visits_other_dummy==0
	label var visits_other_nb "Talked to collectors about Property Tax  Nb of times"
	
	replace salongo_hours = 0 if salongo==0
	replace salongo_hours = . if salongo_hours==99999
	
		preserve
			* Endline data
			u "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta",clear
			keep if tot_complete==1
			cap drop _merge

			* Replace compound code with previous compound code
			replace compound_code=compound_code_prev if (move==1 | move==2)

			* Clean compound code 
			replace compound_code=999999 if compound_code==99999 | compound_code==9999999

			* Drop missing compound code
			drop if compound_code==999999	
			
			drop if compound_code==. 
			
			* Salongo variables
			g salongo_endline = 0 if salongo==0
			replace salongo_endline = 1 if salongo>0 & salongo<.
			
			g salongo_hours_endline = salongo_hours
			replace salongo_hours_endline = . if salongo_hours==16000 | salongo_hours==60000 // obvious outliers
			replace salongo_hours_endline = 0 if salongo_endline==0
			
			keep compound_code *_endline
				
				tempfile el
				sa `el'
			restore
			
		cap drop _merge
		ren compound1 compound_code
		merge 1:m compound_code using `el'
		
	* Interaction
	g t_lXtaxes_paid = t_l*taxes_paid
	
	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
	egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
	egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
	egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
	
	eststo clear
	label var t_l "Local"
	
	* Salongo - Extensive CvL (Midline) - Interaction
	eststo: reg salongo t_l t_lXtaxes_paid taxes_paid i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
	su salongo if t_c==1 & taxes_paid==0 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Salongo - Extensive CvL (Midline) - Interaction
	eststo: reg salongo_hours t_l t_lXtaxes_paid taxes_paid i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
	su salongo_hours if t_c==1 & taxes_paid==0 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Salongo - Extensive CvL (Endline) - Interaction
	eststo: reg salongo_endline t_l t_lXtaxes_paid taxes_paid i.house i.stratum if inlist(tmt,1,2), cl(a7)
	su salongo_endline if t_c==1 & taxes_paid==0 //& time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Salongo - Extensive CvL (Endline) - Interaction
	eststo: reg salongo_hours_endline t_l t_lXtaxes_paid taxes_paid i.house i.stratum if inlist(tmt,1,2), cl(a7)
	su salongo_hours_endline if t_c==1 & taxes_paid==0
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	esttab using "${reploutdir}/salongo_tax_actual.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l t_lXtaxes_paid taxes_paid) ///
	order(t_l t_lXtaxes_paid taxes_paid) ///
	scalar(Clusters Mean) sfmt(0 3 3 3 3 3) ///
	nomtitles ///
	mgroups( "Salongo (Midline)" "Salongo Amt (Midline)" "Salongo (Endline)" "Salongo Amt (Endline)", pattern(1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	indicate("Time FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress

***********
* Panel B *
***********

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
	
	gen visits_other_dummy=visits_other1a
	replace visits_other_dummy=visits_other2a if visits_other1a==. & visits_other2a!=. 
	label var visits_other_dummy "Talked to collectors about Property Tax"
	gen visits_other_nb=visits_other1b
	replace visits_other_nb= visits_other2b if visits_other_nb==.
	replace visits_other_nb=0 if visits_other_dummy==0
	label var visits_other_nb "Talked to collectors about Property Tax  Nb of times"
	
	replace salongo_hours = 0 if salongo==0
	replace salongo_hours = . if salongo_hours==99999
	
		preserve
			* Endline data
			u "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta",clear
			keep if tot_complete==1
			cap drop _merge

			* Replace compound code with previous compound code
			replace compound_code=compound_code_prev if (move==1 | move==2)

			* Clean compound code 
			replace compound_code=999999 if compound_code==99999 | compound_code==9999999

			* Drop missing compound code
			drop if compound_code==999999	
			
			drop if compound_code==. 
			
			* Salongo variables
			g salongo_endline = 0 if salongo==0
			replace salongo_endline = 1 if salongo>0 & salongo<.
			
			g salongo_hours_endline = salongo_hours
			replace salongo_hours_endline = . if salongo_hours==16000 | salongo_hours==60000 // obvious outliers
			replace salongo_hours_endline = 0 if salongo_endline==0
			
			keep compound_code *_endline
				
				tempfile el
				sa `el'
			restore
			
		cap drop _merge
		ren compound1 compound_code
		merge 1:m compound_code using `el'
		
	* Interaction
	g t_lXtaxes_paid = t_l*taxes_paid
	
	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
	egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
	egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
	egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
	
	eststo clear
	label var t_l "Local"
	
* Predicted WTP

	// Merge in consult data
	preserve
		u "${repldir}/Data/01_base/survey_data/chief_consultations.dta",clear
		keep compound1 pay_ease willingness
		ren compound1 compound_code
		tempfile consult
		sa `consult'
	restore
	
	cap drop _merge
	merge m:1 compound_code using `consult'
	
	lab var pay_ease "Ease of payment"
	lab var willingness "Willingness"
	
* Control Means
	
	cap drop p_*
	
	eststo clear
	
	eststo: reg pay_ease age_prop sex_prop employed salaried work_gov main_tribe i.stratum  if t_cli==1,cluster(a7)
		predict p_pay_ease if inlist(tmt,1,2,3)
	eststo: reg pay_ease age_prop sex_prop employed salaried work_gov main_tribe i.stratum  i.time_FE_tdm_2mo_CvCLI if t_cli==1,cluster(a7)
		predict p_pay_ease_timeFE if inlist(tmt,1,2,3)
	eststo: reg willingness age_prop sex_prop employed salaried work_gov main_tribe i.stratum  if t_cli==1,cluster(a7)
		predict p_willingness if inlist(tmt,1,2,3)
	eststo: reg willingness age_prop sex_prop employed salaried work_gov main_tribe i.stratum  i.time_FE_tdm_2mo_CvCLI if t_cli==1,cluster(a7)
		predict p_willingness_timeFE if inlist(tmt,1,2,3)
		
	// Adjust predicted WTP variables to be categorical
		ren p_pay_ease_timeFE p_pay_ease_orig
		cap drop p_pay_ease
		g p_pay_ease = 0 if p_pay_ease_orig<=(2/3)
		replace p_pay_ease = 1 if p_pay_ease_orig>(2/3) & p_pay_ease_orig<=(4/3)
		replace p_pay_ease = 2 if p_pay_ease_orig>(4/3) & p_pay_ease_orig<.
		
		* Leave-one-out mean
		foreach var in house_quality_new p_pay_ease{
			cap g a7_`var' = .
			cap g tmp_`var' = `var'!=.
			cap bys a7: egen N_`var' = sum(tmp_`var')
			cap bys a7: egen sum_`var' = sum(`var')
			cap replace a7_`var' = (sum_`var'-`var')/(N_`var'-1)
			cap replace a7_`var' = . if `var'==.
		}
		
		
		ren p_willingness p_willingness_orig
		g p_willingness = 0 if p_willingness_orig<=(1+2/3)
		replace p_willingness = 1 if p_willingness_orig>(1+2/3) & p_willingness_orig<=(1+4/3)
		replace p_willingness = 2 if p_willingness_orig>(1+4/3) & p_willingness_orig<.
		
		g p_predict = 0 if p_willingness==0 & p_pay_ease==0
		replace p_predict = 1 if (p_willingness==1 & p_pay_ease==0)|(p_willingness==0 & p_pay_ease==1)
		replace p_predict = 2 if (p_willingness==1 & p_pay_ease==1)|(p_willingness==1 & p_pay_ease==1)|(p_willingness==2 & p_pay_ease==0)|(p_willingness==0 & p_pay_ease==2)
		replace p_predict = 3 if (p_willingness==2 & p_pay_ease==1)|(p_willingness==1 & p_pay_ease==2)
		replace p_predict = 4 if (p_willingness==2 & p_pay_ease==2)
		
	* Generate predicted compliers dummy
	
	egen pred_compliance = rowmean(p_pay_ease_orig p_willingness_orig)
	g pred_compl_dum = .
	forval i = 1/2{
		sum pred_compliance if tmt==`i',d
		replace pred_compl_dum = 0 if pred_compliance<=`r(p25)' & tmt==`i'
		replace pred_compl_dum = 1 if pred_compliance>`r(p25)' & pred_compliance<. & tmt==`i'
	}
	
	g t_lXpred_compl_dum = t_l*pred_compl_dum
	
	eststo clear
	
	* Salongo - Extensive CvL (Midline) - Interaction
	eststo: reg salongo t_l t_lXpred_compl_dum pred_compl_dum i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
	su salongo if t_c==1 & pred_compl_dum==0 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Salongo - Extensive CvL (Midline) - Interaction
	eststo: reg salongo_hours t_l t_lXpred_compl_dum pred_compl_dum i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
	su salongo_hours if t_c==1 & pred_compl_dum==0 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Salongo - Extensive CvL (Endline) - Interaction
	eststo: reg salongo_endline t_l t_lXpred_compl_dum pred_compl_dum i.house i.stratum if inlist(tmt,1,2), cl(a7)
	su salongo_endline if t_c==1 & pred_compl_dum==0 //& time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Salongo - Extensive CvL (Endline) - Interaction
	eststo: reg salongo_hours_endline t_l t_lXpred_compl_dum pred_compl_dum i.house i.stratum if inlist(tmt,1,2), cl(a7)
	su salongo_hours_endline if t_c==1 & pred_compl_dum==0 //& time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	esttab using "${reploutdir}/salongo_tax_predicted.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l t_lXpred_compl_dum pred_compl_dum) ///
	order(t_l t_lXpred_compl_dum pred_compl_dum) ///
	scalar(Clusters Mean) sfmt(0 3 3 3 3 3) ///
	nomtitles ///
	mgroups(/*"Salongo (Midline)" "Salongo Amt (Midline)"*/ "Salongo (Midline)" "Salongo Amt (Midline)" /*"Salongo (Endline)" "Salongo Amt (Endline)"*/ "Salongo (Endline)" "Salongo Amt (Endline)", pattern(1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	indicate("Time FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress


	

	
