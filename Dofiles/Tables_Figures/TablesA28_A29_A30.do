
set matsize 800

* Use clean final data
use "${repldir}/Data/03_clean_combined/analysis_data.dta", clear

* Carto: did the collector read all of the flyer?
replace read_flyers=. if read_flyers==.d

* Carto: did the collector read the message?
gen read_message=0 
replace read_message=. if read_message_fr==. &  read_message_tsh==.
replace read_message=1 if read_message_fr==1 | read_message_tsh==1 
	
* eststo clear
eststo clear

* fliers message
gen control_flier=(flier_all==1)
gen central_deterrence=(flier_all==2)
gen local_deterrence=(flier_all==3)
gen central_pub_goods=(flier_all==4)
gen local_pub_goods=(flier_all==5)
gen trust_message=(flier_all==6)
global fliersvars="central_deterrence local_deterrence central_pub_goods local_pub_goods trust_message"

* FEs
egen time_FE_tdm_2mo_CvL = cut(today_alt),at(21355 21415 21475 21532) icodes

*************
* Table A28 *
*************

* col 1: Central vs Local for flier sample 
eststo: reg taxes_paid t_l i.stratum i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2) & today_carto>=td(13nov2018), robust
su taxes_paid if e(sample) & t_l==0
estadd local Mean=round(`r(mean)',0.001)

* Col 2: House FEs & no polygon FEs
eststo: reg taxes_paid central_deterrence local_deterrence central_pub_goods local_pub_goods trust_message i.house if  today_carto>=td(13nov2018), robust
su taxes_paid if e(sample)  & control_flier==1
estadd local Mean=round(`r(mean)',0.001)

* Col 3: House FEs & polygon FEs
eststo: reg taxes_paid central_deterrence local_deterrence central_pub_goods local_pub_goods trust_message i.house i.a7 if  today_carto>=td(13nov2018), robust
su taxes_paid if e(sample)  & control_flier==1
estadd local Mean=round(`r(mean)',0.001)

* col 4: Central vs Local for
eststo: reg taxes_paid_amt t_l i.stratum i.time_FE_tdm_2mo_CvL i.house if inlist(tmt,1,2) & today_carto>=td(13nov2018), robust
su taxes_paid_amt if e(sample) & t_l==0
estadd local Mean=round(`r(mean)',0.001)

* Col 5: House FEs & no polygon FEs
eststo: reg taxes_paid_amt central_deterrence local_deterrence central_pub_goods local_pub_goods trust_message i.house if  today_carto>=td(13nov2018) , robust
su taxes_paid_amt if e(sample)  & control_flier==1
estadd local Mean=round(`r(mean)',0.001)

* Col 6: House FEs & polygon FEs
eststo: reg taxes_paid_amt central_deterrence local_deterrence central_pub_goods local_pub_goods trust_message i.house  i.a7 if  today_carto>=td(13nov2018) , robust
su taxes_paid_amt if e(sample)  & control_flier==1
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_effects_tax_timeFE.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (t_l central_deterrence local_deterrence central_pub_goods local_pub_goods trust_message) ///
order(t_l central_deterrence local_deterrence central_pub_goods local_pub_goods trust_message) ///
scalar (Mean) ///
nomtitles ///
mgroups("Central Vs Local" "Messages vs Controls" "Messages vs Controls" "Central Vs Local" "Messages vs Controls" "Messages vs Controls" ,  pattern(1 1 1 1 1 1) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
star(* 0.10 ** 0.05 *** 0.001) ///
indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*""Neighborhood FE = *a7*") ///
nogaps nonotes compress 

*************
* Table A29 *
*************

***********
* Panel A *
***********

* Local and Central Treatment arms
gen Central=0
replace Central=1 if tmt==1
gen Local=0
replace Local=1 if tmt==2

* variables for interaction between flier message and read flier
foreach treatment in Central Local {
foreach fliervar in central_deterrence local_deterrence central_pub_goods local_pub_goods trust_message{
g `treatment'X`fliervar' = `treatment'*`fliervar'
cap g `fliervar'_read = `fliervar' if  read_message!=.
cap replace `fliervar'_read = 0 if `fliervar'==1 & read_message==1
}
}

* eststo clear
eststo clear

* Col 1: No Strata FEs
eststo: reg taxes_paid  Local central_deterrence LocalXcentral_deterrence i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==2), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 2: Strata FEs 
eststo: reg taxes_paid  Local central_deterrence LocalXcentral_deterrence i.house  i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==2), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 3: No Strata FEs
eststo: reg taxes_paid_amt  Local central_deterrence LocalXcentral_deterrence i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==2), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 4: Strata FEs 
eststo: reg taxes_paid_amt  Local central_deterrence LocalXcentral_deterrence i.house  i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==2), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_PanelA_timeFE.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (Local central_deterrence LocalXcentral_deterrence) ///
order (Local central_deterrence LocalXcentral_deterrence) ///
scalar (Mean) ///
nomtitles ///
mgroups("All properties" "All properties" "Received Flier" "Message Read" "All properties" "All properties" "Received Flier" "Message Read" ,  pattern(1 1 1 1 1 1 1 1 ) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*") ///
	nogaps nonotes compress 
	
***********
* Panel B *
***********

* eststo clear
eststo clear

* Col 1: No Strata FEs
eststo: reg taxes_paid  Local local_deterrence LocalXlocal_deterrence i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==3 ), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 2: Strata FEs 
eststo: reg taxes_paid  Local local_deterrence LocalXlocal_deterrence i.house  i.time_FE_tdm_2mo_CvL  i.stratum if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==3 ), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 3: No Strata FEs
eststo: reg taxes_paid_amt  Local local_deterrence LocalXlocal_deterrence i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==3 ), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 4: Strata FEs 
eststo: reg taxes_paid_amt  Local local_deterrence LocalXlocal_deterrence i.house  i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==3 ), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_PanelB_timeFE.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (Local local_deterrence LocalXlocal_deterrence) ///
order (Local local_deterrence LocalXlocal_deterrence) ///
scalar (Mean) ///
nomtitles ///
mgroups("All properties" "All properties" "Received Flier" "Message Read" "All properties" "All properties" "Received Flier" "Message Read" ,  pattern(1 1 1 1 1 1 1 1 ) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*") ///
	nogaps nonotes compress 
	
***********
* Panel C *
***********

* eststo clear
eststo clear

* Col 1: No Strata FEs
eststo: reg taxes_paid  Local central_pub_goods LocalXcentral_pub_goods i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==4), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 2: Strata FEs 
eststo: reg taxes_paid  Local central_pub_goods LocalXcentral_pub_goods i.house i.time_FE_tdm_2mo_CvL  i.stratum if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==4), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 3: No Strata FEs
eststo: reg taxes_paid_amt  Local central_pub_goods LocalXcentral_pub_goods i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==4), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 4: Strata FEs 
eststo: reg taxes_paid_amt  Local central_pub_goods LocalXcentral_pub_goods i.house  i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==4), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_PanelC_timeFE.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (Local central_pub_goods LocalXcentral_pub_goods) ///
order (Local central_pub_goods LocalXcentral_pub_goods) ///
scalar (Mean) ///
nomtitles ///
mgroups("All properties" "All properties" "Received Flier" "Message Read" "All properties" "All properties" "Received Flier" "Message Read" ,  pattern(1 1 1 1 1 1 1 1 ) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*") ///
	nogaps nonotes compress 

***********
* Panel D *
***********

* eststo clear
eststo clear

* Col 1: No Strata FEs
eststo: reg taxes_paid  Local local_pub_goods LocalXlocal_pub_goods i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==5), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 2: Strata FEs 
eststo: reg taxes_paid  Local local_pub_goods LocalXlocal_pub_goods i.house  i.time_FE_tdm_2mo_CvL  i.stratum if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==5), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 3: No Strata FEs
eststo: reg taxes_paid_amt  Local local_pub_goods LocalXlocal_pub_goods i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==5), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 4: Strata FEs 
eststo: reg taxes_paid_amt  Local local_pub_goods LocalXlocal_pub_goods i.house i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==5), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_PanelD_timeFE.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (Local local_pub_goods LocalXlocal_pub_goods) ///
order (Local local_pub_goods LocalXlocal_pub_goods) ///
scalar (Mean) ///
nomtitles ///
mgroups("All properties" "All properties" "Received Flier" "Message Read" "All properties" "All properties" "Received Flier" "Message Read" ,  pattern(1 1 1 1 1 1 1 1 ) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*") ///
	nogaps nonotes compress 
	
***********
* Panel E *
***********

* eststo clear
eststo clear

* Col 1: No Strata FEs
eststo: reg taxes_paid Local trust_message LocalXtrust_message i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==6), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 2: Strata FEs 
eststo: reg taxes_paid Local trust_message LocalXtrust_message i.house  i.time_FE_tdm_2mo_CvL  i.stratum if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==6), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 3: No Strata FEs
eststo: reg taxes_paid_amt  Local trust_message LocalXtrust_message i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==6), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 4: Strata FEs 
eststo: reg taxes_paid_amt  Local trust_message LocalXtrust_message i.house  i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==1 | tmt==2) & (flier_all==1 | flier_all==6), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_PanelE_timeFE.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (Local trust_message LocalXtrust_message) ///
order (Local trust_message LocalXtrust_message) ///
scalar (Mean) ///
nomtitles ///
mgroups("All properties" "All properties" "Received Flier" "Message Read" "All properties" "All properties" "Received Flier" "Message Read" ,  pattern(1 1 1 1 1 1 1 1 ) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*") ///
	nogaps nonotes compress 	

*************
* Table A30 *
*************

***********
* Panel A *
***********

* eststo clear
eststo clear

* Col 1: No Strata FEs
eststo: reg taxes_paid  central_deterrence i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==2), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 2: Strata FEs 
eststo: reg taxes_paid  central_deterrence i.house  i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==2), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 3: No Strata FEs
eststo: reg taxes_paid_amt  central_deterrence i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==2), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 4: Strata FEs 
eststo: reg taxes_paid_amt  central_deterrence i.house  i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==2), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_PanelA_timeFE_LHet.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (Local central_deterrence LocalXcentral_deterrence) ///
order (Local central_deterrence LocalXcentral_deterrence) ///
scalar (Mean) ///
nomtitles ///
mgroups("All properties" "All properties" "Received Flier" "Message Read" "All properties" "All properties" "Received Flier" "Message Read" ,  pattern(1 1 1 1 1 1 1 1 ) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*") ///
	nogaps nonotes compress 
		
***********
* Panel B *
***********

* eststo clear
eststo clear

* Col 1: No Strata FEs
eststo: reg taxes_paid  local_deterrence i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==3 ), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 2: Strata FEs 
eststo: reg taxes_paid  local_deterrence i.house  i.time_FE_tdm_2mo_CvL  i.stratum if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==3 ), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 3: No Strata FEs
eststo: reg taxes_paid_amt   local_deterrence  i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==3 ), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 4: Strata FEs 
eststo: reg taxes_paid_amt   local_deterrence  i.house  i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==3 ), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_PanelB_timeFE_LHet.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (Local local_deterrence LocalXlocal_deterrence) ///
order (Local local_deterrence LocalXlocal_deterrence) ///
scalar (Mean) ///
nomtitles ///
mgroups("All properties" "All properties" "Received Flier" "Message Read" "All properties" "All properties" "Received Flier" "Message Read" ,  pattern(1 1 1 1 1 1 1 1 ) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*") ///
	nogaps nonotes compress 
	
***********
* Panel C *
***********

* eststo clear
eststo clear

* Col 1: No Strata FEs
eststo: reg taxes_paid   central_pub_goods  i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==4), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 2: Strata FEs 
eststo: reg taxes_paid   central_pub_goods  i.house i.time_FE_tdm_2mo_CvL  i.stratum if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==4), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 3: No Strata FEs
eststo: reg taxes_paid_amt   central_pub_goods  i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==4), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 4: Strata FEs 
eststo: reg taxes_paid_amt   central_pub_goods  i.house  i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==4), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_PanelC_timeFE_LHet.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (Local central_pub_goods LocalXcentral_pub_goods) ///
order (Local central_pub_goods LocalXcentral_pub_goods) ///
scalar (Mean) ///
nomtitles ///
mgroups("All properties" "All properties" "Received Flier" "Message Read" "All properties" "All properties" "Received Flier" "Message Read" ,  pattern(1 1 1 1 1 1 1 1 ) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*") ///
	nogaps nonotes compress 

***********
* Panel D *
***********

* eststo clear
eststo clear

* Col 1: No Strata FEs
eststo: reg taxes_paid   local_pub_goods  i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==5), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 2: Strata FEs 
eststo: reg taxes_paid   local_pub_goods  i.house  i.time_FE_tdm_2mo_CvL  i.stratum if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==5), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 3: No Strata FEs
eststo: reg taxes_paid_amt   local_pub_goods  i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==5), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 4: Strata FEs 
eststo: reg taxes_paid_amt   local_pub_goods  i.house i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==5), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_PanelD_timeFE_LHet.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (Local local_pub_goods LocalXlocal_pub_goods) ///
order (Local local_pub_goods LocalXlocal_pub_goods) ///
scalar (Mean) ///
nomtitles ///
mgroups("All properties" "All properties" "Received Flier" "Message Read" "All properties" "All properties" "Received Flier" "Message Read" ,  pattern(1 1 1 1 1 1 1 1 ) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*") ///
	nogaps nonotes compress 
	
***********
* Panel E *
***********

* eststo clear
eststo clear

* Col 1: No Strata FEs
eststo: reg taxes_paid  trust_message  i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==6), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 2: Strata FEs 
eststo: reg taxes_paid  trust_message  i.house  i.time_FE_tdm_2mo_CvL  i.stratum if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==6), cl(a7) 
su taxes_paid if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 3: No Strata FEs
eststo: reg taxes_paid_amt   trust_message  i.house  i.stratum  if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==6), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

* Col 4: Strata FEs 
eststo: reg taxes_paid_amt   trust_message  i.house  i.time_FE_tdm_2mo_CvL i.stratum if today_carto>=td(13nov2018) & (tmt==2) & (flier_all==1 | flier_all==6), cl(a7) 
su taxes_paid_amt if e(sample)
estadd local Mean=round(`r(mean)',0.001)

esttab using "$reploutdir/flier_PanelE_timeFE_LHet.tex", ///
replace label b(%9.3f) se(%9.3f) ///
keep (Local trust_message LocalXtrust_message) ///
order (Local trust_message LocalXtrust_message) ///
scalar (Mean) ///
nomtitles ///
mgroups("All properties" "All properties" "Received Flier" "Message Read" "All properties" "All properties" "Received Flier" "Message Read" ,  pattern(1 1 1 1 1 1 1 1 ) prefix(\multicolumn{@span}{c}{) suffix(}) span) /// 
	star(* 0.10 ** 0.05 *** 0.001) ///
	indicate("House FE = *house*" "Time FE = *2mo*" "Strata FE = *stratum*") ///
	nogaps nonotes compress 	
	
	
