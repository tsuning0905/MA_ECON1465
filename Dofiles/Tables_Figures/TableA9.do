
************
* Table A9 *
************

* Clean data for analysis
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* Define FE
sum today_alt
local tdm_min = `r(min)'
local tdm_max = `r(max)'+1
	
egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes
egen time_FE_tdm_2mo_CvCLI = cut(today_alt),at(21365.5 21425.5 21485.5 21519) icodes
egen time_FE_tdm_2mo_LvCLI = cut(today_alt),at(21370.5 21430.5 21490.5 21522) icodes
egen time_FE_tdm_2mo_CvLvCLI = cut(today_alt),at(21363.6 21423.6 21483.6 21524.3) icodes

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
	
eststo clear
label var t_l "Local"

* Exemptions
gen exempt_age=0 if exempt!=.
replace exempt_age=1 if why_exempt==2
gen exempt_widow=0 if exempt!=.
replace exempt_widow=1 if why_exempt==5
gen exempt_pension=0 if exempt!=.
replace exempt_pension=1 if why_exempt==3
gen exempt_handicap=0 if exempt!=.
replace exempt_handicap=1 if why_exempt==4
gen exempt_Other=0 if exempt!=.
replace exempt_Other=1 if why_exempt!=2 & why_exempt!=3 & why_exempt!=4 & why_exempt!=5 & why_exempt!=.
gen enum_disagrees=0 if exempt_enum!=. & exempt!=.
replace enum_disagrees=1 if exempt!=exempt_enum & exempt_enum!=. & exempt!=.
gen enum_agrees=0 if exempt_enum!=. & exempt!=.
replace enum_agrees=1 if exempt==exempt_enum & exempt_enum!=. & exempt!=.

* House type
revrs correct

* Tribe and Know
g t_lXtribe_match = t_l*tribe_match
g t_lXknow_eachother = t_l*know_eachother

* label variables
label var t_c    "Central"
label var exempt "Exempted"
label var exempt_age "Senior"
label var exempt_widow "Widow"
label var exempt_pension "Gov Pension"
label var exempt_handicap "Handicap"
label var exempt_Other "Other"
label var enum_disagree "Enum Disagree"
label var enum_agrees "Enum agrees"
label var tribe_match "Co-ethnic"
label var know_eachother "Knows Colllector"

eststo clear

* Exemptions
eststo: reg exempt t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cluster(a7)
su exempt if t_c==1 
estadd local Mean=abs(round(`r(mean)',.001))
estadd scalar Observations = `e(N)'
estadd scalar Clusters = `e(N_clust)'

eststo: reg enum_agrees t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cluster(a7)
su enum_agrees if t_c==1 
estadd local Mean=abs(round(`r(mean)',.001))
estadd scalar Observations = `e(N)'
estadd scalar Clusters = `e(N_clust)'

eststo: reg exempt_age t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cluster(a7)
su exempt_age if t_c==1 
estadd local Mean=abs(round(`r(mean)',.001))
estadd scalar Observations = `e(N)'
estadd scalar Clusters = `e(N_clust)'

eststo: reg exempt_widow t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cluster(a7)
su exempt_widow if t_c==1 
estadd local Mean=abs(round(`r(mean)',.001))
estadd scalar Observations = `e(N)'
estadd scalar Clusters = `e(N_clust)'

eststo: reg exempt_pension t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cluster(a7)
su exempt_pension if t_c==1 
estadd local Mean=abs(round(`r(mean)',.001))
estadd scalar Observations = `e(N)'
estadd scalar Clusters = `e(N_clust)'

eststo: reg exempt_handicap t_l i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cluster(a7)
su exempt_handicap if t_c==1 
estadd local Mean=abs(round(`r(mean)',.001))
estadd scalar Observations = `e(N)'
estadd scalar Clusters = `e(N_clust)'

eststo: reg exempt t_l t_lXtribe_match tribe_match  i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cluster(a7)
su tribe_match if t_c==1 
estadd local Mean=abs(round(`r(mean)',.001))
estadd scalar Observations = `e(N)'
estadd scalar Clusters = `e(N_clust)'

eststo: reg exempt t_l t_lXknow_eachother know_eachother i.house i.stratum i.time_FE_tdm_2mo_CvL if inlist(tmt,1,2), cluster(a7)
su know_eachother if t_c==1 
estadd local Mean=abs(round(`r(mean)',.001))
estadd scalar Observations = `e(N)'
estadd scalar Clusters = `e(N_clust)'

esttab using "$reploutdir/exemptions.tex", scalars(Observations Clusters Mean) sfmt(0 0 3)  nocons noobs l b(3) se(3) compress nogap r2 nonotes star(* 0.10 ** 0.05 *** 0.01)  ///
indicate("Time FE = *time_FE_tdm_2mo_CvL*" "House FE = *house*""Stratum FE = *stratum*") keep(t_l t_lXtribe_match tribe_match t_lXknow_eachother know_eachother) ///
addnote("\scriptsize{Standard errors clustered by polygon. $^* p<0.1, ^{**} p<0.05, ^{***} p<0.01$.}") nonumbers replace
