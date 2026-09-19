***********
* Table 2 *
***********

mat define T2 = J(2,5,.)

* Treatment counts
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
bys a7: egen temp_rank = rank(compound1),unique // number of neighborhoods
replace tmt = 5 if tmt==0 // control
forval i = 1(1)5{

count if temp_rank==1 & tmt==`i'
mat T2[1,`i'] = `r(N)'
count if tmt==`i'
mat T2[2,`i'] = `r(N)'
}
	
* Output

	mat colnames T2 = central local cli cxl control
	mat rownames T2 = neigborhoods properties
	outtable using "${reploutdir}/treatment_allocation.tex",mat(T2) replace






	

	

