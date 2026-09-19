
********************************************************************************
******************** Cost-Effectiveness Calculations ***************************
********************************************************************************

* Prepare Dataset 

	* Use Clean dataset
	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	gen n=1
	replace tmt = 3 if a7==387 & tmt==.
	replace tmt = 1 if a7==545 & tmt==.
	replace tmt = 3 if a7==667 & tmt==.

	* Drop control polygons
	keep if tmt==1 | tmt==2 |tmt==3
	
	* Amounts of bonus paid 
	gen bonus_amt=0 if taxes_paid==0 
	replace bonus_amt=bonus_FC if taxes_paid==1
	
	* Collapse at the polygon level
	collapse (rawsum)taxes_paid_amt bonus_amt n (max) month stratum , by(a7 tmt)
	
	* Merge with transport costs per polygon
	merge 1:1 a7 using "${repldir}/Data/01_base/admin_data/neighborhood_transport_cost.dta", nogen
	
	* Polygon distance to city center for cost-efficiency heterogeneity
	merge 1:1 a7 using "${repldir}/Data/01_base/admin_data/neighborhood_centroids.dta", keepusing(dist_city_center) nogen
	

*******************
* Benefit / Costs *
*******************

* Benefit / costs 
gen benefit_cost=taxes_paid_amt/(bonus_amt+transport_costs)

* Local tmt
gen Local=1 if tmt==2
replace Local=0 if tmt==1 | tmt==3
label define Local 0 "Central" 1 "Local" 
label value Local Local

preserve 
gen benefit_cost_hypothetical=taxes_paid_amt/(bonus_amt)
keep a7 benefit_cost_hypothetical tmt n
keep if tmt==2
rename benefit_cost_hypothetical benefit_cost
replace tmt=3
tempfile hypothetical
save `hypothetical'
restore
append using `hypothetical'

* Central vs Local: all
label drop tmt 
label define tmt 1 "Central" 2 "Local" 3 "Local with mobile payments"
label value tmt tmt

cibar benefit_cost [weight=n] if tmt==1 | tmt==2 |tmt==3, over1(tmt) /// 
graphopts(graphregion(color(white)) ylabel(0 "0" 0.5 "0.5" 1 "1" 1.5 "1.5" 2 "2" 2.5 "2.5" 3 "3") ytitle("Return on $1 in Administrative Costs")) ///
ciopts(yline(1) yscale(r(0 1.5)) ) 
graph export "$reploutdir/Appdx_PaperFigure_marginal_revenue_hypothetical.pdf", replace

* By distance from city center
twoway (scatter benefit_cost dist_city_center if tmt==1, color(black)) (lfit benefit_cost dist_city_center [weight=n]  if tmt==1, lcolor(black)) ///
(scatter benefit_cost dist_city_center if tmt==2,  color(gray)) (lfit benefit_cost dist_city_center [weight=n] if tmt==2, lcolor(gray) lpattern(dash)), ///
xtitle("Distance of Neighborhood to City Center (in km)") ytitle("Return on $1 in Administrative Costs") ///
legend(label(1 "Central") label(2 "Central") label(3 "Local") label(4 "Local"))
graph export "$reploutdir/scatter_benefit_cost_dist_center_CvsL.pdf", replace

********************* 
* Cost by Treatment *
*********************

keep a7 bonus_amt transport_costs tmt taxes_paid_amt n
preserve
keep a7 bonus_amt tmt n
rename bonus_amt cost
gen bonus=1
tempfile bonus
save `bonus'
restore
preserve
keep a7 transport_costs tmt taxes_paid_amt n
rename transport_costs cost
gen bonus=0
append using `bonus'
label define bonus 0 "Transport" 1 "Compensation" 
label value bonus bonus 

cibar cost [weight=n]  if tmt==1 | tmt==2, over2(bonus) over1(tmt) /// 
graphopts(graphregion(color(white)) ylabel() ytitle("Costs in CF by Neighborhood")) ///
ciopts(yline(1) yscale(r(0 1.5)) ) 
graph export "$reploutdir/costs_by_treatment.pdf", replace
