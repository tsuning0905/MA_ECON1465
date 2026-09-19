
**************
* Figure A12 *
**************

	// Load data and define variables
	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
	keep if tmt==1 | tmt==2 | tmt==3
	
	cap g taxes_paid_carto = 0 if taxes_paid!=.
	replace taxes_paid_carto = 1 if collect_success==1
	
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
		
		g walls_new = 0 if inlist(walls_final,0,1)
		replace walls_new = 1 if inlist(walls_final,2,3,4)
				
		g walls_modern = 1 if inlist(walls_final,3,4)
		replace walls_modern = 0 if inlist(walls_final,0,1,2)

		g roof_new = 0 if inlist(roof_final,1,2,3,4)
		replace roof_new = 1 if inlist(roof_final,7,8)

		global house_quality = "walls_final roof_final"
		global house_quality_new = "walls_new"
		global age_adj = "age_prop"

		foreach index in house_quality house_quality_new age_adj{ 
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
		
		ren edu edu_ml
		ren edu2 edu2_ml
	
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
				
				tempfile el
				sa `el'
			restore
			
		cap drop _merge
		ren compound1 compound_code
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
		
				global educ_yrs_ind "educ_yrs_prop"
				global educ_lvl_ind  "educ_lvl_prop"
				foreach index in educ_lvl_ind educ_yrs_ind{ 
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
				
			//  Chief vars
			replace chef1_bl = . if chef1_bl==4
			replace chef2_bl = . if chef2_bl==4
			revrs chef1_bl
			revrs chef2_bl
			revrs chef_eval_bl
			revrs trust_chef
			
			// Reverse liquidity
			cap drop revliq*
			revrs liquid_avg
			
			// Trust
			revrs trust4_bl
			revrs trust5_bl
			revrs trust6_bl
			revrs corr14_end_bl
			
***************
* Standardize *
***************

				foreach var in walls_final roof_final ravine sex_prop employed salaried job_gov main_tribe elect1_bl ///
				civic7_bl bus1_bl trust{
				cap replace `var' = `var'_orig
				cap gen `var'_orig = `var'
				sum `var'
				replace `var' = (`var'-`r(mean)')/(`r(sd)') //standardize
				}
				
***********
* Indices *
***********

global paytax_ind "tax13_bl"
global econ_ind "moto_bl car_bl radio_bl tv_bl egen_bl sewmach_bl employed_prop_bl income_avg transport revliquid_avg elect1_bl"
global govmorale_ind "revtrust4_bl revtrust5_bl revtrust6_bl revcorr14_end_bl gov1_end_bl"
global unobs_ind "tax13_bl moto_bl car_bl radio_bl tv_bl egen_bl sewmach_bl employed_prop_bl income_avg transport revliquid_avg elect1_bl revtrust4_bl revtrust5_bl revtrust6_bl revcorr14_end_bl gov1_end_bl"
global cheflegit_ind "chef4_bl revchef_eval_bl chef_corr1_bl revtrust_chef"
global chefconn1fam_ind "chef0_bl"
global chefconn2know_ind "revchef1_bl revchef2_bl chef3_bl"
global chefconn3serv_ind "chef11_bl chef12_bl"

				foreach index in paytax_ind econ_ind govmorale_ind unobs_ind cheflegit_ind chefconn1fam_ind chefconn2know_ind chefconn3serv_ind{
				foreach var in $`index'{
				cap replace `var' = `var'_orig
				cap gen `var'_orig = `var'
				sum `var'
				replace `var' = (`var'-`r(mean)')/(`r(sd)') //standardize
				}
				}

				foreach index in paytax_ind econ_ind govmorale_ind unobs_ind cheflegit_ind chefconn1fam_ind chefconn2know_ind chefconn3serv_ind{ 
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
				
				foreach index in paytax_ind econ_ind govmorale_ind unobs_ind cheflegit_ind chefconn1fam_ind chefconn2know_ind chefconn3serv_ind{
				g `index'_repl = `index'
				foreach var in $`index'{
				replace `index'_repl = . if `var'==.
				}
				}

	global testvars "chefconn1fam_ind chefconn2know_ind chefconn3serv_ind"

***********
* Panel A *
***********

		mat L = J(6,2,.)
		mat CLI = J(6,2,.)

		local i = 1
		
		foreach var in $testvars{
		
		* Leave-one-out mean
		cap g a7_`var' = .
		cap g tmp_`var' = `var'!=.
		cap bys a7: egen N_`var' = sum(tmp_`var')
		cap bys a7: egen sum_`var' = sum(`var')
		cap replace a7_`var' = (sum_`var'-`var')/(N_`var'-1)
		cap replace a7_`var' = . if `var'==.
		
		reg `var' t_l  i.time_FE_tdm_2mo_CvL a7_`var' i.house i.stratum if visit_post_carto==1 & inlist(tmt,1,2) & taxes_paid_carto==0,cluster(a7)
		mat L[`i',1]=_b[t_l]
		mat L[`i',2]=_se[t_l]
		
		reg `var' t_l  i.time_FE_tdm_2mo_CvL a7_`var' i.house i.stratum if nb_visit_post_carto>1 & nb_visit_post_carto<. & inlist(tmt,1,2) & taxes_paid_carto==0,cluster(a7)
		mat L[`i'+1,1]=_b[t_l]
		mat L[`i'+1,2]=_se[t_l]
		
		reg `var' t_cli  i.time_FE_tdm_2mo_CvCLI a7_`var' i.house i.stratum if visit_post_carto==1 & inlist(tmt,1,3) & taxes_paid_carto==0,cluster(a7)
		mat CLI[`i',1]=_b[t_cli]
		mat CLI[`i',2]=_se[t_cli]
		
		reg `var' t_cli  i.time_FE_tdm_2mo_CvCLI a7_`var' i.house i.stratum if nb_visit_post_carto>1 & nb_visit_post_carto<. & inlist(tmt,1,3) & taxes_paid_carto==0,cluster(a7)
		mat CLI[`i'+1,1]=_b[t_cli]
		mat CLI[`i'+1,2]=_se[t_cli]
		
		local i = `i' + 2
		}
		
	
		foreach matrix in L CLI{
		preserve
			clear
			svmat `matrix'
			ren `matrix'1 b
			ren `matrix'2 se
			g id = _n
			g tmt = "`matrix'"
			
			g id2 = .
			replace id2 = 1 if inlist(id,1,2)
			replace id2 = 2 if inlist(id,3,4)
			replace id2 = 3 if inlist(id,5,6)
			replace id2 = 4 if inlist(id,7,8)
			replace id2 = 5 if inlist(id,9,10)
			replace id2 = 6 if inlist(id,11,12)
			replace id2 = 7 if inlist(id,13,14)
			
			drop if inlist(id,2,4,6,8,10,12,14)
			
			replace id2 = id2+0.25 if tmt=="L" &  inlist(id,1,3,5,7,9,11,13)
			replace id2 = id2-0.25 if tmt=="CLI" &  inlist(id,1,3,5,7,9,11,13)
			
			drop id
			ren id2 id
			
			tempfile `matrix'
			sa ``matrix''
		restore	
		}
			
		preserve
			clear
			foreach matrix in L CLI{
			append using ``matrix''
			}
			
			g ub = b+1.96*se
			g lb = b-1.96*se
			
			g ub90 = b+1.645*se
			g lb90 = b-1.645*se
				
				replace id = id+1 if id>6.5
				
				replace ub = 1 if ub>1
				replace ub90 = 1 if ub90>1
				
				replace lb = -1 if lb<-1
				replace lb90 = -1 if lb90<-1
				
			
			tw (rspike ub lb id if tmt=="L" & inlist(id,1.25,2.25,3.25,4.25,5.25,6.25) & id<7,horiz lc(gs10) lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="L" & inlist(id,1.25,2.25,3.25,4.25,5.25,6.25) & id<7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="L" & inlist(id,1.25,2.25,3.25,4.25,5.25,6.25) & id<7,msize(small) m(diamond) mlc(blue*0.4) mfc(blue*0.4) mlw(thin)) ///
			(rspike ub lb id if tmt=="CLI" & (inlist(id,0.75,1.75,2.75,3,75,4.75,5.75,6.75)|(id>3.6&id<3.8)) & id<7,horiz lc(gs10)  lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="CLI" & (inlist(id,0.75,1.75,2.75,3,75,4.75,5.75,6.75)|(id>3.6&id<3.8)) & id<7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="CLI" & (inlist(id,0.75,1.75,2.75,3,75,4.75,5.75,6.75)|(id>3.6&id<3.8)) & id<7,msize(medsmall) m(circle) mlc(red*0.4) mfc(red*0.4) mlw(thin)) ///
					///
			(rspike ub lb id if tmt=="L" & inlist(id,8.25) & id>7,horiz lc(gs10) lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="L" & inlist(id,8.25) & id>7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="L" & inlist(id,8.25) & id>7,msize(small) m(diamond) mlc(blue*0.4) mfc(blue*0.4) mlw(thin)) ///
			(rspike ub lb id if tmt=="CLI" & inlist(id,7.75) & id>7,horiz lc(gs10)  lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="CLI" & inlist(id,7.75) & id>7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="CLI" & inlist(id,7.75) & id>7,msize(medsmall) m(circle) mlc(red*0.4) mfc(red*0.4) mlw(thin)) ///
			,graphregion(fc(white)) ///
			ylab(1 "Chief Family Member" 2 "Chief Know Index" 3 "Chief Services Index",labsize(small)) ///
			xtitle(" " "Difference relative to Central (among Visited)",size(small)) legend(order(3 6) label(3 "Local") label(6 "CLI") ring(0) pos(2)) ///
			ytick(1 2 3) yscale(range(1 3)) ///
			ytitle("") xline(0,lw(vthin) lc(gs10))
			graph export "${reploutdir}/chief_indices_CvL.pdf",replace
		restore
		
***********
* Panel B *
***********

		mat L = J(6,2,.)
		mat CLI = J(6,2,.)

		local i = 1
		
		foreach var in $testvars{
		
		* Leave-one-out mean
		cap g a7_`var' = .
		cap g tmp_`var' = `var'!=.
		cap bys a7: egen N_`var' = sum(tmp_`var')
		cap bys a7: egen sum_`var' = sum(`var')
		cap replace a7_`var' = (sum_`var'-`var')/(N_`var'-1)
		cap replace a7_`var' = . if `var'==.
		
		reg `var' t_l  i.time_FE_tdm_2mo_CvL a7_`var' i.house i.stratum if visit_post_carto==1 & inlist(tmt,1,2) & taxes_paid_carto==0,cluster(a7)
		mat L[`i',1]=_b[t_l]
		mat L[`i',2]=_se[t_l]
		
		reg `var' t_l  i.time_FE_tdm_2mo_CvL a7_`var' i.house i.stratum if nb_visit_post_carto>1 & nb_visit_post_carto<. & inlist(tmt,1,2) & taxes_paid_carto==0,cluster(a7)
		mat L[`i'+1,1]=_b[t_l]
		mat L[`i'+1,2]=_se[t_l]
		
		reg `var' t_cli  i.time_FE_tdm_2mo_LvCLI a7_`var' i.house i.stratum if visit_post_carto==1 & inlist(tmt,2,3) & taxes_paid_carto==0,cluster(a7)
		mat CLI[`i',1]=_b[t_cli]
		mat CLI[`i',2]=_se[t_cli]
		
		reg `var' t_cli  i.time_FE_tdm_2mo_LvCLI a7_`var' i.house i.stratum if nb_visit_post_carto>1 & nb_visit_post_carto<. & inlist(tmt,2,3) & taxes_paid_carto==0,cluster(a7)
		mat CLI[`i'+1,1]=_b[t_cli]
		mat CLI[`i'+1,2]=_se[t_cli]
		
		local i = `i' + 2
		}
		
	
		foreach matrix in L CLI{
		preserve
			clear
			svmat `matrix'
			ren `matrix'1 b
			ren `matrix'2 se
			g id = _n
			g tmt = "`matrix'"
			
			g id2 = .
			replace id2 = 1 if inlist(id,1,2)
			replace id2 = 2 if inlist(id,3,4)
			replace id2 = 3 if inlist(id,5,6)
			replace id2 = 4 if inlist(id,7,8)
			replace id2 = 5 if inlist(id,9,10)
			replace id2 = 6 if inlist(id,11,12)
			replace id2 = 7 if inlist(id,13,14)
			
			drop if inlist(id,2,4,6,8,10,12,14)
			
			replace id2 = id2+0.25 if tmt=="L" &  inlist(id,1,3,5,7,9,11,13)
			replace id2 = id2 if tmt=="CLI" &  inlist(id,1,3,5,7,9,11,13)
			
			drop id
			ren id2 id
			
			tempfile `matrix'
			sa ``matrix''
		restore	
		}
			
		preserve
			clear
			foreach matrix in CLI{
			append using ``matrix''
			}
			
			g ub = b+1.96*se
			g lb = b-1.96*se
			
			g ub90 = b+1.645*se
			g lb90 = b-1.645*se
				
				replace id = id+1 if id>6.5
				
				replace ub = 1 if ub>1
				replace ub90 = 1 if ub90>1
				
				replace lb = -1 if lb<-1
				replace lb90 = -1 if lb90<-1
				
			
			tw (rspike ub lb id if tmt=="L" & inlist(id,1.25,2.25,3.25,4.25,5.25,6.25) & id<7,horiz lc(gs10) lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="L" & inlist(id,1.25,2.25,3.25,4.25,5.25,6.25) & id<7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="L" & inlist(id,1.25,2.25,3.25,4.25,5.25,6.25) & id<7,msize(small) m(diamond) mlc(blue*0.4) mfc(blue*0.4) mlw(thin)) ///
			(rspike ub lb id if tmt=="CLI" & (inlist(id,1,2,3,4,5,6)) & id<7,horiz lc(gs10)  lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="CLI" & (inlist(id,1,2,3,4,5,6)) & id<7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="CLI" & (inlist(id,1,2,3,4,5,6)) & id<7,msize(medsmall) m(circle) mlc(red*0.4) mfc(red*0.4) mlw(thin)) ///
					///
			(rspike ub lb id if tmt=="L" & inlist(id,8.25) & id>7,horiz lc(gs10) lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="L" & inlist(id,8.25) & id>7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="L" & inlist(id,8.25) & id>7,msize(small) m(diamond) mlc(blue*0.4) mfc(blue*0.4) mlw(thin)) ///
			(rspike ub lb id if tmt=="CLI" & inlist(id,8) & id>7,horiz lc(gs10)  lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="CLI" & inlist(id,8) & id>7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="CLI" & inlist(id,8) & id>7,msize(medsmall) m(circle) mlc(red*0.4) mfc(red*0.4) mlw(thin)) ///
			,graphregion(fc(white)) ///
			ylab(1 "Chief Family Member" 2 "Chief Know Index" 3 "Chief Services Index",labsize(small) angle(0)) ///
			xtitle(" " "Difference relative to Local (among Visited)",size(small)) legend(order(6) label(6 "CLI") ring(0) pos(2)) ///
			ytick(1 2 3) yscale(range(1 3)) ///
			ytitle("") xline(0,lw(vthin) lc(gs10))
			graph export "${reploutdir}/chief_indices_LvCLI.pdf",replace
		restore
		
***********
* Panel C *
***********

		mat L = J(6,2,.)
		mat CLI = J(6,2,.)
		mat C = J(6,2,.)

		local i = 1
		
		foreach var in $testvars{
		
		* Leave-one-out mean
		cap g a7_`var' = .
		cap g tmp_`var' = `var'!=.
		cap bys a7: egen N_`var' = sum(tmp_`var')
		cap bys a7: egen sum_`var' = sum(`var')
		cap replace a7_`var' = (sum_`var'-`var')/(N_`var'-1)
		cap replace a7_`var' = . if `var'==.
		
		reg visit_post_carto `var'  i.time_FE_tdm_2mo_CvL a7_`var' i.house i.stratum if t_l==1 & inlist(tmt,1,2) & taxes_paid_carto==0,cluster(a7)
		mat L[`i',1]=_b[`var']
		mat L[`i',2]=_se[`var']
		
		reg nb_visit_post_carto `var'  i.time_FE_tdm_2mo_CvL a7_`var' i.house i.stratum if t_l==1 & inlist(tmt,1,2) & taxes_paid_carto==0,cluster(a7)
		mat L[`i'+1,1]=_b[`var']
		mat L[`i'+1,2]=_se[`var']
		
		reg visit_post_carto `var' i.time_FE_tdm_2mo_CvL a7_`var' i.house i.stratum if t_cli==1 & inlist(tmt,1,3) & taxes_paid_carto==0,cluster(a7)
		mat CLI[`i',1]=_b[`var']
		mat CLI[`i',2]=_se[`var']
		
		reg nb_visit_post_carto `var' i.time_FE_tdm_2mo_CvL a7_`var' i.house i.stratum if t_cli==1 & inlist(tmt,1,3) & taxes_paid_carto==0,cluster(a7)
		mat CLI[`i'+1,1]=_b[`var']
		mat CLI[`i'+1,2]=_se[`var']
		
		reg visit_post_carto `var' i.time_FE_tdm_2mo_CvL a7_`var' i.house i.stratum if t_c==1 & inlist(tmt,1,3) & taxes_paid_carto==0,cluster(a7)
		mat C[`i',1]=_b[`var']
		mat C[`i',2]=_se[`var']
		
		reg nb_visit_post_carto `var' i.time_FE_tdm_2mo_CvL a7_`var' i.house i.stratum if t_c==1 & inlist(tmt,1,3) & taxes_paid_carto==0,cluster(a7)
		mat C[`i'+1,1]=_b[`var']
		mat C[`i'+1,2]=_se[`var']
		
		local i = `i' + 2
		}
		
		
		foreach matrix in L CLI C{
		preserve
			clear
			svmat `matrix'
			ren `matrix'1 b
			ren `matrix'2 se
			g id = _n
			g tmt = "`matrix'"
			
			g id2 = .
			replace id2 = 1 if inlist(id,1,2)
			replace id2 = 2 if inlist(id,3,4)
			replace id2 = 3 if inlist(id,5,6)
			replace id2 = 4 if inlist(id,7,8)
			replace id2 = 5 if inlist(id,9,10)
			replace id2 = 6 if inlist(id,11,12)
			replace id2 = 7 if inlist(id,13,14)
			
			drop if inlist(id,2,4,6,8,10,12,14)
			
			replace id2 = id2+0.25 if tmt=="L" &  inlist(id,1,3,5,7,9,11,13)
			replace id2 = id2-0.25 if tmt=="CLI" &  inlist(id,1,3,5,7,9,11,13)
			
			drop id
			ren id2 id
			
			tempfile `matrix'
			sa ``matrix''
		restore	
		}
			
		preserve
			clear
			foreach matrix in L CLI  C{
			append using ``matrix''
			}
			
			g ub = b+1.96*se
			g lb = b-1.96*se
			
			g ub90 = b+1.645*se
			g lb90 = b-1.645*se
			
				replace id = id+1 if id>6.5
				
				drop if id>5.25
			
			tw (rspike ub lb id if tmt=="L" & inlist(id,1.25,2.25,3.25,4.25,5.25,6.25) & id<7,horiz lc(gs10) lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="L" & inlist(id,1.25,2.25,3.25,4.25,5.25,6.25) & id<7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="L" & inlist(id,1.25,2.25,3.25,4.25,5.25,6.25) & id<7,msize(small) m(diamond) mlc(blue*0.4) mfc(blue*0.4) mlw(thin)) ///
			(rspike ub lb id if tmt=="CLI" & (inlist(id,0.75,1.75,2.75,3,75,4.75,5.75,6.75)|(id>3.6&id<3.8)) & id<7,horiz lc(gs10)  lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="CLI" & (inlist(id,0.75,1.75,2.75,3,75,4.75,5.75,6.75)|(id>3.6&id<3.8)) & id<7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="CLI" & (inlist(id,0.75,1.75,2.75,3,75,4.75,5.75,6.75)|(id>3.6&id<3.8)) & id<7,msize(medsmall) m(circle) mlc(red*0.4) mfc(red*0.4) mlw(thin)) ///
			(rspike ub lb id if tmt=="C" & (inlist(id,1,2,3,4,5,6)) & id<7,horiz lc(gs10)  lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="C" & (inlist(id,1,2,3,4,5,6)) & id<7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="C" & (inlist(id,1,2,3,4,5,6)) & id<7,msize(medsmall) m(circle) mlc(gs6*0.4) mfc(gs6*0.4) mlw(thin)) ///
					///
			(rspike ub lb id if tmt=="L" & inlist(id,8.25) & id>7,horiz lc(gs10) lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="L" & inlist(id,8.25) & id>7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="L" & inlist(id,8.25) & id>7,msize(small) m(diamond) mlc(blue*0.4) mfc(blue*0.4) mlw(thin)) ///
			(rspike ub lb id if tmt=="CLI" & inlist(id,7.75) & id>7,horiz lc(gs10)  lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="CLI" & inlist(id,7.75) & id>7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="CLI" & inlist(id,7.75) & id>7,msize(medsmall) m(circle) mlc(red*0.4) mfc(red*0.4) mlw(thin)) ///
			(rspike ub lb id if tmt=="C" & inlist(id,8) & id>7,horiz lc(gs10)  lwid(vthin)) ///
					(rspike ub90 lb90 id if tmt=="C" & inlist(id,8) & id>7,horiz lc(gs10) lwid(medium)) ///
					(scatter id b if tmt=="C" & inlist(id,8) & id>7,msize(medsmall) m(circle) mlc(gs6*0.4) mfc(gs6*0.4) mlw(thin)) ///
			,graphregion(fc(white)) ///
			ylab(1 "Chief Family Member" 2 "Chief Know Index" 3 "Chief Services Index",labsize(small) angle(0)) ///
			xtitle(" " "Correlations with Visited",size(small)) legend(order(3 6 9) label(3 "Local") label(6 "CLI") label(9 "Central") ring(0) pos(2)) ///
			ytick(1 2 3) yscale(range(1 3)) ///
			ytitle("") xline(0,lw(vthin) lc(gs10))
			graph export "${reploutdir}/chief_indices_bytmt.pdf",replace
		restore
		
