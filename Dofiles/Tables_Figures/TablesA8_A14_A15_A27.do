*****************************
** Collector heterogeneity **
*****************************

/*
**This table makes the following tables: 

cvl_collector_differences_control.tex - Table A8 

bribe_chief_het_condensed.tex - Table A15

taxes_paid_chief_het_condensed.tex - Table A27 

bribe_chief_worried_sanctions_col4-6.tex - Table A14 

*/


*****************
* Prepare Data *
*****************

	
*********************
* Chief Collectors *
*********************

* Extract chief survey variables
	
use "${repldir}/Data/01_base/survey_data/chief_survey_noPII.dta", clear

ren age age_chef	
	
g chef_tenure = 2019-appoint_yr
g chef_established = chef_tenure>10

g chef_gov_job = other_job2==17

revrs trust5-trust7 corr14_end
ren revtrust5 col_trust_gov
ren revtrust6 col_trust_dgrkoc

g chef_trust_gov = col_trust_gov
g chef_trust_dgrkoc = col_trust_dgrkoc

ren gov_resp col_view_gov_nbhd
ren revcorr14_end col_view_gov_gen
ren gov1_end col_gov_integrity

g chef_party = party==1|party==2

g chef_pprd = party_which==1
g chef_udps = party_which==2

ren tax8 chef_know_2016tax

g chef_know_fired = fire_num>0 & fire_num!=.

g chef_minority_ethnic = tribe!="LULUWA"

g chef_locality = 1 if chef_type==2|chef_type==9|chef_type==10
replace chef_locality=0 if chef_type==1|chef_type==7
	
		
* Education variables
gen educ_lvl=edu 
		
gen educ_yrs=3+edu2 if educ_lvl==2
replace educ_yrs=3+6+edu2 if educ_lvl==3 
replace educ_yrs=3+12+edu2 if educ_lvl==4
ren educ_yrs educ_yrs_chef
		
* Number of possessions (moto, voiture, radio, TV, generator, sewing machine)
egen possessions_nb=rowtotal(possessions_1 possessions_2 possessions_3 possessions_4 possessions_5 possessions_6)
ren possessions_nb possessions_nb_chef



tempfile chef_chars
save `chef_chars'

		
* Clean Data
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* merge collector information from polygon level dataset
merge m:1 a7 using  "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match) nogen

* chief collector code
levelsof col1_chef_code if tmt==2, local(chef1)
levelsof col2_chef_code if tmt==2 | tmt==4, local(chef2)
local chef: list chef1| chef2

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
	
	* merge missing info from chief collector survey: educ, inc, possessions, trsut4, trust5, trust6, state_cap1, gov_resp, revcorr14_end
	
	merge 1:1 code using `chef_chars', ///
	keepusing(age_chef possessions_nb_chef educ_yrs_chef educ_lvl chef_locality chef_minority_ethnic chef_know_2016tax chef_pprd chef_party chef_udps col_gov_integrity col_view_gov_gen col_view_gov_nbhd  col_trust_dgrkoc col_trust_gov  chef_know_fired chef_gov_job chef_tenure chef_established chef_fam trust4 trust5 trust6 chef_trust_gov chef_trust_dgrkoc ) update replace 
	
	keep if _merge>2
	
	
	*Importance of taxation
		replace b1 = . if b1==5
		replace b2 = . if b2==5
		revrs b1 b2, replace
		ren b1 tax_imp
		ren b2 dgrkoc_imp
	
		* Reverse variable scale: 
		revrs red_if red_poor // higher value: pro poor / pro redistribution
		revrs tax_who1 tax_who2 tax_who3 tax_who4 tax_who5 tax_who6 tax_who7 // higher value: more important to tax  
		revrs trust4 trust5 trust6 // higher value: more trust
	
		* Means
		egen trust_mean = rowmean(revtrust4 revtrust5 revtrust6)
		egen prog_mean = rowmean(revred_if red_prog tax_who2 revtax_who1 revtax_who6)

		
		
	* Tempfile
	tempfile chief_col
	save `chief_col'
	
	
	
**********************
* Central Collectors *
**********************
	
* Clean Data
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* merge collector information from polygon level dataset
merge m:1 a7 using "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match)

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
		egen possessions_nb=rowtotal(possessions_1 possessions_2 possessions_3 possessions_4 possessions_5 possessions_6)
		
		*Age 
		ren y7 age
		label var age "Age"

		*Importance of taxation
		replace b1 = . if b1==5
		replace b2 = . if b2==5
		revrs b1 b2, replace
		ren b1 tax_imp
		ren b2 dgrkoc_imp

		* Reverse variable scale: 
		revrs red_if red_poor // higher value: pro poor / pro redistribution
		revrs tax_who1 tax_who2 tax_who3 tax_who4 tax_who5 tax_who6 tax_who7 // higher value: more important to tax  
		revrs trust4 trust5 trust6 // higher value: more trust
	
		* Means
		egen trust_mean = rowmean(revtrust4 revtrust5 revtrust6)
		egen prog_mean = rowmean(revred_if red_prog tax_who2 revtax_who1 revtax_who6)
					
		* colcode 
		gen col1_colcode=colcode
		gen col2_colcode=colcode
		
	* Tempfile
	tempfile central_col
	save `central_col'
	
	
	*********************
	* Add data together *
	*********************
	
	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
	merge m:1 a7 using "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match)
	cap drop _merge
	
	* central
	merge m:1 col1_colcode using `central_col', force keepusing(age inc_mo educ_yrs educ_lvl possessions_nb tax_imp dgrkoc_imp trust_mean prog_mean)
	rename (age inc_mo educ_yrs educ_lvl possessions_nb tax_imp dgrkoc_imp trust_mean prog_mean) (age_col1 inc_mo_col1 educ_yrs_col1 educ_lvl_col1 possessions_nb_col1 tax_imp_col1 dgrkoc_imp_col1 trust_mean_col1 prog_mean_col1)
	drop _merge
	merge m:1 col2_colcode using `central_col', force keepusing(age inc_mo educ_yrs educ_lvl possessions_nb tax_imp dgrkoc_imp trust_mean prog_mean)
	rename (age inc_mo educ_yrs educ_lvl possessions_nb tax_imp dgrkoc_imp trust_mean prog_mean) (age_col2 inc_mo_col2 educ_yrs_col2 educ_lvl_col2 possessions_nb_col2 tax_imp_col2 dgrkoc_imp_col2 trust_mean_col2 prog_mean_col2)
	
	drop _merge
	
	egen age = rowmean(age_col1 age_col2)
	egen inc_mo=rowmean(inc_mo_col1 inc_mo_col2)
	egen educ_yrs=rowmean(educ_yrs_col1 educ_yrs_col2)
	egen educ_lvl=rowmean(educ_lvl_col1 educ_lvl_col2)
	egen possessions_nb=rowmean(possessions_nb_col1 possessions_nb_col2)
	egen tax_imp = rowmean(tax_imp_col1 tax_imp_col2)
	egen dgrkoc_imp=rowmean(dgrkoc_imp_col1 dgrkoc_imp_col2)
	egen trust_mean=rowmean(trust_mean_col1 trust_mean_col2)
	egen prog_mean=rowmean(prog_mean_col1 prog_mean_col2)

	
	*local collectors 
	
	cap drop _merge
	gen chief_code=col1_chef_code if tmt==2
	replace chief_code=col2_chef_code if tmt==4
	cap drop code
	rename chief_code code
	merge m:1 code using `chief_col', force update replace nogen keepusing(possessions_nb_chef educ_yrs_chef educ_lvl age_chef chef_locality chef_minority_ethnic chef_know_2016tax chef_pprd chef_party chef_udps col_gov_integrity col_view_gov_gen col_view_gov_nbhd  col_trust_dgrkoc col_trust_gov  chef_know_fired chef_gov_job chef_tenure chef_established chef_fam prog_mean tax_imp dgrkoc_imp trust_mean chef_trust_gov chef_trust_dgrkoc )
	
	*Chiefs in central neighborhoods
		
	cap drop _merge
	
	preserve
	
	use "${repldir}/Data/01_base/admin_data/chief_collector_candidates_campaignupdated.dta", clear
	keep if rankpop==1
	keep a7 rankpop code
	tempfile top_chefs
	sa `top_chefs'
	
	restore
	
	merge m:1 a7 using `top_chefs', force update nogen
	
	merge m:1 code using `chef_chars', force update keepusing(age_chef possessions_nb_chef educ_yrs_chef educ_lvl chef_locality chef_minority_ethnic chef_know_2016tax chef_pprd chef_party chef_udps col_gov_integrity col_view_gov_gen col_view_gov_nbhd  col_trust_dgrkoc col_trust_gov  chef_know_fired chef_gov_job chef_tenure chef_established chef_fam chef_trust_gov chef_trust_dgrkoc )
	
	*time FE
	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
	
	*Collector-level variables
	replace age = age_chef if tmt==2|tmt==4
	replace possessions_nb = possessions_nb_chef if tmt==2|tmt==4
	replace educ_yrs = educ_yrs_chef if tmt==2|tmt==4
		
	* Distance from city center 
	merge m:1 compound1 using "${repldir}/Data/01_base/admin_data/hh_distances.dta", keepusing(dist_city_center) nogen
	
	* Remoteness
		global remoteness "dist_city_center"
	
		foreach index in remoteness{ 
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

		foreach var in remoteness{
		sum `var', d
		g `var'_norm = (`var'-`r(min)')/(`r(max)'-`r(min)') //normalize variables
		}
		
		foreach var in remoteness{
		su `var'_norm, d
		g `var'_hi = `var'_norm>`r(p50)'
		}
	
	// Baseline information
	preserve
		keep if t_l==1|t_c==1
		duplicates drop a7,force
		keep a7
		tempfile polys
		sa `polys'
	restore
	preserve
	
	
		u "${repldir}/Data/01_base/survey_data/baseline_noPII.dta",clear
		keep if tot_complete==1
		ren code survey1_code
		
		g cit_eval_chief = chef_eval 
		g cit_integrity_chief = chef_corr1
		g cit_responsiveness_chief = chef4

		revrs trust8 trust6 cit_eval_chief tax42, replace
		
		ren trust8 cit_trust_chief		
		ren trust6 cit_trust_dgrkoc
		ren corr7_end cit_integrity_dgrkoc
		ren tax42 cit_eval_dgrkoc
		ren gov_resp cit_responsiveness_dgrkoc
		
		center cit_trust_chief cit_trust_dgrkoc cit_eval_chief cit_eval_dgrkoc cit_integrity_chief cit_integrity_dgrkoc cit_responsiveness_chief cit_responsiveness_dgrkoc, standardize inplace
		
		ren chef_eval chef_eval_bl
			replace chef_eval_bl = chef_eval_bl*100
			replace chef_eval_bl = 1 if chef_eval_bl==700
			replace chef_eval_bl = 2 if chef_eval_bl==600
			replace chef_eval_bl = 3 if chef_eval_bl==500
			replace chef_eval_bl = 4 if chef_eval_bl==400
			replace chef_eval_bl = 5 if chef_eval_bl==300
			replace chef_eval_bl = 6 if chef_eval_bl==200
			replace chef_eval_bl = 7 if chef_eval_bl==100
		ren chef_eval_bl chef_eval
		
		ren chef6 chef6_bl
			replace chef6_bl = chef6_bl*100
			replace chef6_bl = 1 if chef6_bl==500
			replace chef6_bl = 2 if chef6_bl==400
			replace chef6_bl = 3 if chef6_bl==300
			replace chef6_bl = 4 if chef6_bl==200
			replace chef6_bl = 5 if chef6_bl==100
		ren chef6_bl chef6
		
		g chef1_bl = 0 if chef1==3
		replace chef1_bl = 1 if chef1==1|chef1==2
		drop chef1
		ren chef1_bl chef1
		
		g chef2_bl = 0 if chef2==3
		replace chef2_bl = 1 if chef2==1|chef2==2
		drop chef2
		ren chef2_bl chef2
		
		replace chef2 = 0 if chef1==0
		replace chef3 = 0 if chef1==0
		
		ren chef9 chef9_bl
			replace chef9_bl = chef9_bl*100
			replace chef9_bl = 1 if chef9_bl==400
			replace chef9_bl = 2 if chef9_bl==300
			replace chef9_bl = 3 if chef9_bl==200
			replace chef9_bl = 4 if chef9_bl==100
		ren chef9_bl chef9
		
		collapse (mean) chef_eval chef4 chef_corr1 chef6 ///
		chef0 chef1 chef2 chef3	chef5 chef8 chef9 chef11 chef12 ///
		cit_trust_chief cit_trust_dgrkoc cit_eval_chief ///
		cit_eval_dgrkoc cit_integrity_chief cit_integrity_dgrkoc  ///
		cit_responsiveness_chief cit_responsiveness_dgrkoc,by(a7)
		merge 1:1 a7 using `polys'
		keep if _merge==3
		drop _merge
		
		replace chef2 = 0 if chef1==0
		replace chef3 = 0 if chef1==0
		
		// Indices
		global evaluation = "chef_eval chef4 chef_corr1 chef6"
		global connections = "chef0 chef1 chef2 chef3"
		global activity = "chef5 chef8 chef9 chef11 chef12"
		
		// Standardize
		foreach index in evaluation connections activity{ 
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

		foreach var in evaluation connections activity{
		sum `var', d
		g `var'_norm = (`var'-`r(min)')/(`r(max)'-`r(min)') //normalize variables
		}
		
		foreach var in evaluation connections activity{
		su `var'_norm, d
		g `var'_hi = `var'_norm>`r(p50)'
		}
		
		tempfile baseline
		sa `baseline'
	restore
	
	cap drop _merge
	merge m:1 a7 using `baseline'
	
	// Chefferies
	
	cap drop _merge
	merge m:1 a7 using "${repldir}/Data/02_intermediate/concessions_chefferies.dta"
	ren chefferie chefferie_type
	g chefferie = chefferie_type!=""
	replace chefferie = 0 if strmatch(chefferie_type,"*cession*")
	
	// Make binary 
	
	foreach var in chef_trust_gov chef_trust_dgrkoc col_view_gov_gen col_view_gov_nbhd col_gov_integrity age_chef possessions_nb_chef educ_yrs_chef{
	su `var', d
	g `var'_hi = `var'>`r(p50)'
	}

	global chief_chars = "age_chef_hi possessions_nb_chef_hi educ_yrs_chef_hi chef_minority_ethnic"
	global chief_strength = "chef_locality chef_established chef_fam remoteness_hi chefferie"
	global chief_political = "chef_party chef_pprd chef_udps chef_gov_job"
	global chief_views = "chef_trust_gov_hi chef_trust_dgrkoc_hi col_view_gov_gen_hi col_view_gov_nbhd_hi col_gov_integrity_hi"
	global chief_worried_sanctions = "chef_know_fired chef_know_2016tax tmt_2016"
	global neighborhood_chars = "evaluation_hi connections_hi activity_hi "
		
	******************
	*** HTE Tables ***
	******************
				
	***TABLES A15 AND A27***
	
	foreach depvar in bribe taxes_paid{
	eststo clear
	local i = 1
	foreach index in chief_chars chief_strength chief_political chief_views chief_worried_sanctions neighborhood_chars{
	foreach var in $`index'{
	g lX`var' = `var'*t_l
	eststo: reg `depvar' t_l lX`var' `var' i.stratum i.house i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), vce(cl a7)
	di in red "Round `i': `var'"
	local beta1 = round(_b[t_l],.00001)
	di "Beta1: `beta1'"
	local se1 = round(_se[t_l],.00001)
	di "SE1: `se1'"
	local p1 = round(2*ttail(e(df_r), abs(_b[t_l]/_se[t_l])),.001)
	di "p-value: `p1'"
	local beta2 = round(_b[lX`var'],.00001)
	di "Beta2: `beta2'"
	local se2 = round(_se[lX`var'],.00001)
	di "SE2: `se2'"
	local p2 = round(2*ttail(e(df_r), abs(_b[lX`var']/_se[lX`var'])),.001)
	di "p-value: `p2'"
	local beta3 = round(_b[`var'],.00001)
	di "Beta3: `beta3'"
	local se3 = round(_se[`var'],.00001)
	di "SE3: `se3'"
	local p3 = round(2*ttail(e(df_r), abs(_b[`var']/_se[`var'])),.001)
	di "p-value: `p3'"
	local obs = round(`e(N)',1)
	di "N:`obs'"
	local clust = round(`e(N_clust)',1)
	di "Clusters:`clust'"
	local r2 = `e(r2)' 
	di "R2:`r2'"
	su `depvar' if t_c==1 & `var'==0 & time_FE_tdm_2mo_CvL!=.
	local depvarmean = round(`r(mean)',.001)
	di "Dep var mean:`depvarmean'"
	drop lX`var'
	
	if `i' == 1 { 
		mat input reg = (`beta1', `se1', `beta2', `se2', `beta3', `se3',`obs', `depvarmean') 
		mat rownames reg = `var' 
		mat colnames reg = beta1 SE1 beta2 SE2 beta3 SE3 N 	Depvarmean
	}
	
	if `i' > 1 { 
		mat input reg`i' = (`beta1', `se1', `beta2', `se2', `beta3', `se3',`obs', `depvarmean') 
		mat rownames reg`i' = `var' 
		mat colnames reg`i' = beta1 SE1 beta2 SE2 beta3 SE3 N 	Depvarmean 	 
		mat reg = (reg \ reg`i' )
	}
		local i = `i'+1
}
}
	mata reg = st_matrix("reg") 
	mat list reg 	
	
	cd "$reploutdir"
	mmat2tex reg using "`depvar'_chief_het_condensed.tex", replace colnames(beta1 SE1 beta2 SE2 beta3 SE3 N Depvarmean)	rownames("Age" "Wealth (possessions)" "Years of education"  "Minority ethnic" "Locality chief" "Chief for over 10 years" "Dynastic succession"  "Remote neighborhood" "Customary chief" "Political party member" "Ruling party member" "Opposition party member" "Has other gov position" "Trust in government" "Trust in tax ministry" "View of government" "View of gov responsiveness" "View of gov integrity" "Knows fired chiefs" "Knows 2016 campaign" "Neighborhood in 2016 campaign" "Trusted by citizens" "Accessible to citizens" "Active in chief role") preheader("{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \begin{tabular}{l*{8}{c}} \hline\hline")	bottom("\hline\hline \end{tabular} }") fmt(%9.3f)
	pause
	}
	

    
	*TABLE A8: Control for collector-level differences in main regression
	
		
	label var age "Age"
	label var possessions_nb "Number of possessions"
	label var educ_yrs "Years of education"
	label var prog_mean "Progressiveness (mean)"
	label var tax_imp "Taxes important"
	label var dgrkoc_imp "Tax ministry important"
	label var trust_mean "Trust in government (mean)"
	
	eststo clear
	eststo: reg taxes_paid t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt, 1,2), cluster(a7)
	su taxes_paid
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'	
	eststo: reg taxes_paid t_l age i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt, 1,2), cluster(a7)
	su taxes_paid
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'	
	eststo: reg taxes_paid t_l possessions_nb i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt, 1,2), cluster(a7)
	su taxes_paid
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'	
	eststo: reg taxes_paid t_l educ_yrs i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt, 1,2), cluster(a7)
	su taxes_paid
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	eststo: reg taxes_paid t_l trust_mean i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt, 1,2), cluster(a7)
	su taxes_paid
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
		eststo: reg taxes_paid t_l tax_imp i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt, 1,2), cluster(a7)
	su taxes_paid
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
		eststo: reg taxes_paid t_l dgrkoc_imp i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt, 1,2), cluster(a7)
	su taxes_paid
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	eststo: reg taxes_paid t_l prog_mean i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt, 1,2), cluster(a7)
	su taxes_paid
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	eststo: reg taxes_paid t_l age possessions_nb educ_yrs trust_mean tax_imp dgrkoc_imp prog_mean i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt, 1,2), cluster(a7)
	su taxes_paid
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	esttab using "$reploutdir/cvl_collector_differences_control.tex", scalars(Observations Clusters Mean) sfmt(0 0 3)  nocons noobs l b(4) se(4) compress nogap r2 nonotes star(* 0.10 ** 0.05 *** 0.01) indicate("House FE = *house*""Stratum FE = *stratum*""Time FE = *time_FE*") nonumbers replace

	
	
	*** TABLE A14: Hawthorne Effects -- Columns 4-6
	
		
	label var chef_know_fired "Knows fired chiefs"
	label var chef_know_2016tax "Knows 2016 campaign" 
	label var tmt_2016 "Assigned to 2016 campaign"
	
	foreach depvar in bribe {
	eststo clear
	foreach indepvar in $chief_worried_sanctions {
	eststo: reg `depvar' `indepvar' i.house i.stratum if t_l==1,  cluster(a7)
	su `depvar'
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	}	
	esttab using "$reploutdir/`depvar'_chief_worried_sanctions_col4-6.tex", scalars(Observations Clusters Mean) sfmt(0 0 3)  nocons noobs l b(4) se(4) compress nogap r2 nonotes star(* 0.10 ** 0.05 *** 0.01)  ///
	indicate("House FE = *house*""Stratum FE = *stratum*") nonumbers replace
}
		
	 
