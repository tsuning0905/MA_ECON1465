***************************************************************************************
* Program: 1_Package_Setup.do
* Author: Gabriel Tourek
* Created: 6 Aug 2021
* Modified: 		
* Purpose: Checks if necessary packages are present, and if not, installs them.
*	 Modified from Gentzkow Shapiro Lab's config_stata.do 
*	(https://github.com/gslab-econ/template/blob/master/config/config_stata.do)
***************************************************************************************

local ssc_packages "estout outtable mmat2tex geodist center grstyle palettes balancetable winsor revrs distplot blindschemes binscatter cibar"
* install using ssc, but avoid re-installing if already present
foreach pkg in `ssc_packages' {
	capture which `pkg'
	if _rc == 111 {                 
		dis "Installing `pkg'"
		quietly ssc install `pkg', replace
	}
}

* Set graph style
cap set scheme plainplot
cap set scheme plotplainblind //for Stata 16

* Install packages using net, but avoid re-installing if already present
capture which GSSU
if _rc == 111 {
	quietly net from "https://www.jcsuarez.com/GSSU/"
	quietly cap ado uninstall GSSU
	quietly net install GSSU
}

* Install packages using net, but avoid re-installing if already present
capture which cem
if _rc == 111 {
	quietly net from "https://www.mattblackwell.org/files/stata"
	quietly cap ado uninstall cem
	quietly net install cem
}
