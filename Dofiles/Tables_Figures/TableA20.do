
*************
* Table A20 *
*************

********************
* Prepare datasets *
********************

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
	
	g t_lXpresent_sensi = t_l*present_sensi
	
	eststo clear
	
	* Taxes Paid only Stratum FE
	eststo: reg taxes_paid t_l t_lXpresent_sensi present_sensi i.stratum if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1 & present_sensi==0
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Taxes Paid only Stratum FE and Time FE
	eststo: reg taxes_paid t_l t_lXpresent_sensi present_sensi i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1 & present_sensi==0 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Taxes Paid only Stratum FE and Time FE and House FE
	eststo: reg taxes_paid t_l t_lXpresent_sensi present_sensi i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1 & present_sensi==0 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Taxes Paid only Stratum FE and Time FE and House FE + exclude exempted
	eststo: reg taxes_paid t_l t_lXpresent_sensi present_sensi i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2) & exempt!=1, cl(a7)
	su taxes_paid if t_c==1 & present_sensi==0 & time_FE_tdm_2mo_CvL!=. & exempt!=1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	esttab using "${reploutdir}/owner_present_reg.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l t_lXpresent_sensi present_sensi) ///
	order(t_l t_lXpresent_sensi present_sensi) ///
	scalar(Clusters Mean) sfmt(0 3 3 3 3 3) ///
	nomtitles ///
	mgroups("Taxes Paid" "Taxes Paid" "Taxes Paid" "Taxes Paid", pattern(1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	indicate("Time FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
