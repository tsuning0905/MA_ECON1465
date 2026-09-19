

***********************************************
*** Return to additional days of collection ***
***********************************************


use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear


keep if inlist(tmt, 1, 2)
keep if today_alt>=21355 & today_alt<=21532

	cap drop visit_post_carto
	gen visit_post_carto=0 if visited==0 | (visits!=0 & visits!=.)
	replace visit_post_carto=1 if visits!=. & visits>1
	
	cap drop nb_visit_post_carto
	gen nb_visit_post_carto=0 if visits!=. | visited==0
	replace nb_visit_post_carto=visits-1 if visits!=. & visits>1
	replace nb_visit_post_carto=. if nb_visit_post_carto==99998
	replace nb_visit_post_carto = . if visit_post_carto==.
	
bysort a7: egen share_visited_poly = mean(visit_post_carto)
bysort a7: egen total_visits_poly = sum(nb_visit_post_carto)


cap drop taxes_paid_amt
gen taxes_paid_amt=taxes_paid*rate
gen bonus_amt=0 if taxes_paid==0 
replace bonus_amt=bonus_FC if taxes_paid==1

bysort a7: egen total_bonus = sum(bonus_amt)


preserve
collapse tmt, by(a7)
merge 1:1 a7 using "${repldir}/Data/01_base/admin_data/neighborhood_transport_cost.dta"
keep if tmt==1|tmt==2
egen total_transport_c = sum(transport) if tmt==1
sum total_transport_c
local total_transport_c = `r(mean)'
local daily_transport_c = `r(mean)'/90
egen total_transport_l = sum(transport) if tmt==2
sum total_transport_l 
local total_transport_l = `r(mean)'/180
local daily_transport_l = `r(mean)'/180
restore


drop month_tdm
rename date_TDM date_tdm
replace date_tdm = today_carto if date_tdm==. & taxes_paid==1

*************
***Central***
*************

g month_tdm_c = 1 if date_tdm<td(20jul2018)
replace month_tdm_c = 2 if date_tdm>=td(20aug2018) & date_tdm<td(20sep2018)
replace month_tdm_c = 3 if date_tdm>=td(16oct2018) & date_tdm<td(14nov2018)

g day_of_month_c = 30-(td(20jul2018)-date_tdm) if month_tdm_c ==1
replace day_of_month_c = 31-(td(20sep2018)-date_tdm) if month_tdm_c ==2
replace day_of_month_c = 31-(td(16nov2018)-date_tdm) if month_tdm_c ==3
replace day_of_month_c=. if tmt!=1
replace day_of_month_c=day_of_month_c+5 if day_of_month_c<0

sum share_visited_poly if tmt ==1
local share_visited_month_c = `r(mean)'

sum share_visited_poly if tmt ==1 & (month_tdm_c==1|month_tdm_c==2)
local share_visited_month_c1_2 = `r(mean)'

sum share_visited_poly if tmt ==2, d
local share_visited_month_l = `r(mean)'

*Just month 1 and 2

*preserve

keep if tmt==1
keep if taxes_paid==1
drop if month_tdm_c==3

collapse (sum) taxes_paid taxes_paid_amt, by(day_of_month_c)

sum taxes_paid_amt if day_of_month_c==.
local revenue_bad_dates = `r(mean)'
drop if day_of_month_c==.
egen total_revenue = sum(taxes_paid_amt)
sum total_revenue
g scaling = 1+`revenue_bad_dates'/`r(mean)'
g amount_scaled = taxes_paid_amt*(scaling)


egen total_payments = sum(taxes_paid)
g cumul_payments = sum(taxes_paid)
g share_total_payment = cumul_payments/total_payments
g share_total_visited = share_total_payment * `share_visited_month_c1_2'

g daily_cost = `daily_transport_c'

g daily_return = amount_scaled/2 - daily_cost // Not including bonus

*binscatter daily_return share_total_visited, line(qfit)

egen byte day_of_month_c_bin = cut(day_of_month_c), group(10)
set type double
collapse (mean) daily_return share_total_visited, by(day_of_month_c_bin)

twoway (lowess daily_return day) (scatter daily_return day if daily_return<200000), yline(0, lcolor(red)) ytitle("Daily Return (Revenue - Cost)") legend(label(1 "Lowess Fit") label(2 "Scatter") ring(0) position(1)) xtitle("Day of Monthlong Collection Period") xlab(0 "0" 3.33 "10" 6.66 "20" 10 "30" )
graph export "$reploutdir/return_by_day_central_month1-2_bin.pdf", replace


twoway (lowess daily_return share_total_visited) (scatter daily_return share_total_visited), yline(0, lcolor(red)) ytitle("Estimated Return (Revenue - Cost)") legend(label(1 "Lowess Fit") label(2 "Scatter") ring(0) position(1)) xtitle("Share of Households Visited")
graph export "$reploutdir/return_by_visits_central_month1-2_bin.pdf", replace

