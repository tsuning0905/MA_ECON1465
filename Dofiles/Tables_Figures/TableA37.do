
*************
* Table A37 *
*************

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
	
	// Baseline and endline measures
	
		preserve
			
			* merge endline and baseline surveys
				u "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta",clear
				keep if tot_complete==1
				
				* Replace compound code with previous compound code
				replace compound_code=compound_code_prev if (move==1 | move==2)

				* Clean compound code 
				replace compound_code=999999 if compound_code==99999 | compound_code==9999999

				* Drop missing compound code
				drop if compound_code==999999	
				
				drop if compound_code==. 
					
				global reverse_variables = "corr14_end punish"
				
				revrs $reverse_variables , replace 
				
				foreach var in trust1_survey_e trust2_survey_e trust3_survey_e trust4_survey_e trust5_survey_e  trust6_survey_e {
				center `var' , inplace st
				}
				
				rename trust1_survey_e trust_chef
				rename trust5_survey_e trust_ngos
				rename trust6_survey_e trust_dgrkoc
				
				egen trust_gov = rowtotal(trust2_survey_e trust3_survey_e), missing
				center trust_gov , inplace st 

				foreach var in provide1 provide2 provide3 provide4 provide5 provide6 provide7 {
				g `var'_pg=`var'==2
				replace `var'_pg = . if `var'==.
				}
				
				egen pg_provide = rowtotal(*_pg), missing
				center pg_provide , inplace st 

				center conflict3 , gen(conflict_chief) st
				center conflict5 , gen(conflict_formal) st
				
				center demand2, gen(demand_chief) st
				egen demand_gov = rowtotal(demand5 demand4), missing
				center demand_gov, inplace st
				
				*Fill in chief vars if empty
				foreach var in chef4 chef_imp chef8 chef9 chef11 chef12 steal_chef_2018{
				replace `var' = `var'_2 if `var'==.
				} 
				
				center chef4, gen(responsiveness_chief) st
				center gov_resp, gen(responsiveness_gov) st
				center corr14_end, gen(performance_gov) st
				center chef_eval, gen(performance_chief) st
				center tax42, gen(performance_dgrkoc) st
				
				foreach var in chef8 chef9 chef11 chef12{
				center `var', inplace st
				}
				egen help_from_chief = rowtotal(chef8 chef9 chef11 chef12), missing
				center help_from_chief, inplace st
				
				g spend_chef_2018 = 1000-steal_chef_2018
				g spend_gov_2018 = 1000-steal_gov_2018

				center deposit_col_2018, gen(integrity_dgrkoc) st
				center spend_gov_2018, gen(integrity_gov) st
				center spend_chef_2018, gen(integrity_chief) st
				
				center morale, gen(tax_morale) st
				center punish, gen(punish_probability) st

				*Other outcomes we lack at baseline
				center taxnoncompliance3_survey_e, gen(punish_probability_all) st
				center tax_punish_severity, gen(punish_severity_all) st
				
				center chef_imp, gen(importance_chief) st
				center exempt_tribe, gen(coethnic_bias_chief) st

				center compliance_ave, gen(perceived_compliance_ave) st
				center compliance_kan, gen(perceived_compliance_kan) st
				
				center pubgoods_fromtax, inplace st
				center tax_imp, gen(importance_property_tax) s
				center tax_oblig, inplace s
				center taxmorale_survey_e, inplace s
				egen obligation_property_tax = rowtotal(tax_oblig taxmorale_survey_e), missing
				center obligation_property_tax, inplace s
				
				foreach var in fair_tax fair_rates fair_collectors{
				center `var', inplace s
				}
				egen fair_tax_all = rowtotal(fair_tax fair_rates fair_collectors), missing
				center fair_tax_all, inplace s
				
				egen tax_morale_all = rowtotal(tax_morale importance_property_tax pubgoods_fromtax tax_oblig taxmorale_survey_e)
				center tax_morale_all, inplace s
				
				egen gov_index = rowtotal(trust_gov responsiveness_gov performance_gov integrity_gov), missing
				center gov_index, inplace st
				
				egen chief_index = rowtotal(trust_chef responsiveness_chief performance_chief integrity_chief), missing
				center chief_index, inplace st
				
				global el_outcomes = "gov_index chief_index trust_chef trust_ngos trust_dgrkoc trust_gov pg_provide conflict_chief conflict_formal demand_chief demand_gov responsiveness_chief performance_chief responsiveness_gov performance_gov help_from_chief integrity_chief integrity_gov importance_chief tax_morale punish_probability punish_probability_all punish_severity_all coethnic_bias_chief perceived_compliance_ave perceived_compliance_kan importance_property_tax obligation_property_tax pubgoods_fromtax tax_morale_all fair_tax fair_rates fair_collectors fair_tax_all "
				
				foreach var in $el_outcomes {
				rename `var' `var'_el
				}
				
				* Bribe variables
				replace bribe = bribe2a if bribe==.
				replace bribe = bribe2b if bribe==.
				replace bribe = bribe3 if bribe==.
				replace bribe_amt = bribe2a_amt if bribe_amt==.
				replace bribe_amt = bribe2b_amt if bribe_amt==.
				replace bribe_amt = bribe3_amt if bribe_amt==.
				
				replace bribe_amt = 0 if bribe==0
				
				ren bribe bribe_el
				ren bribe_amt bribe_amt_el

				
				tempfile endline
				save `endline'
				

				**************************
				* Get baseline variables**
				**************************

				u "${repldir}/Data/01_base/survey_data/baseline_noPII.dta",clear
				keep if tot_complete==1 
				cap drop _merge
				
				global reverse_variables = "trust2 trust4 trust5 trust6 trust8 corr14_end punish"
				
				revrs $reverse_variables , replace 
				
				foreach var in trust2 trust4 trust5 trust6 trust8 {
				center `var' , inplace st
				}
				
				rename trust8 trust_chef
				rename trust6 trust_dgrkoc
				rename trust2 trust_ngos
				
				egen trust_gov = rowtotal(trust4 trust5), missing
				center trust_gov , inplace st 
					
				foreach var in provide1 provide4 provide5 provide2 provide3 provide6 provide7 { 
				g `var'_pg=`var'==2
				replace `var'_pg = . if `var'==.
				}
				
				egen pg_provide = rowtotal(*_pg), missing
				center pg_provide , inplace st 

				center conflict3 , gen(conflict_chief) st
				center conflict5 , gen(conflict_formal) st
				
				center demand2, gen(demand_chief) st
				egen demand_gov = rowtotal(demand4 demand5), missing
				center demand_gov, inplace st
				
				center chef4, gen(responsiveness_chief) st
				center gov_resp, gen(responsiveness_gov) st
				center corr14_end, gen(performance_gov) st
				center chef_eval, gen(performance_chief) st
				center tax42, gen(performance_dgrkoc) st
				
				foreach var in chef8 chef9 chef11 chef12{
				center `var', inplace st
				}
				egen help_from_chief = rowtotal(chef8 chef9 chef11 chef12), missing
				center help_from_chief, inplace st
				
				center gov1_end, gen(integrity_gov) st
				center chef_corr1, gen(integrity_chief) st
				
				center morale, gen(tax_morale) st
				center punish, gen(punish_probability) st
				
				egen gov_index = rowtotal(trust_gov responsiveness_gov performance_gov integrity_gov), missing
				center gov_index, inplace st
				
				egen chief_index = rowtotal(trust_chef responsiveness_chief performance_chief integrity_chief), missing
				center chief_index, inplace st
				
				global bl_outcomes = "gov_index chief_index trust_chef trust_ngos trust_dgrkoc trust_gov pg_provide conflict_chief conflict_formal demand_chief demand_gov responsiveness_chief performance_chief responsiveness_gov performance_gov help_from_chief integrity_chief integrity_gov tax_morale punish_probability"
				
				foreach var in $bl_outcomes {
				rename `var' `var'_bl
				}

				keep code a7 $bl_outcomes
				
				tempfile baseline
				save `baseline'
				
				*Merge in endline and randomization info
				
				use `endline', clear
				merge 1:1 code using `baseline'
				
				cap drop _merge
				
				keep compound_code *_el *_bl
				
				tempfile el
				sa `el'
			restore
			
		cap drop _merge
		ren compound1 compound_code
		merge 1:m compound_code using `el'
		
***********
* Panel A *
***********
	
		eststo clear
		
		g t_lXtaxes_paid = t_l*taxes_paid
		foreach var in gov_index trust_gov responsiveness_gov performance_gov chief_index trust_chef responsiveness_chief performance_chief{
		
		eststo: reg `var'_el t_l t_lXtaxes_paid taxes_paid `var'_bl i.house i.stratum if inlist(tmt,1,2), cl(a7)
		su `var'_el if taxes_paid==0 & e(sample)
		estadd local Mean =round(`r(mean)', 0.001)
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		}
		

	label var t_lXtaxes_paid "Local X Taxes Paid"
	label var taxes_paid "Taxes Paid"
		
	esttab using "${reploutdir}/views_tax.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l t_lXtaxes_paid taxes_paid) ///
	order(t_l t_lXtaxes_paid taxes_paid) ///
	scalar (Mean) ///
	nomtitles ///
	mgroups("Views of govt (index)" "Trust in govt" "Resp. of govt." "Perf. of govt." "Views of chief (index)" "Trust in chief" "Resp. of chief." "Perf. of chief.",  pattern(1 1 1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Stratum FE = *stratum*") ///
	nogaps nonotes compress
	
***********
* Panel B *
***********

		eststo clear
		
		g t_lXbribe_el = t_l*bribe_el
		foreach var in gov_index trust_gov responsiveness_gov performance_gov chief_index trust_chef responsiveness_chief performance_chief{
		
		eststo: reg `var'_el t_l t_lXbribe_el bribe_el `var'_bl i.house i.stratum if inlist(tmt,1,2), cl(a7)
		su `var'_el if taxes_paid==0 & e(sample)
		estadd local Mean =round(`r(mean)', 0.001)
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		}
		

	label var t_lXbribe_el "Local X Bribe Paid"
	label var bribe_el "Bribe Paid"
		
	esttab using "${reploutdir}/views_bribe.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l t_lXbribe_el bribe_el) ///
	order(t_l t_lXbribe_el bribe_el) ///
	scalar (Mean) ///
	nomtitles ///
	mgroups("Views of govt (index)" "Trust in govt" "Resp. of govt." "Perf. of govt." "Views of chief (index)" "Trust in chief" "Resp. of chief." "Perf. of chief.",  pattern(1 1 1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Stratum FE = *stratum*") ///
	nogaps nonotes compress
