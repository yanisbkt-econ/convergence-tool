* -----------------------------------------------------------------------------
*  World Bank, World Development Indicators                     
*  GDP per capita, constant 2021 international dollars        
*  ----------------------------------------------------------------------------
*  Author: Yanis Bekhti
*  Last update: 22/08/2026
*  Stata version: StataNow/SE, 19.5
* -----------------------------------------------------------------------------
*  Raw data available at:
*  https://data.worldbank.org/indicator/NY.GDP.PCAP.PP.KD
* -----------------------------------------------------------------------------

clear all

*** -----------------------------------------------------------------------------
**# 1. Import raw data, small cleaning, selecting variables.
*** -----------------------------------------------------------------------------

*Importing the raw databases.

import excel "$dirraw/WB_GDPPC.xls", sheet("Data") firstrow clear
drop C D 
rename WorldDevelopmentIndicators iso3
rename DataSource area_name
drop in 1/3

*Quick rename, preparing for the reshape.

local startyear = 1960
foreach var of varlist E-BR {
    rename `var' y`startyear'
    local startyear = `startyear'+ 1
}

*Reshaping the dataset.

reshape long y, i(iso3 area_name) j(year)
rename y gdppc
destring gdppc, replace
drop if year<1990 

*Adjusting areas, droping regions and aggregates.

drop if inlist(area_name, "Africa Western and Central", "Arab World", "Caribbean small states", "Central Europe and the Baltics", "Early-demographic dividend", "East Asia & Pacific", "Europe & Central Asia", "European Union") | ///
	inlist(area_name, "Heavily indebted poor countries (HIPC)", "IBRD only", "IDA & IBRD total", "IDA blend", "IDA only", "IDA total", "Late-demographic dividend", "Latin America & Caribbean") | ///
	inlist(area_name, "OECD members", "Other small states", "Pacific island small states", "Post-demographic dividend", "Pre-demographic dividend", "South Asia", "South Asia (IDA & IBRD)", "Sub-Saharan Africa") | ///
	inlist(area_name, "Sub-Saharan Africa (excluding high income)", "Sub-Saharan Africa (IDA & IBRD countries)", "Not classified", "North America", "Middle East, North Africa, Afghanistan & Pakistan", "Middle East, North Africa, Afghanistan & Pakistan (excluding high income)", "Middle East, North Africa, Afghanistan & Pakistan (IDA & IBRD)", "Latin America & Caribbean (excluding high income)") | ///
	inlist(area_name, "Latin America & the Caribbean (IDA & IBRD countries)", "Least developed countries: UN classification", "East Asia & Pacific (excluding high income)", "East Asia & Pacific (IDA & IBRD countries)", "Europe & Central Asia (excluding high income)", "Europe & Central Asia (IDA & IBRD countries)", "Africa Eastern and Southern", "Euro area", "Small states")
	
*Creating area type.
	
gen area_type = 1
replace area_type = 2 if regexm(area_name, "income")
replace area_type = 3 if area_name=="World"
label define area_type_lbl 1 "country" 2 "benchmark" 3 "world"
label values area_type area_type_lbl
order area_type, after(area_name)
drop if area_name == "Low & middle income"

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
	
*** ---------------------------------------------
**# 2. Exporting 'raw' series, for visualisation.
*** ---------------------------------------------

export delimited using "$dirrdata\Time_series\WB_gdppc_timeseries.csv", replace

*** ---------------------------------------------------------------------
**# 3. Computing the geometric annual growth rate over different windows.
*** ---------------------------------------------------------------------

keep if year>=2013 & year<=2023
encode area_name, gen(area_id)
order area_id, after(area_name)

*Computing annual growth rates.

xtset area_id year
gen ln_gdppc = ln(gdppc)
gen gr_gdppc = ln_gdppc - L1.ln_gdppc // Annual growth rate.
order gr_gdppc, after(gdppc)
drop ln_gdppc

*Reshaping to wide.

reshape wide gdppc gr_gdppc, i(iso3 area_name area_id area_type) j(year)

*Computing geometric average growth rates from 2023, the latest common value.
*Window must be complete, otherwise the geometrical average is missing.

local v gdppc

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

*Small renaming, and keep only necessary variables. 

rename gdppc2023 gdppc
keep iso3 area_name area_type gdppc *P*
drop if missing(gdppc)

*Creating an indicator regarding the latest value.

gen year_latest_value = 2023
order year_latest_value, after(area_type)

* -----------------------------------------------------------------------------
**# 4. Exporting the csv for the convergene tool (latest value + average growth rates)
* -----------------------------------------------------------------------------

export delimited using "$dirrdata\Convergence_tool\WB_gdppc_convergence.csv", replace