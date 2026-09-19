**********************************
*** Collector endline analysis ***
**********************************

/*

endline_collector_traits_small.tex - Table A43

collector_amotivation.tex - Table A44

bribe_chief_worried_sanctions_cols1-3 - Table A14 


*/


*****************
* Prepare Data *
*****************

	
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* merge collector information from polygon level dataset
merge m:1 a7 using  "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match) nogen
keep a7 tmt tmt_2016 col1_chef_code col2_chef_code col1_colcode col2_colcode
duplicates drop
drop if tmt==.

replace col1_chef_code2 = col2_chef_code2 if col1_chef_code2 == . 
replace col1_colcode = col2_colcode if col1_colcode == . 

rename (col1_chef_code2 col2_chef_code2) (chef_code1 chef_code2)
rename (col1_colcode col2_colcode) (col_code1 col_code2)

preserve
	keep a7 tmt* chef_code* 
	drop if chef_code1==. & chef_code2==.
	reshape long chef_code, i(a7) j(order)
	drop if chef_code==.
	bys chef_code: egen tmt_max=max(tmt)
	bys chef_code: egen tmt_min=min(tmt)
// 	drop if tmt_min==tmt_max & tmt_min==4 // Remove chiefs who did only CXL and no pure Local
	duplicates drop tmt chef_code, force
	drop tmt_min tmt_max
	tempfile tmt_chef
	sa `tmt_chef'
restore

preserve
	keep a7 tmt* col_code* 
	drop if col_code1==. & col_code2==.
	reshape long col_code, i(a7) j(order)
	drop if col_code==.
	duplicates drop tmt col_code, force
	tempfile tmt_col
	sa `tmt_col'
restore

**********************
* Chief Collectors *
**********************
	
* Clean Data
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* merge collector information from polygon level dataset
merge m:1 a7 using  "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match) nogen

* chief collector code
levelsof col1_chef_code if tmt==2, local(chef1)
levelsof col2_chef_code if tmt==2 | tmt==4, local(chef2)
local chef: list chef1| chef2
di `chef'

	* Keep all chiefs collectors
	foreach c of local chef{
	use "${repldir}/Data/01_base/survey_data/collector_baseline_noPII.dta", clear
	keep if tot_complete == 1
	keep if col_type==2 & chef_code==`c'
	tempfile chef_`c'
	save `chef_`c''
	}	
	
	* Append 
	use `chef_60920132'
	foreach c of local chef{
		append using `chef_`c''
	}
	
	duplicates drop
	drop code 
	rename chef_code code
	replace code=colcode if code==.
	* merge missing info from chief collector survey 
	* educ, inc, possessions, trsut4, trust5, trust6, state_cap1, gov_resp, revcorr14_end
	merge 1:1 code using "${repldir}/Data/01_base/survey_data/chief_survey_noPII.dta", ///
	keepusing(a7 edu edu2 inc_mo possessions_1 possessions_2 possessions_3 possessions_4 possessions_5 possessions_6 possessions_0 trust4 trust5 trust6 trust7 state_cap1 gov_resp corr14_end sex age kga_born tax_who1 tax_who2 tax_who3 tax_who4 tax_who5 tax_who6 tax_who7 appoint_yr other_job2 gov1_end party party_which tax8 fire_num collect_ever tribe chef_type chef_fam) update replace 
	keep if _merge>2
	drop _merge
	
g chef_tenure = 2019-appoint_yr
g chef_established = chef_tenure>5
g chef_gov_job = other_job2==17

revrs trust5-trust7 corr14_end
ren revtrust5 col_trust_gov
ren revtrust6 col_trust_dgrkoc
ren revtrust7 col_trust_researchers

ren gov_resp col_view_gov_nbhd
ren revcorr14_end col_view_gov_gen
ren gov1_end col_gov_integrity

g chef_party = party==1|party==2

g chef_pprd = party_which==1
g chef_udps = party_which==2

ren tax8 chef_know_2016tax

g chef_know_fired = fire_num>0 & fire_num!=.

ren collect_ever chef_collect_ever

g col_maj_ethnic = tribe=="LULUWA"

g chef_locality = 1 if chef_type==2|chef_type==9|chef_type==10
replace chef_locality=0 if chef_type==1|chef_type==7

* Chief collector Characteristics 
		*Age
		ren age age_chief
		
		* Income per month in USD
		replace inc_mo=inc_mo/1650
		gen ln_inc_mo=ln(inc_mo)
		
		* Education variables
		gen educ_lvl=y9 
		replace educ_lvl=edu if educ_lvl==. & edu!=.
		
		gen educ_yrs=3+y10 if educ_lvl==2
		replace educ_yrs=3+6+y10 if educ_lvl==3 
		replace educ_yrs=3+12+y10 if educ_lvl==4
		
		replace educ_yrs=3+edu2 if educ_lvl==2 & educ_yrs==. & edu2!=.
		replace educ_yrs=3+6+edu2 if educ_lvl==3 & educ_yrs==. & edu2!=.
		replace educ_yrs=3+12+edu2 if educ_lvl==4 & educ_yrs==. & edu2!=.

	tempfile baseline_chief
	sa `baseline_chief'
	
***** Endline Data
	
* Clean Data
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* merge collector information from polygon level dataset
merge m:1 a7 using  "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match) nogen

* chief collector code
levelsof col1_chef_code if tmt==2, local(chef1)
levelsof col2_chef_code if tmt==2 | tmt==4, local(chef2)
local chef: list chef1| chef2
di `chef'

	* Keep all chiefs collectors
	foreach c of local chef{
	use "${repldir}/Data/01_base/survey_data/collector_endline_noPII.dta", clear
	keep if tot_complete == 1
	keep if col_type==2 & chef_code==`c'
	tempfile chef_`c'
	save `chef_`c''
	}	
	
	* Append 
	use `chef_60920132'
	foreach c of local chef{
		append using `chef_`c''
	}
	
	duplicates drop
	drop code 
	rename chef_code code
	replace code=colcode if code==.

	merge 1:1 code using "${repldir}/Data/01_base/survey_data/chief_survey_noPII.dta", ///
	keepusing(a7 edu edu2 inc_mo possessions_1 possessions_2 possessions_3 possessions_4 possessions_5 possessions_6 possessions_0 gov_resp corr14_end sex age kga_born tax_who1 tax_who2 tax_who3 tax_who4 tax_who5 tax_who6 tax_who7 appoint_yr other_job2 gov1_end party party_which tax8 fire_num collect_ever tribe chef_type chef_fam) update replace 
	keep if _merge>2
	drop _merge
	
	tempfile endline_chief
	sa `endline_chief'
	
	cap drop _merge
	merge 1:1 code using `baseline_chief', force
	
	* Tempfile
	tempfile chief_col
	save `chief_col'
	
**********************
* Central Collectors *
**********************

***** Baseline

use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* merge collector information from polygon level dataset
merge m:1 a7 using  "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match)

	* DGRKOC collector code
	levelsof col1_colcode if tmt==1 | tmt==3 | tmt==4, local(col1)
	levelsof col2_colcode if tmt==1 | tmt==3 , local(col2)
	local col: list col1| col2
	
	* Keep all central collectors
	foreach c of local col{
	use "${repldir}/Data/01_base/survey_data/collector_baseline_noPII.dta", clear
	keep if tot_complete == 1
	keep if col_type==1 & colcode==`c'
	tempfile col_`c'
	save `col_`c''
	}
	foreach c of local col{
	append using `col_`c''
	}
	duplicates drop
	drop code 
	
* Central collector Characteristics 
	
		* Income per month in USD
		replace inc_mo=inc_mo/1650
		gen ln_inc_mo=ln(inc_mo)

		* Education variables
		gen educ_lvl=y9 
		gen educ_yrs=3+y10 if educ_lvl==2
		replace educ_yrs=3+6+y10 if educ_lvl==3 
		replace educ_yrs=3+12+y10 if educ_lvl==4

		* Number of possessions (moto, voiture, radio, TV, generator, sewing machine)

		* colcode 
		gen col1_colcode=colcode
		gen col2_colcode=colcode
	
	cap drop _merge
	
	tempfile baseline_dgrkoc
	sa `baseline_dgrkoc'
	
****** Endline
	
* Clean Data
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* merge collector information from polygon level dataset
merge m:1 a7 using  "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match)

	* DGRKOC collector code
	levelsof col1_colcode if tmt==1 | tmt==3 | tmt==4, local(col1)
	levelsof col2_colcode if tmt==1 | tmt==3 , local(col2)
	local col: list col1| col2
	
	* Keep all central collectors
	foreach c of local col{
	use "${repldir}/Data/01_base/survey_data/collector_endline_noPII.dta", clear
	keep if tot_complete == 1
	keep if col_type==1 & colcode==`c'
	tempfile col_`c'
	save `col_`c''
	}
	foreach c of local col{
	append using `col_`c''
	}
	duplicates drop
	drop code 

	
	gen col1_colcode=colcode
	gen col2_colcode=colcode
	
	cap drop _merge
	
	tempfile endline_dgrkoc
	sa `endline_dgrkoc'
	
	cap drop _merge
	merge 1:1 col1_colcode using `baseline_dgrkoc', force
	
	* Tempfile
	tempfile central_col
	save `central_col'
	
append using `chief_col', force

drop chef_code
rename code chef_code
rename col1_colcode col_code

cap drop _merge


* Add the correct tmt info (only keeping Central, Local and CXI)
preserve
	use `tmt_col', clear
	keep if tmt==1 | tmt==3
	drop a7 order
	duplicates tag col_code, gen(dup)
	replace tmt=1 if dup>0
	duplicates drop col_code tmt, force
	tempfile tmt_col_min
	sa `tmt_col_min'
restore

preserve
	use `tmt_chef', clear
	drop if tmt==4 // No CXL for the moment
	drop a7 order
	tempfile tmt_chef_min
	sa `tmt_chef_min'
restore 

merge m:1 col_code using `tmt_col_min', nogen
merge m:1 chef_code using `tmt_chef_min', update replace

*sa "$output/final_collector_analysis.dta", replace


***************************
**** Tables and Graphs ****
***************************

* Collector Endline data


gen tmt_final=.
replace tmt_final=0 if tmt==1 | tmt==3
replace tmt_final=1 if tmt==2

lab def tmt_final 0 `"Central"', modify
lab def tmt_final 1 `"Local"', modify

lab val tmt_final tmt_final

global chief_motivation = "extern1 extern2 extern3 extern4 intrin1 intrin2 intrin3" 
global chief_introj = "introj1 introj2 introj3 introj4"
global chief_goals = "goal1 goal2 goal3"
global chief_amotivation = "amotiv1 amotiv2 amotiv3"
global chief_pdv = "pdv1 pdv2"
global chief_optimism = "optim1 optim2 optim3"
global chief_control = "loc1b loc3b loc7c loc8b loc10b locxb"
global discount = "k1 k2 k3 k4"
global big5_1 "consci2 consci3 consci6 consci8 consci9"
global big5_2 "extrav1 extrav9 extrav2 extrav4 extrav6"

global fairness "fair_periphery fair_mm"
global gov_responsive "resp1 resp2 resp3 resp4 resp5 resp6 resp7 resp8"


revrs amotiv1, replace
revrs amotiv2, replace
revrs amotiv3, replace

foreach var in $chief_motivation $chief_introj $chief_goals $chief_amotivation $chief_pdv $chief_optimism $chief_control $discount $big5_1 $big5_2 {
destring `var', force replace
center `var', inplace standardize
}

egen extrin_index = rowtotal(extern1 extern2 extern3 extern4)
center extrin_index, inplace standardize

egen intrin_index = rowtotal(intrin1 intrin2 intrin3)
center intrin_index, inplace standardize

egen introj_index = rowtotal(introj1 introj2 introj3 introj4)
center introj_index, inplace standardize

egen goal_index = rowtotal(goal1 goal2 goal3)
center goal_index, inplace standardize

egen amotiv_index = rowtotal(amotiv1 amotiv2 amotiv3)
center amotiv_index, inplace standardize

egen pdv_index = rowtotal(pdv1 pdv2)
center pdv_index, inplace standardize

egen optim_index = rowtotal(optim1 optim2 optim3)
center optim_index, inplace standardize

egen control_index = rowtotal(loc1b loc3b loc7c loc8b loc10b locxb)
center control_index, inplace standardize

egen discount_index = rowtotal(k1 k2 k3 k4)
center discount_index, inplace standardize

egen big5_1_index = rowtotal(consci2 consci3 consci6 consci8 consci9)
center big5_1_index, inplace standardize

egen big5_2_index = rowtotal(extrav1 extrav9 extrav2 extrav4 extrav6)
center big5_2_index, inplace standardize

replace extrin_index=. if extern1==.
replace intrin_index=. if intrin1==.
replace introj_index=. if introj1==.
replace goal_index=. if goal1==.
replace amotiv_index=. if amotiv1==.
replace pdv_index=. if pdv1==.
replace optim_index=. if optim1==.
replace control_index=. if loc1b==.
replace discount_index=. if k1==.
replace big5_1_index=. if consci2==.
replace big5_2_index=. if extrav1==.


label var extrin_index "Extrinsic motivation"
label var intrin_index "Intrinsic motivation"
label var introj_index "Introjection"
label var goal_index "Personal goals"
label var amotiv_index "Amotivation"
label var pdv_index "Punishment"
label var optim_index "Optimism"
label var control_index "Locus of Control"
label var discount_index "Time Preference"
label var big5_1_index "Conscientiousness"
label var big5_2_index "Extravert"

split maze_time, p(":")
destring maze_time*, replace
gen maze_time_fin = maze_time1*60+maze_time2+maze_time3/60
replace maze_time_fin=. if maze_time_fin>150 // remove one outlier (14hours to complete the maze...)


global tot_vars "extrin_index intrin_index introj_index goal_index amotiv_index big5_1_index big5_2_index discount_index optim_index control_index maze_time_fin die_pers_gain"

foreach var in $tot_vars {
center `var', inplace standardize
}

**********************************************************************************


* Table A43 : Collector Characteristics

local indepvar "tmt_final"

eststo clear
foreach depvar in $tot_vars {
local counter = `counter' + 1
eststo: reg `depvar' `indepvar' if inlist(tmt_final, 0, 1)
local beta = round(_b[`indepvar'],.001)
di "Beta: `beta'"
local se = round(_se[`indepvar'],.001)
di "SE: `se'"
local p = round(2*ttail(e(df_r), abs(_b[`indepvar']/_se[`indepvar'])),.001)
di "p-value: `p'"
local obs = round(`e(N)',1)
di "N:`obs'"
local r2 = `e(r2)' 
di "R2:`r2'"
sum `depvar' 
local depvarmean = round(`r(mean)',.001)
di "Dep var mean:`depvarmean'"

	if `counter' == 1 { 
		mat input reg = (`beta', `se',`r2',`obs') 
		mat rownames reg = `indepvar' 
		mat colnames reg = beta SE r2 N 	 
	}
	
	if `counter' > 1 { 
		mat input reg`counter' = (`beta', `se',`r2',`obs') 
		mat rownames reg`counter' = `indepvar' 
		mat colnames reg`counter' = beta SE r2 N 	 
		mat reg = (reg \ reg`counter' )
	}
}
	mata reg = st_matrix("reg") 
	mat list reg 	
	
	cd "$reploutdir"
	mmat2tex reg using "endline_collector_traits_small.tex", replace  ///
	colnames(beta SE R2 N) ///
	rownames("Extrinsic motivation" "Intrinsic motivation" "Introjection" "Goal orientation" "Amotivation" "Conscientiousness (big 5)" "Extroverted (big 5)" "Discount factor" "Optimism" "Locus of Control" "Persistence (maze)"  "Dishonesty/cheating (RAG)") ///
	preheader("{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \begin{tabular}{l*{4}{c}} \hline\hline") ///
	bottom("\hline\hline \end{tabular} }") ///
	fmt(%9.3f)
	

*** * Table A14 -- Only Columns 1-3 
	
label var pdv_index "Chief Perception of Monitoring / Punishment for Bribe-Taking"
label var chef_know_fired "Knows fire chiefs"
label var chef_know_2016tax "Knows 2016 campaign"
label var tmt_2016 "Nbhd in 2016 campaign"

global col_vars "chef_know_fired chef_know_2016tax tmt_2016"

eststo clear
foreach var in $col_vars {
	eststo: reg pdv_index `var' if tmt_final==1
 	estadd scalar R2 = `e(r2)'
	su pdv_index if tmt_final==1
	estadd local Mean=abs(round(`r(mean)',.001))
}
	esttab using "$reploutdir/bribe_chief_worried_sanctions_col1-3.tex", scalars(Observations Clusters Mean) sfmt(0 0 3)  nocons noobs l b(4) se(4) compress nogap r2 nonotes star(* 0.10 ** 0.05 *** 0.01)  ///
nonumbers replace

		

	*Table A44 - Endline Amotivation
	
label var amotiv1 "Couldn't Manage Tasks"
label var amotiv2 "Worked Under Unrealistic Conditions"
label var amotiv3 "Bosses Expected Too Much"
label var amotiv_index "Amotivation index"
label var tmt_final "Local"

global col_vars "amotiv1 amotiv2 amotiv3 amotiv_index"

eststo clear
foreach var in $col_vars {
	eststo: reg `var' tmt_final if amotiv1!=.
 	estadd scalar R2 = `e(r2)'
	su `var' if tmt_final==0
	estadd local Mean=abs(round(`r(mean)',.001))
}

esttab est1 est2 est3 est4 using "$reploutdir/collector_amotivation.tex", ///		
	replace label b(%9.3f) se(%9.3f) ///
	scalar(Mean) ///
	nomtitles ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress nocons
	
			
	
	
