
************
* Table A7 *
************

****************
* Prepare Data *
****************

use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
				
**********************************
* Machine Learning and distances * 
**********************************

	preserve
		* Use final Machine Learning data
		insheet using "${repldir}/Data/01_base/admin_data/property_values_MLestimates.csv", clear
		keep compound1 pred_value dist_*
		drop if compound1==.
		rename compound1 compound_code
		tempfile machine_learning
		save `machine_learning'
	restore
	
	ren compound1 compound_code
	
	merge 1:1 compound_code using `machine_learning', nogen keep(match)
	
	egen dist_edu=rowmean(dist_private_schools dist_public_schools dist_universities)
				
**********************************
* Pilot data * 
**********************************	

	preserve
		use "${repldir}/Data/03_clean_combined/combined_data.dta",clear
		keep if pilot==1
		ren compound1 compound_code
		g t_l = tmt==2
		g t_c = tmt==1
		cap drop _merge
		tempfile pilot
		sa `pilot'
	restore
	
	cap drop _merge
	merge 1:1 compound_code using `pilot'
	assert _merge!=3
	drop _merge
	
	
// CvL Compliance and revenues - Figures and Tables

	keep if tmt==1 | tmt==2 | tmt==3
	
	* Define FE
	sum today_alt
	local tdm_min = `r(min)'
	local tdm_max = `r(max)'+1
	
	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
	
	// Pilot
	replace time_FE_tdm_2mo_CvL = 3 if pilot==1
	replace stratum = 999 if pilot==1

	label var t_l "Local"
	
* Add education from baseline

	ren edu edu_ml
	ren edu2 edu2_ml

	preserve
			* Baseline data
			u "${repldir}/Data/01_base/survey_data/baseline_noPII.dta",clear
			keep if tot_complete==1
			ren code survey1_code
			
			g move_conflict = 0 if move1!=.
			replace move_conflict = 1 if move1>0 & move1<. & move2==1
			replace move_conflict = 0 if move1>0 & move1<. & move2==0
			replace move_conflict = 1 if move1==0 & move2==0
			
			keep survey1_code inc_mo possessions possessions_* elect1 renters_b work_gov3 transport church hh_size civic7 ///
				bus1 wed_fun social1 social2 trust8 trust4 trust5 trust6 tax13 move_conflict kga_born ave_born ///
				access1 access2 access3 access4 access5 access6 access7 access8 access9 access10 ///
				chef0 chef1 chef2 chef3 chef4 chef5 ///
				chef_eval chef_corr1 chef11 chef12 ///
				edu edu2 status tax17 tax28 tax32 ///
				pay_gov1_2  pay_gov1_3 pay_gov1_5 pay_gov1_14 pay_gov1_7 pay_gov1_15 pay_gov1_10 pay_gov1_1  pay_gov1_17 pay_gov1_6  ///
				pay_gov2_4 pay_gov2_8 pay_gov2_11 pay_gov2_12 pay_gov2_13 pay_gov2_16 pay_tot ///
				trust4 trust5 trust6 corr14_end gov1_end job1 return
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
			ren return return_bl
			ren tax17 tax17_bl
			ren tax28 tax28_bl
			ren tax32 tax32_bl
			ren tax13 tax13_bl
				replace tax13_bl = 0 if (tax17_bl==2|tax17_bl==3) & return==0
			ren possessions_1 moto_bl
			ren possessions_2 car_bl
			ren possessions_3 radio_bl
			ren possessions_4 tv_bl 
			ren possessions_5 egen_bl
			ren possessions_6 sewmach_bl
			forval i = 0/5{
				ren chef`i' chef`i'_bl
			}
			ren edu edu_bl
			ren edu2 edu2_bl
			ren status status_bl
			ren job1 job1_bl
				g employed_prop_bl = 0 if job1_bl==0 & status_bl==1
				replace employed_prop_bl = 1 if job1_bl>0 & job1_bl<. & status_bl==1
			foreach var in ///
				pay_gov1_2  pay_gov1_3 pay_gov1_5 pay_gov1_14 pay_gov1_7 pay_gov1_15 pay_gov1_10 pay_gov1_1  pay_gov1_17 pay_gov1_6  ///
				pay_gov2_4 pay_gov2_8 pay_gov2_11 pay_gov2_12 pay_gov2_13 pay_gov2_16 pay_tot ///
				chef_eval chef_corr1 chef11 chef12  ///
				corr14_end gov1_end{
					ren `var' `var'_bl
				}
				foreach var in trust4 trust5 trust6 trust8 {
					g `var'_bl = `var'
				}

			* Normalize
				global transport "transport_bl"
				global church "church_bl"
				global wed_fun "wed_fun_bl"
				global social "social1_bl social2_bl"
				global hh_size "hh_size_bl"
				global trust "trust8 trust4 trust5 trust6"
				global access "access1 access2 access3 access4 access5 access6 access7 access8 access9 access10"
				global access_obs "access3 access4 access5 access6 access7"
				global obs_poss "moto_bl car_bl"
				global unobs_poss  "radio_bl tv_bl egen_bl sewmach_bl"
				global all_poss "moto_bl car_bl radio_bl tv_bl egen_bl sewmach_bl"
				foreach index in social transport church wed_fun hh_size trust access obs_poss unobs_poss access_obs all_poss{ 
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
			
			cap drop _merge
			tempfile bl
			sa `bl'
			
			* Endline data
			u "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta",clear
			keep if tot_complete==1
			cap drop _merge
			
			keep code compound_code compound_code_prev visits move inc_mo transport cash_fee_month2_1-cash_fee_month2_31 liquidity_bind_date_1-liquidity_bind_date_31
			rename inc_mo inc_mo_el
			rename transport transport_el
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
			egen trans_mo_avg=rowmean(transport_bl transport_el)
			g inc_trans_avg = inc_mo_avg+trans_mo_avg
			
			* Liquidity and cash fee
			egen cash_fee_days_tot = rowtotal(cash_fee_month2_1-cash_fee_month2_31)
			egen liquidity_bind_days_tot = rowtotal(liquidity_bind_date_1-liquidity_bind_date_31)
			
			* Normalize
				global income_avg "inc_mo_avg"
				global income_transport_avg "inc_trans_avg"
				global liquid_avg "cash_fee_days_tot liquidity_bind_days_tot"
				foreach index in income_avg liquid_avg income_transport_avg { 
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

				/*foreach var in income_avg liquid_avg income_transport_avg{
				sum `var', d
				g `var'_norm = (`var'-`r(min)')/(`r(max)'-`r(min)') //normalize variables
				}*/
				
				tempfile el
				sa `el'
			restore
			
		cap drop _merge
		*ren compound1 compound_code
		merge 1:m compound_code using `el'
		
		//  Education
		ren status status_ml
		g educ_lvl_prop = .
		foreach typ in bl ml{
			replace educ_lvl_prop=edu_`typ' if edu_`typ'!=. & educ_lvl_prop==. & status_`typ'==1
		}
		g educ_yrs_prop =  .
		foreach typ in bl ml{
			replace educ_yrs_prop=0 if educ_lvl_prop==0 & educ_yrs_prop==. & status_`typ'==1
			replace educ_yrs_prop=edu2_`typ' if educ_lvl_prop==1 & educ_yrs_prop==. & edu2_`typ'<=3 & status_`typ'==1
				replace educ_yrs_prop=3 if educ_lvl_prop==1 & educ_yrs_prop==. & edu2_`typ'>3 & edu2_`typ'<. & status_`typ'==1
			replace educ_yrs_prop=3+edu2_`typ' if educ_lvl_prop==2 & edu2_`typ'!=. & educ_yrs_prop==. & status_`typ'==1
			replace educ_yrs_prop=3+6+edu2_`typ' if educ_lvl_prop==3 & edu2_`typ'!=. & educ_yrs_prop==. & status_`typ'==1
			replace educ_yrs_prop=3+12+edu2_`typ' if educ_lvl_prop==4 & edu2_`typ'!=. & educ_yrs_prop==. & status_`typ'==1
		}
	
* Robustness adding controls

	// Replace missing values with mean and create dummy for missing
	g age_prop_squared = age_prop^2
	foreach var in age_prop age_prop_squared sex_prop educ_yrs_prop employed salaried job_gov work_gov main_tribe dist_edu{
		replace `var' = . if `var'==.d
		g `var'_mis = `var'==.
		sum `var' if pilot==0
		replace `var' = `r(mean)' if `var'==.
	}
	
***********
* Panel A *
***********

	eststo clear
	
	* Month FE - Compliance - House FE - Age, Age-Squared, Gender
	eststo: reg taxes_paid t_l i.stratum i.house i.time_FE_tdm_2mo_CvL ///
		age_prop age_prop_squared sex_prop educ_yrs_prop ///
		age_prop_mis age_prop_squared_mis sex_prop_mis educ_yrs_prop_mis if inlist(tmt,1,2) & pilot==0, cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - House FE - + Imbalanced
	eststo: reg taxes_paid t_l i.stratum i.house i.time_FE_tdm_2mo_CvL ///
		age_prop age_prop_squared sex_prop educ_yrs_prop dist_edu ///
		age_prop_mis age_prop_squared_mis sex_prop_mis educ_yrs_prop_mis dist_edu_mis if inlist(tmt,1,2) & pilot==0, cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - House FE - + Socioeconomic
	eststo: reg taxes_paid t_l i.stratum i.house i.time_FE_tdm_2mo_CvL ///
		age_prop age_prop_squared sex_prop educ_yrs_prop dist_edu employed salaried job_gov work_gov main_tribe ///
		age_prop_mis age_prop_squared_mis sex_prop_mis educ_yrs_prop_mis dist_edu_mis employed_mis salaried_mis job_gov_mis work_gov_mis main_tribe_mis if inlist(tmt,1,2) & pilot==0, cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - House FE - + Pilot Polygons
	eststo: reg taxes_paid t_l i.stratum i.house i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2) & inlist(pilot,0,1), cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & inlist(pilot,0,1)
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - House FE - + Drop Polygon 654
	eststo: reg taxes_paid t_l i.stratum i.house i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2) & pilot==0 & a7!=654, cl(a7)
	su taxes_paid if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0 & a7!=654
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Compliance - House FE - + Winsorize (at polygon level)
	preserve
		drop if time_FE_tdm_2mo_CvL==.
		collapse (mean) taxes_paid (min) time_FE_tdm_2mo_CvL (max) t_l t_c stratum,by(a7 tmt)
		winsor taxes_paid,gen(taxes_paid_w10) p(0.1) highonly
		eststo: reg taxes_paid_w10 t_l i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), robust
		su taxes_paid_w10 if t_c==1 & time_FE_tdm_2mo_CvL!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		*estadd scalar Clusters = `e(N_clust)'
	restore
	
	esttab using "${reploutdir}/compl_results_controls.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l) ///
	order(t_l) ///
	scalar(Clusters Mean) sfmt(0 3 3) ///
	nomtitles ///
	mgroups("Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance" "Tax Compliance", pattern(1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	indicate("Month FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
	
	
***********
* Panel B *
***********

	eststo clear
	label var t_l "Local"
	
	* Month FE - Revenues - House FE - Age, Age-Squared, Gender
	eststo: reg taxes_paid_amt t_l i.stratum i.house i.time_FE_tdm_2mo_CvL ///
		age_prop age_prop_squared sex_prop educ_yrs_prop ///
		age_prop_mis age_prop_squared_mis sex_prop_mis educ_yrs_prop_mis if inlist(tmt,1,2) & pilot==0, cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Revenues - House FE - + Imbalanced
	eststo: reg taxes_paid_amt t_l i.stratum i.house i.time_FE_tdm_2mo_CvL ///
		age_prop age_prop_squared sex_prop educ_yrs_prop dist_edu ///
		age_prop_mis age_prop_squared_mis sex_prop_mis educ_yrs_prop_mis dist_edu_mis if inlist(tmt,1,2) & pilot==0, cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Revenues - House FE - + Socioeconomic
	eststo: reg taxes_paid_amt t_l i.stratum i.house i.time_FE_tdm_2mo_CvL ///
		age_prop age_prop_squared sex_prop educ_yrs_prop dist_edu employed salaried job_gov work_gov main_tribe ///
		age_prop_mis age_prop_squared_mis sex_prop_mis educ_yrs_prop_mis dist_edu_mis employed_mis salaried_mis job_gov_mis work_gov_mis main_tribe_mis if inlist(tmt,1,2) & pilot==0, cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Revenues - House FE - + Pilot Polygons
	eststo: reg taxes_paid_amt t_l i.stratum i.house i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2) & inlist(pilot,0,1), cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=. & inlist(pilot,0,1)
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Revenues - House FE - + Drop Polygon 654
	eststo: reg taxes_paid_amt t_l i.stratum i.house i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2) & pilot==0 & a7!=654, cl(a7)
	su taxes_paid_amt if t_c==1 & time_FE_tdm_2mo_CvL!=. & pilot==0 & a7!=654
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Month FE - Revenues - House FE - + Winsorize (at polygon level)
	preserve
		drop if time_FE_tdm_2mo_CvL==.
		collapse (mean) taxes_paid_amt (min) time_FE_tdm_2mo_CvL (max) t_l t_c stratum,by(a7 tmt)
		winsor taxes_paid_amt,gen(taxes_paid_amt_w10) p(0.1) highonly
		eststo: reg taxes_paid_amt_w10 t_l i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), robust
		su taxes_paid_amt_w10 if t_c==1 & time_FE_tdm_2mo_CvL!=.
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		*estadd scalar Clusters = `e(N_clust)'
	restore
	
	esttab using "${reploutdir}/rev_results_controls.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l) ///
	order(t_l) ///
	scalar(Clusters Mean) sfmt(0 3 3) ///
	nomtitles ///
	mgroups("Revenues" "Revenues" "Revenues" "Revenues" "Revenues" "Revenues", pattern(1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	indicate("Month FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
