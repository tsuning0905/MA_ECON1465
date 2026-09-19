*Total tax burden
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes

g tax_or_bribe = taxes_paid
replace tax_or_bribe =1 if bribe ==1

g tax_and_bribe = taxes_paid
replace tax_and_bribe = taxes_paid + bribe if bribe!=.

g total_burden = taxes_paid
replace tax_or_bribe =1 if bribe ==1
replace tax_or_bribe =1 if salongo ==1

g total_burden_intensive = taxes_paid 
replace total_burden_intensive = taxes_paid + bribe if bribe!=.
replace total_burden_intensive = taxes_paid + bribe + salongo if (bribe!=. & salongo!=.)

center tax_and_bribe total_burden_intensive, standardize inplace

eststo clear
	
	foreach depvar in tax_or_bribe tax_and_bribe total_burden total_burden_intensive{
	eststo: reg `depvar' t_l i.stratum i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2),cl(a7)
	su `depvar' if t_c==1 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	}
	esttab using "$reploutdir/cvl_total_tax_burden.tex", ///		
	replace label b(%9.3f) se(%9.3f) ///
	scalar(Clusters Observations Mean) ///
	nomtitles ///
	indicate("Time FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress nocons

