
*************
* Table A13 *
*************

	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
	global RI_ON = 0
	
	cap drop visit_post_carto
	gen visit_post_carto=0 if visited==0 | (visits!=0 & visits!=.)
	replace visit_post_carto=1 if visits!=. & visits>1
	
	cap drop nb_visit_post_carto
	gen nb_visit_post_carto=0 if visits!=. | visited==0
	replace nb_visit_post_carto=visits-1 if visits!=. & visits>1
	replace nb_visit_post_carto=. if nb_visit_post_carto==99998
	replace nb_visit_post_carto = . if visit_post_carto==.
	
	* Outcomes
	
	// House quality
		* roof
		gen roof_final=roof
		replace roof_final=5 if roof==7 & roof2==3
		replace roof_final=6 if roof==7 & roof2==2
		replace roof_final=7 if roof==7 & roof2==1
		replace roof_final=8 if roof==5 | roof==6

		*walls 

		g walls_final = walls
		revrs ravine
		
		g walls_new = 0 if inlist(walls_final,0,1)
		replace walls_new = 1 if inlist(walls_final,2,3,4)
				
		g walls_modern = 1 if inlist(walls_final,3,4)
		replace walls_modern = 0 if inlist(walls_final,0,1,2)

		g roof_new = 0 if inlist(roof_final,1,2,3,4)
		replace roof_new = 1 if inlist(roof_final,7,8)

		global house_quality = "walls_final roof_final"
		global house_quality_new = "walls_new"

		global house_quality = "walls_final roof_final"

		foreach index in house_quality house_quality_new{ 
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
		
	// ML Pred USD
	
		rename compound1 compound_code

		preserve

			* Simulations
			insheet using "${repldir}/Data/01_base/admin_data/property_values_MLestimates.csv", clear
			rename pred_value prediction

			* Keep relevant variables
			keep compound1 a7 value prediction
			rename prediction ml_pred_usd
			rename compound1 compound_code
			drop if compound_code==.
			duplicates drop compound_code,force

			* Tempfile
			tempfile machinelearning
			save `machinelearning'

		restore
		
			merge 1:1 compound_code using `machinelearning', force
			drop if _merge==2 
			drop _merge
	
	// Income
	
		preserve
			* Baseline data
			u "${repldir}/Data/01_base/survey_data/baseline_noPII.dta",clear
			keep if tot_complete==1
			ren code survey1_code
			keep survey1_code inc_mo 
			rename inc_mo inc_mo_bl
			cap drop _merge
			tempfile bl
			sa `bl'
			
			* Endline data
			u "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta",clear
			keep if tot_complete==1
			cap drop _merge
			
			keep code compound_code compound_code_prev move inc_mo cash_fee_month2_1-cash_fee_month2_31 liquidity_bind_date_1-liquidity_bind_date_31
			rename inc_mo inc_mo_el
			ren code survey1_code
			merge 1:1 survey1_code using `bl'
			cap drop _merge

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
				
				duplicates drop compound_code,force
				tempfile el
				sa `el'
			restore
			
		cap drop _merge
		merge 1:m compound_code using `el'
		drop if _merge==2
		
	keep if tmt==1 | tmt==2 | tmt==3
	
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
				
				duplicates drop compound_code,force
				
				tempfile el
				sa `el'
			restore
			
		cap drop _merge
		merge 1:m compound_code using `el'
	
			// Reverse liquidity
			cap drop revliq*
			revrs liquid_avg
			
			// Trust
			revrs trust4_bl
			revrs trust5_bl
			revrs trust6_bl
			revrs corr14_end_bl
			

	* Standardize

				foreach var in walls_final roof_final ravine sex_prop employed salaried job_gov main_tribe elect1_bl ///
				civic7_bl bus1_bl trust{
				cap replace `var' = `var'_orig
				cap gen `var'_orig = `var'
				sum `var'
				replace `var' = (`var'-`r(mean)')/(`r(sd)') //standardize
				}
				
	* Indices


		global econ_ind "moto_bl car_bl radio_bl tv_bl egen_bl sewmach_bl employed_prop_bl income_avg transport revliquid_avg elect1_bl"

				foreach index in econ_ind {
				foreach var in $`index'{
				cap replace `var' = `var'_orig
				cap gen `var'_orig = `var'
				sum `var'
				replace `var' = (`var'-`r(mean)')/(`r(sd)') //standardize
				}
				}

				foreach index in econ_ind { 
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
				
				foreach index in econ_ind {
				g `index'_repl = `index'
				foreach var in $`index'{
				replace `index'_repl = . if `var'==.
				}
				}

	
	* Leave-one-out mean
	foreach var in house_quality_new inc_mo_avg econ_ind{
		g a7_`var' = .
		g tmp_`var' = `var'!=.
		bys a7: egen N_`var' = sum(tmp_`var')
		bys a7: egen sum_`var' = sum(`var')
		replace a7_`var' = (sum_`var'-`var')/(N_`var'-1)
		replace a7_`var' = . if `var'==.
	}
	
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


* Variables
	gen CvsL=0 if tmt==1 
	replace CvsL=1 if tmt==2
	gen CvsCLI=0 if tmt==1 
	replace CvsCLI=1 if tmt==3
	gen CvsLvsCLI=0 if tmt==1 
	replace CvsLvsCLI=1 if tmt==2 
	replace CvsLvsCLI=2 if tmt==3

* Figures of Attributes for Tax Payers, Visited - Polygon-Level

* House Value

***********
* Panel A *
***********
preserve
keep if visit_post_carto==1
collapse (mean) house_quality_new (max) CvsL , by(a7)
ksmirnov house_quality_new, by(CvsL) exact
	local ks_p = round(`r(p_exact)',0.01)
	if `ks_p'==.{
		local ks_p = round(`r(p)',0.01)
	}
	if `ks_p'==0{
		local ks_p = "<0.01"
	}
distplot house_quality_new, over(CvsL) ///
legend(label(1 "Central") label(2 "Local") ///
ring(0) position(1) region(lstyle(none)))  ///
title("House Quality Index distribution of owners visited by collectors", size(large)) ///
subtitle("Central Collectors v. Local Collectors") ///
ytitle("Density") xtitle("House Quality Index (Walls)") graphregion(fcolor(white)) plotregion(color(white)) note("Kolmogorov-Smirnov equality-of-distributions test p-value = `ks_p'")
graph export "$reploutdir/dist_housequal_visited.pdf", replace
restore

***********
* Panel B *
***********
preserve
keep if taxes_paid==1
collapse (mean) house_quality_new (max) CvsL , by(a7)
ksmirnov house_quality_new, by(CvsL) exact
	local ks_p = round(`r(p_exact)',0.01)
	if `ks_p'==.{
		local ks_p = round(`r(p)',0.01)
	}
	if `ks_p'==0{
		local ks_p = "<0.01"
	}
distplot house_quality_new, over(CvsL) ///
legend(label(1 "Central") label(2 "Local") ///
ring(0) position(1) region(lstyle(none)))  ///
title("House Quality Index distribution of taxpayers", size(large)) ///
subtitle("Central Collectors v. Local Collectors") ///
ytitle("Density") xtitle("House Quality Index (Walls)") graphregion(fcolor(white)) plotregion(color(white)) note("Kolmogorov-Smirnov equality-of-distributions test p-value = `ks_p'")
graph export "$reploutdir/dist_housequal_taxpayers.pdf", replace
restore

* Income

***********
* Panel C *
***********
preserve
		keep if visit_post_carto==1
	collapse (mean) inc_mo_avg (max) CvsL , by(a7)
	ksmirnov inc_mo_avg, by(CvsL) exact
		local ks_p = round(`r(p_exact)',0.01)
		if `ks_p'==.{
			local ks_p = round(`r(p)',0.01)
		}
		if `ks_p'==0{
			local ks_p = "<0.01"
		}
	distplot inc_mo_avg, over(CvsL) ///
	legend(label(1 "Central") label(2 "Local") ///
	ring(0) position(1) region(lstyle(none)))  ///
	title("Income distribution of owners visited by collectors", size(large)) ///
	subtitle("Central Collectors v. Local Collectors") ///
	ytitle("Density") xtitle("Monthly Income") graphregion(fcolor(white)) plotregion(color(white)) note("Kolmogorov-Smirnov equality-of-distributions test p-value = `ks_p'")
	graph export "$reploutdir/dist_inc_visited.pdf", replace
restore

***********
* Panel D *
***********
preserve
	keep if taxes_paid==1
	collapse (mean) inc_mo_avg (max) CvsL , by(a7)
	ksmirnov inc_mo_avg, by(CvsL) exact
		local ks_p = round(`r(p_exact)',0.01)
		if `ks_p'==.{
			local ks_p = round(`r(p)',0.01)
		}
		if `ks_p'==0{
			local ks_p = "<0.01"
		}
	distplot inc_mo_avg, over(CvsL) ///
	legend(label(1 "Central") label(2 "Local") ///
	ring(0) position(1) region(lstyle(none)))  ///
	title("Income distribution of taxpayers", size(large)) ///
	subtitle("Central Collectors v. Local Collectors") ///
	ytitle("Density") xtitle("Monthly Income") graphregion(fcolor(white)) plotregion(color(white)) note("Kolmogorov-Smirnov equality-of-distributions test p-value = `ks_p'")
	graph export "$reploutdir/dist_inc_taxpayers.pdf", replace
restore

* Liquidity

***********
* Panel E *
***********
preserve
		keep if visit_post_carto==1
	collapse (mean) econ_ind (max) CvsL , by(a7)
	ksmirnov econ_ind, by(CvsL) exact
		local ks_p = round(`r(p_exact)',0.01)
		if `ks_p'==.{
			local ks_p = round(`r(p)',0.01)
		}
		if `ks_p'==0{
			local ks_p = "<0.01"
		}
	distplot econ_ind, over(CvsL) ///
	legend(label(1 "Central") label(2 "Local") ///
	ring(0) position(1) region(lstyle(none)))  ///
	title("Liquidity distribution of owners visited by collectors", size(large)) ///
	subtitle("Central Collectors v. Local Collectors") ///
	ytitle("Density") xtitle("Monthly Income") graphregion(fcolor(white)) plotregion(color(white)) note("Kolmogorov-Smirnov equality-of-distributions test p-value = `ks_p'")
	graph export "$reploutdir/dist_liq_visited.pdf", replace
restore

***********
* Panel F *
***********
preserve
	keep if taxes_paid==1
	collapse (mean) econ_ind (max) CvsL , by(a7)
	ksmirnov econ_ind, by(CvsL) exact
		local ks_p = round(`r(p_exact)',0.01)
		if `ks_p'==.{
			local ks_p = round(`r(p)',0.01)
		}
		if `ks_p'==0{
			local ks_p = "<0.01"
		}
		local ks_p = "0.95"
	distplot econ_ind, over(CvsL) ///
	legend(label(1 "Central") label(2 "Local") ///
	ring(0) position(1) region(lstyle(none)))  ///
	title("Liquidity distribution of taxpayers", size(large)) ///
	subtitle("Central Collectors v. Local Collectors") ///
	ytitle("Density") xtitle("Monthly Income") graphregion(fcolor(white)) plotregion(color(white)) note("Kolmogorov-Smirnov equality-of-distributions test p-value = `ks_p'")
	graph export "$reploutdir/dist_liq_taxpayers.pdf", replace
restore
