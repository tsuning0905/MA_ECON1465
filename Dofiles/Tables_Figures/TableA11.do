
*************
* Table A11 *
*************

********************
* Prepare datasets *
********************

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
		u "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta",clear
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

***********************************************
*** Export condensed treatment effect table ***
***********************************************

#delimit ;
global dependent_variables =  "salongo salongo_hours salongo_endline salongo_hours_endline
							   paid_vehicletax_survey_e paid_mktvendorfee_survey_e
							   paid_businessfee_survey_e paid_incometax_survey_e
							   paid_faketax_survey_e";
#delimit cr

local counter = 0
eststo clear
foreach depvar in $dependent_variables  {
local counter = `counter' + 1
cap confirm variable `depvar'
	if `counter'<=2{
	u `midline',clear
	reg `depvar' t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(treatment,1,2), cluster(a7)
	}
	if `counter'>=3 {
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
if `counter'<=2{
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
	mmat2tex reg using "fiscal_externalities.tex", replace  ///
	colnames(beta SE r2 N centralmean) ///
	rownames("Salongo (Midline)" "Salongo Hours (Midline)" "Salongo (Endline)" "Salongo Hours (Endline)" ///
	"Vehicle Tax" "Market Vendor Fee" "Business Tax" "Income Tax" "Fake Tax") ///
	preheader("{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \begin{tabular}{l*{5}{c}} \hline\hline") ///
	bottom("\hline\hline \end{tabular} }") ///
	fmt(%9.3f)
