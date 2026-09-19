********************************************************************************
* Program: 3_Main_Tables_Figures
* Author: Gabriel Tourek
* Created: 6 Aug 2021
* Modified: 		
* Purpose: Replicate Main Tables and Figures
********************************************************************************

foreach output in Table1 Table2 Table3 Table4 Table5 Table6 Table7 Table8 Figures1_A9_A10_A11_A14 Table9{
	do "$repldodir/Tables_Figures/`output'.do"
}

* Note: Figures1_A9_A10_A11_A14.do also produces Appendix Figures A9-A11 and A14
