***************************************************************************************
* Program: 2_Data_Construction.do
* Author: Gabriel Tourek
* Created: 6 Aug 2021
* Modified: 		
* Purpose: Clean, combines, and assembles datasets for analysis
***************************************************************************************

clear
set more off

********************************************************************************
********************** DATASET CONSTRUCTION FOR ANALYSIS ***********************
********************************************************************************

*******************
* Geographic Data *
*******************

* Chefferies
insheet using "${repldir}/data/01_base/admin_data/concessions_chefferies.csv", clear comma names
drop if polygon==. 
drop if polygon>=400 & polygon<500 // drop if polygon is missing or Nganza polygons
rename polygon a7
compress
save "${repldir}/data/02_intermediate/concessions_chefferies.dta", replace


*************************************
* 2016 Polygon Treatment Assignment *
*************************************

* Import 2016 treatment assignment data
use "${repldir}/data/01_base/admin_data/campaign_2016_neighborhoods.dta", clear 
drop if nganza==1
keep a7 program
rename program tmt_2016
compress
save "${repldir}/data/02_intermediate/2016_tmt.dta", replace


*************************************
* 2018 Polygon Treatment Assignment *
*************************************
						  
* Use assignment file
use "${repldir}/data/01_base/admin_data/randomization_schedule.dta", clear 
keep a7 treatment month
count
local obs =r(N)+7
set obs `obs'
replace month=0 if a7==.
replace a7 = 201 if a7==. in 357
replace treatment=2 if a7 == 201 // Poygon assigned to local
replace a7 = 202 if a7==. in 358 
replace treatment=1 if a7 == 202 // Poygon assigned to central
replace a7 = 203 if a7==. in 359
replace treatment=1 if a7 == 203 // Poygon assigned to central
replace a7 = 210  if a7==. in 360
replace treatment=2 if a7 == 210 // Poygon assigned to local
replace a7 = 200  if a7==. in 361
replace treatment=1 if a7 == 200 // Central (joined by local for carto for half)
replace a7 = 207 if a7==. in 362
replace treatment=2 if a7 == 207 // Local (joined by central for carto)
replace a7 = 208  if a7==. in 363
replace treatment=4 if a7 == 208 // central x local

* Replace Assignment Mistake (Field team mistake: assigned to CxL but ended up L)
replace treatment=2 if a7==654 

* Define and label polygon treatment
rename treatment tmt
lab def tmt 0 "Control" 1 "Central" 2 "Local" 3 "Central + Chief Info" 4 "Central X Local"
lab val tmt tmt

* Save Dataset
compress
sa "${repldir}/data/02_intermediate/assignment.dta",replace 


***********************************
* Flier Treatment Assignment Data *
***********************************

* Import Pilot Flier Assignment
import excel using "${repldir}/data/01_base/admin_data/fliers_pilot_set1.xlsx", clear first
keep code treatment_fr rate_rand
rename rate_rand rate
tempfile pilot1
save `pilot1'
import excel using "${repldir}/data/01_base/admin_data/fliers_pilot_set2.xlsx", clear first
keep code treatment_fr rate
tempfile pilot2
save `pilot2'
import excel using "${repldir}/data/01_base/admin_data/fliers_pilot_set3.xlsx", clear first
keep code treatment_fr rate
tempfile pilot3
save `pilot3'

* Import All Flier Assignment
use "${repldir}/data/01_base/admin_data/fliers_campaign.dta" if  a7!=200 & a7!=201 & a7!=202 & a7!=203 & a7!=207 & a7!=208 & a7!=210, clear 

keep code treatment_fr rate
tempfile full
save `full'

* Merge
use `full', clear
append using `pilot1'
append using `pilot2'
append using `pilot3'

* Rename variables 
rename code compound1
rename rate assign_flier_rate
rename treatment_fr assign_treatment_fr

* Generate Polygon variable
tostring compound1, gen(compound1_str) force
gen compound1_str_length=strlen(compound1_str)
gen polygon=substr(compound1_str,1,3) if compound1_str_length==6
replace polygon=substr(compound1_str,1,4) if compound1_str_length==7
destring polygon, gen(a7) force

* generate pilot dummy 
gen pilot=0
replace pilot=1 if a7==200 | a7==201 | a7==202 | a7==203 | a7==207 | a7==208 | a7==210

* Generate indicators for Flier Messages: 
gen flier_all=1 if assign_treatment_fr=="Il est important de payer l'impôt foncier." & pilot!=1 
replace flier_all=2 if assign_treatment_fr=="Si vous refusez de payer l'impôt foncier, vous pourriez être interpellé à la DGRKOC pour le suivi et le contrôle." & pilot!=1 
replace flier_all=3 if assign_treatment_fr=="Si vous refusez de payer l'impôt foncier, vous pourriez être interpellé à vous rendre chez le chef de quartier pour le suivi et le contrôle." & pilot!=1 
replace flier_all=4 if assign_treatment_fr=="Le Gouvernement Provincial pourra améliorer les infrastructures publiques à Kananga seulement si les résidents paient l'impôt foncier." & pilot!=1 
replace flier_all=6 if assign_treatment_fr=="Payez l'impôt foncier afin de montrer que vous avez confiance en l'État et ses agents." & pilot!=1 
replace flier_all=5 if flier_all==. & pilot!=1 

* Keep relevant variables 
keep a7 compound1 assign_flier_rate assign_treatment_fr flier_all


* Save Dataset
compress
save "${repldir}/data/02_intermediate/flier_mailmerge.dta", replace

*********************
* Cartographie Data *
*********************

* Use Cartographie Clean and keep complete observations
use "${repldir}/data/01_base/admin_data/registration_noPII.dta",clear
rename today today_carto
keep if tot_complete==1
cap drop tmt

* Create date of the month string
gen date_str_carto=string(today_carto,"%td")
gen day_str_carto=substr(date_str_carto,1,2)
gen month_str_carto=substr(date_str_carto,3,3)

* Create date of the month numerical
destring day_str_carto, gen(day_carto) 
gen month_carto=4 if month_str_carto=="apr"
replace month_carto=5 if month_str_carto=="may"
replace month_carto=6 if month_str_carto=="jun"
replace month_carto=7 if month_str_carto=="jul"
replace month_carto=8 if month_str_carto=="aug"
replace month_carto=9 if month_str_carto=="sep"
replace month_carto=10 if month_str_carto=="oct"
replace month_carto=11 if month_str_carto=="nov"
replace month_carto=12 if month_str_carto=="dec"

* Save Dataset
compress
sa "${repldir}/data/02_intermediate/registration_cleaned.dta",replace

*******************
* Repertoire Data *
******************* 

u "${repldir}/data/01_base/admin_data/taxroll_noPII.dta", clear
gen bonus_FC=regexs(2) if regexm(Bonus, "^([^0-9]*)([0-9]+)([^0-9]*)$")
compress
save "${repldir}/data/02_intermediate/taxroll_cleaned.dta", replace

*******************
* Monitoring Data *
******************* 

* use Monitoring Clean
u "${repldir}/data/01_base/survey_data/midline_noPII.dta",clear
drop tmt pilot
rename compound compound1 
rename today today_monitoring
rename exempt exempt_monitoring

* If missing compound replace compound1 by possible compound
replace possible_compound=. if possible_compound==0 | possible_compound==999999 | possible_compound==9999999 | possible_compound==.d
gen compound_guess=0
replace compound_guess=1 if  compound1==999999 & possible_compound!=.
replace compound1=possible_compound if compound1==999999 & possible_compound!=.
drop if compound1==999999 
drop if compound1==.

* If duplicate compound code, keep the completed one 
sort compound1 tot_complete
by compound1: egen max_tot_complete=max(tot_complete)
drop if tot_complete!=max_tot_complete

* If remaining duplicate in compound code
sort  compound1 start end, stable
by compound1: gen rank=_n
by compound1: gen rank_max=_N
keep if rank==rank_max

compress
save "${repldir}/data/02_intermediate/midline_cleaned.dta", replace

**********************
* Tax Data from TDMs *
**********************

* Use final TDM Clean data 
u "${repldir}/data/01_base/admin_data/tax_payments_noPII.dta",clear
cap drop _merge
rename date date_TDM
rename colcode colcode_TDM 

*drop unmatched_compound or missing compounds
drop if unmatched_compound==1 | compound1==.

* Create date of the month string
gen date_str_tdm=string(date_TDM,"%td")
gen day_str_tdm=substr(date_str_tdm,1,2)
gen month_str_tdm=substr(date_str_tdm,3,3)

* Create date of the month numerical
destring day_str_tdm, gen(day_tdm) 
gen month_tdm=4 if day_str_tdm=="apr"
replace month_tdm=5 if day_str_tdm=="may"
replace month_tdm=6 if day_str_tdm=="jun"
replace month_tdm=7 if day_str_tdm=="jul"
replace month_tdm=8 if day_str_tdm=="aug"
replace month_tdm=9 if day_str_tdm=="sep"
replace month_tdm=10 if day_str_tdm=="oct"
replace month_tdm=11 if day_str_tdm=="nov"
replace month_tdm=12 if day_str_tdm=="dec"

* Save Dataset
compress
sa "${repldir}/data/02_intermediate/tax_payments_cleaned.dta",replace

**************
* Merge Data *
**************

* Use rates and messages data 
use "${repldir}/data/02_intermediate/flier_mailmerge.dta", clear

* merge with stratum used for randomization
merge m:1 a7 using "${repldir}/data/01_base/admin_data/stratum.dta", keepusing(stratum*)
drop _merge

* merge with chefferies
merge m:1 a7 using "${repldir}/data/02_intermediate/concessions_chefferies.dta"
drop _merge

* merge with 2016 polygon assignment
merge m:1 a7 using "${repldir}/data/02_intermediate/2016_tmt.dta"
drop _merge 

* merge with 2018 polygon assignment
merge m:1 a7 using "${repldir}/data/02_intermediate/assignment.dta"
drop _merge 

* merge with cartography data
merge 1:1 compound1 using "${repldir}/data/02_intermediate/registration_cleaned.dta"
* _merge==1 are observations in assignment do not merge with carto (extra fliers or skipped during carto)
tab compound1 if _merge==2 // Keep compound code 236284 (Stephen Mathew: the enumerator cartographied one more compound than had been assigned in the flier mail merge (assignment ends at 236383))
rename _merge _merge_flier_carto

* merge with repertoire 
merge 1:1 compound1 using "${repldir}/data/02_intermediate/taxroll_cleaned.dta", force 
* _merge==1 // observations in assignment do not merge with carto (extra fliers or skipped during carto)
rename _merge _merge_flier_carto_rep

* merge with monitoring 
merge 1:1 compound1 using "${repldir}/data/02_intermediate/midline_cleaned.dta", force 
drop if _merge==2 // TO INVESTIGATE: 51 codes that are in monitoring and not in carto (Augustin: carto dump should fix)
rename _merge _merge_flier_carto_rep_monit

* merge with TDM data 
merge m:1 compound1 using "${repldir}/data/02_intermediate/tax_payments_cleaned.dta", force 

* Drop observations not in carto, repertoire or monitoring 
drop if _merge_flier_carto==1 & _merge_flier_carto_rep==1 & _merge_flier_carto_rep_monit==1

********************************************************************************
************************* DATA ISSUES TO INVESTIGATE ***************************
********************************************************************************

* Rate Assigned and Rate Carto do not Match 
br a7 compound1 assign_flier_rate what_rate_periph if assign_flier_rate!=what_rate_periph & what_rate_periph!=. 
	// 121 periphery compounds (most problematic polygons are 104, 123 and 550).
br a7 compound1 assign_flier_rate what_rate_periph amountCF if assign_flier_rate!=what_rate_periph & what_rate_periph!=. & amountCF!=. 
	// Shows that the assignment is often the same as the TDM rate
	// Suggests enumerators' mistakes when choosing what_rate_periph		
	
* Assigned rate and rate according to the TDM data do not match 
br a7 compound1 assign_flier_rate what_rate_periph amountCF if house==1 & assign_flier_rate!=amountCF & amountCF!=. // TO INVESTIGATE: Why these 168 observations do not match? 
	// 196 periphery compounds 
br a7 compound1 mm_rate assign_flier_rate amountCF if house==2 & mm_rate!=amountCF & amountCF!=. // TO INVESTIGATE: Why these 122 observations do not match? 
	// 127 maison moyenne compounds
gen rates_dont_match=0 
replace rates_dont_match=1 if (house==1 & assign_flier_rate!=amountCF & amountCF!=.) | ( house==2 & mm_rate!=amountCF & amountCF!=.)

********************************************************************************
*************************** VARIABLE CONSTRUCTION ******************************
********************************************************************************


************
* Outcomes *
************

* Tax Compliance Dummy 
gen taxes_paid=0
replace taxes_paid=1 if _merge==3
replace taxes_paid=1 if taxes_paid==0 & code_same==1 
* replace taxes_paid=1 if taxes_paid==0 & collect_success==1 
replace taxes_paid=0 if house==1 & _merge==3 & assign_flier_rate>amountCF & amountCF!=. & assign_flier_rate!=. 
replace taxes_paid=0 if house==2 & _merge==3 & mm_rate>amountCF & amountCF!=. & mm_rate!=. 

* Bribe dummy
gen bribe_combined=.
replace bribe_combined=0 if bribe==0
replace bribe_combined=1 if bribe==1
replace bribe_combined=1 if bribe2a_amt!=. & bribe!=1
replace bribe_combined=1 if bribe2b_amt!=.
replace bribe_combined=1 if bribe3_amt!=.
replace bribe_combined=1 if house==1 & _merge==3 & assign_flier_rate>amountCF & amountCF!=. & assign_flier_rate!=.
replace bribe_combined=1 if house==2 & _merge==3 & mm_rate>amountCF & amountCF!=. & mm_rate!=.
replace bribe_combined=0 if (visited!=1 & visited!=.) | (visited==1 & bribe_combined==.)

* Bribe Payments 
gen bribe_combined_amt=.
replace bribe_combined_amt=bribe_amt if bribe_amt!=.
replace bribe_combined_amt=bribe2a_amt if bribe2a_amt!=.
replace bribe_combined_amt=bribe2b_amt if bribe2b_amt!=.
replace bribe_combined_amt=bribe3_amt if bribe3_amt!=.
replace bribe_combined_amt=amountCF if house==1 & _merge==3 & assign_flier_rate>amountCF & amountCF!=. & assign_flier_rate!=.
replace bribe_combined_amt=amountCF if house==2 & _merge==3 & mm_rate>amountCF & amountCF!=. & mm_rate!=.

* Corrections
replace bribe_combined=0 if bribe_combined_amt==0
replace bribe_combined_amt=. if bribe_combined_amt==0

* Visits by tax collectors 
	
	* Visits - Indicator for Being visited post carto 
	gen visit_post_carto=0 if visited==0 
	replace visit_post_carto=0 if (visited==1 | visited==2) & (visits==0 | visits==1)
	replace visit_post_carto=1 if (visited==1 | visited==2) & visits>1

	* Visits - Number of visits post carto
	gen nb_visit_post_carto=0 if visited==0 
	replace nb_visit_post_carto=0 if (visited==1 | visited==2) & (visits==0 | visits==1)
	replace nb_visit_post_carto=visits-1 if (visited==1 | visited==2) & visits>1
	replace nb_visit_post_carto=. if visits==99999

	* Chalk Info - Indicator for Being visited post carto 
	gen rdv_chalk=0 if revisits_dates!=. & revisits_dates==0
	replace rdv_chalk=1 if revisits_dates!=. & revisits_dates>0
	replace rdv_chalk=. if revisits_dates!=. & revisits_dates==316037

	* Chalk Info - Number of visits post carto
	gen nb_rdv_chalk=0 if revisits_dates!=. & revisits_dates==0
	replace nb_rdv_chalk=revisits_dates if revisits_dates!=. & revisits_dates>0
	replace nb_rdv_chalk=. if nb_rdv_chalk==316037


***********************
* Tax Rate Assignment *
***********************

* Tax Rate Assignments
	
	* Peripherie
	forvalue r=1500(500)3000{
	gen r_`r'=0 if house==1
	replace r_`r'=1 if house==1 & assign_flier_rate==`r'
	}

	* Maison Moyenne
	forvalue r=6600(2200)13200{
	gen r_`r'=0 if house==2
	replace r_`r'=1 if house==2 & mm_rate==`r'
	}

	* All House Types
	gen pct_50=0 if (house==1 | (house==2 & mm_rate!=.))
	replace pct_50=1 if (house==1 & r_1500==1) | (house==2 & r_6600==1 & mm_rate!=.)
	gen pct_66=0 if (house==1 | (house==2 & mm_rate!=.))
	replace pct_66=1 if (house==1 & r_2000==1) | (house==2 & r_8800==1 & mm_rate!=.)
	gen pct_83=0 if (house==1 | (house==2 & mm_rate!=.))
	replace pct_83=1 if (house==1 & r_2500==1) | (house==2 & r_11000==1 & mm_rate!=.)
	gen pct_100=0 if (house==1 | (house==2 & mm_rate!=.))
	replace pct_100=1 if (house==1 & r_3000==1) | (house==2 & r_13200==1 & mm_rate!=.)

	* Rates 

	cap drop rate
	gen rate= assign_flier_rate if house==1
	replace rate=mm_rate if house==2
	gen taxes_paid_amt=taxes_paid*rate


******************************
* Tax Collector Compensation *
******************************

* Split the 750 FC for rate 2500 CF in an arbitrary way (50% is proportional and 50% is constant)
tab assign_flier_rate bonus_FC 
set seed 12345999
gen rand_bonus = runiform() if bonus_FC=="750" & assign_flier_rate==2500
xtile rand_quantile=rand_bonus, nquantiles(2)

* Dummy for constant bonus
gen bonus_constant=0 if bonus_FC!=""
replace bonus_constant=1 if bonus_FC=="750" & rand_quantile
replace bonus_constant=0 if rand_quantile==1
replace bonus_constant=1 if bonus_FC=="2000" 

* Dummy for proportional bonus
gen bonus_30pct=0 if bonus_FC!=""
replace bonus_30pct=1 if bonus_FC=="450" | bonus_FC=="600" | (bonus_FC=="750" & rand_quantile==1) | bonus_FC=="900" 
	
* Tax Collection during Carto: replace with fixed bonus
replace bonus_FC="750" if taxes_paid==1 & house==1 & bonus_FC==""
replace bonus_constant=1 if taxes_paid==1 & house==1 & bonus_FC==""
replace bonus_FC="2000" if taxes_paid==1 & house==2 & bonus_FC==""
replace bonus_constant=1 if taxes_paid==1 & house==2 & bonus_FC==""

* Numerical variable
destring bonus_FC, force replace

***********************
* Neighbor's Tax Rates *
***********************

* Neighbor's tax rate: 

sort a7 compound1, stable
forvalue i=1(1)10{
by a7: gen rate_nm`i'=rate[_n-`i']
by a7 : gen rate_np`i'=rate[_n+`i']
}

* Neighbor's tax rate: code-1, code, code+1 identical
sort a7 compound1, stable
by a7: gen stable_n3=1 if house==1 & (assign_flier_rate[_n]==assign_flier_rate[_n+1]) & (assign_flier_rate[_n]==assign_flier_rate[_n-1])
by a7: replace stable_n3=1 if house==2 & (mm_rate[_n]==mm_rate[_n+1]) & (mm_rate[_n]==mm_rate[_n-1])

*******************************************
* Date of Cartography and Date of Payment *
*******************************************

* Compute number of days between carto and TDM payment
gen taxes_paid_days_post_carto=date_TDM-today_carto 

* TO INVESTIGATE: 48 TDM observations with missing date 
count if date_TDM==. & _merge==3

* TO INVESTIGATE: 2824 carto observations with missing data and 70 for observations for which we have tax payments
count if today_carto==. 
count if today_carto==. & _merge==3

* TO INVESTIGATE: 15 observations for which date of TDM payment is earlier than date of carto
count if taxes_paid_days_post_carto<0
replace taxes_paid_days_post_carto=. if taxes_paid_days_post_carto<0

* Compute if paid taxes within x days of carto
forvalue x=0(1)30{
gen taxes_paid_`x'd=0 if taxes_paid==0 // equal to zero if never paid taxes
replace taxes_paid_`x'd=1 if (taxes_paid==1 & taxes_paid_days_post_carto<=`x' & taxes_paid_days_post_carto!=.) // equal to 1 if paid within x days of carto
replace taxes_paid_`x'd=0 if (taxes_paid==1 & taxes_paid_days_post_carto>`x' & taxes_paid_days_post_carto!=.) // equal to 0 if paid after x days of carto
}

**********************
* Exemption Variable *
**********************

gen exempt_to_exclude=.
replace exempt_to_exclude=1 if exempt_other=="Associations"
replace exempt_to_exclude=1 if exempt_other=="Bien de l'Etat"
replace exempt_to_exclude=1 if exempt_other=="CS"
replace exempt_to_exclude=1 if exempt_other=="Centre de santé"
replace exempt_to_exclude=1 if exempt_other=="Croix rouge"
replace exempt_to_exclude=1 if exempt_other=="De l’etat"
replace exempt_to_exclude=1 if exempt_other=="Eglise et Ecole"
replace exempt_to_exclude=1 if exempt_other=="Etat"
replace exempt_to_exclude=1 if exempt_other=="Hopital"
replace exempt_to_exclude=1 if exempt_other=="Hôpital"
replace exempt_to_exclude=1 if exempt_other=="ME"
replace exempt_to_exclude=1 if exempt_other=="Maison d etat"
replace exempt_to_exclude=1 if exempt_other=="Maison de etat"
replace exempt_to_exclude=1 if exempt_other=="Maison de l Etat"
replace exempt_to_exclude=1 if exempt_other=="Maison de l'Etat"
replace exempt_to_exclude=1 if exempt_other=="Maison de l'etat"
replace exempt_to_exclude=1 if exempt_other=="Maison de l'état"
replace exempt_to_exclude=1 if exempt_other=="Maison de la SNCC"
replace exempt_to_exclude=1 if exempt_other=="Maison de état"
replace exempt_to_exclude=1 if exempt_other=="Maison etat"
replace exempt_to_exclude=1 if exempt_other=="Maison militaire"
replace exempt_to_exclude=1 if exempt_other=="Militaire"
replace exempt_to_exclude=1 if exempt_other=="ONG"
replace exempt_to_exclude=1 if exempt_other=="Ong"
replace exempt_to_exclude=1 if exempt_other=="Organisme"
replace exempt_to_exclude=1 if exempt_other=="Orphelin"
replace exempt_to_exclude=1 if exempt_other=="Parcelle de l'Etat"
replace exempt_to_exclude=1 if exempt_other=="Une maison de l'église"
replace exempt_to_exclude=1 if exempt_other=="Tous deux sont morts"
replace exempt_to_exclude=1 if exempt_other=="Tous décédé et il sont deul"
replace exempt_to_exclude=1 if exempt_monitoring==1

************************************
* Cleaning Covariates - Monitoring *
************************************

* Gender of the owner
replace sex_prop=sex if sex_prop==. & sex!=.
replace sex_prop=0 if sex_prop==2
label define gender 0 "Female" 1 "male"
label val sex_prop gender

* Clean age of the owner 
tab age_prop
tab age_prop_guess
replace age_prop=age if age_prop==. & age!=.	
replace age_prop=19 if age_prop_guess==1 & age_prop==.d // Guess: 18-20 years old
replace age_prop=22.5 if age_prop_guess==2 & age_prop==.d // Guess: 20-25 years old
replace age_prop=27.5 if age_prop_guess==3 & age_prop==.d // Guess: 25-30 years old
replace age_prop=32.5 if age_prop_guess==4 & age_prop==.d // Guess: 30-35 years old
replace age_prop=37.5 if age_prop_guess==5 & age_prop==.d // Guess: 35-40 years old
replace age_prop=42.5 if age_prop_guess==6 & age_prop==.d // Guess: 40-45 years old
replace age_prop=47.5 if age_prop_guess==7 & age_prop==.d // Guess: 45-50 years old
replace age_prop=52.5 if age_prop_guess==8 & age_prop==.d // Guess: 50-55 years old
replace age_prop=57.5 if age_prop_guess==9 & age_prop==.d // Guess: 55-60 years old
replace age_prop=62.5 if age_prop_guess==10 & age_prop==.d // Guess: 60-65 years old
replace age_prop=67.5 if age_prop_guess==11 & age_prop==.d // Guess: 65-70 years old
replace age_prop=72.5 if age_prop_guess==12 & age_prop==.d // Guess: 70-75 years old
replace age_prop=77.5 if age_prop_guess==13 & age_prop==.d // Guess: 75-80 years old
replace age_prop=82.5 if age_prop_guess==14 & age_prop==.d // Guess: 80-85 years old
replace age_prop=87.5 if age_prop_guess==15 & age_prop==.d // Guess: 85-90 years old
replace age_prop=92.5 if age_prop_guess==16 & age_prop==.d // Guess: 90-95 years old
replace age_prop=97.5 if age_prop_guess==17 & age_prop==.d // Guess: 95-100 years old
replace age_prop=100 if age_prop_guess==18 & age_prop==.d // Guess: 95-100 years old

* Clean Tribe of the property owner
tab tribe
replace tribe="" if tribe=="NEVEUTPASDIRE"
replace tribe="" if tribe=="LAPARCELLEDEL'éGLISE"
replace tribe="" if tribe=="JENESAISPAS"
replace tribe="" if tribe=="ILNEVEUTPASDIRE"
replace tribe="" if tribe=="ILNEVEUTPAS"
replace tribe="" if tribe=="I'LLNEVEUTPASDIRE"
replace tribe="" if tribe=="ELLENEVEUTPASMEDIRE"
replace tribe="" if tribe=="ELLENEVEUTPASDIRE"
replace tribe="" if tribe=="ELLENEVEUTPAS"
replace tribe="" if tribe=="ELLENEPASDIRE"
replace tribe="" if tribe=="DOESN'TKNOW"
replace tribe="" if tribe=="BELGE"
replace tribe="" if tribe=="."
replace tribe="" if tribe==".d"
replace tribe="" if tribe==".n"
replace tribe="" if tribe=="9999"
replace tribe="" if tribe=="99999"
replace tribe="" if tribe=="999999"
replace tribe="" if tribe=="9999999"
replace tribe="" if tribe=="99999999"

* Indicator for being Luluwa 
gen main_tribe=0 if tribe!=""
replace main_tribe=1 if tribe=="LULUWA"

* Clean Job Variable 
decode job, gen(job_str) 

	* Set job as missing if doesn't know was picked (clarify what this means with enums)
	replace job_str="" if job_str=="DOESN'T KNOW"

	* Unemployed
	foreach v of varlist job_str job_other{
	replace `v'="Unemployed-no work" if job_other=="Chomeur"
	*replace `v'="Chomeur" if job_other=="Unemployed-no work"
	}
	
	* Set job as missing if other or respondent is dead
	foreach v of varlist job_str job_other{
	replace `v'="" if job_other=="."
	replace `v'="" if job_other=="0"
	replace `v'="" if job_other=="8888"
	replace `v'="" if job_other=="88888"
	replace `v'="" if job_other=="9999"
	replace `v'="" if job_other=="99999"
	replace `v'="" if job_other=="999999"
	replace `v'="" if job_other=="9999999"
	}

	
	* Set job as missing if respondent is dead
	foreach v of varlist job_str job_other{
	replace `v'="" if job_other=="Dcd"
	replace `v'="" if job_other=="Deja mort"
	replace `v'="" if job_other=="Divorce"
	replace `v'="" if job_other=="Décédé"
	replace `v'="" if job_other=="Déjà"
	replace `v'="" if job_other=="Déjà  décédé"
	replace `v'="" if job_other=="Déjà décidé"
	replace `v'="" if job_other=="Déjà décédé"
	replace `v'="" if job_other=="Déjà mort"
	replace `v'="" if job_other=="Elle est décédée depuis le mois d'octobre 2018"
	replace `v'="" if job_other=="Elle vient de décédée"
	replace `v'="" if job_other=="Il est déjà  décédé"
	replace `v'="" if job_other=="Le propriétaire déjà décédé"
	replace `v'="" if job_other=="Le propriétaire est déjà mort"
	replace `v'="" if job_other=="Son mari est déjà décédé"
	replace `v'="" if job_other=="Malade"
	}
	
	* Set job as missing if respondent doesn't want to answer
	foreach v of varlist job_str job_other{
	replace `v'="" if job_other=="Elle a peur de donner toute les reponses"
	replace `v'="" if job_other=="Elle ne pas dire"
	replace `v'="" if job_other=="Il ne veut pas dire"
	replace `v'="" if job_other=="Il ne veux pas dire"
	replace `v'="" if job_other=="Ne veut pas dire"
	replace `v'="" if job_other=="Ne veut pas repondre"
	}
	
	* Set job as missing if other reasons
	foreach v of varlist job_str job_other{
	replace `v'="" if job_other=="Acheter par eglise il ya 1 a 2 mois"
	replace `v'="" if job_other=="Accèlere"
	replace `v'="" if job_other=="La parcelle de l'église"
	replace `v'="" if job_other=="Genre et famille"
	replace `v'="" if job_other=="Prisonnier"
	}
	
	* Personnel de santé
	foreach v of varlist job_str job_other{
	replace `v'="Medical assistant" if job_other=="Medecin" 
	replace `v'="Medical assistant" if job_other=="Medecin traditionnelle" 
	replace `v'="Medical assistant" if job_other=="Infirmier" 
	replace `v'="Medical assistant" if job_other=="Infirmières" 
	replace `v'="Medical assistant" if job_other=="Pharmacien" 
	replace `v'="Medical assistant" if job_other=="Munganga" // Infirmer
	}

	* Avocat 
	foreach v of varlist job_str job_other{
	replace `v'="Lawyer" if job_other=="Avocat" 
	replace `v'="Lawyer" if job_other=="Majustrat" 
	}
	
	* Travaille pour une NGO
	foreach v of varlist job_str job_other{
	replace `v'="Work for NGO" if job_other=="Agent caritas"
	replace `v'="Work for NGO" if job_other=="Agent catholique"
	replace `v'="Work for NGO" if job_other=="Agent du crs"
	replace `v'="Work for NGO" if job_other=="Caritas"
	replace `v'="Work for NGO" if job_other=="Crois rouge"
	replace `v'="Work for NGO" if job_other=="Croix rouge"
	replace `v'="Work for NGO" if job_other=="Crs"
	replace `v'="Work for NGO" if job_other=="Il travail dans une ONG"
	replace `v'="Work for NGO" if job_other=="Il travaille pour l'ong handicap"
	replace `v'="Work for NGO" if job_other=="Il travaille à la caritas"
	replace `v'="Work for NGO" if job_other=="Humanitaire"
	replace `v'="Work for NGO" if job_other=="Membre de la croix rouge et cultivateur"
	replace `v'="Work for NGO" if job_other=="Muena croix rouge"
	replace `v'="Work for NGO" if job_other=="Ong vision mondiale"
	replace `v'="Work for NGO" if job_other=="Muena croix rouge"
	replace `v'="Work for NGO" if job_other=="CPR"
	replace `v'="Work for NGO" if job_other=="Monusco"
	replace `v'="Work for NGO" if job_other=="Il travail à la monusco"
	}
	
	* Driver
	foreach v of varlist job_str job_other{
	replace `v'="Driver (car and taxi moto)" if job_other=="Chauffeur"
	replace `v'="Driver (car and taxi moto)" if job_other=="Chauffeur mecanicien"
	replace `v'="Driver (car and taxi moto)" if job_other=="Taximan"
	}
	
	* Chef coutumier et d'avenue
	foreach v of varlist job_str job_other{
	replace `v'="Chef coutumier" if job_other=="Chef coutumier"
	replace `v'="Chef coutumier" if job_other=="Chef coutumier et président du CCRCC"
	replace `v'="Chef coutumier" if job_other=="Chef de groupement"
	replace `v'="Chef coutumier" if job_other=="Chef du groupement"
	replace `v'="Chef coutumier" if job_other=="Chef du village"
	replace `v'="Chef d'avenue" if job_other=="Chef d'avenues"
	replace `v'="Chef d'avenue" if job_other=="Chef de quartier"
	replace `v'="Chef d'avenue" if job_other=="Chef de secteur"
	replace `v'="Chef d'avenue" if job_other=="Chef quartier"

	}
	
	* Army or police
	foreach v of varlist job_str job_other{
	replace `v'="Military officer/soldier or police officer" if job_other=="Plicier"
	replace `v'="Military officer/soldier or police officer" if job_other=="Police"
	replace `v'="Military officer/soldier or police officer" if job_other=="Policier"
	replace `v'="Military officer/soldier or police officer" if job_other=="Policiere"
	replace `v'="Military officer/soldier or police officer" if job_other=="Policiers"
	replace `v'="Military officer/soldier or police officer" if job_other=="Mpulushi"
	replace `v'="Military officer/soldier or police officer" if job_other=="Élevé policier au centre de formation de Kamina" 
	replace `v'="Military officer/soldier or police officer" if job_other=="Militaire" 
	replace `v'="Military officer/soldier or police officer" if job_other=="Military" 
	replace `v'="Military officer/soldier or police officer" if job_other=="Sécurité civile à l'e.f.o" 
	replace `v'="Military officer/soldier or police officer" if job_other=="Sécurité civile à l'fo" 
	}
	
	* Commerçants	
	foreach v of varlist job_str job_other{
	replace `v'="Seller" if job_other=="Commerçant"
	replace `v'="Seller" if job_other=="Commercant"
	replace `v'="Seller" if job_other=="Commerce"
	replace `v'="Seller" if job_other=="Commercent"
	replace `v'="Seller" if job_other=="Commerçant ambulant"
	replace `v'="Seller" if job_other=="Commerçant mais qui voyage"
	replace `v'="Seller" if job_other=="Commerçante"
	replace `v'="Seller" if job_other=="Il fait le  petit commerce"
	replace `v'="Seller" if job_other=="Il fait le commerce"
	replace `v'="Seller" if job_other=="Il fait le petit commerce"
	replace `v'="Seller" if job_other=="Il fait le petit commerce"
	replace `v'="Seller" if job_other=="Fait le petit commerce"
	replace `v'="Seller" if job_other=="Vendeur artistique"
	replace `v'="Seller" if job_other=="Vendeuse"
	}
	
	* Pensionnaires de l'état
	foreach v of varlist job_str job_other{
	replace `v'="Pensionnaire de l'état" if job_other=="Retraité sncc"
	replace `v'="Pensionnaire de l'état" if job_other=="Retraité ou pensionné"
	replace `v'="Pensionnaire de l'état" if job_other=="Retraité de la fonction publique"
	replace `v'="Pensionnaire de l'état" if job_other=="Retraité de l'armée"
	replace `v'="Pensionnaire de l'état" if job_other=="Retraité"
	replace `v'="Pensionnaire de l'état" if job_other=="Retraiter a la sncc"
	replace `v'="Pensionnaire de l'état" if job_other=="Retraiter"
	replace `v'="Pensionnaire de l'état" if job_other=="Retraite"
	replace `v'="Pensionnaire de l'état" if job_other=="Penssionner"
	replace `v'="Pensionnaire de l'état" if job_other=="Pensionné de la sncc"
	replace `v'="Pensionnaire de l'état" if job_other=="Pensionné de la regideso"
	replace `v'="Pensionnaire de l'état" if job_other=="Pensionné de l état"
	replace `v'="Pensionnaire de l'état" if job_other=="Pensionné de l Etat"
	replace `v'="Pensionnaire de l'état" if job_other=="Pensionné d'Etat"
	replace `v'="Pensionnaire de l'état" if job_other=="Pensionné"
	replace `v'="Pensionnaire de l'état" if job_other=="Pensionner"
	replace `v'="Pensionnaire de l'état" if job_other=="Pensionne d’etat"
	replace `v'="Pensionnaire de l'état" if job_other=="Pensionne d'Etat"
	replace `v'="Pensionnaire de l'état" if job_other=="Pensionne"
	replace `v'="Pensionnaire de l'état" if job_other=="Pension malade"
	replace `v'="Pensionnaire de l'état" if job_other=="Pendionne d’etat"
	replace `v'="Pensionnaire de l'état" if job_other=="Pationné d'état sncc"
	replace `v'="Pensionnaire de l'état" if job_other=="Pationné d'état office de route"
	replace `v'="Pensionnaire de l'état" if job_other=="Pationné d'état SNCC"
	replace `v'="Pensionnaire de l'état" if job_other=="Pationné d'état INSS"
	replace `v'="Pensionnaire de l'état" if job_other=="Pationné d'état Gecamine"
	replace `v'="Pensionnaire de l'état" if job_other=="Pationné d'état (fonction publique)"
	replace `v'="Pensionnaire de l'état" if job_other=="Pationné d'état"
	replace `v'="Pensionnaire de l'état" if job_other=="Pationné d'etat"
	replace `v'="Pensionnaire de l'état" if job_other=="Pationné  d'état SNCC"
	replace `v'="Pensionnaire de l'état" if job_other=="Passionné de l Etat"
	replace `v'="Pensionnaire de l'état" if job_other=="Journalier à la sncc"
	replace `v'="Pensionnaire de l'état" if job_other=="Government personnel"
	}

	* Government Personnel
	foreach v of varlist job_str job_other{
	replace `v'="Government personnel" if job_other=="Agent DGI"
	replace `v'="Government personnel" if job_other=="Agent de l Snel"
	replace `v'="Government personnel" if job_other=="Agent de l'ofida"
	replace `v'="Government personnel" if job_other=="Agent de l'état mais qui est resté à la maison pour éviter des conflits au bureau."
	replace `v'="Government personnel" if job_other=="Agent de la DGI"
	replace `v'="Government personnel" if job_other=="Agent de la DGM"
	replace `v'="Government personnel" if job_other=="Agent de la RVA"
	replace `v'="Government personnel" if job_other=="Agent de la DGRAD"
	replace `v'="Government personnel" if job_other=="Agent de laCENI"
	replace `v'="Government personnel" if job_other=="Agent de la esnl"
	replace `v'="Government personnel" if job_other=="Agent regideso"
	replace `v'="Government personnel" if job_other=="Agent rtnc"
	replace `v'="Government personnel" if job_other=="Agnt de l'etat"
	replace `v'="Government personnel" if job_other=="Anr"
	replace `v'="Government personnel" if job_other=="CENI"
	replace `v'="Government personnel" if job_other=="Conseiller au ministère provincial de transport"
	replace `v'="Government personnel" if job_other=="DGRKOC"
	replace `v'="Government personnel" if job_other=="Depute"
	replace `v'="Government personnel" if job_other=="Dgi" 
	replace `v'="Government personnel" if job_other=="Direcab" 
	replace `v'="Government personnel" if job_other=="Député" 
	replace `v'="Government personnel" if job_other=="Député Nationale" 
	replace `v'="Government personnel" if job_other=="Fonctinnaire" 
	replace `v'="Government personnel" if job_other=="Fonction publique" 
	replace `v'="Government personnel" if job_other=="Fonctionnaire" 
	replace `v'="Government personnel" if job_other=="Fonctionnaire." 
	replace `v'="Government personnel" if job_other=="Fonctiônnaire" 
	replace `v'="Government personnel" if job_other=="Honorable  député" 
	replace `v'="Government personnel" if job_other=="Il est membre du cabinet du ministre provincial de la santé" 
	replace `v'="Government personnel" if job_other=="Il travail à la CENI" 
	replace `v'="Government personnel" if job_other=="Il travaille à  dgi" 
	replace `v'="Government personnel" if job_other=="Pdg régit des eau" 
	replace `v'="Government personnel" if job_other=="R.V.A" 
	replace `v'="Government personnel" if job_other=="RVA" 
	replace `v'="Government personnel" if job_other=="Rva" 
	replace `v'="Government personnel" if job_other=="Regideso" 
	replace `v'="Government personnel" if job_other=="Travail à l'anr" 
	replace `v'="Government personnel" if job_other=="Travailleur à l'ovd." 	
	replace `v'="Government personnel" if job_other=="Brougoumestre" 	
	replace `v'="Government personnel" if job_other=="Brougoustre" 	
	replace `v'="Government personnel" if job_other=="Sénateur" 	
	replace `v'="Government personnel" if job_other=="Muena mbulamatadi"
	replace `v'="Government personnel" if job_other=="Office route"
	}

	
	* Guard
	foreach v of varlist job_str job_other{
	replace `v'="Guard" if job_other=="Agent de sécurité  (société de gardiennage )"  
	replace `v'="Guard" if job_other=="Delta"  
	replace `v'="Guard" if job_other=="Delta sécurité service de gardiennage" 
	replace `v'="Guard" if job_other=="Garde"  
	replace `v'="Guard" if job_other=="Gardien"  
	replace `v'="Guard" if job_other=="Gardiennage"  
	replace `v'="Guard" if job_other=="Santinel"  
	replace `v'="Guard" if job_other=="Sentinnelle" 
	replace `v'="Guard" if job_other=="Service de gardiennage" 
	replace `v'="Guard" if job_other=="Société de sécurité privé" 
	replace `v'="Guard" if job_other=="Mulami"
	}
	
	* Bank employee
	foreach v of varlist job_str job_other{
	replace `v'="Bank" if job_other=="Agent de la banque" 
	replace `v'="Bank" if job_other=="Agent tmb" 
	replace `v'="Bank" if job_other=="Agent tmb" 
	replace `v'="Bank" if job_other=="Travail à la banc" 
	replace `v'="Bank" if job_other=="Travailleur à la banque." 
	}
		
	* Works at the Brasserie
	foreach v of varlist job_str job_other{
	replace `v'="Brasserie" if job_other=="Travailleur à la brasserie" 
	replace `v'="Brasserie" if job_other==" Travailleur à la brasseries" 
	replace `v'="Brasserie" if job_other=="Il travaille à la brasserie" 
	}
	
replace job_str=job_other if job_str==""
	
* Employment Status 
gen employed=0 if job_str!="" 
replace employed=1 if job_str!="" & job_str!="Unemployed-no work" & job_str!="Pensionnaire de l'état" 

* Salaried 
gen salaried=0 if job_str!="" 
replace salaried=1 if inlist(job,1,2,9,15,17,20,21,22,28) 
replace salaried=1 if job_str=="Medical assistant"
replace salaried=1 if job_str=="Lawyer"
replace salaried=1 if job_str=="Teacher"
replace salaried=1 if job_str=="Military officer/soldier or police officer"
replace salaried=1 if job_str=="Government personnel"
replace salaried=1 if job_str=="Professor"
replace salaried=1 if job_str=="Guard"
replace salaried=1 if job_str=="Work for NGO"
replace salaried=1 if job_str=="SNCC"
replace salaried=1 if job_str=="Bank"
replace salaried=1 if job_str=="Brasserie"
replace salaried=1 if job_other=="Il travail chez airtel" | job_other=="Il travail chez les prêtres" | job_other=="Il travail chez vodacom" ///
| job_other=="Il travaille chez airtel" 


* Works for the government 
gen work_gov=0 if job_str!="" 
replace work_gov=1 if inlist(job,15,17,28)
replace work_gov=1 if job_str=="Military officer/soldier or police officer"
replace work_gov=1 if job_str=="Government personnel"
replace work_gov=1 if job_str=="SNCC"

* Relative work for the government
replace job_gov=. if job_gov==.d
replace job_gov=1 if work_gov==1 // job_gov is set to missing if owner works for the government so filling this in

* Years on the Avenue 
replace move_ave=. if move_ave==.d

* Sanctions 
replace sanctions=. if sanctions==.d

* Public goods
replace pubgoods=. if pubgoods==.d

******************************
* Tax Collector Compensation *
******************************

compress
save "${repldir}/data/03_clean_combined/combined_data.dta", replace

********************************************************************************
* Create analysis dataset for paper tables and figures
********************************************************************************

	* Use Clean dataset
	use "${repldir}/data/03_clean_combined/combined_data.dta", clear
	drop _merge
	
	* Drop villas
	drop if house==3
	gen mm=0 if house==1
	replace mm=1 if house==2

	* Drop pilot data
	drop if pilot==1 
	drop if a7==200 | a7==201 | a7==202 | a7==203 | a7==207 | a7==208 | a7==210	
	
	* Treatment variables
	gen t_l=(tmt==2)
	label var t_l "Local"
	gen t_c=(tmt==1)
	label var t_c "Central"
	gen t_cli=(tmt==3)
	label var t_cli "Central with Info"
	gen t_cxl=(tmt==4)
	label var t_cxl "Central x Local"
	
	* Amount of taxes paid 
	cap drop taxes_paid_amt
	gen taxes_paid_amt=taxes_paid*rate
		
		* Missing amounts
		*replace taxes_paid_amt=0 if taxes_paid==0 & rate==.
		*replace taxes_paid_amt=0.3832*6600+0.2804*8800+0.1589*1100+0.1776*13200 if taxes_paid==1 & house==2 & tmt==1 & rate==.
		*replace taxes_paid_amt=0.3628*6600+0.3540*8800+0.885*1100+0.1947*13200 if taxes_paid==1 & house==2 & tmt==2 & rate==.

	
	* Correct error TDM date
	br if date_TDM<td(15jun2018) // Error: Carto did not start before June 15th
	replace date_TDM=. if date_TDM<td(15jun2018) 
	br if tmt==3 & date_TDM<td(15jul2018) // Error: For CLI, carto did not start before July 15th
	replace date_TDM=. if tmt==3 & date_TDM<td(16jul2018) 
	
	* Correct missing carto date 

		* Missing entire polygon: Use "Zoom-in"'s last day of carto
		tab a7 if today_carto==.  
		replace today_carto=td(28nov2018) if a7==112
		replace today_carto=td(28nov2018) if a7==219
		replace today_carto=td(29nov2018) if a7==224
		replace today_carto=td(03dec2018) if a7==238
		replace today_carto=td(06dec2018) if a7==327
		replace today_carto=td(30nov2018) if a7==343
		replace today_carto=td(30nov2018) if a7==356
		replace today_carto=td(03dec2018) if a7==510
		replace today_carto=td(03dec2018) if a7==512
		replace today_carto=td(26nov2018) if a7==514
		replace today_carto=td(28nov2018) if a7==533
		replace today_carto=td(29nov2018) if a7==538
		replace today_carto=td(29nov2018) if a7==544
		replace today_carto=td(27nov2018) if a7==588
		replace today_carto=td(29nov2018) if a7==596
		replace today_carto=td(27nov2018) if a7==658
		replace today_carto=td(28nov2018) if a7==664
		replace today_carto=td(1dec2018) if a7==669
		replace today_carto=td(29nov2018) if a7==678 

		* Missing some observations in the polygon
		
				* rank of compound code in polygon
				sort a7 compound1 
				by a7: gen a7_rank=_n
				by a7: egen a7_max_rank=max(a7_rank)
				
				* previous and next compound code
				gen today_carto_plus1=today_carto[_n+1] if a7[_n]==a7[_n+1]
				gen today_carto_minus1=today_carto[_n-1] if a7[_n]==a7[_n-1]
		
			* missing today_carto but previous and next compound code are not missing... 
	
				* ... And are the same
				br  a7 compound1 a7_rank a7_max_rank today_carto if today_carto==. ///
				& today_carto[_n-1] ==today_carto[_n+1] &  today_carto[_n-1]!=. & today_carto[_n+1]!=.
				replace today_carto=today_carto_minus1 if today_carto==. & ///
				today_carto[_n-1]==today_carto[_n+1] & today_carto[_n-1]!=. & today_carto[_n+1]!=.

				* ... And are different: 
				br  a7 compound1 a7_rank a7_max_rank today_carto if today_carto==. ///
				& today_carto[_n-1]!=today_carto[_n+1] &  today_carto[_n-1]!=. & today_carto[_n+1]!=.

					* Last obs in the polygon
					replace today_carto=today_carto_minus1 if today_carto==. ///
					& today_carto[_n-1]!=today_carto[_n+1] & today_carto[_n-1]!=. & today_carto[_n+1]!=. & a7_rank==a7_max_rank		
			
					* Obs in the middle of the polygon
					replace today_carto=today_carto_plus1 if today_carto==. ///
					& today_carto[_n-1]!=today_carto[_n+1] & today_carto[_n-1]!=. & today_carto[_n+1]!=. & a7_rank!=a7_max_rank

			* Other observations
			replace today_carto=td(09aug2018) if today_carto==. & a7==204
			replace today_carto=td(21jun2018) if today_carto==. & a7==624
			replace today_carto=td(05nov2018) if today_carto==. & a7==694 & (compound1==694001 | compound1==694002 | compound1==694003 | compound1==694004)
			replace today_carto=td(06nov2018) if today_carto==. & a7==694
			replace today_carto=td(08aug2018) if today_carto==. & a7==6104
			replace today_carto=td(18jun2018) if today_carto==. & a7==231
			replace today_carto=td(16jun2018) if today_carto==. & a7==300
			replace today_carto=td(17sep2018) if today_carto==. & a7==312
			replace today_carto=td(15jun2018) if today_carto==. & a7==313
			replace today_carto=td(18jul2018) if today_carto==. & a7==502
			replace today_carto=td(08aug2018) if today_carto==. & a7==507
			replace today_carto=td(08aug2018) if today_carto==. & a7==557
			replace today_carto=td(25jun2018) if today_carto==. & a7==563
			replace today_carto=td(18aug2018) if today_carto==. & a7==571
			replace today_carto=td(08aug2018) if today_carto==. & a7==577
			replace today_carto=td(11dec2018) if today_carto==. & a7==595
			replace today_carto=td(19jul2018) if today_carto==. & a7==597
			replace today_carto=td(08aug2018) if today_carto==. & a7==619
			replace today_carto=td(08aug2018) if today_carto==. & a7==635
			replace today_carto=td(07nov2018) if today_carto==. & a7==647
			replace today_carto=td(07sep2018) if today_carto==. & a7==701
			replace today_carto=td(06nov2018) if today_carto==. & a7==6103
			
* Create alternative date based on: (1) min TDM in the polygon if TDM date not missing, (2) carto date if no TDM date in polygon
sort a7 compound1 
by a7: egen a7_min_today_TDM=min(date_TDM)
by a7: egen a7_max_today_carto=max(today_carto)
gen today_alt=a7_min_today_TDM 
replace today_alt= a7_max_today_carto if today_alt==. & a7_min_today_TDM==. & a7_max_today_carto!=.

drop if rate==.

save "${repldir}/data/03_clean_combined/analysis_data.dta", replace

keep a7 a7_min_today_TDM a7_max_today_carto

duplicates drop
save "${repldir}/data/03_clean_combined/analysis_data_neighborhoods.dta", replace
