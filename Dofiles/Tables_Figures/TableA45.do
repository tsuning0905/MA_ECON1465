
*************
* Table A45 * 
*************

	* Use Clean dataset
	use "${repldir}/Data/03_clean_combined/combined_data.dta", clear
	gen n=1
	gen n_periph=1 if house==1
	gen n_mm=1 if house==2
	
	* Drop villas
	drop if house==3

	* Drop pilot data
	drop if pilot==1 
	drop if a7==200 | a7==201 | a7==202 | a7==203 | a7==207 | a7==208 | a7==210
	
	* Drop control polygons
	drop if tmt==0 
	replace tmt=1 if tmt==. & a7==236 // missing tmt

	* Amounts of taxes paid
	cap drop taxes_paid_amt
	gen taxes_paid_amt=taxes_paid*rate
	gen taxes_paid_amt_periph=0
	replace taxes_paid_amt_periph=taxes_paid*rate if house==1
	gen taxes_paid_amt_mm=0
	replace taxes_paid_amt_mm=taxes_paid*rate if house==2
	
	* Amounts of bonus paid 
	gen bonus_amt=0 if taxes_paid==0 
	replace bonus_amt=bonus_FC if taxes_paid==1
	gen bonus_amt_periph=0 
	replace bonus_amt_periph=bonus_FC if taxes_paid==1 & house==1
	gen bonus_amt_mm=0 
	replace bonus_amt_mm=bonus_FC if taxes_paid==1 & house==2
	
	* Collapse at the polygon level
	collapse (rawsum)taxes_paid_amt taxes_paid_amt_periph taxes_paid_amt_mm bonus_amt bonus_amt_periph bonus_amt_mm visit_post_carto nb_visit_post_carto n n_periph n_mm (max) month stratum tmt, by(a7)
	
	* Merge with transport costs per polygon
	merge 1:1 a7 using "${repldir}/Data/01_base/admin_data/neighborhood_transport_cost.dta" 
		
	* Check problems with merge
	br if _merge==2
	*pause // To check: can't figure out the problem for this 1 obs
	
	br if _merge==1
	replace transport_costs=0 if _merge==1 
	*pause // To check: missing 5 polygons in transport sheet
	
	drop _merge
	
	* Merge with timing per polygon
	merge 1:1 a7 using "${repldir}/Data/03_clean_combined/analysis_data_neighborhoods.dta"
		drop _merge
	
	// Bribes
			
		* Bribe variables
		preserve
			use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
			g counter = 1 if bribe_combined!=.
			collapse (sum) bribe_combined_amt n_svyd_ml = counter (count) n_prop = compound1,by(a7)
			tempfile ml_bribes
			sa `ml_bribes'
		restore
		preserve
			u "${repldir}/Data/01_base/survey_data/endline_round1_noPII.dta",clear
			keep if tot_complete==1 
			replace compound_code=compound_code_prev if (compound_code_prev!=. & compound_code_prev!=3)
			rename compound_code compound1
			replace bribe = bribe2a if bribe==.
			replace bribe = bribe2b if bribe==.
			replace bribe = bribe3 if bribe==.
			replace bribe_amt = bribe2a_amt if bribe_amt==.
			replace bribe_amt = bribe2b_amt if bribe_amt==.
			replace bribe_amt = bribe3_amt if bribe_amt==.
			
			replace bribe_amt = 0 if bribe==0
			
			ren bribe bribe_endline
			ren bribe_amt bribe_amt_endline
			
			ren o_pay2 informal_pay_endline
			ren pay_tot2 informal_pay_amt_endline
				replace informal_pay_amt_endline = . if informal_pay_amt_endline==8885 // looks like enum coding error
			
			ren paid_self paid_self_endline
			
			* Salongo variables
			g salongo_endline = 0 if salongo==0
			replace salongo_endline = 1 if salongo>0 & salongo<.
			
			g salongo_hours_endline = salongo_hours
			replace salongo_hours_endline = . if salongo_hours==16000 | salongo_hours==60000 // obvious outliers
			replace salongo_hours_endline = 0 if salongo_endline==0
			
			keep code a7 *_endline paid_* tot_complete
			
			collapse (sum) bribe_amt_endline informal_pay_amt_endline n_svyd_el = tot_complete,by(a7)
		
			tempfile el_bribes
			sa `el_bribes'
			
		restore
		
		cap drop _merge
		merge 1:1 a7 using `ml_bribes'
		keep if _merge==3
		drop _merge
		merge 1:1 a7 using `el_bribes'
		keep if _merge==3
		
		* Adjust for number
		replace bribe_combined_amt = bribe_combined_amt/(n_svyd_ml/n_prop)
		replace bribe_amt_endline = bribe_amt_endline/(n_svyd_el/n_prop)
		replace informal_pay_amt_endline = informal_pay_amt_endline/(n_svyd_el/n_prop)
	
	*******************
	* Benefit / Costs *
	*******************

	* Benefit / costs 

	* Full
	gen benefit_cost=taxes_paid_amt-(bonus_amt+transport_costs)
	gen benefit_cost_restrict=taxes_paid_amt-(bonus_amt+transport_costs) if tmt==1
	replace benefit_cost_restrict=taxes_paid_amt-(bonus_amt) if tmt==2
	
	bys tmt: egen tot_benefit = sum(taxes_paid_amt)
		g cost = bonus_amt+transport_costs
	bys tmt: egen tot_cost = sum(cost)
	bys tmt: egen tot_cost_restrict = sum(bonus_amt)
	replace tot_cost_restrict = tot_cost if tmt==1
	
	g tot_benefit_cost = tot_benefit-tot_cost
	g tot_benefit_cost_restrict = tot_benefit-tot_cost_restrict if tmt==2
	replace tot_benefit_cost_restrict = tot_benefit-tot_cost if tmt==1
	
	bys tmt: egen tot_ml_bribes = sum(bribe_combined_amt)
	bys tmt: egen tot_el_bribes = sum(bribe_amt_endline)
	bys tmt: egen tot_el_infpay = sum(informal_pay_amt_endline)
	
	bys tmt: g counter = _n
	
	preserve
		keep if counter==1
		keep if tmt==1|tmt==2
		
		keep tot_benefit_cost tot_benefit_cost_restrict tot_ml_bribes tot_el_bribes tot_el_infpay tmt a7 ///
			tot_benefit tot_cost tot_cost_restrict
		
		reshape wide tot_benefit tot_cost tot_cost_restrict tot_benefit_cost tot_benefit_cost_restrict tot_ml_bribes tot_el_bribes tot_el_infpay,i(a7) j(tmt)
		
		collapse (max) tot_benefit* tot_cost* tot_ml_bribes* tot_el_bribes* tot_el_infpay*
		
		g m_el_bribes = (tot_benefit_cost2-tot_benefit_cost1)/(tot_el_bribes2-tot_el_bribes1)
		g m_el_infpay = (tot_benefit_cost2-tot_benefit_cost1)/(tot_el_infpay2-tot_el_infpay1)
		
		g mres_el_bribes = (tot_benefit_cost_restrict2-tot_benefit_cost_restrict1)/(tot_el_bribes2-tot_el_bribes1)
		g mres_el_infpay = (tot_benefit_cost_restrict2-tot_benefit_cost_restrict1)/(tot_el_infpay2-tot_el_infpay1)
		
		sum m*
		
		g type = "Campaign Amounts"
		order type
		expand 2,g(new)
		replace type = "With Mobile Money Payment" if new==1
		drop new
		
		ren tot_benefit1 tot_benefitC
		ren tot_cost1 tot_costC
		ren tot_el_bribes1 tot_el_bribesC
		
		ren tot_benefit2 tot_benefitL
		ren tot_cost2 tot_costL
		ren tot_el_bribes2 tot_el_bribesL
		
		ren m_el_bribes mult_bribes
		
		replace tot_costC = tot_cost_restrict1 if type=="With Mobile Money Payment"
			drop tot_cost_restrict1
		replace tot_costL = tot_cost_restrict2 if type=="With Mobile Money Payment"
			drop tot_cost_restrict2
		replace mult_bribes = mres_el_bribes if type=="With Mobile Money Payment"
			drop mres_el_bribes
			
		replace tot_benefitC = . if type=="With Mobile Money Payment"
		replace tot_benefitL = . if type=="With Mobile Money Payment"
		replace tot_el_bribesC = . if type=="With Mobile Money Payment"
		replace tot_el_bribesL = . if type=="With Mobile Money Payment"
		
		
		outsheet type tot_benefitC tot_costC tot_el_bribesC tot_benefitL tot_costL tot_el_bribesL mult_bribes using "${reploutdir}/bribe_multiplier.csv", comma replace
	restore
