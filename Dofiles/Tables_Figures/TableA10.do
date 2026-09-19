
*************
* Table A10 *
*************

********************
* Prepare datasets *
********************

use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
	preserve
		collapse (max) tmt (min) today_alt,by(a7)
		ren a7 nbr_poly_nm
		ren today_alt nbr_tmt_timing
		tempfile tmt
		sa `tmt'
		ren tmt tmt_own
		ren nbr_poly_nm src_poly_nm
		ren nbr_tmt_timing tmt_timing
		tempfile tmt_own
		sa `tmt_own'
	restore
	
	preserve
		insheet using "${repldir}/Data/01_base/admin_data/adjacent_neighborhoods.csv",clear names
		destring nbr_poly_nm src_poly_nm length,replace ignore(",")
		replace length = length/1000
		merge m:1 nbr_poly_nm using `tmt' // 1 non-matching (non-adjacent?): 574
		drop if _merge==2
		drop _merge
		ren tmt nbr_tmt
		merge m:1 src_poly_nm using `tmt_own'
		drop if _merge==1 // still non-matching: 574
		ren src a7
		
		bys a7: egen nbr_count = count(nbr_poly_nm)
		bys a7: egen border_tot = sum(length)
		
		// Other treatments
		g other_tmt_strict = 0 if inlist(tmt_own,1,2)
		replace other_tmt_strict = 1 if tmt_own==1 & nbr_tmt==2 & ((tmt_timing+30)>nbr_tmt_timing)
		replace other_tmt_strict = 1 if tmt_own==2 & nbr_tmt==1 & ((tmt_timing+30)>nbr_tmt_timing)
		
		g other_tmt_strict_border = other_tmt_strict*length
		
		g other_tmt_broad = 0 if inlist(tmt_own,1,2)
		replace other_tmt_broad = 1 if tmt_own==1 & (nbr_tmt==2|nbr_tmt==4) & ((tmt_timing+30)>nbr_tmt_timing)
		replace other_tmt_broad = 1 if tmt_own==2 & (nbr_tmt==1|nbr_tmt==3|nbr_tmt==4) & ((tmt_timing+30)>nbr_tmt_timing)
		
		g other_tmt_broad_border = other_tmt_broad*length

		collapse (sum) n_other_tmt_strict = other_tmt_strict n_other_tmt_broad = other_tmt_broad ///
					   other_tmt_strict_border other_tmt_broad_border ///
				 (max) nbr_count border_tot, ///
					   by(a7)
		
		tempfile nbr
		sa `nbr'

	restore
	
	merge m:1 a7 using `nbr'
	assert _merge==3
	
	* Define interactions
	g t_lXn_other_tmt_strict = t_l*n_other_tmt_strict
	g t_lXn_other_tmt_broad = t_l*n_other_tmt_broad
	g t_lXother_tmt_strict_border = t_l*other_tmt_strict_border
	g t_lXother_tmt_broad_border = t_l*other_tmt_broad_border
	
	* Define FE
	sum today_alt
	local tdm_min = `r(min)'
	local tdm_max = `r(max)'+1
	
	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
	
	eststo clear
	label var t_l "Local"
	
	* Normal - Compliance - Strict N Other Tmt
	eststo: reg taxes_paid t_l n_other_tmt_strict i.house i.time_FE_tdm_2mo_CvL i.stratum nbr_count if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Normal - Compliance - Strict N Other Tmt
	eststo: reg taxes_paid t_l t_lXn_other_tmt_strict n_other_tmt_strict i.house i.time_FE_tdm_2mo_CvL i.stratum nbr_count if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Normal - Compliance - Broad N Other Tmt
	eststo: reg taxes_paid t_l n_other_tmt_broad i.house i.time_FE_tdm_2mo_CvL i.stratum nbr_count if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Normal - Compliance - Broad N Other Tmt
	eststo: reg taxes_paid t_l t_lXn_other_tmt_broad n_other_tmt_broad i.house i.time_FE_tdm_2mo_CvL i.stratum nbr_count if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Normal - Compliance - Strict Border Tmt
	eststo: reg taxes_paid t_l other_tmt_strict_border i.house i.time_FE_tdm_2mo_CvL i.stratum border_tot if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Normal - Compliance - Strict Border Tmt
	eststo: reg taxes_paid t_l t_lXother_tmt_strict_border other_tmt_strict_border i.house i.time_FE_tdm_2mo_CvL i.stratum border_tot if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Normal - Compliance - Broad Broad Tmt
	eststo: reg taxes_paid t_l t_lXother_tmt_broad_border other_tmt_broad_border i.house i.time_FE_tdm_2mo_CvL i.stratum border_tot if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	* Normal - Compliance - Broad Broad Tmt
	eststo: reg taxes_paid t_l t_lXother_tmt_broad_border other_tmt_broad_border i.house i.time_FE_tdm_2mo_CvL i.stratum border_tot if inlist(tmt,1,2), cl(a7)
	su taxes_paid if t_c==1
	estadd local Mean=abs(round(`r(mean)',.001))
	estadd scalar Observations = `e(N)'
	estadd scalar Clusters = `e(N_clust)'
	
	esttab using "${reploutdir}/awareness_other_tmts.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l t_lXn_other_tmt_strict n_other_tmt_strict t_lXn_other_tmt_broad n_other_tmt_broad t_lXother_tmt_strict_border other_tmt_strict_border t_lXother_tmt_broad_border other_tmt_broad_border nbr_count border_tot) ///
	order(t_l t_lXn_other_tmt_strict n_other_tmt_strict t_lXn_other_tmt_broad n_other_tmt_broad t_lXother_tmt_strict_border other_tmt_strict_border t_lXother_tmt_broad_border other_tmt_broad_border nbr_count border_tot) ///
	scalar(Clusters Mean) sfmt(0 3 3) ///
	nomtitles ///
	mgroups("Tax Compliance" "Tax Compliance" "Tax Compliance"  "Tax Compliance", pattern(1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
	indicate("Time FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
