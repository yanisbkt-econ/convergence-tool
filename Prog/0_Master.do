* ----------------------------------
*  Master Do-file.                           
* -------------------------------
*  Author: Yanis Bekhti
*  Last update: 22/08/2026
*  Stata version: StataNow/SE, 19.5
* ----------------------------------

*** ----------------------------
**# 0. Defining the environment.
*** ----------------------------

clear all
set more off, permanently

*** ------------------------------------------
**# 1. Unique path, please set accordingly.
*** ------------------------------------------

global path ""

*** ------------------------------
**# 2. Input and output globals. 
*** ------------------------------ 

global dirraw "$path\Raw"
global dirrdata "$path\Data"
global dirrprog "$path\Prog"

*** --------------------------
**# 4. Running every do-files. 
*** --------------------------

local run_dofiles "" // Switch to 'true' to run all the do-files.

if lower("`run_dofiles'") == "true" {
    do "$dirrprog\1_Cleaning_UNDP"
	do "$dirrprog\2_Cleaning_WB_GDPPC"
}