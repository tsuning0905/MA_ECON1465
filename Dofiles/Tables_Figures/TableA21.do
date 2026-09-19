
*************
* Table A21 *
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

	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
	egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
	egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
	egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
	
	// House quality

		* roof
		gen roof_final=roof
		replace roof_final=5 if roof==7 & roof2==3
		replace roof_final=6 if roof==7 & roof2==2
		replace roof_final=7 if roof==7 & roof2==1
		replace roof_final=8 if roof==5 | roof==6

		* walls
		g walls_final = walls
		revrs ravine 

		global house_quality = "walls_final roof_final"

		foreach index in house_quality{ 
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

		foreach var in house_quality{
		sum `var', d
		g `var'_norm = (`var'-`r(min)')/(`r(max)'-`r(min)') //normalize variables
		}
	
	// Income
	
		preserve
			* Baseline data
			u "${repldir}/Data/01_base/survey_data/baseline_noPII.dta",clear
			keep if tot_complete==1
			ren code survey1_code
			
			g move_conflict = 0 if move1!=.
			replace move_conflict = 1 if move1>0 & move1<. & move2==1
			replace move_conflict = 0 if move1>0 & move1<. & move2==0
			replace move_conflict = 1 if move1==0 & move2==0
			
			keep survey1_code inc_mo possessions elect1 renters_b work_gov3 transport church hh_size civic7 ///
				bus1 wed_fun social1 social2 trust8 trust4 trust5 trust6 tax13 move_conflict kga_born ave_born ///
				access1 access2 access3 access4 access5 access6 access7 access8 access9 access10
			rename inc_mo inc_mo_bl
			ren possessions possessions_bl
			ren elect1 elect1_bl
			ren renters_b renters_bl
			ren work_gov3 work_gov3_bl
			ren  transport  transport_bl
				replace transport_bl = transport_bl/10000
			ren church church_bl
				replace church_bl = church_bl/10000
			ren hh_size hh_size_bl
			ren civic7 civic7_bl
			ren bus1 bus1_bl
			ren wed_fun wed_fun_bl
			ren social1 social1_bl
			ren social2 social2_bl
			ren tax13 tax13_bl

			* Normalize
				global transport "transport_bl"
				global church "church_bl"
				global wed_fun "wed_fun_bl"
				global social "social1_bl social2_bl"
				global hh_size "hh_size_bl"
				global trust "trust8 trust4 trust5 trust6"
				global access "access1 access2 access3 access4 access5 access6 access7 access8 access9 access10"
				foreach index in social transport church wed_fun hh_size trust access{ 
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

				foreach var in social transport church wed_fun hh_size trust access{
				sum `var', d
				g `var'_norm = (`var'-`r(min)')/(`r(max)'-`r(min)') //normalize variables
				}
			
			cap drop _merge
			tempfile bl
			sa `bl'
			
			* Endline data
			u "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta",clear
			keep if tot_complete==1
			cap drop _merge
			
			keep code compound_code compound_code_prev visits move inc_mo cash_fee_month2_1-cash_fee_month2_31 liquidity_bind_date_1-liquidity_bind_date_31
			rename inc_mo inc_mo_el
			ren code survey1_code
			merge 1:1 survey1_code using `bl'
			cap drop _merge
			
			*  Visits
			g visited_endline = 1 if visits>2  &  visits<.

			* Replace compound code with previous compound code
			replace compound_code=compound_code_prev if (move==1 | move==2)

			* Clean compound code 
			replace compound_code=999999 if compound_code==99999 | compound_code==9999999

			* Drop missing compound code
			drop if compound_code==999999	
			
			drop if compound_code==. 
			
			* Average Income per month (over baseline and endline)
			egen inc_mo_avg=rowmean(inc_mo_bl inc_mo_el)
			
			* Liquidity and cash fee
			egen cash_fee_days_tot = rowtotal(cash_fee_month2_1-cash_fee_month2_31)
			egen liquidity_bind_days_tot = rowtotal(liquidity_bind_date_1-liquidity_bind_date_31)
			
			* Normalize
				global income_avg "inc_mo_avg"
				global liquid_avg "cash_fee_days_tot liquidity_bind_days_tot"
				foreach index in income_avg liquid_avg { 
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

				foreach var in income_avg liquid_avg{
				sum `var', d
				g `var'_norm = (`var'-`r(min)')/(`r(max)'-`r(min)') //normalize variables
				}
				
				tempfile el
				sa `el'
			restore
			
		cap drop _merge
		ren compound1 compound_code
		merge 1:m compound_code using `el'

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
	
	g pay_ease_dum = 0 if pay_ease!=.
	replace pay_ease_dum = 1 if pay_ease==2
	
	g willingness_dum = 0 if willingness!=.
	replace willingness_dum = 1 if willingness==3
	
	lab var pay_ease "Ease of payment"
	lab var willingness "Willingness"
	
	lab var age_prop "Age"
	lab var sex_prop "Male"
	lab var employed "Employed"
	lab var salaried "Salaried"
	lab var work_gov "Work Govt"
	lab var main_tribe "Main Tribe"
	lab var house_quality "House quality index"
	
	// For prediction and appendix table (also show alternate definition with different dummies)
	
	cap drop p_*
	
	eststo clear
	
	eststo: reg pay_ease age_prop sex_prop employed salaried work_gov main_tribe  i.stratum if t_cli==1,cluster(a7)
		estadd scalar Clusters = `e(N_clust)'
		predict p_pay_ease if inlist(tmt,1,2,3)
		sum pay_ease_dum if age_prop!=. & sex_prop!=. & employed!=. & salaried!=. & work_gov!=. & main_tribe!=. & t_cli==1
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
	eststo: reg pay_ease age_prop sex_prop employed salaried work_gov main_tribe i.stratum i.time_FE_tdm_2mo_CvCLI if t_cli==1,cluster(a7)
		estadd scalar Clusters = `e(N_clust)'
		predict p_pay_ease_timeFE if inlist(tmt,1,2,3)
		sum pay_ease_dum if age_prop!=. & sex_prop!=. & employed!=. & salaried!=. & work_gov!=. & main_tribe!=. &  t_cli==1 & time_FE_tdm_2mo_CvCLI!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
	eststo: reg willingness age_prop sex_prop employed salaried work_gov main_tribe  i.stratum if t_cli==1,cluster(a7)
		estadd scalar Clusters = `e(N_clust)'
		predict p_willingness if inlist(tmt,1,2,3)
		sum willingness_dum if age_prop!=. & sex_prop!=. & employed!=. & salaried!=. & work_gov!=. & main_tribe!=. & t_cli==1
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
	eststo: reg willingness age_prop sex_prop employed salaried work_gov main_tribe  i.stratum i.time_FE_tdm_2mo_CvCLI if t_cli==1,cluster(a7)
		estadd scalar Clusters = `e(N_clust)'
		predict p_willingness_timeFE if inlist(tmt,1,2,3)
		sum willingness_dum if age_prop!=. & sex_prop!=. & employed!=. & salaried!=. & work_gov!=. & main_tribe!=.  & t_cli==1 & time_FE_tdm_2mo_CvCLI!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		local Mean=abs(round(`r(mean)',.001))
		estadd scalar Mean2 = `Mean'
	
	// CLI table
	
		// Adjust predicted WTP variables to be categorical
		ren p_pay_ease p_pay_ease_orig
		g p_pay_ease = 0 if p_pay_ease_orig<=(2/3)
		replace p_pay_ease = 1 if p_pay_ease_orig>(2/3) & p_pay_ease_orig<=(4/3)
		replace p_pay_ease = 2 if p_pay_ease_orig>(4/3) & p_pay_ease_orig<.
		
		ren p_willingness p_willingness_orig
		g p_willingness = 0 if p_willingness_orig<=(1+2/3)
		replace p_willingness = 1 if p_willingness_orig>(1+2/3) & p_willingness_orig<=(1+4/3)
		replace p_willingness = 2 if p_willingness_orig>(1+4/3) & p_willingness_orig<.
	
	lab var p_pay_ease "Predicted Ease of payment"
	lab var p_willingness "Predicted Willingness to pay"
	lab var walls_final "Wall quality"
	lab var roof_final "Roof quality"
	
***********
* Panel A *
***********
		
		eststo clear
			
		// Actual pay ease predicting visits and compliance in CLI
		eststo: reg visit_post_carto pay_ease i.stratum if t_cli==1,cluster(a7)
			estadd scalar Clusters = `e(N_clust)'
			sum visit_post_carto if t_cli==1 & pay_ease!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
		eststo: reg taxes_paid pay_ease i.stratum if t_cli==1,cluster(a7)
			estadd scalar Clusters = `e(N_clust)'
			sum taxes_paid if t_cli==1 & pay_ease!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			
		// Actual pay ease predicting visits and compliance in CLI - controlling for observables
		
		sum ravine
		cap g ravine_final = (ravine-`r(mean)')/(`r(sd)') //standardize
		
		lab var ravine_final "Erosion threat"
		
		eststo: reg visit_post_carto pay_ease walls_final roof_final ravine_final i.stratum if t_cli==1,cluster(a7)
			estadd scalar Clusters = `e(N_clust)'
			sum visit_post_carto if t_cli==1 & pay_ease!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
		eststo: reg taxes_paid pay_ease walls_final roof_final ravine_final i.stratum if t_cli==1,cluster(a7)
			estadd scalar Clusters = `e(N_clust)'
			sum taxes_paid if t_cli==1 & pay_ease!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			
		// Predicted pay ease function predicting visits/payment in C and L
		eststo: reg visit_post_carto p_pay_ease walls_final roof_final ravine_final i.stratum if t_l==1,cluster(a7)
			estimates store L_visit_pay_ease
			estadd scalar Clusters = `e(N_clust)'
			sum visit_post_carto if t_l==1 & p_pay_ease!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
		eststo: reg taxes_paid p_pay_ease walls_final roof_final ravine_final i.stratum if t_l==1,cluster(a7)
			estimates store L_compl_pay_ease
			estadd scalar Clusters = `e(N_clust)'
			sum taxes_paid if t_l==1 & p_pay_ease!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
		eststo: reg visit_post_carto p_pay_ease walls_final roof_final ravine_final i.stratum if t_c==1,cluster(a7)
			estimates store C_visit_pay_ease
			estadd scalar Clusters = `e(N_clust)'
			sum visit_post_carto if t_c==1 & p_pay_ease!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
		eststo: reg taxes_paid p_pay_ease walls_final roof_final ravine_final i.stratum if t_c==1,cluster(a7)
			estimates store C_compl_pay_ease
			estadd scalar Clusters = `e(N_clust)'
			sum taxes_paid if t_c==1 & p_pay_ease!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			
		esttab using "${reploutdir}/chiefs_info_payease_nohouseFE.tex", ///
		replace label b(%9.3f) se(%9.3f) ///
		keep (pay_ease p_pay_ease walls_final roof_final ravine_final) ///
		order(pay_ease p_pay_ease walls_final roof_final ravine_final) ///
		scalar(Clusters Mean) sfmt(0 0 3) ///
		nomtitles ///
		mgroups("Visited Post Carto" "Compliance" "Visited Post Carto" "Compliance" "Compliance" "Visited Post Carto" "Compliance" "Visited Post Carto"  "Compliance", pattern(1 1 1 1 1 1  1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
		indicate("Stratum FE = *stratum*") ///
		star(* 0.10 ** 0.05 *** 0.001) ///
		nogaps nonotes compress

***********
* Panel B *
***********
		
		eststo clear
			
		// Actual willingness predicting visits and compliance in CLI
		eststo: reg visit_post_carto willingness i.stratum if t_cli==1,cluster(a7)
			estadd scalar Clusters = `e(N_clust)'
			sum visit_post_carto if t_cli==1 & willingness!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
		eststo: reg taxes_paid willingness i.stratum if t_cli==1,cluster(a7)
			estadd scalar Clusters = `e(N_clust)'
			sum taxes_paid if t_cli==1 & willingness!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			
		// Actual willingness predicting visits and compliance in CLI - controlling for observables
		
		sum ravine
		cap g ravine_final = (ravine-`r(mean)')/(`r(sd)') //standardize
		
		eststo: reg visit_post_carto willingness walls_final roof_final ravine_final i.stratum if t_cli==1,cluster(a7)
			estadd scalar Clusters = `e(N_clust)'
			sum visit_post_carto if t_cli==1 & willingness!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
		eststo: reg taxes_paid willingness walls_final roof_final ravine_final i.stratum if t_cli==1,cluster(a7)
			estadd scalar Clusters = `e(N_clust)'
			sum taxes_paid if t_cli==1 & willingness!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			
		// Predicted willingness function predicting visits/payment in C and L
		eststo: reg visit_post_carto p_willingness walls_final roof_final ravine_final i.stratum if t_l==1,cluster(a7)
			estimates store L_visit_wtp
			estadd scalar Clusters2 = `e(N_clust)'
			sum visit_post_carto if t_l==1 & p_willingness!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean2=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
		eststo: reg taxes_paid p_willingness walls_final roof_final ravine_final i.stratum if t_l==1,cluster(a7)
			estimates store L_compl_wtp
			estadd scalar Clusters2 = `e(N_clust)'
			sum taxes_paid if t_l==1 & p_willingness!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean2=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
		eststo: reg visit_post_carto p_willingness walls_final roof_final ravine_final i.stratum if t_c==1,cluster(a7)
			estimates store C_visit_wtp
			estadd scalar Clusters2 = `e(N_clust)'
			sum visit_post_carto if t_c==1 & p_willingness!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean2=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
		eststo: reg taxes_paid p_willingness walls_final roof_final ravine_final i.stratum if t_c==1,cluster(a7)
			estimates store C_compl_wtp
			estadd scalar Clusters2 = `e(N_clust)'
			sum taxes_paid if t_c==1 & p_willingness!=. & walls_final!=. & roof_final!=. & ravine_final!=.
			estadd local Mean2=abs(round(`r(mean)',.001))
			estadd scalar Observations = `e(N)'
			
		esttab using "${reploutdir}/chiefs_info_wtp_nohouseFE.tex", ///
		replace label b(%9.3f) se(%9.3f) ///
		keep (willingness p_willingness walls_final roof_final ravine_final) ///
		order(willingness p_willingness walls_final roof_final ravine_final) ///
		scalar(Clusters Mean  Clusters2 Mean2) sfmt(0 0 3 0 3) ///
		nomtitles ///
		mgroups("Visited Post Carto" "Compliance" "Visited Post Carto" "Compliance" "Visited Post Carto"  "Compliance" "Visited Post Carto" "Compliance", pattern(1 1 1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
		indicate("Stratum FE = *stratum*") ///
		star(* 0.10 ** 0.05 *** 0.001) ///
		nogaps nonotes compress
		
