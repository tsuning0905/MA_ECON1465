

use "${repldir}/Data/01_base/admin_data/tax_payments_noPII.dta", clear
duplicates tag compound1, gen(dup_compund1) 
drop if dup_compund1==1
drop if compound1==. 
tempfile full
save `full'

use `full', clear
merge 1:m compound1 using "${repldir}/Data/01_base/admin_data/tax_payment_timing_noPII.dta", keepusing(hours minutes seconds hours_minutes_seconds) keep(match) force 
drop _merge
merge m:1 a7 using "${repldir}/Data/02_intermediate/assignment.dta" 

drop if hours_minutes_seconds==0
twoway (kdensity hours_minutes_seconds if tmt==1) (kdensity hours_minutes_seconds if tmt==2) (kdensity hours_minutes_seconds if tmt==3) (kdensity hours_minutes_seconds if tmt==4), ///
xtitle("Tax collection: hour of the day") ytitle("Density") ///
legend(label(1 "Central") label(2 "Local") label(3 "CLI") label(4 "CxL") ring(0) position(1)) 
graph export "$reploutdir/time_collection_all_tmt.pdf", replace

twoway (kdensity hours_minutes_seconds if tmt==1) (kdensity hours_minutes_seconds if tmt==2), xtitle("Tax collection: hour of the day") ytitle("Density") legend(label(1 "Central") label(2 "Local") ring(0) position(1)) 
graph export "$reploutdir/time_collection_CvL.pdf", replace

twoway (kdensity hours_minutes_seconds if tmt==1) (kdensity hours_minutes_seconds if tmt==2) (kdensity hours_minutes_seconds if tmt==3), xtitle("Tax collection: hour of the day") ytitle("Density") legend(label(1 "Central") label(2 "Local") label(3 "CLI") ring(0) position(1)) 
graph export "$reploutdir/time_collection_CvLvCLI.pdf", replace

* L vs. CLI Gap


preserve

	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
	keep if tmt==1 | tmt==2 | tmt==3
	
	cap drop visit_post_carto
	gen visit_post_carto=0 if visited==0 | (visits!=0 & visits!=.)
	replace visit_post_carto=1 if visits!=. & visits>1
	
	cap drop nb_visit_post_carto
	gen nb_visit_post_carto=0 if visits!=. | visited==0
	replace nb_visit_post_carto=visits-1 if visits!=. & visits>1
	replace nb_visit_post_carto=. if nb_visit_post_carto==99998
	replace nb_visit_post_carto = . if visit_post_carto==.

	egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
	egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
	egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
	
	* Same spec with revenues
	
	reg taxes_paid_amt t_cli t_l i.house i.stratum i.time_FE_tdm_2mo_CvLvCLI if inlist(tmt,1,2,3), cl(a7)
	local cli_rev_per_person = _b[_cons] + _b[t_cli]
	local l_rev_per_person = _b[_cons] + _b[t_l]
	
	count if taxes_paid_amt!=. & tmt==2
	local num_l = `r(N)'
	
	local predict_rev_l = `num_l' * `l_rev_per_person'
	di "Local predicted total revenue: `predict_rev_l'"
	
	count if taxes_paid_amt!=. & tmt==3
	local num_cli = `r(N)'
	
	local predict_rev_cli = `num_cli' * `cli_rev_per_person'
	di "CLI predicted total revenue: `predict_rev_cli'"
	
	local scaler = `num_cli' / `num_l'
	local predict_rev_l_scaled = `predict_rev_l'*`scaler'

	di "Local predicted total revenue (scaled): `predict_rev_l_scaled'"

	local l_cli_gap = `predict_rev_l_scaled'- `predict_rev_cli'
	di "Local (scaled) - CLI: `l_cli_gap'"

	global l_cli_gap = `l_cli_gap'
	
	egen tot_rev_l = sum(taxes_paid_amt) if tmt==2
	egen tot_rev_cli = sum(taxes_paid_amt) if tmt==3
	
	sum tot_rev_l
	local tot_rev_l = `r(mean)' * `scaler'
	sum tot_rev_cli
	g rev_diff_l_cli = `tot_rev_l' - `r(mean)'
	
restore

* Back of the envelope

g late_collect = hours_minutes_seconds>= 16
replace late_collect = . if hours_minutes_seconds==.

egen sum_late_collect_c = sum(amountCF) if late_collect==1 & tmt==1
egen sum_late_collect_l = sum(amountCF) if late_collect==1 & tmt==2
egen sum_late_collect_cli = sum(amountCF) if late_collect==1 & tmt==3

sum sum_late_collect_c 
local sum_late_collect_c = `r(mean)'

sum sum_late_collect_l
local sum_late_collect_l = `r(mean)'

sum sum_late_collect_cli
local sum_late_collect_cli = `r(mean)'

global diff_late_collect_l_c = `sum_late_collect_l' - `sum_late_collect_c'

di "Local collects more than Central after 4pm: $diff_late_collect_l_c"

global diff_late_collect_l_cli = `sum_late_collect_l' - `sum_late_collect_cli'

di "Local collects more than CLI after 4pm: $diff_late_collect_l_cli"

*Note $l_cli_gap from Main_Tax_Outcomes_Tables_HouseFE dofile

global percent_rev_gap_cli = $diff_late_collect_l_cli / $l_cli_gap

di "Late collections as percent of total revenue gap between Local and CLI: $percent_rev_gap_cli"

