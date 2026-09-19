
*************
* Table A31 *
*************

	use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear
	
	global RI_ON = 0
	
	cap drop visit_post_carto
	gen visit_post_carto=0 if visited==0 | (visits!=0 & visits!=.)
	replace visit_post_carto=1 if visits!=. & visits>1
	
	cap drop nb_visit_post_carto
	gen nb_visit_post_carto=0 if visits!=. | visited==0
	replace nb_visit_post_carto=visits-1 if visits!=. & visits>1
	replace nb_visit_post_carto=. if nb_visit_post_carto==99998
	replace nb_visit_post_carto = . if visit_post_carto==.
	
	preserve
		u "${repldir}/Data/01_base/admin_data/chief_tribe_info.dta",clear
		keep a7 chef_*tribe col1_*tribe col2_*tribe *_y36
		duplicates drop
		tempfile col_tribe
		sa `col_tribe'
	restore
	
	merge m:1 a7 using `col_tribe'
	drop if _merge==2
	drop _merge

	* Tribe
	foreach val in tribe{
	replace chef_`val'="" if chef_`val'=="."|chef_`val'=="9999"|chef_`val'=="8888"|chef_`val'=="7777"|chef_`val'=="0"
	replace col1_`val'="" if col1_`val'=="."|col1_`val'=="9999"|col1_`val'=="8888"|col1_`val'=="7777"|col1_`val'=="0"
	replace col2_`val'="" if col2_`val'=="."|col2_`val'=="9999"|col2_`val'=="8888"|col2_`val'=="7777"|col2_`val'=="0"
	g collector_`val' = ""
	replace collector_`val' = chef_`val' if collector_`val'==""
	replace collector_`val' = col1_`val' if collector_`val'==""
	replace collector_`val' = col2_`val' if collector_`val'==""
	}
	foreach val in subtribe{
	replace chef_`val'=. if chef_`val'==9999|chef_`val'==8888|chef_`val'==7777|chef_`val'==0
	replace col1_`val'=. if col1_`val'==9999|col1_`val'==8888|col1_`val'==7777|col1_`val'==0
	replace col2_`val'=. if col2_`val'==9999|col2_`val'==8888|col2_`val'==7777|col2_`val'==0
	g collector_`val' = .
	replace collector_`val' = chef_`val' if collector_`val'==.
	replace collector_`val' = col1_`val' if collector_`val'==.
	replace collector_`val' = col2_`val' if collector_`val'==.
	}

	replace subtribe = . if subtribe==99
	*replace tribe = tribe_new if tribe==""
	
	g luluwa_citizen = tribe=="LULUWA"

	g tribe_match = 0
		replace tribe_match = 1 if (tribe == collector_tribe) & (collector_tribe!="" | tribe!="") & t_l==1
		replace tribe_match = . if (collector_tribe=="" | tribe=="") & t_l==1
		replace tribe_match = 1 if ((tribe == col1_tribe)|(tribe==col2_tribe)) & col1_tribe!="" & col2_tribe!="" & tribe!="" & t_c==1
		replace tribe_match = . if (col1_tribe=="" | col2_tribe=="" | tribe=="") & t_c==1
	g subtribe_match = 0
		replace subtribe_match = 1 if (subtribe == collector_subtribe) & (collector_subtribe!=. | subtribe!=.) & t_l==1
		replace subtribe_match = . if (collector_subtribe==. | subtribe==.) & t_l==1
		replace subtribe_match = 1 if ((subtribe == col1_subtribe)|(subtribe==col2_subtribe)) & (col1_subtribe!=. | col2_subtribe!=. | subtribe!=.) & t_c==1
		replace subtribe_match = . if (col1_subtribe==. | col2_subtribe==. | subtribe==.) & t_c==1

	g comaj_match = 0
		replace comaj_match = 1 if tribe=="LULUWA" & collector_tribe=="LULUWA" & t_l==1
		replace comaj_match = . if (collector_tribe=="" | tribe=="") & t_l==1
		replace comaj_match = 1 if tribe=="LULUWA" & (col1_tribe=="LULUWA"|col2_tribe=="LULUWA") & t_c==1
		replace comaj_match = . if (col1_tribe=="" | col2_tribe=="" | tribe=="") & t_c==1
	g comaj_lang_match = 0
		replace comaj_lang_match = 1 if inlist(tribe,"LULUWA","LUNTU","LUBA") & inlist(collector_tribe,"LULUWA","LUNTU","LUBA") & t_l==1
		replace comaj_lang_match = . if (collector_tribe=="" | tribe=="") & t_l==1
		replace comaj_lang_match = 1 if inlist(tribe,"LULUWA","LUNTU","LUBA") & (inlist(col1_tribe,"LULUWA","LUNTU","LUBA")|inlist(col2_tribe,"LULUWA","LUNTU","LUBA")) & t_c==1
		replace comaj_lang_match = . if (col1_tribe=="" | col2_tribe=="" | tribe=="") & t_c==1

	* Territory
	foreach val in y36{
	g collector_terr = ""
	replace collector_terr = chef_`val' if collector_terr==""
	replace collector_terr = col1_`val' if collector_terr==""
	replace collector_terr = col2_`val' if collector_terr==""
	}

	g terr_match = 0
		replace terr_match = 1 if territory == collector_terr & collector_terr!="" & territory!="" & t_l==1
		replace terr_match = . if (collector_terr=="" | territory=="") & t_l==1
		replace terr_match = 1 if ((territory == col1_y36)|(territory == col2_y36)) & col1_y36!="" & col2_y36!="" & territory!="" & t_l==1
		replace terr_match = . if (col1_y36=="" | col2_y36=="" | territory=="") & t_l==1

	* Interactions
	foreach tmt in c l{
	foreach var in tribe subtribe comaj comaj_lang terr {
		g t_`tmt'X`var' = t_`tmt'*`var'_match
	}
	}
	
	egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
	egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
	egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
	egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes
	
	eststo clear
	label var t_l "Local"
	label var t_cli "CLI"
	
	preserve
	keep if inlist(tmt,1,2) & house!=. & stratum!=. & time_FE_tdm_2mo_CvL!=.
	gen nb1=1
	collapse (sum) nb1, by(a7)
	count
	local clusters_all=`r(N)'
	restore

	preserve
	eststo clear
	foreach depvar in visit_post_carto taxes_paid{
	foreach var in tribe subtribe comaj_lang{
	g hetXt_l = t_lX`var'
	g het = `var'_match
	label var hetXt_l "Local X Het"
	label var het "Het"
	eststo: reg `depvar' t_l hetXt_l het i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2),vce(cl a7)
		test t_l = hetXt_l
		estadd local LvHXL = abs(round(`r(p)',.001))
		test het = hetXt_l
		estadd local HvHXL = abs(round(`r(p)',.001))
	estadd local House="Pooled"
	estadd local Polygons=`e(N_clust)'
	su `depvar' if t_c==1 & het==0 & time_FE_tdm_2mo_CvL!=.
	estadd local Mean=abs(round(`r(mean)',.001))
	
	cap drop het*
	}
	}
	esttab using "${reploutdir}/ethnicity_interaction.tex", ///
	replace label b(%9.3f) se(%9.3f) ///
	keep (t_l hetXt_l het) ///
	order(t_l hetXt_l het) ///
	scalar(Mean Polygons) ///
	nomtitles ///
	mgroups("Tribe" "Subtribe" "Lang. Maj." "Tribe" "Subtribe" "Lang. Maj.", pattern(1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	indicate("Time FE = *2mo*""House FE = *house*""Stratum FE = *stratum*") ///
	star(* 0.10 ** 0.05 *** 0.001) ///
	nogaps nonotes compress
	restore
