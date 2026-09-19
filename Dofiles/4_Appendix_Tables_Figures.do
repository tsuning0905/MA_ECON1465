********************************************************************************
* Program: 4_Appendix_Tables_Figures
* Author: Gabriel Tourek
* Created: 6 Aug 2021
* Modified: 		
* Purpose: Replicate Appendix Tables and Figures
********************************************************************************

foreach output in ///
TableA1 TableA2 TableA3 TableA4 TablesA5_A18_FigureA6 TableA6 ///
TableA7 TablesA8_A14_A15_A27 TableA9 TableA10 TableA11 TableA12 ///
TableA13 TablesA14_A43_A44 TableA16 TableA17 TableA19 TableA20 ///
TableA21 TableA22 TablesA24_A25 TableA26 TablesA28_A29_A30 ///
TableA31 TableA32 TableA33 TablesA34_A35 TableA36 TableA37 ///
TableA39 TablesA40_A41_A42 TableA45 FigureA4 ///
FigureA5 FigureA7_TableA23 Figures1_A9_A10_A11_A14 ///
FigureA12 FigureA13 FigureA15 FigureA18_TableA38 ///
FigureA19 FigureA20 FiguresA21_A22{
	do "$repldodir/Tables_Figures/`output'.do"
}
