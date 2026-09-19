
************************************************
* Appendix Table A1: Collector Characteristics *
************************************************

	* Use clean final data
	u "${repldir}/Data/03_clean_combined/analysis_data.dta",clear
	
	* merge collector information from polygon level dataset
	merge m:1 a7 using  "${repldir}/Data/01_base/admin_data/campaign_collector_info.dta", keep(match)

	* DGRKOC collector code
	levelsof col1_colcode, local(col1)
	levelsof col2_colcode if tmt!=4, local(col2)
	local col: list col1| col2

	* chief collector code
	levelsof col1_chef_code, local(chef1)
	levelsof col2_chef_code, local(chef2)
	local chef: list chef1| chef2
	
	* Keep all central collectors
	foreach c of local col{
	use "${repldir}/Data/01_base/survey_data/collector_baseline_noPII.dta", clear
	keep if tot_complete == 1
	keep if col_type==1 & colcode==`c'
	tempfile col_`c'
	save `col_`c''
	}
	
	* Keep all chiefs collectors
	foreach c of local chef{
	use "${repldir}/Data/01_base/survey_data/collector_baseline_noPII.dta", clear
	keep if tot_complete == 1
	keep if col_type==2 & chef_code==`c'
	tempfile chef_`c'
	save `chef_`c''
	}	
	
	* Append 
	use `chef_3196 '
	foreach c of local chef{
	append using `chef_`c''
	}
	duplicates drop
	drop code 
	rename chef_code code
	* merge missing info from chief collector survey 
	* educ, inc, possessions, trsut4, trust5, trust6, state_cap1, gov_resp, revcorr14_end
	merge 1:1 code using "${repldir}/Data/01_base/survey_data/chief_survey_noPII.dta", ///
	keepusing(edu edu2 inc_mo possessions_1 possessions_2 possessions_3 possessions_4 possessions_5 possessions_6 possessions_0 trust4 trust5 trust6 state_cap1 gov_resp corr14_end sex age kga_born tax_who1 tax_who2 tax_who3 tax_who4 tax_who5 tax_who6 tax_who7 other_job other_job2) update replace 
	keep if _merge>2
	foreach c of local col{
	append using `col_`c''
	} 
	* tempfile 
	tempfile collectors
	save `collectors'
	
	* Cleaning of collector Characteristics
	
		* Reverse variable scale: 
		revrs red_if red_poor // higher value: pro poor / pro redistribution
		revrs tax_who1 tax_who2 tax_who3 tax_who4 tax_who5 tax_who6 tax_who7 // higher value: more important to tax  
		revrs trust4 trust5 trust6 corr14_end // higher value: more trust
		revrs b1 // higher value: higher tax morale
		revrs b2 // higher value: DGRKOC's work more important

		* Poor were unlucky 
		gen poor_unlucky=0 if red_poor!=.
		replace poor_unlucky=1 if red_poor==1 | red_poor==2

		* Income per week in USD
		replace inc_wk=inc_wk/1650
		gen ln_inc_wk=ln(inc_wk)

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
		
		* other job before tax campaign
		gen occupation_str=occupation
		tostring occupation_str,replace
		destring occupation, force replace
		gen other_job_combined=. 
		replace other_job_combined=1 if occupation!=. | occupation_str=="other"
		replace other_job_combined=0 if occupation_str=="other" & occupation_other=="DGRKOC"
		replace other_job_combined=0 if occupation_str=="other" & occupation_other=="Il travaillait à la dgrkoc"
		replace other_job_combined=0 if occupation_str=="other" & occupation_other=="Je travaillais à la Dgrkoc"
		replace other_job_combined=0 if occupation_str=="other" & occupation_other=="Percepteur de taxe au marché  central"
		replace other_job_combined=0 if occupation_str=="other" & occupation_other=="Il était toujours à la Dgrkoc"
		replace other_job_combined=0 if occupation_str=="other" & occupation_other=="Stagiaire à la DGRKOC"
		replace other_job_combined=0 if (occupation==27 | occupation==29) //student
		replace other_job_combined=0 if (occupation==0) //unemployed
		replace other_job_combined=other_job if col_type==2 // info for chiefs
		
		* Number of possessions (moto, voiture, radio, TV, generator, sewing machine)
		egen possessions_nb =rowtotal(possessions_1 possessions_2 possessions_3 possessions_4 possessions_5 possessions_6)

		* use of gov funds
		replace gov1_end=. if gov1_end==0 & gov2_end==0
		replace gov2_end=. if gov1_end==0 & gov2_end==0

		* age 
		replace age=y7 if age==.

		* gender
		gen female=0 if y3==1
		replace female=0 if sex==1
		replace female=1 if y3==2
		replace female=1 if sex==2

		* Born in Kananga
		replace born_kga =kga_born if born_kga==.
		
		* Means
		egen math_mean = rowmean(c11 c12 c13 c14)
		egen read_mean = rowmean(read3 read4 read6 read7)
		egen trust_mean = rowmean(revtrust4 revtrust5 revtrust6)
		egen prov_mean = rowmean(state_cap1 gov_resp revcorr14_end gov1_end)
		egen poor_mean = rowmean(red_ngo red_state poor_unlucky)
		egen prog_mean = rowmean(revred_if red_prog tax_who2 revtax_who1 revtax_who6)
					
		* Chief / DGRKOC dummy
		gen chief_dummy=0 if col_type==1
		replace chief_dummy=1 if col_type==2
		keep if chief_dummy!=.

* Globals
global demographics "age female born_kga ln_inc_mo possessions_nb educ_yrs other_job_combined"
global math "math_mean"
global read "read_mean"
global trust "trust_mean"
global gov "prov_mean"
global rev "revb2 revb1"
global redistribution "poor_mean"
global redistribtion2 "prog_mean"

* Outcomes
label var age "Age" 
label var female "\% Female" 
label var educ_lvl "Education level"
label var educ_yrs "Education years" 
label var ln_inc_mo "Log Monthly Income" 
label var other_job_combined "Works Other Job" 
label var possessions_nb "Number of Possessions"
label var born_kga "Born in Kananga"
label var math_mean "Test Maths (Mean)"
label var read_mean "Reading Ability (Mean)"
label var trust_mean "Trust in Gov. (Mean)"
label var prov_mean "Prov. Gov. Capacity (Mean)"
label var revb2 "Tax Min. Important"
label var revb1 "Taxes Important"
label var poor_mean "Poor Priority (Mean)"
label var prog_mean "Progressiveness (Mean)"

* Summary stat table
balancetable chief_dummy ${demographics} ${math} ${read} ${trust} ${gov} ${redistribution} ${redistribtion2} using "$reploutdir/collector_summary.tex", replace  varlabels ctitles("Central collectors" "Local Collectors" "Difference")
