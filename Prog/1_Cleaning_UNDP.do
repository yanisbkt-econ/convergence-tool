* -----------------------------------------------------------------------------
*  UNDP Human Development Reports (HDR)                     
*  Composite Indices - Complete Time Series (1990-2023)           
*  ----------------------------------------------------------------------------
*  Author: Yanis Bekhti
*  Last update: 22/08/2026
*  Stata version: StataNow/SE, 19.5
* -----------------------------------------------------------------------------
*  Raw data and metadata available at:
*  https://hdr.undp.org/data-center/documentation-and-downloads
* -----------------------------------------------------------------------------

clear all

*** ---------------------------------------------------------
**# 1. Import raw data, small cleaning, selecting variables.
*** ---------------------------------------------------------

*Importing the raw databases.

import delimited "$dirraw\UNDP_HDR25_CI_CTS.csv", clear 

*Preparing the reshape.

drop hdi_rank_2023 hdicode
ds iso3 country region, not
local allvars `r(varlist)'
foreach v of local allvars {
    local var_reshape = substr("`v'", 1, length("`v'") - 4)
    local all_reshape `all_reshape' `var_reshape'
}
local all_reshape : list uniq all_reshape

*Reshaping the dataset.

reshape long `all_reshape', i(iso3 country region) j(year)

*Renaming.

foreach v of varlist * {
    if substr("`v'", -1, 1) == "_" {
        local newname = substr("`v'", 1, length("`v'") - 1)
        rename `v' `newname'
    }
}

*Labeling some variables following the UNSD Metadata. 

label variable iso3 "ISO3 country code"
label variable country "Country name"
label variable region "UNDP region"
label variable year "Year"

label variable le "Life expectancy at birth"
label variable mys "Mean years of schooling"
label variable eys "Expected years of schooling"
label variable gnipc "Gross national income per capita"

label variable hdi "Human Development Index (HDI)"
label variable ihdi "Inequality-adjusted Human Development Index (IHDI)"
label variable gii "Gender Inequality Index (GII)"


*We keep only variables having labels.

foreach v of varlist _all {
        local lbl : variable label `v'
        if "`lbl'" == "" {
            drop `v'
        }
}

*For consistency we construct an Inverted Gender Inequality Index.
*Being close to 1 means a better equality. 

gen gii_inv = 1 - gii
label variable gii_inv "Gender inequality index (1 - GII)"
drop gii

*Adjusting areas, creating area type and droping regions.

rename country area_name

gen area_type = 1
replace area_type = 2 if regexm(area_name, "development")
replace area_type = 3 if area_name=="World"
label define area_type_lbl 1 "country" 2 "benchmark" 3 "world"
label values area_type area_type_lbl
order area_type, after(area_name)

drop region
drop if inlist(area_name, "Arab States", "East Asia and the Pacific", "Europe and Central Asia", ///
    "Latin America and the Caribbean", "South Asia", "Sub-Saharan Africa")
	
*Adjusting areas names, from UNSD M49. 

preserve
import excel "$dirraw\M49_UNSD.xlsx", firstrow clear
tempfile m49
keep CountryorArea ISOalpha3Code
rename ISOalpha3Code iso3
rename CountryorArea area_name_M49
save `m49'
restore 
merge m:1 iso3 using `m49'
replace area_name_M49 = area_name if _merge==1
drop if _merge==2
drop _merge area_name 
rename area_name_M49 area_name
order area_name, before(area_type)

*Storing the main variables in a macro for subsquent loops.

ds iso3 area_name area_type year, not
local varlist_shortname `r(varlist)'
	
*** ------------------------------------------------
**# 2. Exporting 'raw' series, for visualisation.
*** ------------------------------------------------

foreach v of local varlist_shortname {
preserve
keep iso3 area_name area_type year `v'
export delimited using "$dirrdata\Time_series\UNDP_`v'_timeseries.csv", replace 
restore	
}

*** -----------------------------------------------------------------------------
**# 3. Computing the geometric annual growth rate over different windows.
*** -----------------------------------------------------------------------------

encode area_name, gen(area_id)
order area_id, after(area_name)

*Computing annual growth rates.

xtset area_id year
foreach v of local varlist_shortname {
    gen ln_`v' = ln(`v')
    gen gr_`v' = ln_`v' - L1.ln_`v' // Annual growth rate.
	order gr_`v', after(`v')
	drop ln_`v'
}

*Reshaping to wide format. 

ds iso3 area_name area_id area_type year, not
reshape wide `r(varlist)', i(iso3 area_name area_id area_type) j(year)

*Computing geometric average growth rates from 2023, the latest common value.
*Window must be complete, otherwise the geometrical average is missing.

foreach v of local varlist_shortname {
    foreach n in 1 3 5 10 {
        local start = 2023 - `n' + 1
        local gr_required ""
			forvalues y = `start'/2023 {
				local gr_required "`gr_required' gr_`v'`y'"
			}
			egen nmiss_`v'`n' = rowmiss(`gr_required')
			egen mean_gr_`v'`n' = rowmean(`gr_required')
			gen gr_`v'_P`n' = exp(mean_gr_`v'`n') - 1 if nmiss_`v'`n' == 0 
       order gr_`v'_P`n', after(`v'2023)
	   drop mean_gr_`v'`n' nmiss_`v'`n'
    }
}

*Small renaming, and keep only necessary variables. 

foreach v of local varlist_shortname {
	rename `v'2023 `v'
}
keep iso3 area_name area_type `varlist_shortname' *P*

*Creating an indicator regarding the latest value.

gen year_latest_value = 2023
order year_latest_value, after(area_type)

* -----------------------------------------------------------------------------
**# 4. Exporting the csv for the convergene tool (latest value + average growth rates)
* -----------------------------------------------------------------------------

foreach v of local varlist_shortname {
    preserve
    local keepvars `v'
    foreach n in 1 3 5 10 {
        local keepvars `keepvars' gr_`v'_P`n'
    }
    keep iso3 area_name area_type year_latest_value `keepvars'
    export delimited using "$dirrdata\Convergence_tool\UNDP_`v'_convergence.csv", replace 
    restore	
}