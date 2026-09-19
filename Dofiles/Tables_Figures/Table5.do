***********
* Table 5 *
***********

******************
* Panels A and B *
******************

	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	keep if tmt==1 | tmt==2 | tmt==3

	* Outcomes
	gen enum_disagrees_exempt=0 if exempt_enum!=. & exempt!=.
	replace enum_disagrees_exempt=1 if exempt!=exempt_enum & exempt_enum!=. & exempt!=.

	g house_type = 0 if house==1
	replace house_type = 1 if house==2
	revrs correct
	replace revcorrect = revcorrect-1
	ren revcorrect enum_disagrees_house
	
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
	
	replace bribe_combined_amt=0 if bribe_combined==0
	
	g gap_midline = 0 if taxes_paid==0 & paid_self==0
	replace gap_midline = 1 if taxes_paid==0 & paid_self==1
	
	replace salongo_hours = 0 if salongo==0
	replace salongo_hours = . if salongo_hours==99999
	
	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
	egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
	egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
	egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
	
	cap drop treatment
	ren tmt treatment
	
	eststo clear
	label var t_l "Local"
	
	tempfile midline
	sa `midline'
		
	* Merge endline not on compound code
		use "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta", clear
		keep if tot_complete==1 
		replace compound_code=compound_code_prev if (compound_code_prev!=. & compound_code_prev!=3)
		rename compound_code compound1
			
		* Bribe variables
			replace bribe = bribe2a if bribe==.
			replace bribe = bribe2b if bribe==.
			replace bribe = bribe3 if bribe==.
			replace bribe_amt = bribe2a_amt if bribe_amt==.
			replace bribe_amt = bribe2b_amt if bribe_amt==.
			replace bribe_amt = bribe3_amt if bribe_amt==.
			
			replace bribe_amt = 0 if bribe==0
			
			ren bribe bribe_endline
			ren bribe_amt bribe_amt_endline
			
			ren o_pay2 informal_pay_endline
			ren pay_tot2 informal_pay_amt_endline
				replace informal_pay_amt_endline = . if informal_pay_amt_endline==8885 // looks like enum coding error
			
			ren paid_self paid_self_endline
			
			* Salongo variables
			g salongo_endline = 0 if salongo==0
			replace salongo_endline = 1 if salongo>0 & salongo<.
			
			g salongo_hours_endline = salongo_hours
			replace salongo_hours_endline = . if salongo_hours==16000 | salongo_hours==60000 // obvious outliers
			replace salongo_hours_endline = 0 if salongo_endline==0
			
			keep code a7 *_endline paid_*
			
			cap drop _merge
			cap drop tmt
			cap drop treatment
			
			preserve
				use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
				collapse (max) tmt stratum,by(a7)
				ren tmt treatment
				tempfile tmt
				sa `tmt'
			restore
			
			merge m:1 a7 using `tmt', nogen keep(3)
			
					g t_l = treatment==2
					g t_c = treatment==1
		
			tempfile endline
			save `endline'

* Export table

#delimit ;
global dependent_variables =  "exempt enum_disagrees_exempt house_type enum_disagrees_house
							   bribe_combined gap_midline bribe_endline informal_pay_endline";
#delimit cr

local counter = 0
eststo clear
foreach depvar in $dependent_variables  {
local counter = `counter' + 1
cap confirm variable `depvar'
	if `counter'<=2 | (`counter'==5) | (`counter'==6){
	u `midline',clear
	reg `depvar' t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(treatment,1,2), cluster(a7)
	}
	if `counter'==3 | `counter'==4{
	u `midline',clear
	reg `depvar' t_l i.stratum i.time_FE_tdm_2mo_CvL if inlist(treatment,1,2), cluster(a7)
	}
	if `counter'==7 | (`counter'==8){
	u `endline',clear
	reg `depvar' t_l i.stratum if inlist(treatment,1,2), cluster(a7)
	}
local beta = round(_b[t_l],.001)
di "Beta: `beta'"
local se = round(_se[t_l],.001)
di "SE: `se'"
local p = round(2*ttail(e(df_r), abs(_b[t_l]/_se[t_l])),.001)
di "p-value: `p'"
local obs = round(`e(N)',1)
di "N:`obs'"
local clust = round(`e(N_clust)',1)
di "Clusters:`clust'"
local r2 = `e(r2)' 
di "R2:`r2'"
if `counter'<=2 | (`counter'==4) | (`counter'==5) | (`counter'==6) | (`counter'==3){
sum `depvar' if t_c==1 & time_FE_tdm_2mo_CvL!=.
}
else{
sum `depvar' if t_c==1
}
local centralmean = round(`r(mean)',.001)
di "Central mean:`centralmean'"

	if `counter' == 1 { 
		mat input reg = (`beta', `se',`r2',`obs',`centralmean') 
		mat rownames reg = `depvar' 
		mat colnames reg = beta SE r2 N centralmean	 
	}
	
	if `counter' > 1 { 
		mat input reg`counter' = (`beta', `se',`r2',`obs',`centralmean') 
		mat rownames reg`counter' = `depvar' 
		mat colnames reg`counter' = beta SE r2 N centralmean	 
		mat reg = (reg \ reg`counter' )
	}
}
	mata reg = st_matrix("reg") 
	mat list reg 	
	
	cd "$reploutdir"
	mmat2tex reg using "assessment_bribes.tex", replace  ///
	colnames(beta SE r2 N centralmean) ///
	rownames("Assigned Exemption" "Incorrect Exemption" "Assigned High Band" "Incorrect Assignment" ///
	"Paid Bribe (Midline)" "Gap Self v. Admin (Midline)" "Paid Bribe (Endline)" "Other Payments (Endline)") ///
	preheader("{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \begin{tabular}{l*{5}{c}} \hline\hline") ///
	bottom("\hline\hline \end{tabular} }") ///
	fmt(%9.3f)
	
**********************
* Panels C, D, and E *
**********************

	* merge endline and baseline surveys
	use "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta", clear
	keep if tot_complete==1 
	replace compound_code=compound_code_prev if (compound_code_prev!=. & compound_code_prev!=3)
	rename compound_code compound1
		
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
	
	* Fill in chief vars if empty
	foreach var in chef4 chef_imp chef8 chef9 chef11 chef12 steal_chef_2018{
	replace `var' = `var'_2 if `var'==.
	} 
	
	* Code indices and center variables
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

	
	tempfile endline
	save `endline'

	* Get baseline variables

	use "${repldir}/Data/01_base/survey_data/baseline_noPII.dta", clear
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
	
	* Merge in endline and randomization info
	
	use `endline', clear
	merge 1:1 code using `baseline'
	
	cap drop _merge
	cap drop treatment
	
	preserve
		use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
		collapse (max) tmt stratum,by(a7)
		ren tmt treatment
		tempfile tmt
		sa `tmt'
	restore
	
	merge m:1 a7 using `tmt', nogen keep(3)
	
	g t_l = treatment==2
	g t_c = treatment==1
	
	g female = sex=="Female"
	g age2 = age*age
	
* Export condensed treatment effect table

global covariates = "age age2 female"

global outcomes_with_bl =  "trust_chef trust_ngos trust_dgrkoc trust_gov pg_provide conflict_chief conflict_formal demand_chief demand_gov responsiveness_chief responsiveness_gov performance_gov help_from_chief integrity_chief integrity_gov tax_morale punish_probability"

foreach depvar in $outcomes_with_bl {
	reg `depvar'_el t_l i.stratum if inlist(treatment,1,2), cluster(a7)
	reg `depvar'_el t_l `depvar'_bl i.stratum if inlist(treatment,1,2), cluster(a7)
}


* Version with no baseline controls 


global outcomes_no_bl = "importance_chief punish_probability_all punish_severity_all coethnic_bias_chief perceived_compliance_ave perceived_compliance_kan importance_property_tax obligation_property_tax pubgoods_fromtax tax_morale_all fair_tax fair_rates fair_collectors fair_tax_all"


foreach depvar in $outcomes_no_bl {
	reg `depvar'_el t_l i.stratum if inlist(treatment,1,2), cluster(a7)
	reg `depvar'_el t_l i.stratum $covariates if inlist(treatment,1,2), cluster(a7)
}

* Export table

global dependent_variables =  "gov_index trust_gov responsiveness_gov performance_gov integrity_gov perceived_compliance_ave trust_dgrkoc tax_morale fair_tax_all punish_probability"

local counter = 0
eststo clear
foreach depvar in $dependent_variables  {
local counter = `counter' + 1
cap confirm variable `depvar'_bl
	if !_rc {
	reg `depvar'_el t_l `depvar'_bl i.stratum if inlist(treatment,1,2), cluster(a7)
	}
	else {
	reg `depvar'_el t_l i.stratum if inlist(treatment,1,2), cluster(a7)
	}
local beta = round(_b[t_l],.001)
di "Beta: `beta'"
local se = round(_se[t_l],.001)
di "SE: `se'"
local p = round(2*ttail(e(df_r), abs(_b[t_l]/_se[t_l])),.001)
di "p-value: `p'"
local obs = round(`e(N)',1)
di "N:`obs'"
local clust = round(`e(N_clust)',1)
di "Clusters:`clust'"
local r2 = `e(r2)' 
di "R2:`r2'"
sum `depvar'_el if t_c==1
local centralmean = round(`r(mean)',.001)
di "Central mean:`centralmean'"

	if `counter' == 1 { 
		mat input reg = (`beta', `se',`r2',`obs',`centralmean') 
		mat rownames reg = `depvar' 
		mat colnames reg = beta SE r2 N centralmean	 
	}
	
	if `counter' > 1 { 
		mat input reg`counter' = (`beta', `se',`r2',`obs',`centralmean') 
		mat rownames reg`counter' = `depvar' 
		mat colnames reg`counter' = beta SE r2 N centralmean	 
		mat reg = (reg \ reg`counter' )
	}
}
	mata reg = st_matrix("reg") 
	mat list reg 	
	
	cd "$reploutdir"
	mmat2tex reg using "attitudes.tex", replace  ///
	colnames(beta SE r2 N centralmean) ///
	rownames("View of government (index)" "Trust in government" "Responsiveness of government" "Performance of government" "Integrity of government" "Perceived tax compliance on avenue" "Trust in tax ministry" "Property tax morale" "Fairness of property taxation" "Perception of enforcement") ///
	preheader("{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \begin{tabular}{l*{5}{c}} \hline\hline") ///
	bottom("\hline\hline \end{tabular} }") ///
	fmt(%9.3f)
