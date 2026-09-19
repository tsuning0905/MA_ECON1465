
************
* Table A3 *
************

********************
* Prepare datasets *
********************

*****************
* Baseline Data *
*****************

	* use clean baseline data 
	use "${repldir}/Data/01_base/survey_data/baseline_noPII.dta", clear
	keep if tot_complete==1 
	drop possessions

	* Education variables
	g edu_yrs = .
	replace edu_yrs = 0 if edu==0
	replace edu_yrs = 1 if edu==1
	replace edu_yrs = 6 if edu==2
	replace edu_yrs = 1+edu2 if edu2!=. & edu==2 & edu2<7 // not counting repeating grade
	replace edu_yrs = 13 if edu==3
	replace edu_yrs = 7+edu2 if edu2!=. & edu==3 & edu2<5 // not counting repeating grade
	replace edu_yrs = 17 if edu==4
	replace edu_yrs = 13+edu2 if edu2!=. & edu==4 // allow for higher values for masters/PhD
		
	* Normalized possessions
	global possessions = "possessions_1 possessions_2 possessions_3 possessions_4 possessions_5 possessions_6"
	foreach index in possessions{
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

	foreach var in possessions{
	sum `var', d
	g `var'_norm = (`var'-`r(min)')/(`r(max)'-`r(min)') //normalize variables
	}
	
	* Gender dummy
	g male = sex
	replace male = 0 if male==2
	
	* log of income
	g lg_inc_mo = log(inc_mo+1)
	
	* log of transport
	g lg_transport = log(transport+1)
	
	* trust variables
	revrs trust8 trust4 trust5 trust6
	rename revtrust8 trust_chief
	rename revtrust4 trust_nat_gov
	rename revtrust5 trust_prov_gov
	rename revtrust6 trust_tax_min
				
	keep code a7 edu_yrs age male elect1 possessions possessions_norm lg_inc_mo inc_mo lg_transport transport fence trust_chief trust_nat_gov trust_prov_gov trust_tax_min tax1 tax11 tax12 tax13 tax14 tax15 tax17
		
	* tempfile 
	tempfile bl
	save `bl'

****************
* Endline Data *
****************

	* Use clean endline data 
	use "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta", clear
	keep if tot_complete==1 
	replace compound_code=compound_code_prev if (compound_code_prev!=. & compound_code_prev!=3)
	keep compound_code code a7 bribe bribe_amt o_pay2 paid_vehicletax_survey_e paid_mktvendorfee_survey_e paid_businessfee_survey_e paid_incometax_survey_e paid_faketax_survey_e corr14_end tax42 trust3_survey_e trust2_survey_e trust6_survey_e steal_gov_2018 steal_col_2018 fair_tax fair_rates fair_collectors liquidity_bind liquidity_bind_date* cash_fee cash_fee_month cash_fee_month2* message1 message2 message3 message4 message5 message6 message7 message8 message9 inc_mo transport
	rename inc_mo inc_mo_el
	rename transport transport_el

	drop if compound_code==999999 | compound_code==9999999
	
	ren bribe bribe_endline
	ren bribe_amt bribe_amt_endline
	ren o_pay2 informal_pay_endline

	tempfile el
	save `el'
	
**********************************
* Machine Learning and distances * 
**********************************

	* Use final Machine Learning data
	insheet using "${repldir}/Data/01_base/admin_data/property_values_MLestimates.csv", clear
	keep compound1 pred_value dist_*
	drop if compound1==.
	rename compound1 compound_code
	tempfile machine_learning
	save `machine_learning'
	
*****************
* Combined Data *
*****************
	
	* Use clean combined data
	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	rename compound1 compound_code
	
	// House quality
		* roof
		gen roof_final=roof
		replace roof_final=5 if roof==7 & roof2==3
		replace roof_final=6 if roof==7 & roof2==2
		replace roof_final=7 if roof==7 & roof2==1
		replace roof_final=8 if roof==5 | roof==6
	
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
	
	keep compound_code today_alt exempt stratum a7 tmt house r_* pct_* rate taxes_paid pilot house_quality_new roof walls ravine sex_prop age_prop move_ave main_tribe employed salaried work_gov job_gov neighbor_know neighbor_know2 discount_know discount_self tmt_2016  bribe_combined bribe_combined_amt paid_self salongo salongo_hours flier_all today_carto taxes_paid_*d
	tempfile ml
	save `ml'

**************
* Merge Data *
**************
	
* merge baseline and endline 
use `bl', clear
merge 1:1 code using `el', nogen
drop if compound_code==. 
tempfile bl_el
save `bl_el'

* merge full data, machine learning, baseline and endline
use `ml', clear
merge 1:1 compound_code using `machine_learning', nogen keep(match)
merge 1:m compound_code using `bl_el' 
drop if _merge==2 // 5 compound codes reported at endline don't exist in the complete data (104191,204030,504107,542145,6outpu86022)
drop _merge

**********************
* Polygon-Level Data *
**********************

preserve
		
		// Data from randomization
			use "${repldir}/Data/01_base/survey_data/endline_2016campaign_noPII.dta",clear
			keep a7 program commune stratum paid_receipt_union paid_amt_admin
			ren program jontax
			ren stratum stratum_jon
			ren paid_receipt_union paid_2016
			g paid_counter = paid_2016!=.
			collapse (mean) jontax paid_2016 (sum) count_prop_2016 = paid_counter rev_2016 = paid_amt_admin (first) stratum commune, by(a7)
			
				replace rev_2016 = rev_2016/count_prop_2016
			
				// One commune fix
				replace commune = 1 if commune==. & a7==574
			
				// Fix polygon for spilts
				expand 3 if a7==609,g(exp)
				sort exp,stable
				by exp: g tmp_id = _n
				replace tmp_id = . if exp==0
				replace a7 = 6091 if tmp_id==1
				replace a7 = 6092 if tmp_id==2
				replace a7 = 6093 if tmp_id==. & a7==609
				drop exp tmp_id
				
				expand 4 if a7==610,g(exp)
				sort exp,stable
				by exp: g tmp_id = _n
				replace tmp_id = . if exp==0
				replace a7 = 6101 if tmp_id==. & exp==0 & a7==610
				replace a7 = 6102 if tmp_id==1 & exp==1 & a7==610
				replace a7 = 6103 if tmp_id==2 & exp==1 & a7==610
				replace a7 = 6104 if tmp_id==3 & exp==1 & a7==610
				drop exp tmp_id
				
				drop if a7>400 & a7<500 // Nganza
				drop if inlist(a7,200,201,202,203,207,208,210) // Pilot polygons
				
				g joncomp2016 = 1 if jontax==1 & paid_2016==0
				replace joncomp2016 = 2 if jontax==1 & paid_2016>0 & paid_2016<.
				replace joncomp2016 = 1 if jontax==0
				
			tempfile impots1
			sa `impots1'
		
		restore
		
	// Jon's JMP taxation outcomes by polygon
	merge m:1 a7 using `impots1',keepusing(paid_2016 rev_2016)
	assert _merge==3
	drop _merge
	
	// Chef survey outcomes
	preserve
	
		* Start with Pablo data to get chef "domains" by polygon (don't necessarily align with chef polygon-code)
		u "${repldir}/Data/01_base/admin_data/chief_collector_candidates.dta",clear
		keep if rankpop<=5 // Keep top 5 ranked chefs
		cap drop _merge
		
		merge m:1 code using "${repldir}/Data/01_base/survey_data/chief_survey_randbasis_noPII.dta",gen(_mergechef) ///
			keepusing(edu inc_mo state_cap1 collect_ever)
		drop if _mergechef!=3 // 8 observations
		drop _merge*
		
		* Drop pilot polygons
		drop if inlist(a7,200,201,202,203,207,208,210)

		* Create dataset at the polygon-level
		collapse (mean) chef_edu = edu chef_inc_mo = inc_mo chef_statecap = state_cap1 (count) chefs_poly = code,by(a7)
		
		tempfile chefsurvey1
		sa `chefsurvey1'
	
	restore
	
	merge m:1 a7 using `chefsurvey1'
	drop if _merge==2 // 9 non-matching observations - these are "excluded" polygons
	assert _merge==3
	drop _merge
	
	// Other compliance measure
	preserve
		u "${repldir}/Data/01_base/admin_data/tax_payments_neighborhoods.dta",clear
		
		// Fix polygon for spilts
				expand 3 if a7==609,g(exp)
				sort exp,stable
				by exp: g tmp_id = _n
				replace tmp_id = . if exp==0
				replace a7 = 6091 if tmp_id==1
				replace a7 = 6092 if tmp_id==2
				replace a7 = 6093 if tmp_id==. & a7==609
				drop exp tmp_id
				
				expand 4 if a7==610,g(exp)
				sort exp,stable
				by exp: g tmp_id = _n
				replace tmp_id = . if exp==0
				replace a7 = 6101 if tmp_id==. & exp==0 & a7==610
				replace a7 = 6102 if tmp_id==1 & exp==1 & a7==610
				replace a7 = 6103 if tmp_id==2 & exp==1 & a7==610
				replace a7 = 6104 if tmp_id==3 & exp==1 & a7==610
				drop exp tmp_id
				
				drop if a7>400 & a7<500 // Nganza
				drop if inlist(a7,200,201,202,203,207,208,210) // Pilot polygons
				
			ren paid paid_2016_alternate
			replace paid_2016_alternate = paid_2016_alternate/hh_final
			
			g rev_2016_alternate = amount/hh_final
			
			tempfile paid_alternate
			sa `paid_alternate'
		
	restore
	
	merge m:1 a7 using `paid_alternate'
	assert _merge!=2
	replace rev_2016_alternate = rev_2016 if _merge==1
	drop _merge
	
	// Rouge (conflict-affectedness)

	merge m:1 a7 using "${repldir}/Data/01_base/admin_data/randomization_assignment.dta",keepusing(rouge)

	// Time FE
	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes

**************
* Coding *
**************

* drop villas 
drop if house==3

* drop if rate is missing (to investigate: 1,000+ maison moyennes missing rate info)
drop if rate==.

* drop pilot
drop if pilot==1

sort a7 compound_code,stable
by a7: g counter = _n
foreach var in paid_2016 chefs_poly rouge rev_2016_alternate{
replace `var' = . if counter!=1 // polygon-level outcomes
}

egen dist_health=rowmin(dist_health_centers dist_hospitals)
egen dist_edu=rowmean(dist_private_schools dist_public_schools dist_universities)
egen dist_stateandmkt=rowmean(dist_state_buildings dist_police_stations dist_city_center dist_markets dist_gas_stations)

* Globals for Table
global balancevars_bl "rev_2016_alternate rouge edu_yrs elect1 lg_inc_mo trust_chief trust_nat_gov trust_prov_gov trust_tax_min"
global balancevars_ml "dist_stateandmkt dist_health dist_edu dist_roads dist_ravin house_quality_new sex_prop age_prop main_tribe employed salaried work_gov job_gov"

global balancevars_ml_dist "dist_stateandmkt dist_health dist_edu dist_roads dist_ravin"
global balancevars_ml_owner "house_quality_new sex_prop age_prop main_tribe employed salaried work_gov job_gov"

tempfile full
sa `full'

**********************************
* Balance for Baseline Variables *
**********************************

* Below we calculate the mean of the LHS variable within the control group and then run a regression of the LHS var on treatment dummies
* I write all of the output to a csv because it is difficult to get the formatting we want using Stata programs like esttab

* Open temp file to write table output to. This will be converted to the actual output
tempfile temp
capture file close outfile
file open outfile using `temp', write replace
file write outfile ",Obs,ControlMean,ExpCoef_C,ExpCoef_L,ExpCoef_CLI,ExpCoef_CXL" _n

* Define an output format for estimates
global fmt "%9.4f"

* Keep track of total number of coefficients estimated and number of significant coefficients for text notes
local coef_count = 0
local p10_count = 0
local p05_count = 0
local p01_count = 0

* Generate tmts
g central = tmt==1
g local = tmt==2
g centralwinfo = tmt==3
g centralxlocal = tmt==4

* Generate control 
gen control=1
replace control=0 if central==1 
replace control=0 if local==1
replace control=0 if centralwinfo==1
replace control=0 if centralxlocal==1
 
local i=1
foreach v of global balancevars_bl {
	
	* Calculate mean of each variable within control group
	su `v' if control==1
	local cont = `r(mean)'	
	
	* Test for statistically significant deviations from control mean in experimental and section 8 groups
	reg `v' central local centralwinfo centralxlocal, vce(cl a7) //  abs(stratum)
	local observations = e(N)	
	local coef_count = `coef_count'+2
	
	* Store coefficients and significance stars to be printed below
	local b_exp_c  = _b[central]
	local se_b_exp_c = _se[central]
	local star_exp_c = ""
	if abs(`b_exp_c'/`se_b_exp_c')>invnormal(.95) & abs(`b_exp_c'/`se_b_exp_c')<=invnormal(.975) { 
		local star_exp_c = "*"
		local p10_count = `p10_count'+1
	}
	if abs(`b_exp_c'/`se_b_exp_c')>invnormal(.975) & abs(`b_exp_c'/`se_b_exp_c')<=invnormal(.995) { 
		local star_exp_c = "**"
		local p05_count = `p05_count'+1
	}
	if abs(`b_exp_c'/`se_b_exp_c')>invnormal(.995) & abs(`b_exp_c'/`se_b_exp_c')<. {
		local star_exp_c = "***"
		local p01_count = `p01_count'+1
	}
	
	local b_exp_l  = _b[local]
	local se_b_exp_l = _se[local]
	local star_exp_l = ""
	if abs(`b_exp_l'/`se_b_exp_l')>invnormal(.95) & abs(`b_exp_l'/`se_b_exp_l')<=invnormal(.975) { 
		local star_exp_l = "*"
		local p10_count = `p10_count'+1
	}
	if abs(`b_exp_l'/`se_b_exp_l')>invnormal(.975) & abs(`b_exp_l'/`se_b_exp_l')<=invnormal(.995) { 
		local star_exp_l = "**"
		local p05_count = `p05_count'+1
	}
	if abs(`b_exp_l'/`se_b_exp_l')>invnormal(.995) & abs(`b_exp_l'/`se_b_exp_l')<. {
		local star_exp_l = "***"
		local p01_count = `p01_count'+1
	}
	
	
	local b_exp_cli  = _b[centralwinfo]
	local se_b_exp_cli = _se[centralwinfo]
	local star_exp_cli = ""
	if abs(`b_exp_cli'/`se_b_exp_cli')>invnormal(.95) & abs(`b_exp_cli'/`se_b_exp_cli')<=invnormal(.975) { 
		local star_exp_cli = "*"
		local p10_count = `p10_count'+1
	}
	if abs(`b_exp_cli'/`se_b_exp_cli')>invnormal(.975) & abs(`b_exp_cli'/`se_b_exp_cli')<=invnormal(.995) { 
		local star_exp_cli = "**"
		local p05_count = `p05_count'+1
	}
	if abs(`b_exp_cli'/`se_b_exp_cli')>invnormal(.995) & abs(`b_exp_cli'/`se_b_exp_cli')<. {
		local star_exp_cli = "***"
		local p01_count = `p01_count'+1
	}
	
	local b_exp_cxl  = _b[centralxlocal]
	local se_b_exp_cxl = _se[centralxlocal]
	local star_exp_cxl = ""
	if abs(`b_exp_cxl'/`se_b_exp_cxl')>invnormal(.95) & abs(`b_exp_cxl'/`se_b_exp_cxl')<=invnormal(.975) { 
		local star_exp_cxl = "*"
		local p10_count = `p10_count'+1
	}
	if abs(`b_exp_cli'/`se_b_exp_cxl')>invnormal(.975) & abs(`b_exp_cxl'/`se_b_exp_cxl')<=invnormal(.995) { 
		local star_exp_cxl = "**"
		local p05_count = `p05_count'+1
	}
	if abs(`b_exp_cxl'/`se_b_exp_cxl')>invnormal(.995) & abs(`b_exp_cxl'/`se_b_exp_cxl')<. {
		local star_exp_cxl = "***"
		local p01_count = `p01_count'+1
	}
	
	* Use value of 99999 as flag for missing coefficient to be parsed and dropped below
	if _b[central]==0 & _se[central]==0{
		local b_exp_c = 99999
		local se_b_exp_c = 99999
		local star_exp_c = ""
	}
	if _b[local]==0 & _se[local]==0{
		local b_exp_l = 99999
		local se_b_exp_l = 99999
		local star_exp_l = ""
	}
		if _b[centralwinfo]==0 & _se[centralwinfo]==0{
		local b_exp_cli = 99999
		local se_b_exp_cli = 99999
		local star_exp_cli = ""
	}
		if _b[centralxlocal]==0 & _se[centralxlocal]==0{
		local b_exp_cxl = 99999
		local se_b_exp_cxl = 99999
		local star_exp_cxl = ""
	}
	

	* Print means, coefficients, standard errors, and significance stars to output csv file
	local rowname : word `i' of rev_2016_alternate rouge edu_yrs elect1 lg_inc_mo trust_chief trust_nat_gov trust_prov_gov trust_tax_min
	file write outfile `"`rowname',=""' ${fmt} (`observations') `"", =""' ${fmt} (`cont') `"", =""' ${fmt} (`b_exp_c') `"`star_exp_c'", =""' ${fmt} (`b_exp_l') `"`star_exp_l'", =""' ${fmt} (`b_exp_cli') `"`star_exp_cli'",  =""' ${fmt} (`b_exp_cxl') `"`star_exp_cxl'""' _n
	file write outfile `" , , ,="("' ${fmt} (`se_b_exp_c') `")",="("'${fmt} (`se_b_exp_l') `")",="("'${fmt} (`se_b_exp_cli') `")",="("'${fmt} (`se_b_exp_cxl') `")""' _n

	local i=`i'+1
}

local ++i

cap file close infile
file open infile using `temp', read

* Open csv file to write table
file close outfile
file open outfile using "${reploutdir}/balance_baseline_wcontrol.csv", write replace

* Write each line from the temporary table file to the final output table. Replace 99999 placeholders for missing coefficients with blanks
file read infile line
while r(eof)==0{
	local out = subinstr(trim(itrim(`"`line'"'))," ","",.)
	local out = subinstr(`"`out'"', "(99999.0)", "", .)
	local out = subinstr(`"`out'"', "99999.0", "", .)
	file write outfile `"`out'"' _n
	file read infile line
}
file close infile 
file close outfile

*********************************
* Balance for Midline Variables *
*********************************

* Below we calculate the mean of the LHS variable within the control group and then run a regression of the LHS var on treatment dummies
* I write all of the output to a csv because it is difficult to get the formatting we want using Stata programs like esttab

* Open temp file to write table output to. This will be converted to the actual output
tempfile temp_ml
capture file close outfile
file open outfile using `temp_ml', write replace
file write outfile ",Obs,ControlMean,ExpCoef_C,ExpCoef_L,ExpCoef_CLI,ExpCoef_CXL" _n

* Define an output format for estimates
global fmt "%9.4f"

* Keep track of total number of coefficients estimated and number of significant coefficients for text notes
local coef_count = 0
local p10_count = 0
local p05_count = 0
local p01_count = 0
 
local i=1
foreach v of global balancevars_ml {
	
	* Calculate mean of each variable within control group
	su `v' if control==1
	local cont = `r(mean)'	
	
	* Test for statistically significant deviations from control mean in experimental and section 8 groups
	reg `v' central local centralwinfo centralxlocal, vce(cl a7) // abs(stratum)
	local observations = e(N)	
	local coef_count = `coef_count'+2
	
	* Store coefficients and significance stars to be printed below
	local b_exp_c  = _b[central]
	local se_b_exp_c = _se[central]
	local star_exp_c = ""
	if abs(`b_exp_c'/`se_b_exp_c')>invnormal(.95) & abs(`b_exp_c'/`se_b_exp_c')<=invnormal(.975) { 
		local star_exp_c = "*"
		local p10_count = `p10_count'+1
	}
	if abs(`b_exp_c'/`se_b_exp_c')>invnormal(.975) & abs(`b_exp_c'/`se_b_exp_c')<=invnormal(.995) { 
		local star_exp_c = "**"
		local p05_count = `p05_count'+1
	}
	if abs(`b_exp_c'/`se_b_exp_c')>invnormal(.995) & abs(`b_exp_c'/`se_b_exp_c')<. {
		local star_exp_c = "***"
		local p01_count = `p01_count'+1
	}
	
	local b_exp_l  = _b[local]
	local se_b_exp_l = _se[local]
	local star_exp_l = ""
	if abs(`b_exp_l'/`se_b_exp_l')>invnormal(.95) & abs(`b_exp_l'/`se_b_exp_l')<=invnormal(.975) { 
		local star_exp_l = "*"
		local p10_count = `p10_count'+1
	}
	if abs(`b_exp_l'/`se_b_exp_l')>invnormal(.975) & abs(`b_exp_l'/`se_b_exp_l')<=invnormal(.995) { 
		local star_exp_l = "**"
		local p05_count = `p05_count'+1
	}
	if abs(`b_exp_l'/`se_b_exp_l')>invnormal(.995) & abs(`b_exp_l'/`se_b_exp_l')<. {
		local star_exp_l = "***"
		local p01_count = `p01_count'+1
	}
	
	
	local b_exp_cli  = _b[centralwinfo]
	local se_b_exp_cli = _se[centralwinfo]
	local star_exp_cli = ""
	if abs(`b_exp_cli'/`se_b_exp_cli')>invnormal(.95) & abs(`b_exp_cli'/`se_b_exp_cli')<=invnormal(.975) { 
		local star_exp_cli = "*"
		local p10_count = `p10_count'+1
	}
	if abs(`b_exp_cli'/`se_b_exp_cli')>invnormal(.975) & abs(`b_exp_cli'/`se_b_exp_cli')<=invnormal(.995) { 
		local star_exp_cli = "**"
		local p05_count = `p05_count'+1
	}
	if abs(`b_exp_cli'/`se_b_exp_cli')>invnormal(.995) & abs(`b_exp_cli'/`se_b_exp_cli')<. {
		local star_exp_cli = "***"
		local p01_count = `p01_count'+1
	}
	
	local b_exp_cxl  = _b[centralxlocal]
	local se_b_exp_cxl = _se[centralxlocal]
	local star_exp_cxl = ""
	if abs(`b_exp_cxl'/`se_b_exp_cxl')>invnormal(.95) & abs(`b_exp_cxl'/`se_b_exp_cxl')<=invnormal(.975) { 
		local star_exp_cxl = "*"
		local p10_count = `p10_count'+1
	}
	if abs(`b_exp_cli'/`se_b_exp_cxl')>invnormal(.975) & abs(`b_exp_cxl'/`se_b_exp_cxl')<=invnormal(.995) { 
		local star_exp_cxl = "**"
		local p05_count = `p05_count'+1
	}
	if abs(`b_exp_cxl'/`se_b_exp_cxl')>invnormal(.995) & abs(`b_exp_cxl'/`se_b_exp_cxl')<. {
		local star_exp_cxl = "***"
		local p01_count = `p01_count'+1
	}
	
	* Use value of 99999 as flag for missing coefficient to be parsed and dropped below
	if _b[central]==0 & _se[central]==0{
		local b_exp_c = 99999
		local se_b_exp_c = 99999
		local star_exp_c = ""
	}
	if _b[local]==0 & _se[local]==0{
		local b_exp_l = 99999
		local se_b_exp_l = 99999
		local star_exp_l = ""
	}
		if _b[centralwinfo]==0 & _se[centralwinfo]==0{
		local b_exp_cli = 99999
		local se_b_exp_cli = 99999
		local star_exp_cli = ""
	}
		if _b[centralxlocal]==0 & _se[centralxlocal]==0{
		local b_exp_cxl = 99999
		local se_b_exp_cxl = 99999
		local star_exp_cxl = ""
	}
	
	* Print means, coefficients, standard errors, and significance stars to output csv file
	local rowname : word `i' of dist_stateandmkt dist_health dist_edu dist_roads dist_ravin house_quality_new sex_prop age_prop main_tribe employed salaried work_gov job_gov
	file write outfile `"`rowname',=""' ${fmt} (`observations') `"", =""' ${fmt} (`cont') `"", =""' ${fmt} (`b_exp_c') `"`star_exp_c'", =""' ${fmt} (`b_exp_l') `"`star_exp_l'", =""' ${fmt} (`b_exp_cli') `"`star_exp_cli'",  =""' ${fmt} (`b_exp_cxl') `"`star_exp_cxl'""' _n
	file write outfile `" , , ,="("' ${fmt} (`se_b_exp_c') `")",="("'${fmt} (`se_b_exp_l') `")",="("'${fmt} (`se_b_exp_cli') `")",="("'${fmt} (`se_b_exp_cxl') `")""' _n

	local i=`i'+1
}

local ++i

cap file close infile
file open infile using `temp_ml', read

* Open csv file to write table
file close outfile
file open outfile using "${reploutdir}/balance_midline_wcontrol.csv", write replace

* Write each line from the temporary table file to the final output table. Replace 99999 placeholders for missing coefficients with blanks
file read infile line
while r(eof)==0{
	local out = subinstr(trim(itrim(`"`line'"'))," ","",.)
	local out = subinstr(`"`out'"', "(99999.0)", "", .)
	local out = subinstr(`"`out'"', "99999.0", "", .)
	file write outfile `"`out'"' _n
	file read infile line
}
file close infile 
file close outfile

*************
* Attrition *
*************


	* use clean baseline data 
	use "${repldir}/Data/01_base/survey_data/baseline_noPII.dta", clear
	keep if tot_complete==1 
				
	keep code a7

	****************
	* Endline Data *
	****************

		preserve
		* Use clean endline data 
		use "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta", clear
		keep if tot_complete==1 
		
		keep code a7 replacement

		tempfile el
		save `el'
		restore
		
		merge 1:1 code using `el'
		
		assert _merge!=2
		g attrited = _merge==1
		drop _merge
		
	*****************
	* Combined Data *
	*****************
		
		preserve
		* Use clean combined data
		use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
		
		collapse (max) tmt stratum,by(a7)
		
		tempfile tmt
		sa `tmt'
		
		restore
		
		merge m:1 a7 using `tmt'
		drop if inlist(a7,200,201,202,203,207,208,210) // pilot
		assert  _merge==3
		drop _merge
		
	**********************
	* Regressions *
	**********************

	* Generate tmts
	g central = tmt==1
	g local = tmt==2
	g centralwinfo = tmt==3
	g centralxlocal = tmt==4

	* Generate control 
	gen control=1
	replace control=0 if central==1 
	replace control=0 if local==1
	replace control=0 if centralwinfo==1
	replace control=0 if centralxlocal==1
	
	// Baseline

		* No Control group, Strata FE
		eststo clear
		eststo: areg attrited central local centralwinfo centralxlocal if inlist(tmt,0,1,2,3,4), vce(cl a7)  abs(stratum)
		sum attrited if control==1
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
		
		* No Control group, Strata FE
		eststo: areg replacement central local centralwinfo centralxlocal if inlist(tmt,0,1,2,3,4), vce(cl a7)  abs(stratum)
		sum replacement if control==1
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'

	// Midline
	
		use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
		keep if tmt!=.

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
		
		replace salongo_hours = 0 if salongo==0
		replace salongo_hours = . if salongo_hours==99999
		
		egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
		egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
		egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
		egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
		
		* Midline attrition measures

		g attrited_monitoring = 1 if _merge_flier_carto_rep_monit==1
		replace attrited_monitoring = 0 if _merge_flier_carto_rep_monit==3

		* Generate tmts
		g central = tmt==1
		g local = tmt==2
		g centralwinfo = tmt==3
		g centralxlocal = tmt==4

		* Generate control
		cap gen control=1
		replace control=0 if central==1
		replace control=0 if local==1
		replace control=0 if centralwinfo==1
		replace control=0 if centralxlocal==1

		* No Control group, Strata FE
		eststo: areg attrited_monitoring central local centralwinfo centralxlocal if inlist(tmt,0,1,2,3,4), vce(cl a7)  abs(stratum)
		sum attrited_monitoring if tmt==0
		estadd local Mean=abs(round(`r(mean)',.001))
		estadd scalar Observations = `e(N)'
		estadd scalar Clusters = `e(N_clust)'
	
	esttab using "${reploutdir}/attrition_wcontrol.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (central local centralwinfo centralxlocal) ///
	order(central local centralwinfo centralxlocal) ///
	scalar(Clusters Mean) sfmt(0 3) ///
	nomtitles ///
	mgroups("Baseline to Endline Attrition" "Baseline Replacement" "Midline Attrition", pattern(1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
