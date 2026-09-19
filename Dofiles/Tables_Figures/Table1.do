***********
* Table 1 *
***********

mat define T1 = J(5,2,.)

* Tax campaign activity counts (registration and visits)
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
count if tmt!=.
mat T1[1,1] = `r(N)'
mat T1[2,1] = `r(N)' // same N for registration and visits

bys a7: egen temp_rank = rank(compound1),unique // number of neighborhoods
count if temp_rank==1 & tmt!=.
mat T1[1,2] = `r(N)'
mat T1[2,2] = `r(N)'
drop temp_rank

keep if tmt!=.
collapse (mean) tmt,by(a7)
tempfile treatment
sa `treatment'

* Evaluation activity counts

	* Baseline
	u "${repldir}/Data/01_base/survey_data/baseline_noPII.dta",clear
	keep if tot_complete==1

	merge m:1 a7 using `treatment'
	drop if _merge==2 | _merge==1
	drop _merge

	count
	mat T1[3,1] = `r(N)'

	bys a7: egen temp_rank = rank(code),unique // number of neighborhoods
	count if temp_rank==1
	mat T1[3,2] = `r(N)'
	drop temp_rank
	
	* Midline
	u "${repldir}/Data/01_base/survey_data/midline_noPII.dta",clear
	keep if tot_complete==1
	cap drop tmt

	merge m:1 a7 using `treatment'
	drop if _merge==2 | _merge==1
	drop _merge

	count
	mat T1[4,1] = `r(N)'

	bys a7: egen temp_rank = rank(compound),unique // number of neighborhoods
	count if temp_rank==1
	mat T1[4,2] = `r(N)'
	drop temp_rank
	
	* Endline
	u "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta",clear
	keep if tot_complete==1
	cap drop tmt

	merge m:1 a7 using `treatment'
	drop if _merge==2 | _merge==1
	drop _merge

	count
	mat T1[5,1] = `r(N)'

	bys a7: egen temp_rank = rank(code),unique // number of neighborhoods
	count if temp_rank==1
	mat T1[5,2] = `r(N)'
	drop temp_rank
	
* Output

	cap ssc install outtable
	mat rownames T1 = registration visits baseline midline endline
	mat colnames T1 = N J
	outtable using "${reploutdir}/campaign_components.tex",mat(T1) replace






	

	

