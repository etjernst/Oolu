* **********************************************************************
* Project:          Oolu
* Created:          20201019
* Last modified:    20201019 by et
* Stata v.16.1
* **********************************************************************
* does
  /*  Opens the Nigeria General Household Survey (GHS)
			LSMS Wave 4

			Nigeria National Bureau of Statistics
			General Household Survey, Panel (GHS-Panel) 2018-2019
			Dataset downloaded from www.microdata.worldbank.org on OCt 19, 2020

			Raw data, questionnaires, and basic info are available at
			http://microdata.worldbank.org/index.php/catalog/2734
  */

* TO DO:
  *

***********************************************************************
* 1 - Open household identification info
***********************************************************************
	use ${data}/secta_plantingw4.dta, clear
	gen 							urban = (sector == 1)
	label variable 		urban "Urban = 1"

* Only keep complete interviews
	keep if 					interview_result == 1

	* wt_wave4		= household cross-sectional weight
	* ea		= enumeration area

***********************************************************************
* 2 - Assets
***********************************************************************
	use ${data}/sect5_plantingw4.dta, clear

	gen 							urban = (sector == 1)
	label variable 		urban "Urban = 1"

	gen 							value_assets = s5q4 * s5q1
	label var					value_assets "Value today times no items owned"

* Copy variable labels:
	include https://gist.githubusercontent.com/etjernst/4055c1434280ca63e1185c8b46b279e5/raw/c2f8991409a2ae47acec29e76146387ebc711e1a/copylabels.do

* Collapse at hhid level, keeping sum of asset values, ea, urban dummy
	collapse 	(sum)		value_assets 				///
						(mean) 	ea urban						///
						, by(hhid)

* Re-attach variable labels:
	include	https://gist.githubusercontent.com/etjernst/4055c1434280ca63e1185c8b46b279e5/raw/c2f8991409a2ae47acec29e76146387ebc711e1a/attachlabels.do

* Winsorize asset values
	winsor2 value_assets, suffix(W)

* Log asset values
	gen 							log_assets = log(value_assets)

* Quick box plot
	graph box log_assets if urban, over(ea, sort(1)) noout ytitle("Log asset value, urban") 

e
***********************************************************************
* 2 - Household roster
***********************************************************************
	use ${data}/sect1_plantingw4.dta, clear
e
********************************************************************************
* EXCHANGE RATE AND INFLATION FOR CONVERSION IN USD
********************************************************************************
global Nigeria_GHS_W3_exchange_rate 199.04975  	// https://www.bloomberg.com/quote/USDETB:CUR
global Nigeria_GHS_W3_gdp_ppp_dollar 93.915   	// https://data.worldbank.org/indicator/PA.NUS.PPP
global Nigeria_GHS_W3_cons_ppp_dollar 123.639 	// https://data.worldbank.org/indicator/PA.NUS.PRVT.PP?locations=NG
global Nigeria_GHS_W3_inflation 0



********************************************************************************
* HOUSEHOLD IDS *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/HHTrack.dta", clear
merge m:1 hhid using "${Nigeria_GHS_W3_raw_data}/sectaa_plantingw3.dta"
gen rural = (sector==2)
lab var rural "1= Rural"
keep hhid zone state lga ea wt_wave3 rural
ren wt_wave3 weight
save  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hhids.dta", replace

********************************************************************************
* WEIGHTS *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/HHTrack.dta", clear
merge m:1 hhid using "${Nigeria_GHS_W3_raw_data}/sectaa_plantingw3.dta"
gen rural = (sector==2)
lab var rural "1= Rural"
keep hhid zone state lga ea wt_wave3 rural
ren wt_wave3 weight
save  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_weights.dta", replace

********************************************************************************
* INDIVIDUAL IDS *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/PTrack.dta", clear
keep hhid indiv sex age
gen female= sex==2
la var female "1= individual is female"
la var age "Individual age"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_person_ids.dta", replace

********************************************************************************
* HOUSEHOLD SIZE *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/PTrack.dta", clear
gen hh_members = 1
ren sex gender
gen fhh = (relat_w3v1==1 | relat_w3v2==1) & gender==2

collapse (sum) hh_members (max) fhh, by (hhid)
lab var hh_members "Number of household members"
lab var fhh "1= Female-headed household"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hhsize.dta", replace

********************************************************************************
*HEAD OF HOUSEHOLD *
********************************************************************************
*Creating HOH gender
clear
use "$Nigeria_GHS_W3_raw_data/PTrack.dta", clear
gen male_head = 0
replace male_head =1 if (relat_w3v1==1 | relat_w3v2==1) & sex ==1
collapse (max) male_head, by(hhid)
la var male_head "HH is male headed, 1=yes"
save "$Nigeria_GHS_W3_created_data/Nigeria_GHS_W3_male_head.dta", replace

********************************************************************************
* PLOT AREAS *
********************************************************************************
*starting with planting
clear
use "${Nigeria_GHS_W3_raw_data}/sect11a1_plantingw3"
*merging in planting section to get cultivated status
merge 1:1 hhid plotid using "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3", nogen
*merging in harvest section to get areas for new plots
merge 1:1 hhid plotid using "${Nigeria_GHS_W3_raw_data}/secta1_harvestw3.dta", gen(plot_merge)
ren s11aq4a area_size
ren s11aq4b area_unit
ren sa1q9a area_size2
ren sa1q9b area_unit2
ren s11aq4c area_meas_sqm
ren sa1q9c area_meas_sqm2
gen cultivate = s11b1q27 ==1
*assuming new plots are cultivated
replace cultivate = 1 if sa1q3==1
*using conversion factors from LSMS-ISA Nigeria Wave 2 Basic Information Document (Wave 3 unavailable, but Waves 1 & 2 are identical)
*found at http://econ.worldbank.org/WBSITE/EXTERNAL/EXTDEC/EXTRESEARCH/EXTLSMS/0,,contentMDK:23635560~pagePK:64168445~piPK:64168309~theSitePK:3358997,00.html
*General Conversion Factors to Hectares
//		Zone   Unit         Conversion Factor
//		All    Plots        0.0667
//		All    Acres        0.4
//		All    Hectares     1
//		All    Sq Meters    0.0001

*Zone Specific Conversion Factors to Hectares
//		Zone           Conversion Factor
//				 Heaps      Ridges      Stands
//		1 		 0.00012 	0.0027 		0.00006
//		2 		 0.00016 	0.004 		0.00016
//		3 		 0.00011 	0.00494 	0.00004
//		4 		 0.00019 	0.0023 		0.00004
//		5 		 0.00021 	0.0023 		0.00013
//		6  		 0.00012 	0.00001 	0.00041

*farmer reported field size for post-planting
gen field_size= area_size if area_unit==6
replace field_size = area_size*0.0667 if area_unit==4									//reported in plots
replace field_size = area_size*0.404686 if area_unit==5		    						//reported in acres
replace field_size = area_size*0.0001 if area_unit==7									//reported in square meters

replace field_size = area_size*0.00012 if area_unit==1 & zone==1						//reported in heaps
replace field_size = area_size*0.00016 if area_unit==1 & zone==2
replace field_size = area_size*0.00011 if area_unit==1 & zone==3
replace field_size = area_size*0.00019 if area_unit==1 & zone==4
replace field_size = area_size*0.00021 if area_unit==1 & zone==5
replace field_size = area_size*0.00012 if area_unit==1 & zone==6

replace field_size = area_size*0.0027 if area_unit==2 & zone==1							//reported in ridges
replace field_size = area_size*0.004 if area_unit==2 & zone==2
replace field_size = area_size*0.00494 if area_unit==2 & zone==3
replace field_size = area_size*0.0023 if area_unit==2 & zone==4
replace field_size = area_size*0.0023 if area_unit==2 & zone==5
replace field_size = area_size*0.00001 if area_unit==2 & zone==6

replace field_size = area_size*0.00006 if area_unit==3 & zone==1						//reported in stands
replace field_size = area_size*0.00016 if area_unit==3 & zone==2
replace field_size = area_size*0.00004 if area_unit==3 & zone==3
replace field_size = area_size*0.00004 if area_unit==3 & zone==4
replace field_size = area_size*0.00013 if area_unit==3 & zone==5
replace field_size = area_size*0.00041 if area_unit==3 & zone==6

*replacing farmer reported with GPS if available
replace field_size = area_meas_sqm*0.0001 if area_meas_sqm!=.
gen gps_meas = (area_meas_sqm!=. | area_meas_sqm2!=.)
la var gps_meas "Plot was measured with GPS, 1=Yes"
*farmer reported field size for post-harvest added fields
replace field_size= area_size2 if area_unit2==6 & field_size==.
replace field_size = area_size2*0.0667 if area_unit2==4	& field_size==.		            	//reported in plots
replace field_size = area_size2*0.404686 if area_unit2==5 & field_size==.					//reported in acres
replace field_size = area_size2*0.0001 if area_unit2==7	& field_size==.		            	//reported in square meters

replace field_size = area_size2*0.00012 if area_unit2==1 & zone==1 & field_size==.			//reported in heaps
replace field_size = area_size2*0.00016 if area_unit2==1 & zone==2 & field_size==.
replace field_size = area_size2*0.00011 if area_unit2==1 & zone==3 & field_size==.
replace field_size = area_size2*0.00019 if area_unit2==1 & zone==4 & field_size==.
replace field_size = area_size2*0.00021 if area_unit2==1 & zone==5 & field_size==.
replace field_size = area_size2*0.00012 if area_unit2==1 & zone==6 & field_size==.

replace field_size = area_size2*0.0027 if area_unit2==2 & zone==1 & field_size==.			//reported in ridges
replace field_size = area_size2*0.004 if area_unit2==2 & zone==2 & field_size==.
replace field_size = area_size2*0.00494 if area_unit2==2 & zone==3 & field_size==.
replace field_size = area_size2*0.0023 if area_unit2==2 & zone==4 & field_size==.
replace field_size = area_size2*0.0023 if area_unit2==2 & zone==5 & field_size==.
replace field_size = area_size2*0.00001 if area_unit2==2 & zone==6 & field_size==.

replace field_size = area_size2*0.00006 if area_unit2==3 & zone==1 & field_size==.			//reported in stands
replace field_size = area_size2*0.00016 if area_unit2==3 & zone==2 & field_size==.
replace field_size = area_size2*0.00004 if area_unit2==3 & zone==3 & field_size==.
replace field_size = area_size2*0.00004 if area_unit2==3 & zone==4 & field_size==.
replace field_size = area_size2*0.00013 if area_unit2==3 & zone==5 & field_size==.
replace field_size = area_size2*0.00041 if area_unit2==3 & zone==6 & field_size==.

*replacing farmer reported with GPS if available
replace field_size = area_meas_sqm2*0.0001 if area_meas_sqm2!=.
la var field_size "Area of plot (ha)"
ren plotid plot_id
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta", replace

********************************************************************************
* PLOT DECISION MAKERS *
********************************************************************************
*Creating gender variables for plot manager from post-planting
use "${Nigeria_GHS_W3_raw_data}/sect1_plantingw3.dta", clear
gen female = s1q2==2 if s1q2!=.
gen age = s1q6
*dropping duplicates (data is at holder level so some individuals are listed multiple times, we only need one record for each)
duplicates drop hhid indiv, force
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_gender_merge_temp.dta", replace

*adding in gender variables for plot manager from post-harvest
use "${Nigeria_GHS_W3_raw_data}/sect1_harvestw3.dta", clear
gen female = s1q2==2 if s1q2!=.
gen age = s1q4
duplicates drop hhid indiv, force
merge 1:1 hhid indiv using "$Nigeria_GHS_W3_created_data/Nigeria_GHS_W3_gender_merge_temp.dta", nogen
keep hhid indiv female age
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_gender_merge.dta", replace

*Using planting data
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta", clear
//Post-Planting
*First manager
gen indiv = s11aq6a
merge m:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_gender_merge_temp.dta", gen(dm1_merge) keep(1 3)
gen dm1_female = female if s11aq6a!=.
drop indiv
*Second manager
gen indiv = s11aq6b
merge m:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_gender_merge_temp.dta", gen(dm2_merge) keep(1 3)
gen dm2_female = female & s11aq6b!=.
drop indiv
//Post-Harvest (only reported for "new" plot)
*First manager
gen indiv = sa1q11
merge m:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_gender_merge_temp.dta", gen(dm4_merge) keep(1 3)
gen dm3_female = female & sa1q11!=.
drop indiv
*Second manager
gen indiv = sa1q11b
merge m:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_gender_merge_temp.dta", gen(dm5_merge) keep(1 3)
gen dm4_female = female & sa1q11b!=.
drop indiv
*Replace PP with PH if missing
replace dm1_female=dm3_female if dm1_female==.
replace dm2_female=dm4_female if dm1_female==.
*Constructing three-part gendered decision-maker variable; male only (=1) female only (=2) or mixed (=3)
gen dm_gender = 1 if (dm1_female==0 | dm1_female==.) & (dm2_female==0 | dm2_female==.) & !(dm1_female==. & dm2_female==.)
replace dm_gender = 2 if (dm1_female==1 | dm1_female==.) & (dm2_female==1 | dm2_female==.) & !(dm1_female==. & dm2_female==.)
replace dm_gender = 3 if dm_gender==. & !(dm1_female==. & dm2_female==.)
la def dm_gender 1 "Male only" 2 "Female only" 3 "Mixed gender"
*replacing observations without gender of plot manager with gender of HOH
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hhsize.dta", nogen keep(1 3)
replace dm_gender=1 if fhh ==0 & dm_gender==. //0 changes
replace dm_gender=2 if fhh ==1 & dm_gender==. //0 changes
gen dm_male = dm_gender==1
gen dm_female = dm_gender==2
gen dm_mixed = dm_gender==3
keep field_size plot_id hhid dm_* fhh
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", replace

********************************************************************************
*Formalized Land Rights*
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3.dta", clear
gen formal_land_rights = s11b1q8>=1 & s11b1q8b!= "NO NEED"
*Individual level (for women)
*Starting with first owner
preserve
ren s11b1q8b1 indiv
merge m:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_person_ids.dta", nogen keep(3)
keep hhid indiv female formal_land_rights
tempfile p1
save `p1', replace
restore
*Now second owner
preserve
ren s11b1q8b2 indiv
merge m:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_person_ids.dta", nogen keep(3)
keep hhid indiv female
tempfile p2
save `p2', replace
restore
*Now third owner
preserve
ren s11b1q8b3 indiv
merge m:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_person_ids.dta", nogen keep(3)
keep hhid indiv female
append using `p1'
append using `p2'
gen formal_land_rights_f = formal_land_rights==1 if female==1
collapse (max) formal_land_rights_f, by(hhid indiv)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_rights_ind.dta", replace
restore
collapse (max) formal_land_rights_hh=formal_land_rights, by(hhid)		// taking max at household level; equals one if they have official documentation for at least one plot
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_rights_hh.dta", replace


********************************************************************************
*crop unit conversion factors
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/ag_conv_w3", clear
ren crop_cd crop_code
ren conv_NC_1 conv_fact1
ren conv_NE_2 conv_fact2
ren conv_NW_3 conv_fact3
ren conv_SE_4 conv_fact4
ren conv_SS_5 conv_fact5
ren conv_SW_6 conv_fact6
sort crop_code unit_cd conv_national
reshape long conv_fact, i(crop_code unit_cd conv_national) j(zone)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_ng3_cf.dta", replace


********************************************************************************
*MONOCROPPED PLOTS
********************************************************************************

forvalues k=1(1)$nb_topcrops  {
	local c : word `k' of $topcrop_area
	local cn : word `k' of $topcropname_area
	local cn_full : word `k' of $topcropname_area_full
	use "${Nigeria_GHS_W3_raw_data}/sect11f_plantingw3.dta", clear
	merge 1:1 hhid plotid cropcode cropid using "${Nigeria_GHS_W3_raw_data}/secta3i_harvestw3.dta"
	ren plotid plot_id
	*heaps
	gen conversion = 0.00012 if zone==1 & (s11fq1b==1 | s11fq4b==1)
	replace conversion = 0.00016 if zone==2 & (s11fq1b==1 | s11fq4b==1)
	replace conversion = 0.00011 if zone==3 & (s11fq1b==1 | s11fq4b==1)
	replace conversion = 0.00019 if zone==4 & (s11fq1b==1 | s11fq4b==1)
	replace conversion = 0.00021 if zone==5 & (s11fq1b==1 | s11fq4b==1)
	replace conversion = 0.00012 if zone==6 & (s11fq1b==1 | s11fq4b==1)
	*Ridges
	replace conversion = 0.0027 if zone==1 & (s11fq1b==2 | s11fq4b==2)
	replace conversion = 0.004 if zone==2 & (s11fq1b==2 | s11fq4b==2)
	replace conversion = 0.00494 if zone==3 & (s11fq1b==2 | s11fq4b==2)
	replace conversion = 0.0023 if zone==4 & (s11fq1b==2 | s11fq4b==2)
	replace conversion = 0.0023 if zone==5 & (s11fq1b==2 | s11fq4b==2)
	replace conversion = 0.0001 if zone==6 & (s11fq1b==2 | s11fq4b==2)
	*Stands
	replace conversion = 0.00006 if zone==1 & (s11fq1b==3 | s11fq4b==3)
	replace conversion = 0.00016 if zone==2 & (s11fq1b==3 | s11fq4b==3)
	replace conversion = 0.00004 if zone==3 & (s11fq1b==3 | s11fq4b==3)
	replace conversion = 0.00004 if zone==4 & (s11fq1b==3 | s11fq4b==3)
	replace conversion = 0.00013 if zone==5 & (s11fq1b==3 | s11fq4b==3)
	replace conversion = 0.00041 if zone==6 & (s11fq1b==3 | s11fq4b==3)
	*Plots
	replace conversion = 0.0667 if (s11fq1b==4 | s11fq4b==4)
	*Acres
	replace conversion = 0.404686 if (s11fq1b==5 | s11fq4b==5)
	*Hectares
	replace conversion = 1 if (s11fq1b==6 | s11fq4b==6)
	*Square meters
	replace conversion = 0.0001 if (s11fq1b==7 | s11fq4b==7)
	gen ha_planted = s11fq1a*conversion
	replace ha_planted = s11fq4a*conversion if ha_planted==.
	*renaming unit code for merge
	ren cropcode crop_code
	ren sa3iq6ii unit_cd
	ren sa3iq6i quantity_harvested
	//we recoded plantains to bananas in the yield section - doing the same here
	recode crop_code (2170=2030)
	*merging in conversion factors
	merge m:1 crop_code unit_cd zone using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_ng3_cf.dta", gen(cf_merge)
	gen quant_harv_kg= quantity_harvested*conv_fact
	bys unit_cd zone state: egen state_conv_unit = median(conv_fact)
	bys unit_cd zone: egen zone_conv_unit = median(conv_fact)
	bys unit_cd: egen national_conv = median(conv_fact)
	replace conv_fact = state_conv_unit if conv_fact==. & unit_cd!=900
	replace conv_fact = zone_conv_unit if conv_fact==. & unit_cd!=900
	replace conv_fact = national_conv if conv_fact==. & unit_cd!=900
	replace quant_harv_kg= quantity_harvested*conv_fact
	replace quant_harv_kg= quantity_harvested if unit_cd==1
	replace quant_harv_kg= quantity_harvested/1000 if unit_cd==2
	gen kgs_harv_mono_`cn' = quantity_harvested if crop_code==`c'
	ren crop_code cropcode
	xi i.cropcode, noomit
	collapse (sum) kgs_harv_mono_`cn' (max) _Icropcode_*, by(hhid plot_id ha_planted)
	egen crop_count = rowtotal(_Icropcode_*)
	keep if crop_count==1 & _Icropcode_`c'==1
	duplicates report hhid plot_id
	collapse (sum)kgs_harv_mono_`cn' ha_planted (max) _Icropcode_*, by(hhid plot_id)
	gen `cn'_monocrop_ha = ha_planted
	drop if `cn'_monocrop_ha==0
	gen `cn'_monocrop=1
	la var `cn'_monocrop "HH grows `cn_full' on a monocropped plot"
	save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`cn'_monocrop.dta", replace
}

forvalues k=1(1)$nb_topcrops  {
	local c : word `k' of $topcrop_area
	local cn : word `k' of $topcropname_area
	use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`cn'_monocrop.dta", clear
	merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", keep(3)
	foreach i in `cn'_monocrop_ha kgs_harv_mono_`cn' {
		gen `i'_male = `i' if dm_gender==1
		gen `i'_female = `i' if dm_gender==2
		gen `i'_mixed = `i' if dm_gender==3
		replace `i'_male = . if dm_gender!=1
		replace `i'_female = . if dm_gender!=2
		replace `i'_mixed = . if dm_gender!=3
	}
	gen `cn'_monocrop_male = 0
	replace `cn'_monocrop_male=1 if dm_gender==1
	gen `cn'_monocrop_female = 0
	replace `cn'_monocrop_female=1 if dm_gender==2
	gen `cn'_monocrop_mixed = 0
	replace `cn'_monocrop_mixed=1 if dm_gender==3
	collapse (sum) `cn'_monocrop_ha* kgs_harv_mono_`cn'* (max) `cn'_monocrop_male `cn'_monocrop_female `cn'_monocrop_mixed `cn'_monocrop = _Icropcode_`c', by(hhid)
	foreach g in male female mixed {
		la var `cn'_monocrop_`g' "HH grows `cn_full' on a `cn' monocropped `g' managed plot"
	}
	foreach i in male female mixed {
		replace `cn'_monocrop_ha = . if `cn'_monocrop!=1
		replace `cn'_monocrop_ha_`i' =. if  `cn'_monocrop!=1
		replace `cn'_monocrop_ha_`i' =. if `cn'_monocrop_`i'==0
		replace `cn'_monocrop_ha_`i' =. if `cn'_monocrop_ha_`i'==0
		replace kgs_harv_mono_`cn' = . if `cn'_monocrop!=1
		replace kgs_harv_mono_`cn'_`i' =. if  `cn'_monocrop!=1
		replace kgs_harv_mono_`cn'_`i' =. if `cn'_monocrop_`i'==0
		replace kgs_harv_mono_`cn'_`i' =. if `cn'_monocrop_ha_`i'==0
	}
	la var `cn'_monocrop_ha "Total `cn' monocrop hectares - Household"
	la var `cn'_monocrop "Household has at least one `cn' monocrop"
	la var kgs_harv_mono_`cn' "Total kilograms of `cn' harvested - Household"
	foreach g in male female mixed {
		la var `cn'_monocrop_ha_`g' "Total `cn' monocrop hectares on `g' managed plots - Household"
		la var kgs_harv_mono_`cn'_`g' "Total kilograms of `cn' harvested on `g' managed plots - Household"
	}
	save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`cn'_monocrop_hh_area.dta", replace
}

*TLU (Tropical Livestock Units)
use "${Nigeria_GHS_W3_raw_data}/sect11i_plantingw3.dta", clear
gen tlu=0.5 if (animal_cd==101|animal_cd==102|animal_cd==103|animal_cd==104|animal_cd==105|animal_cd==106|animal_cd==107|animal_cd==109)
replace tlu=0.3 if (animal_cd==108)
replace tlu=0.1 if (animal_cd==110|animal_cd==111)
replace tlu=0.2 if (animal_cd==112)
replace tlu=0.01 if (animal_cd==113|animal_cd==114|animal_cd==115|animal_cd==116|animal_cd==117|animal_cd==118|animal_cd==119|animal_cd==120|animal_cd==121)
replace tlu=0.7 if (animal_cd==122)
lab var tlu "Tropical Livestock Unit coefficient"
ren tlu tlu_coefficient
*Owned
ren animal_cd lvstckid
gen cattle=inrange(lvstckid,101,107)
gen smallrum=inlist(lvstckid,110,  111, 119,  120)
gen poultry=inrange(lvstckid,113,118)
gen other_ls=inlist(lvstckid,108,109, 121, 122, 123)
gen cows=inrange(lvstckid,105,105)
gen chickens=inrange(lvstckid,113,116)
ren s11iq6 nb_ls_stardseas
gen nb_cattle_stardseas=nb_ls_stardseas if cattle==1
gen nb_smallrum_stardseas=nb_ls_stardseas if smallrum==1
gen nb_poultry_stardseas=nb_ls_stardseas if poultry==1
gen nb_other_ls_stardseas=nb_ls_stardseas if other_ls==1
gen nb_cows_stardseas=nb_ls_stardseas if cows==1
gen nb_chickens_stardseas=nb_ls_stardseas if chickens==1
gen nb_ls_today =s11iq2
gen nb_cattle_today=nb_ls_today if cattle==1
gen nb_smallrum_today=nb_ls_today if smallrum==1
gen nb_poultry_today=nb_ls_today if poultry==1
gen nb_other_ls_today=nb_ls_today if other_ls==1
gen nb_cows_today=nb_ls_today if cows==1
gen nb_chickens_today=nb_ls_today if chickens==1
gen tlu_stardseas = nb_ls_stardseas * tlu_coefficient
gen tlu_today = nb_ls_today * tlu_coefficient
ren s11iq16 nb_ls_sold
ren s11iq17 income_ls_sales
recode   tlu_* nb_* (.=0)
collapse (sum) tlu_* nb_*  , by (hhid)
lab var nb_cattle_stardseas "Number of cattle owned at the begining of ag season"
lab var nb_smallrum_stardseas "Number of small ruminant owned at the begining of ag season"
lab var nb_poultry_stardseas "Number of cattle poultry at the begining of ag season"
lab var nb_other_ls_stardseas "Number of other livestock (dog, donkey, and other) owned at the begining of ag season"
lab var nb_cows_stardseas "Number of cows owned at the begining of ag season"
lab var nb_chickens_stardseas "Number of chickens owned at the begining of ag season"
lab var nb_cattle_today "Number of cattle owned as of the time of survey"
lab var nb_smallrum_today "Number of small ruminant owned as of the time of survey"
lab var nb_poultry_today "Number of cattle poultry as of the time of survey"
lab var nb_other_ls_today "Number of other livestock (dog, donkey, and other) owned as of the time of survey"
lab var nb_cows_today "Number of cows owned as of the time of survey"
lab var nb_chickens_today "Number of chickens owned as of the time of survey"
lab var tlu_stardseas "Tropical Livestock Units at the begining of ag season"
lab var tlu_today "Tropical Livestock Units as of the time of survey"
lab var nb_ls_stardseas  "Number of livestock owned at the begining of ag season"
lab var nb_ls_stardseas  "Number of livestock owned at the begining of ag season"
lab var nb_ls_today "Number of livestock owned as of today"
lab var nb_ls_sold "Number of total livestock sold alive this ag season"
drop tlu_coefficient
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_TLU_Coefficients.dta", replace

********************************************************************************
* GROSS CROP REVENUE *
********************************************************************************
**Creating median crop prices at different geographic levels to use for imputation**
*median prices at state level
use "${Nigeria_GHS_W3_raw_data}/secta3i_harvestw3.dta", clear
ren cropname crop_name
ren cropcode crop_code
ren sa3iq3 harvest_yesno
keep if harvest_yesno==1
ren sa3iq6i quantity_harvested
ren sa3iq6ii quantity_harvested_unit
ren sa3iq6ii_os quantity_harvested_unit_other
ren sa3iq6a value_harvested
collapse (sum) value_harvested quantity_harvested, by (hhid crop_code quantity_harvested_unit)
gen price_per_unit = value_harvested / quantity_harvested /* Has to be at unit-level because units for a single crop can vary across plots within a household */
recode price_per_unit (0=.)
gen observation=1
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_weights.dta"
collapse (median) price_per_unit (count) observation [aw = weight], by (crop_code quantity_harvested_unit zone state)
ren observation obs_state
ren price_per_unit price_per_unit_median_state
lab var price_per_unit_median_state "Median price for this crop-unit combination in the state"
ren quantity_harvested_unit unit
save  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_state.dta", replace

*median prices at zone level
use "${Nigeria_GHS_W3_raw_data}/secta3i_harvestw3.dta", clear
ren cropname crop_name
ren cropcode crop_code
ren sa3iq3 harvest_yesno
keep if harvest_yesno==1
ren sa3iq6i quantity_harvested
ren sa3iq6ii quantity_harvested_unit
ren sa3iq6ii_os quantity_harvested_unit_other
ren sa3iq6a value_harvested
collapse (sum) value_harvested quantity_harvested, by (hhid crop_code quantity_harvested_unit)
gen price_per_unit = value_harvested / quantity_harvested /* Has to be at unit-level because units for a single crop can vary across plots within a household */
recode price_per_unit (0=.)
gen observation=1
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_weights.dta"
collapse (median) price_per_unit (count) observation [aw = weight], by (crop_code quantity_harvested_unit zone)
ren observation obs_zone
ren price_per_unit price_per_unit_median_zone
lab var price_per_unit_median_zone "Median price for this crop-unit combination in the zone"
ren quantity_harvested_unit unit
save  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_zone.dta", replace

*median prices at country level
use "${Nigeria_GHS_W3_raw_data}/secta3i_harvestw3.dta", clear
ren cropname crop_name
ren cropcode crop_code
ren sa3iq3 harvest_yesno
keep if harvest_yesno==1
ren sa3iq6i quantity_harvested
ren sa3iq6ii quantity_harvested_unit
ren sa3iq6ii_os quantity_harvested_unit_other
ren sa3iq6a value_harvested
collapse (sum) value_harvested quantity_harvested, by (hhid crop_code quantity_harvested_unit)
gen price_per_unit = value_harvested / quantity_harvested /* Has to be at unit-level because units for a single crop can vary across plots within a household */
recode price_per_unit (0=.)
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_weights.dta"
collapse (median) price_per_unit [aw = weight], by (crop_code quantity_harvested_unit)
ren price_per_unit price_per_unit_median
lab var price_per_unit_median "Median price for this crop-unit combination in the country"
ren quantity_harvested_unit unit
save  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_country.dta", replace

*Generating Value of crop sales
use "${Nigeria_GHS_W3_raw_data}/secta3ii_harvestw3.dta", clear
ren cropcode crop_code
ren sa3iiq6 sales_value
recode sales_value (.=0)
collapse (sum) sales_value, by (hhid crop_code)
lab var sales_value "Value of sales of this crop"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_cropsales_value.dta", replace

use "${Nigeria_GHS_W3_raw_data}/secta3i_harvestw3.dta", clear
ren cropname crop_name
ren cropcode crop_code
ren sa3iq3 harvest_yesno
ren sa3iq6i quantity_harvested
ren sa3iq6ii quantity_harvested_unit
ren sa3iq6ii_os quantity_harvested_unit_other
ren sa3iq6a value_harvested
replace value_harvested = 0 if harvest_yesno==2
replace value_harvested = 0 if value_harvested==. & quantity_harvested == 0
ren sa3iq6b finished_harvest
ren sa3iq6d1 quantity_to_harvest
ren sa3iq6d2 quantity_to_harvest_unit
ren sa3iq6d2_os quantity_to_harvest_unit_other
gen price_per_unit = value_harvested / quantity_harvested
gen same_unit = 1 if quantity_harvested_unit == quantity_to_harvest_unit
replace same_unit = 0 if quantity_harvested_unit != quantity_to_harvest_unit & finished_harvest==2
tab same_unit if finished_harvest==2
lab var same_unit "Units for harevst (completed and future) are the same"
gen value_still_to_harvest = quantity_to_harvest * price_per_unit if same_unit==1
replace value_still_to_harvest = 0 if finished_harvest==1 |  harvest_yesno==2
gen unit = quantity_to_harvest_unit
merge m:1 zone state crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_state.dta", nogen keep(1 3)
merge m:1 zone crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_zone.dta", nogen keep(1 3)
merge m:1 crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_country.dta", nogen keep(1 3)
replace value_still_to_harvest = quantity_to_harvest * price_per_unit_median_state if same_unit==0 & obs_state>=10
replace value_still_to_harvest = quantity_to_harvest * price_per_unit_median_zone if same_unit==0 & obs_zone>=10 & value_still_to_harvest==.
replace value_still_to_harvest = quantity_to_harvest * price_per_unit_median if same_unit==0 & value_still_to_harvest==.
replace value_still_to_harvest = 0 if finished_harvest==2 & value_still_to_harvest==. & same_unit!=. & quantity_to_harvest!=.
replace value_still_to_harvest = 0 if finished_harvest==2 & quantity_to_harvest==.
drop unit
gen unit = quantity_harvested_unit
merge m:1 zone state crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_state.dta", nogen keep(1 3)
merge m:1 zone crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_zone.dta", nogen keep(1 3)
merge m:1 crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_country.dta", nogen keep(1 3)
replace value_harvested = quantity_harvested * price_per_unit_median if harvest_yesno==1 & value_harvested==.
replace value_harvested = 0 if harvest_yesno==1 & value_harvested==.
replace value_still_to_harvest=0 if hhid==290128 & value_still_to_harvest==. /* typo */
gen value_harvest = value_harvested + value_still_to_harvest
lab var value_harvest "Value of crop harvest, already harvested and what is expected"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_values_tempfile.dta", replace

collapse (sum) value_harvest , by (hhid crop_code)
merge 1:1 hhid crop_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_cropsales_value.dta"
replace value_harvest = sales_value if sales_value>value_harvest & sales_value!=. /* In a few cases, sales value reported exceeds the estimated value of crop harvest */
ren sales_value value_crop_sales
recode  value_harvest value_crop_sales  (.=0)
collapse (sum) value_harvest value_crop_sales  , by (hhid crop_code)
ren value_harvest value_crop_production
lab var value_crop_production "Gross value of crop production, summed over main and short season"
lab var value_crop_sales "Value of crops sold so far, summed over main and short season"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_values_production.dta", replace

collapse (sum) value_crop_production value_crop_sales, by (hhid)
lab var value_crop_production "Gross value of crop production for this household"
lab var value_crop_sales "Value of crops sold so far"
gen proportion_cropvalue_sold = value_crop_sales / value_crop_production
lab var proportion_cropvalue_sold "Proportion of crop value produced that has been sold"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_production.dta", replace

*Generating value of crop production at plot level
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_values_tempfile.dta", clear
ren plotid plot_id
collapse (sum) value_harvest, by (hhid plot_id)
ren value_harvest plot_value_harvest
lab var plot_value_harvest "Value of crop harvest on this plot"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_cropvalue.dta", replace

*Crops lost post-harvest
use "${Nigeria_GHS_W3_raw_data}/secta3ii_harvestw3.dta", clear
ren cropname crop_name
ren cropcode crop_code
ren sa3iiq18c share_lost
merge m:1 hhid crop_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_values_production.dta", nogen keep(1 3)
recode share_lost (.=0)
gen crop_value_lost = value_crop_production * (share_lost/100)
collapse (sum) crop_value_lost, by (hhid)
lab var crop_value_lost "Value of crops lost between harvest and survey time"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_losses.dta", replace


********************************************************************************
* CROP EXPENSES *
********************************************************************************
use  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_values_tempfile.dta", clear
keep hhid crop_code quantity_harvested_unit price_per_unit
ren quantity_harvested_unit unit
collapse (mean) price_per_unit, by (hhid crop_code unit)
ren price_per_unit hh_price_mean
lab var hh_price_mean "Average price reported for this crop-unit in the household"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_prices_for_wages.dta", replace

*Expenses: Hired labor
use "${Nigeria_GHS_W3_raw_data}/sect11c1_plantingw3.dta", clear
ren s11c1q2 number_men
ren s11c1q3 number_days_men
ren s11c1q4 wage_perday_men
ren s11c1q5 number_women
ren s11c1q6 number_days_women
ren s11c1q7 wage_perday_women
ren s11c1q8 number_children
ren s11c1q9 number_days_children
ren s11c1q10 wage_perday_children
gen wages_paid_men = number_days_men * wage_perday_men
gen wages_paid_women = number_days_women * wage_perday_women
gen wages_paid_children = number_days_children * wage_perday_children
recode wages_paid_men wages_paid_women wages_paid_children (.=0)
gen wages_paid_aglabor_postplant =  wages_paid_men + wages_paid_women + wages_paid_children


*monocropped plots
foreach cn in $topcropname_area{
preserve
	ren wages_paid_aglabor_postplant wages_paid_postp
	ren plotid plot_id
	merge m:1 hhid plot_id using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers"
	foreach i in wages_paid_postp{
		gen wages_paid_pp_`cn' = `i'
		gen wages_paid_pp_`cn'_male = `i' if dm_gender==1
		gen wages_paid_pp_`cn'_female = `i' if dm_gender==2
		gen wages_paid_pp_`cn'_mixed = `i' if dm_gender==3
	}
	*Merge in monocropped plots
	merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`cn'_monocrop.dta", nogen /*assert(1 3)*/ keep(3)
	collapse (sum) wages_paid_pp_`cn'*, by(hhid)
	lab var wages_paid_pp_`cn' "Wages paid for hired labor postplanting - Monocropped `cn' plots only"
	foreach g in male female mixed {
		la var wages_paid_pp_`cn'_`g' "Wages paid for hired labor postplanting - Monocropped `cn' `g' plots only"
	}
	save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_wages_postplanting_`cn'.dta", replace
restore
}
collapse (sum) wages_paid_aglabor_postplant, by (hhid)
lab var wages_paid_aglabor_postplant "Wages paid for hired labor (crops), as captured in post-planting survey"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_wages_postplanting.dta", replace

use "${Nigeria_GHS_W3_raw_data}/secta2_harvestw3.dta", clear
*Harvest
ren sa2q2 number_men
ren sa2q3 number_days_men
ren sa2q4 wage_perday_men
ren sa2q5 number_women
ren sa2q6 number_days_women
ren sa2q7 wage_perday_women
ren sa2q8 number_children
ren sa2q9 number_days_children
ren sa2q10 wage_perday_children
*Before harvest
ren sa2q1c number_men2  		// Adding to capture hired labor used between planting and harvesting
ren sa2q1d number_days_men2
ren sa2q1e wage_perday_men2
ren sa2q1f number_women2
ren sa2q1g number_days_women2
ren sa2q1h wage_perday_women2
ren sa2q1i number_children2
ren sa2q1j number_days_children2
ren sa2q1k wage_perday_children2
recode number_days_men wage_perday_men number_days_men2 wage_perday_men2 number_days_women wage_perday_women number_days_women2 wage_perday_women2 /*
*/ number_days_children wage_perday_children number_days_children2 wage_perday_children2 (.=0)
gen wages_paid_men = (number_days_men * wage_perday_men) + (number_days_men2 * wage_perday_men2)
gen wages_paid_women = (number_days_women * wage_perday_women) + (number_days_women2 * wage_perday_women2)
gen wages_paid_children = (number_days_children * wage_perday_children) + (number_days_children2 * wage_perday_children2)
recode wages_paid_men wages_paid_women wages_paid_children (.=0)
gen wages_paid_aglabor_postharvest =  wages_paid_men + wages_paid_women + wages_paid_children
*Value wages paid in the form of harvest at either the household crop-unit value OR the median crop-unit value in the country.
ren sa2q1m_a crop_code
ren sa2q1m_b quantity
ren sa2q1m_c unit
merge m:1 hhid crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_prices_for_wages.dta", nogen keep (1 3)
merge m:1 crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_country.dta", nogen keep (1 3)
gen inkind_payment = quantity * hh_price_mean
replace inkind_payment = quantity * price_per_unit_median if quantity!=. & inkind_payment==.
lab var inkind_payment "Wages paid out from the harvest, for work between planting and harvest"
drop crop_code quantity unit price hh_price_mean price_per_unit_median
ren sa2q11a crop_code
ren sa2q11b quantity
ren sa2q11c unit
merge m:1 hhid crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_prices_for_wages.dta", nogen keep (1 3)
merge m:1 crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_country.dta", nogen keep (1 3)
gen inkind_payment2 = quantity * hh_price_mean
replace inkind_payment2 = quantity * price_per_unit_median if quantity!=. & inkind_payment==.
lab var inkind_payment2 "Wages paid out from the harvest, for harvest/threshing labor"
recode inkind_payment inkind_payment2 (.=0)
replace wages_paid_aglabor_postharvest = wages_paid_aglabor_postharvest + inkind_payment + inkind_payment2

*monocropped plots
foreach cn in $topcropname_area{
	preserve
	ren wages_paid_aglabor_postharvest wages_paid_postharv
	ren plotid plot_id
	merge m:1 hhid plot_id using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers"
	foreach i in wages_paid_postharv{
		gen wages_paid_ph_`cn' = `i'
		gen wages_paid_ph_`cn'_male = `i' if dm_gender==1
		gen wages_paid_ph_`cn'_female = `i' if dm_gender==2
		gen wages_paid_ph_`cn'_mixed = `i' if dm_gender==3
	}
	*Merge in monocropped plots
	merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`cn'_monocrop.dta", nogen /*assert(1 3)*/ keep(3)
	collapse (sum) wages_paid_ph_`cn'*, by(hhid)
	lab var wages_paid_ph_`cn' "Wages paid for hired labor postharvest - Monocropped `cn' plots only"
	foreach g in male female mixed {
		lab var wages_paid_ph_`cn'_`g' "Wages paid for hired labor postharvest - Monocropped `cn' `g' plots only"
	}
	save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_wages_postharvest_`cn'.dta", replace
	restore
}

collapse (sum) wages_paid_aglabor_postharvest, by (hhid)
lab var wages_paid_aglabor_postharvest "Wages paid for hired labor (crops), as captured in post-harvest survey"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_wages_postharvest.dta", replace

*Expenses: Inputs
use "${Nigeria_GHS_W3_raw_data}/secta11d_harvestw3.dta", clear
ren s11dq5d expenditure_subsidized_fert
ren s11dq19 value_fertilizer_1
ren s11dq29 value_fertilizer_2
ren s11dq10 cost_transport_free_fert
ren s11dq17 cost_transport_fertilizer_1
ren s11dq31 cost_transport_fertilizer_2
recode expenditure_subsidized_fert value_fertilizer_1 value_fertilizer_2 cost_transport_free_fert cost_transport_fertilizer_1 cost_transport_fertilizer_2 (.=0)
gen value_fertilizer = value_fertilizer_1 + value_fertilizer_2
gen cost_transport_fertilizer = cost_transport_fertilizer_1 + cost_transport_fertilizer_2


*monocropped plots
foreach cn in $topcropname_area{
	preserve
	ren plotid plot_id
	ren cost_transport_fertilizer cost_trans_fert
	merge m:1 hhid plot_id using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers"
	foreach i in value_fertilizer cost_trans_fert {
		gen `i'_`cn' = `i'
		gen `i'_`cn'_male = `i' if dm_gender==1
		gen `i'_`cn'_female = `i' if dm_gender==2
		gen `i'_`cn'_mixed = `i' if dm_gender==3
	}
	*Merge in monocropped plots
	merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`cn'_monocrop.dta", nogen /*assert(1 3)*/ keep(3)
	collapse (sum) value_fertilizer_`cn'* cost_trans_fert_`cn'*, by(hhid)
	lab var value_fertilizer_`cn' "Value of fertilizer purchased (not necessarily the same as used) - Monocropped `cn' plots only"
	lab var cost_trans_fert_`cn' "Value of tranportation for fertilizer purchased - Monocropped `cn' plots only"
	foreach g in male female mixed {
		lab var value_fertilizer_`cn'_`g' "Value of fertilizer purchased - Monocropped `cn' `g' plots only"
		lab var cost_trans_fert_`cn'_`g' "Value of transportation for fertilizer purchased - Monocropped `cn' `g' plots only"
	}
	save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fertilizer_costs_`cn'.dta", replace
	restore
}

collapse (sum) expenditure_subsidized_fert value_fertilizer cost_transport_fertilizer cost_transport_free_fert, by (hhid)
lab var value_fertilizer "Value of fertilizer purchased (not necessarily the same as used)"
lab var expenditure_subsidized_fert "Expenditure on subsidized fertilizer"
lab var cost_transport_free_fert "Cost of transportation associated with free fertilizer"
lab var cost_transport_fertilizer "Cost of transportation associated with purchased fertilizer"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fertilizer_costs.dta", replace

*Other chemicals
use "${Nigeria_GHS_W3_raw_data}/secta11c2_harvestw3.dta", clear
recode s11c2q13a s11c2q13b s11c2q14a s11c2q14b (.=0)
gen value_herbicide_1 = s11c2q13a + s11c2q14a
gen value_herbicide_2 = s11c2q13b + s11c2q14b
recode s11c2q4a s11c2q4b s11c2q5a s11c2q5b (.=0)
gen value_pesticide_1 = s11c2q4a + s11c2q5a
gen value_pesticide_2 = s11c2q4b + s11c2q5b
gen value_herbicide = value_herbicide_1 + value_herbicide_2
gen value_pesticide = value_pesticide_1 + value_pesticide_2

*monocropped plots
foreach cn in $topcropname_area{
	preserve
	ren plotid plot_id
	*Merge in monocropped plots
	merge m:1 hhid plot_id using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers"
	merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`cn'_monocrop.dta", nogen /*assert(1 3)*/ keep(3)
	foreach i in value_herbicide value_pesticide {
		gen `i'_`cn' = `i'
		gen `i'_`cn'_male = `i' if dm_gender==1
		gen `i'_`cn'_female = `i' if dm_gender==2
		gen `i'_`cn'_mixed = `i' if dm_gender==3
	}
	collapse (sum) value_herbicide_`cn'* value_pesticide_`cn'*, by(hhid)
	lab var value_herbicide_`cn' "Value of herbicide purchased (not necessarily the same as used)) - Monocropped `cn' plots only"
	lab var value_pesticide_`cn' "Value of pesticide purchased (not necessarily the same as used)) - Monocropped `cn' plots only"
	foreach g in male female mixed {
		lab var value_herbicide_`cn'_`g' "Value of herbicide purchased - Monocropped `cn' `g' plots only"
		lab var value_pesticide_`cn'_`g' "Value of pesticide purchased - Monocropped `cn' `g' plots only"
	}
	save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_chemical_costs_`cn'.dta", replace
	restore
}

collapse (sum) value_herbicide value_pesticide, by (hhid)
lab var value_herbicide "Value of herbicide purchased (not necessarily the same as used)"
lab var value_pesticide "Value of pesticide purchased (not necessarily the same as used)"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_chemical_costs.dta", replace

*Manure
use "${Nigeria_GHS_W3_raw_data}/secta11d_harvestw3.dta", clear
ren s11dq39 value_manure_purchased
ren s11dq41 cost_transport_manure
recode value_manure_purchased cost_transport_manure (.=0)

*costs for monocropped plots
foreach cn in $topcropname_area{
	preserve
	ren value_manure_purchased value_manure_purch
	ren cost_transport_manure cost_trans_manure
	ren plotid plot_id
	*Merge in monocropped plots
	merge m:1 hhid plot_id using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers"
	merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`cn'_monocrop.dta", nogen /*assert(1 3)*/ keep(3)
	foreach i in value_manure_purch cost_trans_manure {
		gen `i'_`cn' = `i'
		gen `i'_`cn'_male = `i' if dm_gender==1
		gen `i'_`cn'_female = `i' if dm_gender==2
		gen `i'_`cn'_mixed = `i' if dm_gender==3
	}
	collapse (sum) value_manure_purch_`cn'* cost_trans_manure_`cn'*, by(hhid)
	lab var value_manure_purch_`cn' "Value of manure purchased (not what was used)- Monocropped `cn' plots only"
	lab var cost_trans_manure_`cn' "Cost transport for manure that was purchased - Monocropped `cn' plots only"
	foreach g in male female mixed {
		lab var value_manure_purch_`cn'_`g' "Value of manure purchased - Monocropped `cn' `g' plots only"
		lab var cost_trans_manure_`cn'_`g' "Cost of transport for manure that was purchased - Monocropped `cn' `g' plots only"
	}
	save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_manure_costs_`cn'.dta", replace
	restore
}
collapse (sum) value_manure_purchased cost_transport_manure, by (hhid)
lab var value_manure_purchased "Value of manure purchased (not what was used)"
lab var cost_transport_manure "Cost transport for manure that was purchased"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_manure_costs.dta", replace

*Seed
use "${Nigeria_GHS_W3_raw_data}/sect11e_plantingw3.dta", clear
ren s11eq21 cost_seed_1
ren s11eq33 cost_seed_2
ren s11eq19 cost_transportation_seed_1
ren s11eq31 cost_transportation_seed_2
recode cost_seed_1 cost_seed_2 cost_transportation_seed_1 cost_transportation_seed_2 (.=0)
gen cost_seed = cost_seed_1 + cost_seed_2
gen cost_transportation_seed = cost_transportation_seed_1 + cost_transportation_seed_2

*costs for monocropped plots
foreach cn in $topcropname_area{
	preserve
	ren plotid plot_id
	*Merge in monocropped plots
	merge m:1 hhid plot_id using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers"
	gen cost_seed_male=cost_seed if dm_gender==1
	gen cost_seed_female=cost_seed if dm_gender==2
	gen cost_seed_mixed=cost_seed if dm_gender==3
	merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`cn'_monocrop.dta", nogen /*assert(1 3)*/ keep(3)
	collapse (sum) cost_seed_`cn' = cost_seed cost_seed_`cn'_male = cost_seed_male cost_seed_`cn'_female = cost_seed_female cost_seed_`cn'_mixed = cost_seed_mixed, by(hhid)		// renaming all to "_`cn'" suffix
	lab var cost_seed_`cn' "Expenditures on seed for temporary crops - Monocropped `cn' plots only"
	lab var cost_seed_`cn'_male "Expenditures on seed for temporary crops - Monocropped `cn' male managed plots only"
	lab var cost_seed_`cn'_female "Expenditures on seed for temporary crops - Monocropped `cn' female managed plots only"
	lab var cost_seed_`cn'_mixed "Expenditures on seed for temporary crops - Monocropped `cn' mixed managed plots only"
	save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_seed_costs_`cn'.dta", replace
	restore
}
collapse (sum) cost_seed cost_transportation_seed, by (hhid)
lab var cost_seed "Cost of purchased seed"
lab var cost_transportation_seed "Cost of transportation associated with purchased seed"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_seed_costs.dta", replace

*Land rental
use "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3.dta", clear
gen rented_plot = (s11b1q4==2)
ren s11b1q13 rental_cost_cash
ren s11b1q14 rental_cost_inkind
recode rental_cost_cash rental_cost_inkind (.=0)
gen rental_cost_land = rental_cost_cash + rental_cost_inkind
*costs for monocropped plots
foreach cn in $topcropname_area{
	preserve
	ren plotid plot_id
	*Merge in monocropped plots
	merge m:1 hhid plot_id using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers"
	merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`cn'_monocrop.dta", nogen /*assert(1 3)*/ keep(3)
	gen rental_cost_land_`cn'=rental_cost_land
	gen rental_cost_land_`cn'_male=rental_cost_land if dm_gender==1
	gen rental_cost_land_`cn'_female=rental_cost_land if dm_gender==2
	gen rental_cost_land_`cn'_mixed=rental_cost_land if dm_gender==3
	collapse (sum) rental_cost_land_`cn'*, by(hhid)
	lab var rental_cost_land_`cn' "Rental costs paid for land - Monocropped `cn' plots only"
	lab var rental_cost_land_`cn'_male "Rental costs paid for land - Monocropped `cn' male managed plots only"
	lab var rental_cost_land_`cn'_female "Rental costs paid for land - Monocropped `cn' female managed plots only"
	lab var rental_cost_land_`cn'_mixed "Rental costs paid for land - Monocropped `cn' mixed managed plots only"
	save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_rental_costs_`cn'.dta", replace
	restore
}
collapse (sum) rental_cost_land, by (hhid)
lab var rental_cost_land "Rental costs paid for land"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_rental_costs.dta", replace

*Rental of agricultural tools, machines, animal traction
use "${Nigeria_GHS_W3_raw_data}/secta11c2_harvestw3.dta", clear
ren s11c2q21 days_oxen_rental
ren s11c2q23a animal_rent_quantity
ren s11c2q23b animal_rent_unit
ren s11c2q23c animal_rent_unit_other
ren s11c2q24a animal_rent_inkind_quantity
ren s11c2q24b animal_rent_inkind_unit
ren s11c2q25 animal_rent_feeding_costs
ren s11c2q32 rental_cost_ag_assets_cash
ren s11c2q33 rental_cost_ag_assets_inkind
gen animal_rent_paid = days_oxen_rental * animal_rent_quantity if animal_rent_unit ==2
replace animal_rent_paid = days_oxen_rental * (animal_rent_quantity/8) if animal_rent_unit ==1 /* Assume oxen have 8-hour workday */
replace animal_rent_paid = animal_rent_quantity if animal_rent_unit ==6
gen hectares_ploughed = animal_rent_quantity if animal_rent_unit==4
replace animal_rent_paid = days_oxen_rental * (animal_rent_quantity/8) if animal_rent_unit_other == "8 Days"
gen animal_rent_per_ha = (animal_rent_quantity/2.47105) if animal_rent_unit==4
replace animal_rent_per_ha = animal_rent_quantity if animal_rent_unit==5
ren plotid plot_id
merge 1:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta"
gen animal_rent_area = animal_rent_per_ha * field_size
recode animal_rent_paid animal_rent_feeding_costs rental_cost_ag_assets_cash rental_cost_ag_assets_inkind animal_rent_area (.=0)
replace animal_rent_paid = animal_rent_paid + animal_rent_feeding_costs + animal_rent_area
gen rental_cost_ag_assets = rental_cost_ag_assets_cash + rental_cost_ag_assets_inkind
collapse (sum) animal_rent_paid rental_cost_ag_assets, by (hhid)
lab var animal_rent_paid "Cost for renting animal traction"
lab var rental_cost_ag_assets "Cost for renting agricultural machine/equipment (including tractors)"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_asset_rental_costs.dta", replace


********************************************************************************
* LIVESTOCK INCOME *
********************************************************************************
*Expenses
use "${Nigeria_GHS_W3_raw_data}/sect11j_plantingw3.dta", clear
ren s11jq2a cost_cash
ren s11jq2b cost_inkind
recode cost_cash cost_inkind (.=0)
gen cost_hired_labor_livestock = (cost_cash + cost_inkind) if item_cd==1 | item_cd==4
gen cost_fodder_livestock = (cost_cash + cost_inkind) if item_cd==2
gen cost_vaccines_livestock = (cost_cash + cost_inkind) if item_cd==3 /* Includes treatment */
gen cost_other_livestock = (cost_cash + cost_inkind) if item_cd>=5 & item_cd<=9
recode cost_hired_labor_livestock cost_fodder_livestock cost_vaccines_livestock cost_other_livestock (.=0)
**cannot disaggregate costs by species
collapse (sum) cost_hired_labor_livestock cost_fodder_livestock cost_vaccines_livestock cost_other_livestock, by (hhid)
lab var cost_fodder_livestock "Cost for fodder for livestock"
lab var cost_vaccines_livestock "Cost for vaccines and veterminary treatment for livestock"
lab var cost_hired_labor_livestock "Cost for hired labor for livestock"
lab var cost_other_livestock "Cost for any other expenses for livestock"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_expenses.dta", replace

use "${Nigeria_GHS_W3_raw_data}/sect11k_plantingw3.dta", clear
ren prod_cd livestock_code
ren s11kq2 months_produced
ren s11kq3a quantity_produced
ren s11kq3b quantity_produced_unit
ren s11kq5a quantity_sold_season
ren s11kq5b quantity_sold_season_unit
ren s11kq6 earnings_sales
recode quantity_produced quantity_sold_season months_produced (.=0)
gen price_unit = earnings_sales / quantity_sold_season
recode price_unit (0=.)
bys livestock_code: count if quantity_sold_season !=0
keep hhid livestock_code months_produced quantity_produced quantity_produced_unit quantity_sold_season quantity_sold_season_unit earnings_sales price_unit
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_products.dta", replace

use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_products", clear
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_weights.dta"
drop if _merge==2
collapse (median) price_unit [aw=weight], by (livestock_code quantity_sold_season_unit)
ren price_unit price_unit_median_country
ren quantity_sold_season_unit unit
replace price_unit_median_country = 100 if livestock_code == 1 & unit==1
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_products_prices_country.dta", replace

use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_products", clear
replace quantity_produced_unit = 80 if livestock_code==2 & (quantity_produced_unit==70 | quantity_produced_unit==82 | quantity_produced_unit==90 | quantity_produced_unit==191 /*
*/ | quantity_produced_unit==141 | quantity_produced_unit==160 | quantity_produced_unit==3 | quantity_produced_unit==1)
replace quantity_produced_unit = 3 if livestock_code==1 & (quantity_produced_unit==1 | quantity_produced_unit==70 | quantity_produced_unit==81  | quantity_produced_unit==80 | quantity_produced_unit==191)
gen unit = quantity_produced_unit
merge m:1 livestock_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_products_prices_country.dta", nogen keep(1 3)
keep if quantity_produced!=0
gen value_produced = price_unit * quantity_produced * months_produced if quantity_produced_unit == quantity_sold_season_unit
replace value_produced = price_unit_median_country * quantity_produced * months_produced if value_produced==.
replace value_produced = earnings_sales if value_produced==.
lab var price_unit "Price per liter (milk) or per egg/liter/container honey or palm wine, imputed with local median prices if household did not sell"
gen value_milk_produced = quantity_produced * price_unit * months_produced if livestock_code==1
replace value_milk_produced = quantity_produced * price_unit_median_country * months_produced if livestock_code==1 & value_milk_produced==.
gen value_eggs_produced = quantity_produced * price_unit * months_produced if livestock_code==2
replace value_eggs_produced = quantity_produced * price_unit_median_country * months_produced if livestock_code==2 & value_eggs_produced==.
gen value_other_produced = quantity_produced * price_unit * months_produced if livestock_code!=1 & livestock_code!=2
*Share of total production sold
gen sales_livestock_products = earnings_sales
collapse (sum) value_milk_produced value_eggs_produced value_other_produced sales_livestock_products, by (hhid)
*Share of production sold
*First, constructing total value
egen value_livestock_products = rowtotal(value_milk_produced value_eggs_produced value_other_produced)
*Now, the share
gen share_livestock_prod_sold = sales_livestock_products/value_livestock_products
replace share_livestock_prod_sold = 1 if share_livestock_prod_sold>1 & share_livestock_prod_sold!=.
lab var share_livestock_prod_sold "Percent of production of livestock products that is sold"
lab var value_milk_produced "Value of milk produced"
lab var value_eggs_produced "Value of eggs produced"
lab var value_other_produced "Value of honey and skins produced"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_products.dta", replace

*Sales (live animals)
use "${Nigeria_GHS_W3_raw_data}/sect11i_plantingw3.dta", clear
ren animal_cd livestock_code
ren s11iq16 number_sold
ren s11iq17 income_live_sales
ren s11iq19a number_slaughtered_sold
ren s11iq19b number_slaughtered_consumption
ren s11iq11 value_livestock_purchases
recode number_sold income_live_sales number_slaughtered_sold number_slaughtered_consumption value_livestock_purchases (.=0)
gen number_slaughtered = number_slaughtered_sold + number_slaughtered_consumption
lab var number_slaughtered "Number slaughtered for sale and home consumption"
gen price_per_animal = income_live_sales / number_sold
recode price_per_animal (0=.)
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_weights.dta", nogen keep(1 3)
keep if price_per_animal !=. & price_per_animal!=0
keep hhid weight zone state lga ea livestock_code number_sold income_live_sales number_slaughtered number_slaughtered_sold price_per_animal value_livestock_purchases
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_sales", replace

*Implicit prices (based on observed sales)
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_sales", clear
gen observation = 1
bys zone state lga ea livestock_code: egen obs_ea = count(observation)
collapse (median) price_per_animal [aw=weight], by (zone state lga ea livestock_code obs_ea)
ren price_per_animal price_median_ea
lab var price_median_ea "Median price per unit for this livestock in the ea"
lab var obs_ea "Number of sales observations for this livestock in the ea"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_ea.dta", replace
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_sales", clear
gen observation = 1
bys zone state lga livestock_code: egen obs_lga = count(observation)
collapse (median) price_per_animal [aw=weight], by (zone state lga livestock_code obs_lga)
ren price_per_animal price_median_lga
lab var price_median_lga "Median price per unit for this livestock in the lga"
lab var obs_lga "Number of sales observations for this livestock in the lga"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_lga.dta", replace
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_sales", clear
gen observation = 1
bys zone state livestock_code: egen obs_state = count(observation)
collapse (median) price_per_animal [aw=weight], by (zone state livestock_code obs_state)
ren price_per_animal price_median_state
lab var price_median_state "Median price per unit for this livestock in the state"
lab var obs_state "Number of sales observations for this livestock in the state"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_state.dta", replace
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_sales", clear
gen observation = 1
bys zone livestock_code: egen obs_zone = count(observation)
collapse (median) price_per_animal [aw=weight], by (zone livestock_code obs_zone)
ren price_per_animal price_median_zone
lab var price_median_zone "Median price per unit for this livestock in the zone"
lab var obs_zone "Number of sales observations for this livestock in the zone"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_zone.dta", replace
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_sales", clear
gen observation = 1
bys livestock_code: egen obs_country = count(observation)
collapse (median) price_per_animal [aw=weight], by (livestock_code obs_country)
ren price_per_animal price_median_country
lab var price_median_country "Median price per unit for this livestock in the country"
lab var obs_country "Number of sales observations for this livestock in the country"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_country.dta", replace

use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_sales", clear
merge m:1 zone state lga ea livestock_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_ea.dta", nogen
merge m:1 zone state lga livestock_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_lga.dta", nogen
merge m:1 zone state livestock_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_state.dta", nogen
merge m:1 zone livestock_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_zone.dta", nogen
merge m:1 livestock_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_country.dta", nogen
replace price_per_animal = price_median_ea if price_per_animal==. & obs_ea >= 10
replace price_per_animal = price_median_lga if price_per_animal==. & obs_lga >= 10
replace price_per_animal = price_median_state if price_per_animal==. & obs_state >= 10
replace price_per_animal = price_median_zone if price_per_animal==. & obs_zone >= 10
replace price_per_animal = price_median_country if price_per_animal==.
lab var price_per_animal "Price per animal sold, imputed with local median prices if household did not sell"
gen value_lvstck_sold = price_per_animal * number_sold
gen value_slaughtered = price_per_animal * number_slaughtered
gen value_slaughtered_sold = price_per_animal * number_slaughtered_sold
gen value_livestock_sales = value_lvstck_sold + value_slaughtered_sold
collapse (sum) value_livestock_sales value_livestock_purchases value_lvstck_sold value_slaughtered, by (hhid)
lab var value_livestock_sales "Value of livestock sold (live and slaughtered)"
lab var value_livestock_purchases "Value of livestock purchases (seems to span only the agricutlural season, not the year)"
lab var value_slaughtered "Value of livestock slaughtered (with slaughtered livestock that weren't sold valued at local median prices for live animal sales)"
lab var value_lvstck_sold "Value of livestock sold live"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_sales.dta", replace


*TLU (Tropical Livestock Units)
use "${Nigeria_GHS_W3_raw_data}/sect11i_plantingw3.dta", clear
gen tlu=0.5 if (animal_cd==101|animal_cd==102|animal_cd==103|animal_cd==104|animal_cd==105|animal_cd==106|animal_cd==107|animal_cd==109)
replace tlu=0.3 if (animal_cd==108)
replace tlu=0.1 if (animal_cd==110|animal_cd==111)
replace tlu=0.2 if (animal_cd==112)
replace tlu=0.01 if (animal_cd==113|animal_cd==114|animal_cd==115|animal_cd==116|animal_cd==117|animal_cd==118|animal_cd==119|animal_cd==120|animal_cd==121)
replace tlu=0.7 if (animal_cd==122)
lab var tlu "Tropical Livestock Unit coefficient"
ren animal_cd livestock_code
ren tlu tlu_coefficient
ren s11iq2 number_today
ren s11iq3 price_per_animal_est /* Estimated by the respondent */
ren s11iq6 number_start_agseas
gen tlu_start_agseas = number_start_agseas * tlu_coefficient
gen tlu_today = number_today * tlu_coefficient
ren s11iq16 number_sold
ren s11iq17 income_live_sales
egen lost_disease = rowtotal (s11iq21b s11iq21d)

*Livestock mortality rate and percent of improved livestock breeds
egen mean_agseas = rowmean(number_today number_start_agseas)
egen animals_lost_agseas = rowtotal(s11iq21b s11iq21d)	// Only animals lost to disease; thefts and death by accidents not included
gen species = (inlist(livestock_code,101,102,103,104,105,106,107)) + 2*(inlist(livestock_code,110,111)) + 3*(livestock_code==112) + 4*(inlist(livestock_code,108,109,122)) + 5*(inlist(livestock_code,113,114,115,116,117,118,120))
recode species (0=.)
la def species 1 "Large ruminants (cows, buffalos)" 2 "Small ruminants (sheep, goats)" 3 "Pigs" 4 "Equine (horses, donkeys, camel)" 5 "Poultry"
la val species species
preserve
*Now to household level
*First, generating these values by species
collapse (sum) number_today number_start_agseas animals_lost_agseas lost_disease lvstck_holding=number_today, by(hhid species)
egen mean_agseas = rowmean(number_today number_start_agseas)
*A loop to create species variables
foreach i in animals_lost_agseas mean_agseas lvstck_holding lost_disease{
	gen `i'_lrum = `i' if species==1
	gen `i'_srum = `i' if species==2
	gen `i'_pigs = `i' if species==3
	gen `i'_equine = `i' if species==4
	gen `i'_poultry = `i' if species==5
}
*Now we can collapse to household (taking firstnm because these variables are only defined once per household)
collapse (sum) number_today  (firstnm) *lrum *srum *pigs *equine *poultry , by(hhid)
*Overall any improved herd
drop  number_today
*Generating missing variables in order to construct labels (just for the labeling loop below)
foreach i in lvstck_holding animals_lost_agseas mean_agseas lost_disease{
	gen `i' = .
}
la var lvstck_holding "Total number of livestock holdings (# of animals)"
lab var animals_lost_agseas  "Total number of livestock  lost to disease"
lab var  mean_agseas  "Average number of livestock  today and 1  year ago"
lab var lost_disease "Total number of livestock lost to disease"
*A loop to label these variables (taking the labels above to construct each of these for each species)
foreach i in lvstck_holding animals_lost_agseas mean_agseas lost_disease{
	local l`i' : var lab `i'
	lab var `i'_lrum "`l`i'' - large ruminants"
	lab var `i'_srum "`l`i'' - small ruminants"
	lab var `i'_pigs "`l`i'' - pigs"
	lab var `i'_equine "`l`i'' - equine"
	lab var `i'_poultry "`l`i'' - poultry"
}
*Now dropping these missing variables, used to construct the labels above
gen lvstck_holding_all = lvstck_holding_lrum + lvstck_holding_srum + lvstck_holding_poultry
la var lvstck_holding_all "Total number of livestock holdings (# of animals) - large ruminants, small ruminants, poultry"
drop lvstck_holding animals_lost_agseas mean_agseas lost_disease
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_herd_characteristics", replace
restore
gen price_per_animal = income_live_sales / number_sold
recode price_per_animal (0=.)
merge m:1 zone state lga ea livestock_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_ea.dta", nogen
merge m:1 zone state lga livestock_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_lga.dta", nogen
merge m:1 zone state livestock_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_state.dta", nogen
merge m:1 zone livestock_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_zone.dta", nogen
merge m:1 livestock_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_prices_country.dta", nogen
replace price_per_animal = price_median_ea if price_per_animal==. & obs_ea >= 10
replace price_per_animal = price_median_lga if price_per_animal==. & obs_lga >= 10
replace price_per_animal = price_median_state if price_per_animal==. & obs_state >= 10
replace price_per_animal = price_median_zone if price_per_animal==. & obs_zone >= 10
replace price_per_animal = price_median_country if price_per_animal==.
lab var price_per_animal "Price per animal sold, imputed with local median prices if household did not sell"
gen value_start_agseas = number_start_agseas * price_per_animal
gen value_today = number_today * price_per_animal
gen value_today_est = number_today * price_per_animal_est
collapse (sum) tlu_start_agseas tlu_today value_start_agseas value_today value_today_est, by (hhid)
lab var tlu_start_agseas "Tropical Livestock Units as of the start of the agricultural season"
lab var tlu_today "Tropical Livestock Units as of the time of survey"
gen lvstck_holding_tlu = tlu_today
lab var lvstck_holding_tlu "Total HH livestock holdings, TLU"
lab var value_start_agseas "Value of livestock holdings from one year ago"
lab var value_today "Value of livestock holdings today"
lab var value_today_est "Value of livestock holdings today, per estimates (not observed sales)"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_TLU.dta", replace


********************************************************************************
* FISH INCOME *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/secta9a2_harvestw3.dta", clear
ren fish_cd fish_code
ren sa9aq5b unit
ren sa9aq6 price_per_unit
recode price_per_unit (0=.)
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_weights.dta"
drop if _merge==2
collapse (median) price_per_unit [aw=weight], by (fish_code unit)
ren price_per_unit price_per_unit_median
replace price_per_unit_median = . if fish_code==5 /* "Other */
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fish_prices_1.dta", replace /* Caught fish */

use "${Nigeria_GHS_W3_raw_data}/secta9a2_harvestw3.dta", clear
ren fish_cd fish_code
ren sa9aq7b unit
ren sa9aq8 price_per_unit
recode price_per_unit (0=.)
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_weights.dta"
drop if _merge==2
collapse (median) price_per_unit [aw=weight], by (fish_code unit)
ren price_per_unit price_per_unit_median
replace price_per_unit_median = . if fish_code==5 /* "Other */
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fish_prices_2.dta", replace /* Harvested fish */

use "${Nigeria_GHS_W3_raw_data}/secta9a2_harvestw3.dta", clear
keep if sa9aq2==1
ren fish_cd fish_code
ren sa9aq3 weeks_fishing
ren sa9aq4a1 quantity_caught /* on average per week */
ren sa9aq4a2 quantity_caught_unit
ren sa9aq4b1 quantity_harvested /* on average per week */
ren sa9aq4b2 quantity_harvested_unit
ren sa9aq5b sold_unit
ren sa9aq6 price_per_unit
ren sa9aq7b sold_unit_harvested
ren sa9aq8 price_per_unit_harvested
recode quantity_caught quantity_harvested (.=0)
ren quantity_caught_unit unit
merge m:1 fish_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fish_prices_1.dta", nogen keep(1 3)
gen value_fish_caught = (quantity_caught * price_per_unit) if unit==sold_unit
replace value_fish_caught = (quantity_caught * price_per_unit_median) if value_fish_caught==.
replace value_fish_caught = (quantity_caught * price_per_unit) if unit==91 & sold_unit==90 & value_fish_caught==.
ren unit quantity_caught_unit
ren quantity_harvested_unit unit
drop price_per_unit_median
merge m:1 fish_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fish_prices_2.dta", nogen keep(1 3)
gen value_fish_harvest = (quantity_harvested * price_per_unit_harvested) if unit==sold_unit_harvested
replace value_fish_harvest = (quantity_harvested * price_per_unit_median) if value_fish_harvest==.
replace value_fish_harvest = (quantity_harvested * (3500*10)) if unit==80 & sold_unit_harvested==1 & value_fish_harvest==.
replace value_fish_harvest = (quantity_harvested * (600)) if unit==3 & sold_unit_harvested==. & value_fish_harvest==.
replace value_fish_harvest = value_fish_harvest * weeks_fishing /* Multiply average weekly earnings by number of weeks */
replace value_fish_caught = value_fish_caught * weeks_fishing
recode value_fish_harvest value_fish_caught weeks_fishing (.=0)
collapse (median) value_fish_harvest value_fish_caught (max) weeks_fishing, by (hhid)
lab var value_fish_caught "Value of fish caught over the past 12 months"
lab var value_fish_harvest "Value of fish harvested over the past 12 months"
lab var weeks_fishing "Maximum number weeks fishing for any species"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fish_income.dta", replace

use "${Nigeria_GHS_W3_raw_data}/secta9b2_harvestw3.dta", clear
ren sa9bq7 rental_costs_day
ren sa9bq6 days_rental
ren sa9bq9 maintenance_costs_per_week
ren sa9bq8 fuel_per_week /* Multiply this by weeks fishing */
recode days_rental rental_costs_day maintenance_costs_per_week (.=0)
gen rental_costs_fishing = rental_costs_day * days_rental
gen fish_expenses_1 = fuel_per_week + maintenance_costs_per_week
collapse (sum) fish_expenses_1, by (hhid)
lab var fish_expenses_1 "Expenses associated with boat rental and maintenance per week"
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fish_income.dta"
replace fish_expenses_1 = fish_expenses_1 * weeks_fishing
keep hhid fish_expenses_1
lab var fish_expenses_1 "Expenses associated with boat rental and maintenance over the year"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fishing_expenses_1.dta", replace

use "${Nigeria_GHS_W3_raw_data}/secta9b3_harvestw3.dta", clear
ren sa9bq10a number_men
ren sa9bq10b weeks_men
ren sa9bq11a number_women
ren sa9bq11b weeks_women
ren sa9bq12a number_children
ren sa9bq12b weeks_child
ren sa9bq15a wages_week_man
ren sa9bq15b wages_week_woman
ren sa9bq15c wages_week_child
ren sa9bq19a cash_men
ren sa9bq19b cash_women
ren sa9bq19c cash_child
ren sa9bq22a costs_feed
ren sa9bq22b costs_irrigation
ren sa9bq22c costs_maintenance
ren sa9bq22d costs_fishnets
ren sa9bq22e costs_other
recode number_men weeks_men number_women weeks_women number_children weeks_child wages_week_man wages_week_woman /*
*/ wages_week_child cash_men cash_women cash_child costs_feed costs_irrigation costs_maintenance costs_fishnets costs_other (.=0)
gen fish_expenses_2 = (number_men * weeks_men * wages_week_man) + (number_women * weeks_women * wages_week_woman) + /*
*/ (number_children * weeks_child * wages_week_child) + (cash_men + cash_women + cash_child) + /*
*/ (costs_feed + costs_irrigation + costs_maintenance + costs_fishnets + costs_other)
keep hhid fish_expenses_2
lab var fish_expenses_2 "Expenses associated with hired labor and fish pond maintenance"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fishing_expenses_2.dta", replace


********************************************************************************
* SELF-EMPLOYMENT INCOME *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect9_harvestw3.dta", clear
local vars s9q10a s9q10b s9q10c s9q10d s9q10e s9q10f s9q10g s9q10h s9q10i s9q10j s9q10k s9q10l
foreach p of local vars {
replace `p' = "1" if `p'=="X"
replace `p' = "0" if `p'==""
destring `p', replace
}
egen months_activ = rowtotal(s9q10a - s9q10l)
ren s9q27a monthly_profit
gen annual_selfemp_profit = monthly_profit * months_activ
recode annual_selfemp_profit (.=0)
collapse (sum) annual_selfemp_profit, by (hhid)
lab var annual_selfemp_profit "Estimated annual net profit from self-employment over previous 12 months (Feb 15 - Jan 16)"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_self_employment_income.dta", replace

*Sales of processed crops were captured separately.
*Value crop inputs used in the processed products.
use "${Nigeria_GHS_W3_raw_data}/secta3i_harvestw3.dta", clear
ren cropname crop_name
ren cropcode crop_code
ren sa3iq3 harvest_yesno
ren sa3iq6i quantity_harvested
ren sa3iq6ii unit
ren sa3iq6ii_os quantity_harvested_unit_other
ren sa3iq6a value_harvested
replace value_harvested = 0 if harvest_yesno==2
replace value_harvested = 0 if value_harvested==. & quantity_harvested == 0
ren sa3iq6b finished_harvest
ren sa3iq6d1 quantity_to_harvest
ren sa3iq6d2 quantity_to_harvest_unit
ren sa3iq6d2_os quantity_to_harvest_unit_other
collapse (sum) value_harvested quantity_harvested, by (hhid crop_code unit)
gen price_per_unit = value_harvested / quantity_harvested
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_unit_values.dta", replace

use "${Nigeria_GHS_W3_raw_data}/secta3ii_harvestw3.dta", clear
ren cropname crop_name
ren cropcode crop_code
ren sa3iiq19 sell_processedcrop_yesno
ren sa3iiq20a quant_processed_crop_sold
ren sa3iiq20b unit
ren sa3iiq20b_os quant_proccrop_sold_unit_other
ren sa3iiq21 value_processed_crop_sold
merge m:1 hhid crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_unit_values.dta", nogen keep(1 3)
merge m:1 crop_code unit using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_prices_median_country.dta", nogen keep(1 3)
gen price_received = value_processed_crop_sold / quant_processed_crop_sold
gen price_as_input = price_per_unit
replace price_as_input = price_per_unit_median if price_as_input==.
replace price_as_input = price_received if price_as_input > price_received /* Where unit-value of input exceeds the unit-value of processed output, we'll cap the per-unit price at the processed output price */
gen value_crop_input = quant_processed_crop_sold * price_as_input
gen profit_processed_crop_sold = value_processed_crop_sold - value_crop_input
collapse (sum) profit_processed_crop_sold, by (hhid)
lab var profit_processed_crop_sold "Net value of processed crops sold, with crop inputs valued at the unit price for the harvest"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_agproduct_income.dta", replace


********************************************************************************
*OFF-FARM HOURS
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect3_harvestw3.dta", clear
*Start with first wage job; no agriculture (which also includes mining/livestock)
gen primary_hours = s3q18 if  s3q14>2 &  s3q14!=.		// s3q14<2 is ag/mining
gen secondary_hours = s3q31 if  s3q27>2 & s3q27!=.
gen other_hours =  s3q47 if  s3q44b>9 & s3q44b!=.
egen off_farm_hours = rowtotal(primary_hours secondary_hours other_hours)
gen off_farm_any_count = off_farm_hours!=0
gen member_count = 1
collapse (sum) off_farm_hours off_farm_any_count member_count, by(hhid)
la var member_count "Number of HH members age 5 or above"
la var off_farm_any_count "Number of HH members with positive off-farm hours"
la var off_farm_hours "Total household off-farm hours"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_off_farm_hours.dta", replace


********************************************************************************
* WAGE INCOME *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect3_harvestw3.dta", clear
ren s3q13b activity_code
ren s3q14 sector_code
ren s3q12b1 mainwage_yesno
ren s3q16 mainwage_number_months
ren s3q17 mainwage_number_weeks
ren s3q18 mainwage_number_hours
ren s3q21a mainwage_recent_payment
gen ag_activity = (sector_code==1)
replace mainwage_recent_payment = . if ag_activity==1 // exclude ag wages
ren s3q21b mainwage_payment_period
ren s3q24a mainwage_recent_payment_other
replace mainwage_recent_payment_other = . if ag_activity==1
ren s3q24b mainwage_payment_period_other
ren s3q27 sec_sector_code
ren s3q25 secwage_yesno
ren s3q29 secwage_number_months
ren s3q30 secwage_number_weeks
ren s3q31 secwage_number_hours
ren s3q34a secwage_recent_payment
gen sec_ag_activity = (sec_sector_code==1)
replace secwage_recent_payment = . if sec_ag_activity==1 // exclude ag wages
ren s3q34b secwage_payment_period
ren s3q37a secwage_recent_payment_other
replace secwage_recent_payment_other = . if sec_ag_activity==1
ren s3q44b other_sector_code
ren s3q37b secwage_payment_period_other
ren s3q42 othwage_yesno
ren s3q45 othwage_number_months
ren s3q46 othwage_number_weeks
ren s3q47 othwage_number_hours
ren s3q49a othwage_recent_payment
replace othwage_recent_payment = . if other_sector_code==1 // exclude ag wages
ren s3q49b othwage_payment_period
gen othwage_recent_payment_other = .
gen othwage_payment_period_other = .
ren s3q4 worked_as_employee
recode  mainwage_number_months secwage_number_months (12/max=12)
recode  mainwage_number_weeks secwage_number_weeks (52/max=52)
recode  mainwage_number_hours secwage_number_hours (84/max=84)
local vars main sec
local vars main sec oth
foreach p of local vars {
	replace `p'wage_recent_payment=. if worked_as_employee!=1
	gen `p'wage_salary_cash = `p'wage_recent_payment if `p'wage_payment_period==8
	replace `p'wage_salary_cash = ((`p'wage_number_months/6)*`p'wage_recent_payment) if `p'wage_payment_period==7
	replace `p'wage_salary_cash = ((`p'wage_number_months/4)*`p'wage_recent_payment) if `p'wage_payment_period==6
	replace `p'wage_salary_cash = (`p'wage_number_months*`p'wage_recent_payment) if `p'wage_payment_period==5
	replace `p'wage_salary_cash = ((`p'wage_number_weeks/2)*`p'wage_recent_payment) if `p'wage_payment_period==4
	replace `p'wage_salary_cash = (`p'wage_number_weeks*`p'wage_recent_payment) if `p'wage_payment_period==3
	replace `p'wage_salary_cash = (`p'wage_number_weeks*(`p'wage_number_hours/8)*`p'wage_recent_payment) if `p'wage_payment_period==2
	replace `p'wage_salary_cash = (`p'wage_number_weeks*`p'wage_number_hours*`p'wage_recent_payment) if `p'wage_payment_period==1
	replace `p'wage_recent_payment_other=. if worked_as_employee!=1
	gen `p'wage_salary_other = `p'wage_recent_payment_other if `p'wage_payment_period_other==8
	replace `p'wage_salary_other = ((`p'wage_number_months/6)*`p'wage_recent_payment_other) if `p'wage_payment_period_other==7
	replace `p'wage_salary_other = ((`p'wage_number_months/4)*`p'wage_recent_payment_other) if `p'wage_payment_period_other==6
	replace `p'wage_salary_other = (`p'wage_number_months*`p'wage_recent_payment_other) if `p'wage_payment_period_other==5
	replace `p'wage_salary_other = ((`p'wage_number_weeks/2)*`p'wage_recent_payment_other) if `p'wage_payment_period_other==4
	replace `p'wage_salary_other = (`p'wage_number_weeks*`p'wage_recent_payment_other) if `p'wage_payment_period_other==3
	replace `p'wage_salary_other = (`p'wage_number_weeks*(`p'wage_number_hours/8)*`p'wage_recent_payment_other) if `p'wage_payment_period_other==2
	replace `p'wage_salary_other = (`p'wage_number_weeks*`p'wage_number_hours*`p'wage_recent_payment_other) if `p'wage_payment_period_other==1
	recode `p'wage_salary_cash `p'wage_salary_other (.=0)
	gen `p'wage_annual_salary = `p'wage_salary_cash + `p'wage_salary_other
}
gen annual_salary = mainwage_annual_salary + secwage_annual_salary + othwage_annual_salary
collapse (sum) annual_salary, by (hhid)
lab var annual_salary "Estimated annual earnings from non-agricultural wage employment over previous 12 months"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_wage_income.dta", replace


*Ag wage income
use "${Nigeria_GHS_W3_raw_data}/sect3_harvestw3.dta", clear
ren s3q13b activity_code
ren s3q14 sector_code
ren s3q12b1 mainwage_yesno
ren s3q16 mainwage_number_months
ren s3q17 mainwage_number_weeks
ren s3q18 mainwage_number_hours
ren s3q21a mainwage_recent_payment
gen ag_activity = (sector_code==1)
replace mainwage_recent_payment = . if ag_activity!=1 // include only ag wages
ren s3q21b mainwage_payment_period
ren s3q24a mainwage_recent_payment_other
replace mainwage_recent_payment_other = . if ag_activity!=1 // include only ag wages
ren s3q24b mainwage_payment_period_other
ren s3q25 secwage_yesno
ren s3q27 sec_sector_code
ren s3q29 secwage_number_months
ren s3q30 secwage_number_weeks
ren s3q31 secwage_number_hours
ren s3q34a secwage_recent_payment
gen sec_ag_activity = (sec_sector_code==1)
replace secwage_recent_payment = . if sec_ag_activity!=1
ren s3q34b secwage_payment_period
ren s3q37a secwage_recent_payment_other
replace secwage_recent_payment_other = . if sec_ag_activity!=1 // include only ag wages
ren s3q37b secwage_payment_period_other
ren s3q42 othwage_yesno
ren s3q44b other_sector_code
ren s3q45 othwage_number_months
ren s3q46 othwage_number_weeks
ren s3q47 othwage_number_hours
ren s3q49a othwage_recent_payment
replace othwage_recent_payment = . if other_sector_code!=1 // include only ag wages
ren s3q49b othwage_payment_period
gen othwage_recent_payment_other = .
gen othwage_payment_period_other = .
ren s3q4 worked_as_employee
recode  mainwage_number_months secwage_number_months (12/max=12)
recode  mainwage_number_weeks secwage_number_weeks (52/max=52)
recode  mainwage_number_hours secwage_number_hours (84/max=84)
local vars main sec

local vars main sec oth
foreach p of local vars {
	replace `p'wage_recent_payment=. if worked_as_employee!=1
	gen `p'wage_salary_cash = `p'wage_recent_payment if `p'wage_payment_period==8
	replace `p'wage_salary_cash = ((`p'wage_number_months/6)*`p'wage_recent_payment) if `p'wage_payment_period==7
	replace `p'wage_salary_cash = ((`p'wage_number_months/4)*`p'wage_recent_payment) if `p'wage_payment_period==6
	replace `p'wage_salary_cash = (`p'wage_number_months*`p'wage_recent_payment) if `p'wage_payment_period==5
	replace `p'wage_salary_cash = ((`p'wage_number_weeks/2)*`p'wage_recent_payment) if `p'wage_payment_period==4
	replace `p'wage_salary_cash = (`p'wage_number_weeks*`p'wage_recent_payment) if `p'wage_payment_period==3
	replace `p'wage_salary_cash = (`p'wage_number_weeks*(`p'wage_number_hours/8)*`p'wage_recent_payment) if `p'wage_payment_period==2
	replace `p'wage_salary_cash = (`p'wage_number_weeks*`p'wage_number_hours*`p'wage_recent_payment) if `p'wage_payment_period==1
	replace `p'wage_recent_payment_other=. if worked_as_employee!=1
	gen `p'wage_salary_other = `p'wage_recent_payment_other if `p'wage_payment_period_other==8
	replace `p'wage_salary_other = ((`p'wage_number_months/6)*`p'wage_recent_payment_other) if `p'wage_payment_period_other==7
	replace `p'wage_salary_other = ((`p'wage_number_months/4)*`p'wage_recent_payment_other) if `p'wage_payment_period_other==6
	replace `p'wage_salary_other = (`p'wage_number_months*`p'wage_recent_payment_other) if `p'wage_payment_period_other==5
	replace `p'wage_salary_other = ((`p'wage_number_weeks/2)*`p'wage_recent_payment_other) if `p'wage_payment_period_other==4
	replace `p'wage_salary_other = (`p'wage_number_weeks*`p'wage_recent_payment_other) if `p'wage_payment_period_other==3
	replace `p'wage_salary_other = (`p'wage_number_weeks*(`p'wage_number_hours/8)*`p'wage_recent_payment_other) if `p'wage_payment_period_other==2
	replace `p'wage_salary_other = (`p'wage_number_weeks*`p'wage_number_hours*`p'wage_recent_payment_other) if `p'wage_payment_period_other==1
	recode `p'wage_salary_cash `p'wage_salary_other (.=0)
	gen `p'wage_annual_salary = `p'wage_salary_cash + `p'wage_salary_other
}
gen annual_salary_agwage = mainwage_annual_salary + secwage_annual_salary + othwage_annual_salary
collapse (sum) annual_salary_agwage, by (hhid)
lab var annual_salary_agwage "Estimated annual earnings from agricultural wage employment over previous 12 months"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_agwage_income.dta", replace


********************************************************************************
*OTHER INCOME *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect6_harvestw3.dta", clear
*To convert from US dollars and Euros, we'll use the June 2015 exchange rate.
*https://fx-rate.net/NGN/?date_input=2015-06-05
*1 USD --> 199 naira; 1 Euro --> 223.1 naira for June 5, 2015
ren s6q4a cash_received
ren s6q4b cash_received_unit
ren s6q8a inkind_received
ren s6q8b inkind_received_unit
local vars cash_received inkind_received
foreach p of local vars {
	replace `p' = `p'*199 if `p'_unit==1
	replace `p' = `p'*223.1 if `p'_unit==2
	replace `p'_unit = 5 if `p'_unit==1|`p'_unit==2
	tab `p'_unit
}
recode cash_received inkind_received (.=0)
gen remittance_income = cash_received + inkind_received
collapse (sum) remittance_income, by (hhid)
lab var remittance_income "Estimated income from OVERSEAS remittances over previous 12 months"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_remittance_income.dta", replace

use "${Nigeria_GHS_W3_raw_data}/sect13_harvestw3.dta", clear
append using "${Nigeria_GHS_W3_raw_data}/sect14_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/secta4_harvestw3.dta"
ren s13q2 investment_income
ren s13q5 rental_income_buildings
ren s13q8 other_income
ren s14q2a assistance_cash
ren s14q2d assistance_food
ren s14q2e assistance_inkind
ren sa4q7 rental_income_assets
recode investment_income rental_income_buildings other_income assistance_cash assistance_food assistance_inkind rental_income_assets (.=0)
gen assistance_income = assistance_cash + assistance_food + assistance_inkind
collapse (sum) investment_income rental_income_buildings other_income assistance_income rental_income_assets, by (hhid)
lab var investment_income "Estimated income from interest or investments over previous 12 months"
lab var rental_income_buildings "Estimated income from rentals of buildings, tools, land, transport animals over previous 12 months"
lab var other_income "Estimated income from any OTHER source over previous 12 months"
lab var assistance_income "Estimated income from a food aid, food-for-work, etc. over previous 12 months"
lab var rental_income_assets "Estimated income from rentals of tools and other agricultural assets over previous 12 months"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_other_income.dta", replace

*Land rental
use "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3.dta", clear
ren s11b1q29 year_rented
ren s11b1q31 land_rental_income_cash
ren s11b1q33 land_rental_income_inkind
recode land_rental_income_cash land_rental_income_inkind (.=0)
gen land_rental_income = land_rental_income_cash + land_rental_income_inkind
replace land_rental_income = . if year_rented < 2015 | year_rented == .
collapse (sum) land_rental_income, by (hhid)
lab var land_rental_income "Estimated income from renting out land over previous 12 months"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_rental_income.dta", replace


********************************************************************************
* FARM SIZE/LAND SIZE *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/secta3i_harvestw3.dta", clear
gen cultivated = 1
merge m:1 hhid plotid using "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3.dta"
ren s11b1q27 cultivated_this_year
preserve
use "${Nigeria_GHS_W3_raw_data}/sect11f_plantingw3.dta", clear
gen cultivated = 1 if (s11fq7!=. & s11fq7!=0) |  (s11fq11a!=. & s11fq11a!=0)
collapse (max) cultivated, by (hhid plotid)
tempfile tree
save `tree', replace
restore
append using `tree'

replace cultivated = 1 if cultivated_this_year==1 & cultivated==.
ren plotid plot_id
collapse (max) cultivated, by (hhid plot_id)
lab var cultivated "1= Parcel was cultivated in this data set"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_parcels_cultivated.dta", replace

use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta", clear
merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_parcels_cultivated.dta"
keep if cultivated==1
collapse (sum) field_size, by (hhid plot_id)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_sizes.dta", replace
collapse (sum) field_size, by (hhid)
ren field_size farm_area
lab var farm_area "Land size (denominator for land productivitiy), in hectares" /* Uses measures */
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_size.dta", replace

*All Agricultural Land
use "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3.dta", clear
ren plotid plot_id
gen agland = (s11b1q27==1 | s11b1q28==1 | s11b1q28==6) // Cultivated, fallow, or pasture
merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_parcels_cultivated.dta", nogen keep(1 3)
preserve
use "${Nigeria_GHS_W3_raw_data}/sect11f_plantingw3.dta", clear
gen cultivated = 1 if (s11fq7!=. & s11fq7!=0) |  (s11fq11a!=. & s11fq11a!=0)
collapse (max) cultivated, by (hhid plotid)
ren plotid plot_id
tempfile tree
save `tree', replace
restore
append using `tree'
replace agland=1 if cultivated==1
keep if agland==1
collapse (max) agland, by (hhid plot_id)
keep hhid plot_id agland
lab var agland "1= Plot was cultivated, left fallow, or used for pasture"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_parcels_agland.dta", replace

use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta", clear
merge 1:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_parcels_agland.dta", nogen
keep if agland==1
collapse (sum) field_size, by (hhid)
ren field_size farm_size_agland
lab var farm_size_agland "Land size in hectares, including all plots cultivated, fallow, or pastureland"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmsize_all_agland.dta", replace

*Total land holding including cultivated and rented out
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta", clear
collapse (sum) field_size, by (hhid)
ren field_size land_size_total
lab var land_size_total "Total land size in hectares, including rented in and rented out plots"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_size_total.dta", replace


********************************************************************************
*LAND SIZE
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3.dta", clear
ren plotid plot_id
gen rented_out = 1 if s11b1q29==2015
drop if rented_out==1
gen plot_held=1
keep hhid plot_id plot_held
lab var plot_held "1= Plot was NOT rented out in 2015"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_parcels_held.dta", replace

use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta", clear
merge 1:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_parcels_held.dta", nogen
keep if plot_held==1
collapse (sum) field_size, by (hhid)
ren field_size land_size
lab var land_size "Land size in hectares, including all plots listed by the household (and not rented out)"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_size_all.dta", replace


********************************************************************************
*FARM LABOR
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect11c1_plantingw3.dta", clear
ren s11c1q2 number_men
ren s11c1q3 number_days_men
ren s11c1q5 number_women
ren s11c1q6 number_days_women
ren s11c1q8 number_children
ren s11c1q9 number_days_children
gen days_men_pp = number_men * number_days_men
gen days_women_pp = number_women * number_days_women
gen days_children_pp = number_children * number_days_children
recode days_men_pp  days_women_pp  days_children_pp  (.=0)
gen days_hired_postplant =  days_men_pp  + days_women_pp  + days_children_pp
ren s11c1q1a2 weeks_1
ren s11c1q1a3 days_week_1
ren s11c1q1b2 weeks_2
ren s11c1q1b3 days_week_2
ren s11c1q1c2 weeks_3
ren s11c1q1c3 days_week_3
ren s11c1q1d2 weeks_4
ren s11c1q1d3 days_week_4
recode weeks_1 days_week_1 weeks_2 days_week_2 weeks_3 days_week_3 weeks_4 days_week_4 (.=0)
gen days_famlabor_postplant = (weeks_1 * days_week_1) + (weeks_2 * days_week_2) + (weeks_3 * days_week_3) + (weeks_4 * days_week_4)
ren plotid plot_id
collapse (sum) days_hired_postplant days_famlabor_postplant days_men_pp days_women_pp, by (hhid plot_id)
lab var days_hired_postplant "Workdays for hired labor (crops), as captured in post-planting survey"
lab var days_famlabor_postplant "Workdays for family labor (crops), as captured in post-planting survey"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_farmlabor_postplanting.dta", replace
collapse (sum) days_hired_postplant days_famlabor_postplant, by (hhid)
lab var days_hired_postplant "Workdays for hired labor (crops), as captured in post-planting survey"
lab var days_famlabor_postplant "Workdays for family labor (crops), as captured in post-planting survey"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmlabor_postplanting.dta", replace

use "${Nigeria_GHS_W3_raw_data}/secta2_harvestw3.dta", clear
ren sa2q2 number_men
ren sa2q3 number_days_men
ren sa2q5 number_women
ren sa2q6 number_days_women
ren sa2q8 number_children
ren sa2q9 number_days_children
gen days_men_ph = number_men * number_days_men
gen days_women_ph = number_women * number_days_women
gen days_children_ph = number_children * number_days_children
recode days_men_ph days_women_ph days_children_ph (.=0)
gen days_hired_postharvest =  days_men_ph + days_women_ph + days_children_ph
*From between planting and harvest
ren sa2q1c number_men2 // Hired labor
ren sa2q1d number_days_men2
ren sa2q1f number_women2
ren sa2q1g number_days_women2
ren sa2q1i number_children2
ren sa2q1j number_days_children2
gen days_men_ph2 = number_men2 * number_days_men2
gen days_women_ph2 = number_women2 * number_days_women2
gen days_children_ph2 = number_children2 * number_days_children2
recode days_men_ph2 days_women_ph2 days_children_ph2 (.=0)
gen days_hired_postharvest2 =  days_men_ph2 + days_women_ph2 + days_children_ph2
replace days_hired_postharvest = days_hired_postharvest + days_hired_postharvest2 // Includes pre-harvest AND harvest labor
ren sa2q1b_a2 weeks_1
ren sa2q1b_a3 days_week_1
ren sa2q1b_b2 weeks_2
ren sa2q1b_b3 days_week_2
ren sa2q1b_c2 weeks_3
ren sa2q1b_c3 days_week_3
ren sa2q1b_d2 weeks_4
ren sa2q1b_d3 days_week_4
ren sa2q1b_e2 weeks_5
ren sa2q1b_e3 days_week_5
ren sa2q1b_f2 weeks_6
ren sa2q1b_f3 days_week_6
ren sa2q1b_g2 weeks_7
ren sa2q1b_g3 days_week_7
ren sa2q1b_h2 weeks_8
ren sa2q1b_h3 days_week_8
ren sa2q1a2 weeks_9
ren sa2q1a3 days_week_9
ren sa2q1b2 weeks_10
ren sa2q1b3 days_week_10
ren sa2q1c2 weeks_11
ren sa2q1c3 days_week_11
ren sa2q1d2 weeks_12
ren sa2q1d3 days_week_12
ren sa2q1e2 weeks_13
ren sa2q1e3 days_week_13
ren sa2q1f2 weeks_14
ren sa2q1f3 days_week_14
ren sa2q1g2 weeks_15
ren sa2q1g3 days_week_15
ren sa2q1h2 weeks_16
ren sa2q1h3 days_week_16
ren sa2q1n_a number_exchange_men2 // Exchange labor before harvest
ren sa2q1n_b number_exchange_women2
ren sa2q1n_c number_exchange_children2
ren sa2q12a number_exchange_men // Exchange labor for harvest, we understand this to be "person-days", as only the number of days was asked.
ren sa2q12b number_exchange_women
ren sa2q12c number_exchange_children
recode number_exchange_men2 number_exchange_women2 number_exchange_children2 number_exchange_men number_exchange_women number_exchange_children (.=0)
recode weeks_1 days_week_1 weeks_2 days_week_2 weeks_3 days_week_3 weeks_4 days_week_4 /*
*/ weeks_5 days_week_5 weeks_6 days_week_6 weeks_7 days_week_7 weeks_8 days_week_8 /*
*/ weeks_9 days_week_9 weeks_10 days_week_10 weeks_11 days_week_11 weeks_12 days_week_12 /*
*/ weeks_13 days_week_13 weeks_14 days_week_14 weeks_15 days_week_15 weeks_16 days_week_16 (.=0)
gen days_famlabor_postharvest = (weeks_1 * days_week_1) + (weeks_2 * days_week_2) + (weeks_3 * days_week_3) + (weeks_4 * days_week_4) /*
*/ + (weeks_5 * days_week_5) + (weeks_6 * days_week_6) + (weeks_7 * days_week_7) + (weeks_8 * days_week_8) + /*
*/ (weeks_9 * days_week_9) + (weeks_10 * days_week_10) + (weeks_11 * days_week_11) + (weeks_12 * days_week_12) + /*
*/ (weeks_13 * days_week_13) + (weeks_14 * days_week_14) + (weeks_15 * days_week_15) + (weeks_16 * days_week_16)
gen days_exchange_labor_postharvest = number_exchange_men2 + number_exchange_women2 + number_exchange_children2 /*
*/ + number_exchange_men + number_exchange_women + number_exchange_children
ren plotid plot_id
collapse (sum) days_hired_postharvest days_famlabor_postharvest days_exchange_labor_postharvest days_men_ph* days_women_ph*, by (hhid plot_id)
lab var days_hired_postharvest "Workdays for hired labor (crops), as captured in post-harvest survey"
lab var days_famlabor_postharvest "Workdays for family labor (crops), as captured in post-harvest survey"
lab var days_exchange_labor_postharvest "Workdays (lower-bound estimate) of exchange labor, as captured in post-harvest survey"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_farmlabor_postharvest.dta", replace

collapse (sum) days_hired_postharvest days_famlabor_postharvest days_exchange_labor_postharvest, by (hhid)
lab var days_hired_postharvest "Workdays for hired labor (crops), as captured in post-harvest survey"
lab var days_famlabor_postharvest "Workdays for family labor (crops), as captured in post-harvest survey"
lab var days_exchange_labor_postharvest "Workdays (lower-bound estimate) of exchange labor, as captured in post-harvest survey"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmlabor_postharvest.dta", replace

use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_farmlabor_postplanting.dta", clear
merge 1:1  hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_farmlabor_postharvest.dta", nogen
recode days*  (.=0)
collapse (sum) days*, by(hhid plot_id)
egen labor_hired =rowtotal(days_hired_postplant days_hired_postharvest)
egen labor_family=rowtotal(days_famlabor_postplant days_famlabor_postharvest )
egen labor_total = rowtotal(labor_hired labor_family days_exchange_labor_postharvest)
egen labor_hired_male = rowtotal(days_men_pp days_men_ph days_men_ph2)
egen labor_hired_female = rowtotal(days_women_pp days_women_ph days_men_ph2)
lab var labor_total "Total labor days (family, hired, or other) allocated to the plot in the past year"
lab var labor_hired "Total labor days (hired) allocated to the plot in the past year"
lab var labor_family "Total labor days (family) allocated to the plot in the past year"
lab var labor_total "Total labor days (hired +family) allocated to the plot in the past year"
lab var labor_hired_male "Workdays for male hired labor allocated to the plot in the past year"
lab var labor_hired_female "Workdays for female hired labor allocated to the plot in the past year"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_family_hired_labor.dta", replace

collapse (sum) labor_*, by(hhid)
lab var labor_total "Total labor days (family, hired, or other) allocated to the farm in the past year"
lab var labor_hired "Total labor days (hired) allocated to the farm in the past year"
lab var labor_family "Total labor days (family) allocated to the farm in the past year"
lab var labor_total "Total labor days (hired +family) allocated to the farm in the past year"
lab var labor_hired_male "Workdays for male hired labor allocated to the farm in the past year"
lab var labor_hired_female "Workdays for female hired labor allocated to the farm in the past year"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_family_hired_labor.dta", replace

********************************************************************************
* VACCINE USAGE *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect11i_plantingw3.dta", clear
gen vac_animal= s11iq22>=1 & s11iq1==1
replace  vac_animal=. if animal_cd==121 | animal_cd==123 // other categories includes essentially dogsa and cats and other animals for which vaccination is not relevant
replace vac_animal = . if s11iq1==2 | s11iq1==. //missing if the household did now own any of these types of animals
*disagregating vaccine usage by animal type
ren animal_cd livestock_code
gen species = (inlist(livestock_code,101,102,103,104,105,106,107)) + 2*(inlist(livestock_code,110,111)) + 3*(livestock_code==112) + 4*(inlist(livestock_code,108,109,122)) + 5*(inlist(livestock_code,113,114,115,116,117,118,120))
recode species (0=.)
la def species 1 "Large ruminants (cows, buffalos)" 2 "Small ruminants (sheep, goats)" 3 "Pigs" 4 "Equine (horses, donkeys)" 5 "Poultry"
la val species species
*A loop to create species variables
foreach i in vac_animal {
	gen `i'_lrum = `i' if species==1
	gen `i'_srum = `i' if species==2
	gen `i'_pigs = `i' if species==3
	gen `i'_equine = `i' if species==4
	gen `i'_poultry = `i' if species==5
}
collapse (max) vac_animal*, by (hhid)
lab var vac_animal "1= Household has an animal vaccinated"
foreach i in vac_animal {
	local l`i' : var lab `i'
	lab var `i'_lrum "`l`i'' - large ruminants"
	lab var `i'_srum "`l`i'' - small ruminants"
	lab var `i'_pigs "`l`i'' - pigs"
	lab var `i'_equine "`l`i'' - equine"
	lab var `i'_poultry "`l`i'' - poultry"
}
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_vaccine.dta", replace

use "${Nigeria_GHS_W3_raw_data}/sect11i_plantingw3.dta", clear
gen all_vac_animal=s11iq22>=1 & s11iq1==1
replace  all_vac_animal=. if animal_cd==121 | animal_cd==123 // other categories includes essentially dogsa and cats and other animals for which vaccination is not relevant
replace all_vac_animal = . if s11iq1==2 | s11iq1==. //missing if the household did now own any of these types of animals
preserve
keep hhid s11iq5a all_vac_animal
ren s11iq5a farmerid
tempfile farmer1
save `farmer1'
restore
preserve
keep hhid  s11iq5b  all_vac_animal
ren s11iq5b farmerid
tempfile farmer2
save `farmer2'
restore
use   `farmer1', replace
append using  `farmer2'
collapse (max) all_vac_animal , by(hhid farmerid)
gen indiv=farmerid
drop if indiv==.
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_gender_merge_temp.dta", nogen
keep hhid farmerid all_vac_animal indiv female age
lab var all_vac_animal "1 = Individual farmer (livestock keeper) uses vaccines"
gen livestock_keeper=1 if farmerid!=.
recode livestock_keeper (.=0)
lab var livestock_keeper "1=Indvidual is listed as a livestock keeper (at least one type of livestock)"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmer_vaccine.dta", replace

********************************************************************************
*ANIMAL HEALTH - DISEASES
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect11i_plantingw3.dta", clear
gen disease_animal = 1 if s11iq20==1
replace disease_animal = 0 if s11iq20==2
gen disease_fmd = (s11iq21a==4 | s11iq21c==4 )
gen disease_lump = (s11iq21a==5 | s11iq21c==5 )
gen disease_bruc = (s11iq21a==7 | s11iq21c==7 )
gen disease_cbpp = (s11iq21a==9 | s11iq21c==9 )
gen disease_bq = (s11iq21a==6 | s11iq21c==6 )
ren animal_cd livestock_code
gen species = (inlist(livestock_code,101,102,103,104,105,106,107)) + 2*(inlist(livestock_code,110,111)) + 3*(livestock_code==112) + 4*(inlist(livestock_code,108,109,122)) + 5*(inlist(livestock_code,113,114,115,116,117,118,120))
recode species (0=.)
la def species 1 "Large ruminants (cows, buffalos)" 2 "Small ruminants (sheep, goats)" 3 "Pigs" 4 "Equine (horses, donkeys)" 5 "Poultry"
la val species species
*A loop to create species variables
foreach i in disease_animal disease_fmd disease_lump disease_bruc disease_cbpp disease_bq{
	gen `i'_lrum = `i' if species==1
	gen `i'_srum = `i' if species==2
	gen `i'_pigs = `i' if species==3
	gen `i'_equine = `i' if species==4
	gen `i'_poultry = `i' if species==5
}
collapse (max) disease_*, by (hhid)
lab var disease_animal "1= Household has animal that suffered from disease"
lab var disease_fmd "1= Household has animal that suffered from foot and mouth disease"
lab var disease_lump "1= Household has animal that suffered from lumpy skin disease"
lab var disease_bruc "1= Household has animal that suffered from black quarter"
lab var disease_cbpp "1= Household has animal that suffered from brucelosis"
lab var disease_bq "1= Household has animal that suffered from black quarter"
foreach i in disease_animal disease_fmd disease_lump disease_bruc disease_cbpp disease_bq{
	local l`i' : var lab `i'
	lab var `i'_lrum "`l`i'' - large ruminants"
	lab var `i'_srum "`l`i'' - small ruminants"
	lab var `i'_pigs "`l`i'' - pigs"
	lab var `i'_equine "`l`i'' - equine"
	lab var `i'_poultry "`l`i'' - poultry"
}
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_diseases.dta", replace


********************************************************************************
*LIVESTOCK WATER, FEEDING, AND HOUSING
********************************************************************************
**cannot construct


********************************************************************************
* USE OF INORGANIC FERTILIZER *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/secta11d_harvestw3.dta", clear
gen use_inorg_fert=s11dq1a==1
collapse (max) use_inorg_fert, by (hhid)
la var use_inorg_fert "1= Household uses inorganic fertilizer"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fert_use.dta", replace

*Fertilizer use by farmers ( a farmer is an individual listed as plot manager)
use "${Nigeria_GHS_W3_raw_data}/secta11d_harvestw3.dta", clear
ren plotid plot_id
merge 1:1 hhid plot_id using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta"
gen all_use_inorg_fert= s11dq1a==1
preserve
keep hhid s11aq6a   all_use_inorg_fert
ren s11aq6a farmerid
tempfile farmer1
save `farmer1'
restore
preserve
keep hhid s11aq6b all_use_inorg_fert
ren s11aq6b farmerid
tempfile farmer2
save `farmer2'
restore

use   `farmer1', replace
append using  `farmer2'
collapse (max) all_use_inorg_fert , by(hhid farmerid)
gen indiv=farmerid
drop if indiv==.
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_gender_merge.dta", nogen
lab var all_use_inorg_fert "1 = Individual farmer (plot manager) uses inorganic fertilizer"
gen farm_manager=1 if farmerid!=.
recode farm_manager (.=0)
lab var farm_manager "1=Indvidual is listed as a manager for at least one plot"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmer_fert_use.dta", replace


********************************************************************************
* USE OF IMPROVED SEED *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect11e_plantingw3.dta", clear
gen imprv_seed_use=s11eq3b==1 |  s11eq3b==2
forvalues k=1/$nb_topcrops {
	local c : word `k' of $topcrop_area
	local cn : word `k' of $topcropname_area
	gen imprv_seed_`cn'=imprv_seed_use if cropcode==`c'
	gen hybrid_seed_`cn'=.
}
collapse (max) imprv_seed_* hybrid_seed_*, by(hhid)
lab var imprv_seed_use "1 = Household uses improved seed"
foreach v in $topcropname_area {
	lab var imprv_seed_`v' "1= Household uses improved `v' seed"
	lab var hybrid_seed_`v' "1= Household uses improved `v' seed"
}
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_improvedseed_use.dta", replace

*Improved use by farmers ( a farmer is an individual listed as plot manager)
use "${Nigeria_GHS_W3_raw_data}/sect11e_plantingw3.dta", clear
ren plotid plot_id
merge m:1 hhid plot_id using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta"
gen all_imprv_seed_use=s11eq3b==1 |  s11eq3b==2
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmer_improvedseed_use_temp.dta", replace

forvalues k=1/$nb_topcrops {
	use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmer_improvedseed_use_temp.dta", clear
	local c : word `k' of $topcrop_area
	local cn : word `k' of $topcropname_area
	*Adding adoption of improved maize seeds
	gen all_imprv_seed_`cn'=all_imprv_seed_use if cropcode==`c'
	gen all_hybrid_seed_`cn' =.
	*We also need a variable that indicates if farmer (plot manager) grows maize
	gen `cn'_farmer= cropcode==`c'
	preserve
	keep hhid s11aq6a all_imprv_seed_use all_imprv_seed_`cn' all_hybrid_seed_`cn' `cn'_farmer
	ren s11aq6a farmerid
	tempfile farmer1
	save `farmer1'
	restore
	preserve
	keep hhid s11aq6b all_imprv_seed_use all_imprv_seed_`cn' all_hybrid_seed_`cn' `cn'_farmer
	ren s11aq6b farmerid
	tempfile farmer2
	save `farmer2'
	restore

	use   `farmer1', replace
	append using  `farmer2'
	collapse (max) all_imprv_seed_use  all_imprv_seed_`cn' all_hybrid_seed_`cn'  `cn'_farmer, by (hhid farmerid)
	save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmer_improvedseed_use_temp_`cn'.dta", replace
}

*Combining all together
foreach v in $topcropname_area {
	merge 1:1 hhid farmerid all_imprv_seed_use using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmer_improvedseed_use_temp_`v'.dta", nogen
}
gen indiv=farmerid
drop if indiv==.
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_gender_merge.dta", nogen
lab var all_imprv_seed_use "1 = Individual farmer (plot manager) uses improved seeds"
foreach v in $topcropname_area {
	lab var all_imprv_seed_`v' "1 = Individual farmer (plot manager) uses improved seeds - `v'"
	lab var all_hybrid_seed_`v' "1 = Individual farmer (plot manager) uses hybrid seeds - `v'"
	lab var `v'_farmer "1 = Individual farmer (plot manager) grows `v'"
}
gen farm_manager=1 if farmerid!=.
recode farm_manager (.=0)
lab var farm_manager "1=Indvidual is listed as a manager for at least one plot"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmer_improvedseed_use.dta", replace


********************************************************************************
* REACHED BY AG EXTENSION *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect11l1_plantingw3.dta", clear
ren s11l1q1 receive_advice
ren s11l1q2 sourceid
ren s11l1q2_os sourceid_other
preserve
use "${Nigeria_GHS_W3_raw_data}/secta5a_harvestw3.dta", clear
ren sa5aq1 receive_advice
ren sa5aq2 sourceid
ren sa5aq2b sourceid_other
tempfile advie_ph
save `advie_ph'
restore
append using `advie_ph'

**Government Extension
gen advice_gov = ((sourceid==1 |sourceid==3) & receive_advice==1)
**private Extension
gen advice_private = (sourceid==2 & receive_advice==1)
**NGO
gen advice_ngo = (sourceid==4 & receive_advice==1)
**Cooperative/ Farmer Association
gen advice_coop = (sourceid==5 & receive_advice==1)
**Radio
gen advice_media = (sourceid==12 & receive_advice==1)
**Publication
gen advice_pub = (sourceid==13 & receive_advice==1)
**Neighbor
gen advice_neigh = ((sourceid==8 | sourceid==10 | sourceid==11) & receive_advice==1)
**Other
gen advice_other = ((sourceid==7 | sourceid==9 | sourceid==14)  & receive_advice==1)
**advice on prices from extension
gen ext_reach_all=(advice_gov==1 | advice_ngo==1 | advice_coop==1 | advice_media==1  | advice_pub==1)
gen ext_reach_public=(advice_gov==1)
gen ext_reach_private=(advice_ngo==1 | advice_coop==1)
gen ext_reach_unspecified=(advice_media==1 | advice_pub==1 | advice_other==1)
gen ext_reach_ict=(advice_media==1)
collapse (max) ext_reach_* , by (hhid)
lab var ext_reach_all "1 = Household reached by extensition services - all sources"
lab var ext_reach_public "1 = Household reached by extensition services - public sources"
lab var ext_reach_private "1 = Household reached by extensition services - private sources"
lab var ext_reach_unspecified "1 = Household reached by extensition services - unspecified sources"
lab var ext_reach_ict "1 = Household reached by extensition services through ICT"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_any_ext.dta", replace


********************************************************************************
* USE OF FORMAL FINANCIAL SERVICES *
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect4a_plantingw3.dta", clear
append using "${Nigeria_GHS_W3_raw_data}/sect4b_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect4c1_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect4c2_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect4c3_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect9_harvestw3.dta"
gen use_bank_acount=s4aq1==1
gen use_bank_other=s4bq10b==1 | ((s9q17==1 |  s9q18==1) &( s9q19a==1 |  s9q19b==1))
gen use_saving=s4aq9b==3 | s4aq9d==1 | s4aq9f==1
gen use_MM=s4bq10b==1  & s4bq10!=0 & s4bq10!=.
gen formal_loan=1 if (s4cq2b==3 | s4cq2b==4) & s4cq8!=.
gen rec_loan=formal_loan==1
gen use_credit_selfemp= (s9q17==1 |  s9q18==1) &( s9q19a==1 |  s9q19b==1)
gen use_insur=s4aq16==1
gen use_fin_serv_bank= use_bank_acount==1
gen use_fin_serv_credit= use_credit_selfemp==1 | rec_loan==1
gen use_fin_serv_insur= use_insur==1
gen use_fin_serv_digital=use_MM==1
gen use_fin_serv_others= use_saving==1
gen use_fin_serv_all=use_fin_serv_bank==1 | use_fin_serv_credit==1 | use_fin_serv_insur==1 | use_fin_serv_digital==1 |  use_fin_serv_others==1
recode use_fin_serv* (.=0)
collapse (max) use_fin_serv_*, by (hhid)
lab var use_fin_serv_all "1= Household uses formal financial services - all types"
lab var use_fin_serv_bank "1= Household uses formal financial services - bank accout"
lab var use_fin_serv_credit "1= Household uses formal financial services - credit"
lab var use_fin_serv_insur "1= Household uses formal financial services - insurance"
lab var use_fin_serv_digital "1= Household uses formal financial services - digital"
lab var use_fin_serv_others "1= Household uses formal financial services - others"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fin_serv.dta", replace


********************************************************************************
* MILK PRODUCTIVITY *
********************************************************************************
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_products", clear
keep if livestock_code == 1 & quantity_produced!=0
replace quantity_produced_unit = 3 if livestock_code==1 & (quantity_produced_unit==1 | quantity_produced_unit==70 | quantity_produced_unit==81  | quantity_produced_unit==80 | quantity_produced_unit==191)
replace quantity_produced = quantity_produced/100 if quantity_produced_unit==4
replace quantity_produced_unit = 3 if quantity_produced_unit==4
gen milk_quantity_produced = quantity_produced
gen milk_months_produced = months_produced
drop if quantity_produced_unit==.
replace milk_quantity_produced = milk_quantity_produced*50 if quantity_produced_unit==193
drop if quantity_produced_unit==11 | quantity_produced_unit==30 | quantity_produced_unit==31 | quantity_produced_unit==71 | quantity_produced_unit==91 | quantity_produced_unit==150 //Odd units that we don't have a conversion factor for
collapse (sum) milk_months_produced milk_quantity_produced , by (hhid)
la var milk_months_produced "Number of months that the household produced milk"
la var milk_quantity_produced "Average quantity of milk produced per month - liters"
drop if milk_months_produced==0 | milk_quantity_produced==0
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_milk_animals.dta", replace


********************************************************************************
* EGG PRODUCTIVITY *
********************************************************************************
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_livestock_products", clear
keep if livestock_code==2 & quantity_produced!=0
replace quantity_produced_unit = 80 if livestock_code==2 & (quantity_produced_unit==70 | quantity_produced_unit==82 | quantity_produced_unit==90 | quantity_produced_unit==191 /*
*/ | quantity_produced_unit==141 | quantity_produced_unit==160 | quantity_produced_unit==3 | quantity_produced_unit==1)
gen eggs_quantity_produced = quantity_produced
gen eggs_months_produced = months_produced
drop if quantity_produced_unit==.
collapse (sum) eggs_months_produced eggs_quantity_produced, by (hhid)
drop if eggs_months_produced==0 | eggs_quantity_produced==0
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_egg_animals.dta", replace


********************************************************************************
* CROP PRODUCTION COSTS PER HECTARE *
********************************************************************************
*Land rental rates
use "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3.dta", clear
ren plotid plot_id
merge 1:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas", nogen keep(1 3)
merge 1:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", nogen keep (1 3)
egen plot_rental_rate = rowtotal(s11b1q13 s11b1q14)		// cash (s11b1q13) and in-kind (s11b1q14)
recode plot_rental_rate (0=.)
preserve
gen value_rented_land = plot_rental_rate
gen value_rented_land_male = plot_rental_rate if dm_gender==1
gen value_rented_land_female = plot_rental_rate if dm_gender==2
gen value_rented_land_mixed = plot_rental_rate if dm_gender==3
collapse (sum) value_rented_land_* value_rented_land = plot_rental_rate, by(hhid)			// total paid for rent at household level
la var value_rented_land "Value of rented land owned by the household"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_rental_rate.dta", replace
restore
gen ha_rental_rate_hh = plot_rental_rate/field_size
recode ha_rental_rate_hh (0=.)

*Now, getting total area of all plots that were cultivated this year
preserve
gen ha_cultivated_plots = field_size if cultivate==1					// non-missing only if plot was cultivated
collapse (sum) ha_cultivated_plots, by(hhid)		// total ha of all plots that were cultivated
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cultivated_plots_ha.dta", replace
restore

*Now, getting household-level average rental rate (for households that rented any)
preserve
keep if plot_rental_rate!=. & plot_rental_rate!=0			// keeping only plots that were rented (and non-zero paid)
collapse (sum) plot_rental_rate field_size, by(hhid)			// collapsing total paid and area rented to household level
gen ha_rental_hh = plot_rental_rate/field_size				// naira per ha
drop field_size
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_rental_rate_hh.dta", replace
restore

*Geographic medians
bys zone state lga sector: egen ha_rental_count_sect = count(ha_rental_rate_hh)
bys zone state lga sector: egen ha_rental_rate_sect = median(ha_rental_rate_hh)
bys zone state lga: egen ha_rental_count_lga = count(ha_rental_rate_hh)
bys zone state lga: egen ha_rental_rate_lga = median(ha_rental_rate_hh)
bys zone state: egen ha_rental_count_state = count(ha_rental_rate_hh)
bys zone state: egen ha_rental_rate_state = median(ha_rental_rate_hh)
bys zone: egen ha_rental_count_zone = count(ha_rental_rate_hh)
bys zone: egen ha_rental_rate_zone = median(ha_rental_rate_hh)
egen ha_rental_rate_nat = median(ha_rental_rate_hh)

gen ha_rental_rate = ha_rental_rate_sect if ha_rental_count_sect>=10
replace ha_rental_rate = ha_rental_rate_lga if ha_rental_count_lga>=10 & ha_rental_rate==.
replace ha_rental_rate = ha_rental_rate_state if ha_rental_count_state>=10 & ha_rental_rate==.
replace ha_rental_rate = ha_rental_rate_zone if ha_rental_count_zone>=10 & ha_rental_rate==.
replace ha_rental_rate = ha_rental_rate_nat if ha_rental_rate==.
collapse (firstnm) ha_rental_rate, by(zone state lga sector)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_rental_rate.dta", replace

*Now getting area planted
use "${Nigeria_GHS_W3_raw_data}/sect11f_plantingw3.dta", clear
ren plotid plot_id
*Merging in gender of plot manager
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas", nogen keep(1 3)
*Using conversion factors from BID
*Heaps
gen conversion = 0.00012 if zone==1 & s11fq1b==1
replace conversion = 0.00016 if zone==2 & s11fq1b==1
replace conversion = 0.00011 if zone==3 & s11fq1b==1
replace conversion = 0.00019 if zone==4 & s11fq1b==1
replace conversion = 0.00021 if zone==5 & s11fq1b==1
replace conversion = 0.00012 if zone==6 & s11fq1b==1
*Ridges
replace conversion = 0.0027 if zone==1 & s11fq1b==2
replace conversion = 0.004 if zone==2 & s11fq1b==2
replace conversion = 0.00494 if zone==3 & s11fq1b==2
replace conversion = 0.0023 if zone==4 & s11fq1b==2
replace conversion = 0.0023 if zone==5 & s11fq1b==2
replace conversion = 0.0001 if zone==6 & s11fq1b==2
*Stands
replace conversion = 0.00006 if zone==1 & s11fq1b==3
replace conversion = 0.00016 if zone==2 & s11fq1b==3
replace conversion = 0.00004 if zone==3 & s11fq1b==3
replace conversion = 0.00004 if zone==4 & s11fq1b==3
replace conversion = 0.00013 if zone==5 & s11fq1b==3
replace conversion = 0.00041 if zone==6 & s11fq1b==3
*Plots
replace conversion = 0.0667 if s11fq1b==4
*Acres
replace conversion = 0.404686 if s11fq1b==5
*Hectares
replace conversion = 1 if s11fq1b==6
*Square meters
replace conversion = 0.0001 if s11fq1b==7
gen ha_planted = s11fq1a*conversion
*Rescaling
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas", nogen keep(1 3)
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", nogen keep(1 3)
bys plot_id hhid: egen total_ha_planted = total(ha_planted)
replace ha_planted = ha_planted*(field_size/total_ha_planted) if total_ha_planted>field_size
gen ha_planted_male = ha_planted if dm_gender==1
gen ha_planted_female = ha_planted if dm_gender==2
gen ha_planted_mixed = ha_planted if dm_gender==3
ren plot_id plotid
*Merging in rental rate (both at aggregate level and at household level)
merge m:1 hhid plotid using "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3.dta", nogen keep(1 3)
egen plot_rent = rowtotal(s11b1q13 s11b1q14)										// total paid for rent (on plot)
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_rental_rate_hh.dta", nogen keep(1 3)			// household's average rental rate (total rent paid divided by total ha rented at household level)
merge m:1 zone state lga sector using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_rental_rate.dta", nogen keep(1 3)	// aggregate rental rates
gen value_owned_land = ha_planted*ha_rental_rate if (plot_rent==. | plot_rent==0)		// generate value owned using aggregate rental rate - only for plots that were not rented
replace value_owned_land = ha_planted*ha_rental_hh if (plot_rent==. | plot_rent==0) & ha_rental_hh!=. & ha_rental_hh!=0
*Repeating for male
gen value_owned_land_male = ha_planted*ha_rental_rate if (plot_rent==. | plot_rent==0) & dm_gender==1
replace value_owned_land_male = ha_planted*ha_rental_hh if (plot_rent==. | plot_rent==0) & ha_rental_hh!=. & ha_rental_hh!=0 & dm_gender==1
*Repeating for female
gen value_owned_land_female = ha_planted*ha_rental_rate if (plot_rent==. | plot_rent==0) & dm_gender==2
replace value_owned_land_female = ha_planted*ha_rental_hh if (plot_rent==. | plot_rent==0) & ha_rental_hh!=. & ha_rental_hh!=0 & dm_gender==2
*Repeating for mixed
gen value_owned_land_mixed = ha_planted*ha_rental_rate if (plot_rent==. | plot_rent==0) & dm_gender==3
replace value_owned_land_mixed = ha_planted*ha_rental_hh if (plot_rent==. | plot_rent==0) & ha_rental_hh!=. & ha_rental_hh!=0 & dm_gender==3
collapse (sum) value_owned_land* ha_planted*, by(hhid)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_land.dta", replace

*Prep labor costs
use "${Nigeria_GHS_W3_raw_data}/sect11c1_plantingw3.dta", clear
*Merging in gender of plot manager
ren plotid plot_id
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", nogen keep(1 3) keepusing (dm_gender)
gen male_hired_days = s11c1q3*s11c1q2
gen female_hired_days = s11c1q6*s11c1q5
gen child_hired_days = s11c1q9*s11c1q8
gen wage_male = s11c1q4/s11c1q2		// total paid per day to all men divided by number of men
gen wage_female = s11c1q7/s11c1q5
gen wage_child = s11c1q10/s11c1q8
sum wage_*, d
recode wage_* (0=.)
gen value_male_hired = male_hired_days*wage_male
gen value_female_hired = female_hired_days*wage_female
gen value_child_hired = child_hired_days*wage_child
*Generating average wage at the household level
preserve
foreach i in male female child{
	gen wage_`i'_total = wage_`i'*`i'_hired_days		// wage per day times number of hired days
}
collapse (sum) wage_*_total *hired_days, by(hhid)		// summing total paid to all workers and total number of hired days to household level.
foreach i in male female child{
	gen wage_`i'_hh = wage_`i'_total/`i'_hired_days		// generating an average household wage as total wage paid divided by total hired days (naira per day)
}
keep wage_*_hh hhid
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_wages_prep.dta", replace
restore

*Geographic medians
foreach i in male female child{
	recode wage_`i' (0=.)
	bys zone state lga sector: egen `i'_count_sect = count(wage_`i')
	bys zone state lga sector: egen `i'_price_sect = median(wage_`i')
	bys zone state lga: egen `i'_count_lga = count(wage_`i')
	bys zone state lga: egen `i'_price_lga = median(wage_`i')
	bys zone state: egen `i'_count_state = count(wage_`i')
	bys zone state: egen `i'_price_state = median(wage_`i')
	bys zone: egen `i'_count_zone = count(wage_`i')
	bys zone: egen `i'_price_zone = median(wage_`i')
	egen `i'_price_nat = median(wage_`i')
	*Generating wage
	gen `i'_wage_rate = `i'_price_sect if `i'_count_sect>=10
	replace `i'_wage_rate = `i'_price_lga if `i'_count_lga>=10 & `i'_wage_rate==.
	replace `i'_wage_rate = `i'_price_state if `i'_count_state>=10 & `i'_wage_rate==.
	replace `i'_wage_rate = `i'_price_zone if `i'_count_zone>=10 & `i'_wage_rate==.
	replace `i'_wage_rate = `i'_price_nat if `i'_wage_rate==.
}

*To do family labor, we first need to merge in gender
preserve
use "${Nigeria_GHS_W3_raw_data}/sect1_plantingw3.dta", clear
ren indiv pid
isid hhid pid
gen male = s1q2==1
gen age = s1q6
keep hhid pid age male
tempfile members
save `members', replace
restore
*Starting with "member 1"
gen pid = s11c1q1a1
merge m:1 hhid pid using `members', gen(fam_merge1) keep(1 3)
count if s11c1q1a3!=0 & s11c1q1a3!=. & fam_merge1==1
ren male male1
ren pid pid1
ren age age1
*Now "member 2"
gen pid = s11c1q1b1
merge m:1 hhid pid using `members', gen(fam_merge2) keep(1 3)
ren male male2
ren pid pid12
ren age age2
*Now "member 3"
gen pid = s11c1q1c1
merge m:1 hhid pid using `members', gen(fam_merge3) keep(1 3)
ren male male3
ren pid pid13
ren age age3
*Now "member 4"
gen pid = s11c1q1d1
merge m:1 hhid pid using `members', gen(fam_merge4) keep(1 3)
ren male male4
ren pid pid14
ren age age4
recode male1 male2 male3 male4 (.=1)
gen male_fam_days1 = s11c1q1a2*s11c1q1a3 if male1 & age1>=15
gen male_fam_days2 = s11c1q1b2*s11c1q1b3 if male2 & age2>=15
gen male_fam_days3 = s11c1q1c2*s11c1q1c3 if male3 & age3>=15
gen male_fam_days4 = s11c1q1d2*s11c1q1d3 if male4 & age4>=15
gen female_fam_days1 = s11c1q1a2*s11c1q1a3 if !male1 & age1>=15
gen female_fam_days2 = s11c1q1b2*s11c1q1b3 if !male2 & age2>=15
gen female_fam_days3 = s11c1q1c2*s11c1q1c3 if !male3 & age3>=15
gen female_fam_days4 = s11c1q1d2*s11c1q1d3 if !male4 & age4>=15
gen child_fam_days1 = s11c1q1a2*s11c1q1a3 if age1<15
gen child_fam_days2 = s11c1q1b2*s11c1q1b3 if age2<15
gen child_fam_days3 = s11c1q1c2*s11c1q1c3 if age3<15
gen child_fam_days4 = s11c1q1d2*s11c1q1d3 if age4<15
egen total_male_fam_days = rowtotal(male_fam_days*)
egen total_female_fam_days = rowtotal(female_fam_days*)
egen total_child_fam_days = rowtotal(child_fam_days*)
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_wages_prep.dta", nogen keep(1 3)
*Now, valuing household labor
*Using aggregate wages
gen value_male_nonhired = total_male_fam_days*male_wage_rate
gen value_female_nonhired = total_female_fam_days*female_wage_rate
gen value_child_nonhired = total_child_fam_days*child_wage_rate
*Now, replacing with household wage rate where available
replace value_male_nonhired = total_male_fam_days*wage_male_hh if (wage_male_hh!=. & wage_male_hh!=0)
replace value_female_nonhired = total_female_fam_days*wage_female_hh if (wage_female_hh!=. & wage_female_hh!=0)
replace value_child_nonhired = total_child_fam_days*wage_child_hh if (wage_child_hh!=. & wage_child_hh!=0)
egen value_hired_labor = rowtotal(value_male_hired value_female_hired value_child_hired)
egen value_fam_labor = rowtotal(value_male_nonhired value_female_nonhired value_child_nonhired)
gen value_hired_labor_male = value_hired_labor if dm_gender==1
gen value_hired_labor_female = value_hired_labor if dm_gender==2
gen value_hired_labor_mixed = value_hired_labor if dm_gender==3
gen value_fam_labor_male = value_fam_labor if dm_gender==1
gen value_fam_labor_female = value_fam_labor if dm_gender==2
gen value_fam_labor_mixed = value_fam_labor if dm_gender==3
collapse (sum) value_hired* value_fam*, by(hhid)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_prep_labor.dta", replace

* Between planting and harvest labor
use "${Nigeria_GHS_W3_raw_data}/secta2_harvestw3.dta", clear
*Merging in gender of plot manager
ren plotid plot_id
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", nogen keep(1 3) keepusing(dm_gender)
gen male_hired_days = sa2q1d*sa2q1c
gen female_hired_days = sa2q1g*sa2q1f
gen child_hired_days = sa2q1j*sa2q1i
gen wage_male = sa2q1e/sa2q1c
gen wage_female = sa2q1h/sa2q1f
gen wage_child = sa2q1k/sa2q1i
recode wage_* (0=.)
gen value_male_hired = male_hired_days*sa2q1e
gen value_female_hired = female_hired_days*sa2q1h
gen value_child_hired = child_hired_days*sa2q1k
*Generating average wage at the household level
preserve
foreach i in male female child{
	gen wage_`i'_total = wage_`i'*`i'_hired_days
}
collapse (sum) wage_*_total *hired_days, by(hhid)		// summing total paid to all workers and total number of hired days to household level.
foreach i in male female child{
	gen wage_`i'_hh = wage_`i'_total/`i'_hired_days	// generating an average household wage as total wage paid divided by total hired days (naira per day)
}
keep wage_*_hh hhid
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_wages_mid.dta", replace
restore

*Geographic medians
foreach i in male female child{
	recode wage_`i' (0=.)
	bys zone state lga sector: egen `i'_count_sect = count(wage_`i')
	bys zone state lga sector: egen `i'_price_sect = median(wage_`i')
	bys zone state lga: egen `i'_count_lga = count(wage_`i')
	bys zone state lga: egen `i'_price_lga = median(wage_`i')
	bys zone state: egen `i'_count_state = count(wage_`i')
	bys zone state: egen `i'_price_state = median(wage_`i')
	bys zone: egen `i'_count_zone = count(wage_`i')
	bys zone: egen `i'_price_zone = median(wage_`i')
	egen `i'_price_nat = median(wage_`i')
	*Generating wage
	gen `i'_wage_rate = `i'_price_sect if `i'_count_sect>=10
	replace `i'_wage_rate = `i'_price_lga if `i'_count_lga>=10 & `i'_wage_rate==.
	replace `i'_wage_rate = `i'_price_state if `i'_count_state>=10 & `i'_wage_rate==.
	replace `i'_wage_rate = `i'_price_zone if `i'_count_zone>=10 & `i'_wage_rate==.
	replace `i'_wage_rate = `i'_price_nat if `i'_wage_rate==.
}

*To do family labor, we first need to merge in gender
preserve
use "${Nigeria_GHS_W3_raw_data}/sect1_harvestw3.dta", clear
ren indiv pid
isid hhid pid
gen male = s1q2==1
gen age = s1q4
keep hhid pid age male
tempfile members
save `members', replace
restore
*Starting with "member 1"
gen pid = sa2q1b_a1
merge m:1 hhid pid using `members', gen(fam_merge1) keep(1 3)
count if sa2q1b_a3!=0 & sa2q1b_a3!=. & fam_merge1==1
ren male male1
ren pid pid1
ren age age1
*Now "member 2"
gen pid = sa2q1b_b1
merge m:1 hhid pid using `members', gen(fam_merge2) keep(1 3)
ren male male2
ren pid pid12
ren age age2
*Now "member 3"
gen pid = sa2q1b_c1
merge m:1 hhid pid using `members', gen(fam_merge3) keep(1 3)
ren male male3
ren pid pid13
ren age age3
*Now "member 4"
gen pid = sa2q1b_d1
merge m:1 hhid pid using `members', gen(fam_merge4) keep(1 3)
ren male male4
ren pid pid14
ren age age4
recode male1 male2 male3 male4 (.=1)
gen male_fam_days1 = sa2q1b_a2*sa2q1b_a3 if male1 & age1>=15
gen male_fam_days2 = sa2q1b_b2*sa2q1b_b3 if male2 & age2>=15
gen male_fam_days3 = sa2q1b_c2*sa2q1b_c3 if male3 & age3>=15
gen male_fam_days4 = sa2q1b_d2*sa2q1b_d3 if male4 & age4>=15
gen female_fam_days1 = sa2q1b_a2*sa2q1b_a3 if !male1 & age1>=15
gen female_fam_days2 = sa2q1b_b2*sa2q1b_b3 if !male2 & age2>=15
gen female_fam_days3 = sa2q1b_c2*sa2q1b_c3 if !male3 & age3>=15
gen female_fam_days4 = sa2q1b_d2*sa2q1b_d3 if !male4 & age4>=15
gen child_fam_days1 = sa2q1b_a2*sa2q1b_a3 if age1<15
gen child_fam_days2 = sa2q1b_b2*sa2q1b_b3 if age2<15
gen child_fam_days3 = sa2q1b_c2*sa2q1b_c3 if age3<15
gen child_fam_days4 = sa2q1b_d2*sa2q1b_d3 if age4<15
egen total_male_fam_days = rowtotal(male_fam_days*)
egen total_female_fam_days = rowtotal(female_fam_days*)
egen total_child_fam_days = rowtotal(child_fam_days*)
*And here are the total costs
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_wages_mid.dta", nogen keep(1 3)
*Aggregat wages first
gen value_male_nonhired = total_male_fam_days*male_wage_rate
gen value_female_nonhired = total_female_fam_days*female_wage_rate
gen value_child_nonhired = total_child_fam_days*child_wage_rate
*Now household wages when available
replace value_male_nonhired = total_male_fam_days*wage_male_hh if (wage_male_hh!=. & wage_male_hh!=0)
replace value_female_nonhired = total_female_fam_days*wage_female_hh if (wage_female_hh!=. & wage_female_hh!=0)
replace value_child_nonhired = total_child_fam_days*wage_child_hh if (wage_child_hh!=. & wage_child_hh!=0)
egen value_hired_mid_labor = rowtotal(value_male_hired value_female_hired value_child_hired)
egen value_fam_mid_labor = rowtotal(value_male_nonhired value_female_nonhired value_child_nonhired)
gen value_hired_mid_labor_male = value_hired_mid_labor if dm_gender==1
gen value_hired_mid_labor_female = value_hired_mid_labor if dm_gender==2
gen value_hired_mid_labor_mixed = value_hired_mid_labor if dm_gender==3
gen value_fam_mid_labor_male = value_fam_mid_labor if dm_gender==1
gen value_fam_mid_labor_female = value_fam_mid_labor if dm_gender==2
gen value_fam_mid_labor_mixed = value_fam_mid_labor if dm_gender==3
collapse (sum) value_hired* value_fam*, by(hhid)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_mid_labor.dta", replace

* Harvest labor
use "${Nigeria_GHS_W3_raw_data}/secta2_harvestw3.dta", clear
*Merging in gender of plot manager
ren plotid plot_id
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", nogen keep(1 3) keepusing(dm_gender)
gen male_hired_days = sa2q3*sa2q2
gen female_hired_days = sa2q6*sa2q5
gen child_hired_days = sa2q9*sa2q8
gen wage_male = sa2q4/sa2q2
gen wage_female = sa2q7/sa2q5
gen wage_child = sa2q10/sa2q8
recode wage_* (0=.)
gen value_male_hired = male_hired_days*wage_male
gen value_female_hired = female_hired_days*wage_female
gen value_child_hired = child_hired_days*wage_child
*Generating average wage at the household level
preserve
foreach i in male female child{
	gen wage_`i'_total = wage_`i'*`i'_hired_days
}
collapse (sum) wage_*_total *hired_days, by(hhid)		// summing total paid to all workers and total number of hired days to household level.
foreach i in male female child{
	gen wage_`i'_hh = wage_`i'_total/`i'_hired_days	// generating an average household wage as total wage paid divided by total hired days (naira per day)
}
keep wage_*_hh hhid
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_wages_harv.dta", replace
restore

*Geographic medians
foreach i in male female child{
	recode wage_`i' (0=.)
	bys zone state lga sector: egen `i'_count_sect = count(wage_`i')
	bys zone state lga sector: egen `i'_price_sect = median(wage_`i')
	bys zone state lga: egen `i'_count_lga = count(wage_`i')
	bys zone state lga: egen `i'_price_lga = median(wage_`i')
	bys zone state: egen `i'_count_state = count(wage_`i')
	bys zone state: egen `i'_price_state = median(wage_`i')
	bys zone: egen `i'_count_zone = count(wage_`i')
	bys zone: egen `i'_price_zone = median(wage_`i')
	egen `i'_price_nat = median(wage_`i')
	*Generating wage
	gen `i'_wage_rate = `i'_price_sect if `i'_count_sect>=10
	replace `i'_wage_rate = `i'_price_lga if `i'_count_lga>=10 & `i'_wage_rate==.
	replace `i'_wage_rate = `i'_price_state if `i'_count_state>=10 & `i'_wage_rate==.
	replace `i'_wage_rate = `i'_price_zone if `i'_count_zone>=10 & `i'_wage_rate==.
	replace `i'_wage_rate = `i'_price_nat if `i'_wage_rate==.
}

*To do family labor, we first need to merge in gender
preserve
use "${Nigeria_GHS_W3_raw_data}/sect1_harvestw3.dta", clear
ren indiv pid
isid hhid pid
gen male = s1q2==1
gen age = s1q4
keep hhid pid age male
tempfile members
save `members', replace
restore
*Starting with "member 1"
gen pid = sa2q1a1
merge m:1 hhid pid using `members', gen(fam_merge1) keep(1 3)
ren male male1
ren pid pid1
ren age age1
*Now "member 2"
gen pid = sa2q1b1
merge m:1 hhid pid using `members', gen(fam_merge2) keep(1 3)
ren male male2
ren pid pid12
ren age age2
*Now "member 3"
gen pid = sa2q1c1
merge m:1 hhid pid using `members', gen(fam_merge3) keep(1 3)
ren male male3
ren pid pid13
ren age age3
*Now "member 4"
gen pid = sa2q1d1
merge m:1 hhid pid using `members', gen(fam_merge4) keep(1 3)
ren male male4
ren pid pid14
ren age age4
*Now "member 5"
gen pid = sa2q1e1
merge m:1 hhid pid using `members', gen(fam_merge5) keep(1 3)
ren male male5
ren pid pid15
ren age age5
*Now "member 6"
gen pid = sa2q1f1
merge m:1 hhid pid using `members', gen(fam_merge6) keep(1 3)
ren male male6
ren pid pid16
ren age age6
*Now "member 7"
gen pid = sa2q1g1
merge m:1 hhid pid using `members', gen(fam_merge7) keep(1 3)
ren male male7
ren pid pid17
ren age age7
*Now "member 8"
gen pid = sa2q1h1
merge m:1 hhid pid using `members', gen(fam_merge8) keep(1 3)
ren male male8
ren pid pid18
ren age age8
recode male1 male2 male3 male4 male5 male6 male7 male8 (.=1)
gen male_fam_days1 = sa2q1a2*sa2q1a3 if male1 & age1>=15
gen male_fam_days2 = sa2q1b2*sa2q1b3 if male2 & age2>=15
gen male_fam_days3 = sa2q1c2*sa2q1c3 if male3 & age3>=15
gen male_fam_days4 = sa2q1d2*sa2q1d3 if male4 & age4>=15
gen male_fam_days5 = sa2q1e2*sa2q1e3 if male5 & age5>=15
gen male_fam_days6 = sa2q1f2*sa2q1f3 if male6 & age6>=15
gen male_fam_days7 = sa2q1g2*sa2q1g3 if male7 & age7>=15
gen male_fam_days8 = sa2q1h2*sa2q1h3 if male8 & age8>=15
gen female_fam_days1 = sa2q1a2*sa2q1a3 if !male1 & age1>=15
gen female_fam_days2 = sa2q1b2*sa2q1b3 if !male2 & age2>=15
gen female_fam_days3 = sa2q1c2*sa2q1c3 if !male3 & age3>=15
gen female_fam_days4 = sa2q1d2*sa2q1d3 if !male4 & age4>=15
gen female_fam_days5 = sa2q1e2*sa2q1e3 if !male5 & age5>=15
gen female_fam_days6 = sa2q1f2*sa2q1f3 if !male6 & age6>=15
gen female_fam_days7 = sa2q1g2*sa2q1g3 if !male7 & age7>=15
gen female_fam_days8 = sa2q1h2*sa2q1h3 if !male8 & age8>=15
gen child_fam_days1 = sa2q1a2*sa2q1a3 if age1<15
gen child_fam_days2 = sa2q1b2*sa2q1b3 if age2<15
gen child_fam_days3 = sa2q1c2*sa2q1c3 if age3<15
gen child_fam_days4 = sa2q1d2*sa2q1d3 if age4<15
gen child_fam_days5 = sa2q1e2*sa2q1e3 if age5<15
gen child_fam_days6 = sa2q1f2*sa2q1f3 if age6<15
gen child_fam_days7 = sa2q1g2*sa2q1g3 if age7<15
gen child_fam_days8 = sa2q1h2*sa2q1h3 if age8<15
egen total_male_fam_days = rowtotal(male_fam_days*)
egen total_female_fam_days = rowtotal(female_fam_days*)
egen total_child_fam_days = rowtotal(child_fam_days*)
*Total costs
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_wages_harv.dta", nogen keep(1 3)
*Aggregate wages first
gen value_male_nonhired = total_male_fam_days*male_wage_rate
gen value_female_nonhired = total_female_fam_days*female_wage_rate
gen value_child_nonhired = total_child_fam_days*child_wage_rate
*Now household wages when available
replace value_male_nonhired = total_male_fam_days*wage_male_hh if (wage_male_hh!=. & wage_male_hh!=0)
replace value_female_nonhired = total_female_fam_days*wage_female_hh if (wage_female_hh!=. & wage_female_hh!=0)
replace value_child_nonhired = total_child_fam_days*wage_child_hh if (wage_child_hh!=. & wage_child_hh!=0)
egen value_hired_harv_labor = rowtotal(value_male_hired value_female_hired value_child_hired)
egen value_fam_harv_labor = rowtotal(value_male_nonhired value_female_nonhired value_child_nonhired)
gen value_hired_harv_labor_male = value_hired_harv_labor if dm_gender==1
gen value_hired_harv_labor_female = value_hired_harv_labor if dm_gender==2
gen value_hired_harv_labor_mixed = value_hired_harv_labor if dm_gender==3
gen value_fam_harv_labor_male = value_fam_harv_labor if dm_gender==1
gen value_fam_harv_labor_female = value_fam_harv_labor if dm_gender==2
gen value_fam_harv_labor_mixed = value_fam_harv_labor if dm_gender==3
collapse (sum) value_hired* value_fam*, by(hhid)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_harv_labor.dta", replace


*Seeds
use "${Nigeria_GHS_W3_raw_data}/sect11e_plantingw3.dta", clear
ren plotid plot_id
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", nogen keep(1 3) keepusing(dm_gender)

gen same_unit_own = s11eq6b==s11eq18b if s11eq6b!=0 & s11eq6b!=. & s11eq18b!=0 & s11eq18b!=.
gen same_unit_free = s11eq10b==s11eq18b if s11eq10b!=0 & s11eq10b!=. & s11eq18b!=0 & s11eq18b!=.

preserve
use "${Nigeria_GHS_W3_raw_data}/ag_conv_w3.dta", clear
ren conv_NC_1 conv_zone_1
ren conv_NE_2 conv_zone_2
ren conv_NW_3 conv_zone_3
ren conv_SE_4 conv_zone_4
ren conv_SS_5 conv_zone_5
ren conv_SW_6 conv_zone_6
reshape long conv_zone_, i(crop_cd unit_cd) j(zone)
ren conv_zone_ conversion
tempfile conversion
save `conversion', replace
restore
*Merging with zone and unit code
gen unit_cd = s11eq18b
gen crop_cd = s11eq17
tab unit_cd
merge m:1 unit_cd crop_cd zone using `conversion', nogen keep(1 3)
egen value_seeds_purchased = rowtotal(s11eq19 s11eq21 s11eq31 s11eq33)
gen value_seeds_purchased_male = value_seeds_purchased if dm_gender==1
gen value_seeds_purchased_female = value_seeds_purchased if dm_gender==2
gen value_seeds_purchased_mixed = value_seeds_purchased if dm_gender==3
collapse (sum) value_seeds_purchased*, by(hhid)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_seed.dta", replace


* Pesticides/Herbicides
use "${Nigeria_GHS_W3_raw_data}/secta11c2_harvestw3.dta", clear
ren plotid plot_id
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", nogen keep(1 3) keepusing(dm_gender)
egen value_pesticide = rowtotal(s11c2q4a s11c2q4b s11c2q5a s11c2q5b)
*Constructing pesticide prices
replace s11c2q2a = s11c2q2a/1000 if s11c2q2b==2
replace s11c2q2a = s11c2q2a/100 if s11c2q2b==4
recode s11c2q2b (2=1) (4=3) (5=3)
gen pesticide_price = value_pesticide/s11c2q2a if s11c2q2b==3
recode pesticide_price (0=.)
*Constructing household values
preserve
keep if value_pesticide!=0 & value_pesticide!=. & s11c2q2b==3
collapse (sum) value_pesticide s11c2q2a, by(hhid)
gen pesticide_price_hh = value_pesticide/s11c2q2a
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_pest_price.dta", replace
restore
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_pest_price.dta", nogen

bys zone state lga sector: egen pest_count_sect = count(pesticide_price)
bys zone state lga sector: egen pest_price_sect = median(pesticide_price)
bys zone state lga: egen pest_count_lga = count(pesticide_price)
bys zone state lga: egen pest_price_lga = median(pesticide_price)
bys zone state: egen pest_count_state = count(pesticide_price)
bys zone state: egen pest_price_state = median(pesticide_price)
bys zone: egen pest_count_zone = count(pesticide_price)
bys zone: egen pest_price_zone = median(pesticide_price)
egen pest_price_nat = median(pesticide_price)
gen value_pesticide_free = s11c2q7a*pest_price_sect if pest_count_sect>=10
replace value_pesticide_free = s11c2q7a*pest_price_lga if pest_count_lga>=10 & value_pesticide_free==.
replace value_pesticide_free = s11c2q7a*pest_price_state if pest_count_state>=10 & value_pesticide_free==.
replace value_pesticide_free = s11c2q7a*pest_price_zone if pest_count_zone>=10 & value_pesticide_free==.
replace value_pesticide_free = s11c2q7a*pest_price_nat if value_pesticide_free==.
replace value_pesticide_free = s11c2q7a*pesticide_price_hh if pesticide_price_hh!=0 & pesticide_price_hh!=.
*Now herbicide
egen value_herbicide = rowtotal(s11c2q13a s11c2q13b s11c2q14a s11c2q14b)
*Constructing herbicide prices
replace s11c2q11a = s11c2q11a/1000 if s11c2q11b==2
replace s11c2q11a = s11c2q11a/100 if s11c2q11b==4
recode s11c2q11b (2=1) (4=3)
gen herbicide_price = value_herbicide/s11c2q11a
recode herbicide_price (0=.)
gen value_herb_kg = value_herbicide if s11c2q11b==1
gen value_herb_l = value_herbicide if s11c2q11b==3
gen qty_herb_kg = s11c2q11a if s11c2q11b==1
gen qty_herb_l = s11c2q11a if s11c2q11b==3
*Constructing household values
preserve
replace qty_herb_kg = . if value_herb_kg==. | value_herb_kg==0
replace qty_herb_l = . if value_herb_l==. | value_herb_l==0
collapse (sum) value_herb_* qty_herb_*, by(hhid)
gen herb_price_hh_kg = value_herb_kg/qty_herb_kg	// naira per kg
gen herb_price_hh_l = value_herb_l/qty_herb_l		// naira per l
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_herb_price.dta", replace
restore
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_herb_price.dta", nogen
drop value_herb_*
bys s11c2q11b zone state lga sector: egen herb_count_sect = count(herbicide_price)
bys s11c2q11b zone state lga sector: egen herb_price_sect = median(herbicide_price)
bys s11c2q11b zone state lga: egen herb_count_lga = count(herbicide_price)
bys s11c2q11b zone state lga: egen herb_price_lga = median(herbicide_price)
bys s11c2q11b zone state: egen herb_count_state = count(herbicide_price)
bys s11c2q11b zone state: egen herb_price_state = median(herbicide_price)
bys s11c2q11b zone: egen herb_count_zone = count(herbicide_price)
bys s11c2q11b zone: egen herb_price_zone = median(herbicide_price)
bys s11c2q11b: egen herb_price_nat = median(herbicide_price)
gen herb_price_kg = herb_price_sect if herb_count_sect>=10 & s11c2q11b==1
replace herb_price_kg = herb_price_lga if herb_count_lga>=10 & s11c2q11b==1 & herb_price_kg==.
replace herb_price_kg = herb_price_state if herb_count_state>=10 & s11c2q11b==1 & herb_price_kg==.
replace herb_price_kg = herb_price_zone if herb_count_zone>=10 & s11c2q11b==1 & herb_price_kg==.
replace herb_price_kg = herb_price_nat if s11c2q11b==1 & herb_price_kg==.
replace herb_price_kg = herb_price_hh_kg if herb_price_hh_kg!=. & herb_price_hh_kg!=0
gen herb_price_l = herb_price_sect if herb_count_sect>=10 & s11c2q11b==3
replace herb_price_l = herb_price_lga if herb_count_lga>=10 & s11c2q11b==3 & herb_price_l==.
replace herb_price_l = herb_price_state if herb_count_state>=10 & s11c2q11b==3 & herb_price_l==.
replace herb_price_l = herb_price_zone if herb_count_zone>=10 & s11c2q11b==3 & herb_price_l==.
replace herb_price_l = herb_price_nat if s11c2q11b==3 & herb_price_l==.
replace herb_price_l = herb_price_hh_l if herb_price_hh_l!=. & herb_price_hh_l!=0
gen value_herbicide_free = s11c2q7a*herb_price_kg if s11c2q16b==1			// for kg
replace value_herbicide_free = s11c2q7a*herb_price_l if s11c2q16b==3		// for l
*NOTE: Assuming 0.5 acres per day (https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4635562/ says a pair of draft cattle can plow 1 acre in about 2.2 days, at 4.3 hours per day)
gen paid_cash = s11c2q23a if s11c2q23b==6		// full planting period
replace paid_cash = s11c2q23a*s11c2q21*5 if s11c2q23b==1				// ASSUME FIVE HOURS PER DAY: payment times number of days times 5 if unit is payment per hour
replace paid_cash = s11c2q23a*s11c2q21 if s11c2q23b==2					// payment times number of days if unit is payment per day
replace paid_cash = s11c2q23a*s11c2q21*0.5 if s11c2q23b==4				// acres times 0.5 to put payment into days. then times days (e.g. if you hired for one day but paid "per acre" and they did half an acre, you pay half of the "per acre" price)
replace paid_cash = s11c2q23a*s11c2q21*(0.5/2.47105) if s11c2q23b==5	// hectares times 2.47105 for acres, then acres times 0.5 to put payment into days. then times days (e.g. if you hired for one day but paid "per hectare" and they did half an acre, you pay (0.5/2.47105)~0.202 of the "per hectare" price)
replace paid_cash = s11c2q23a*s11c2q21/8 if s11c2q23c=="8 Days"			// "Other" unit: payment divided by 8 times number of days if reported as "8 days"
gen paid_inkind = s11c2q24a if s11c2q24b==6		// full planting period
replace paid_inkind = s11c2q24a*s11c2q21*5 if s11c2q24b==1		// ASSUME FIVE HOURS PER DAY: payment times number of days times 5 if unit is payment per hour
replace paid_inkind = s11c2q24a*s11c2q21 if s11c2q24b==2		// payment times number of days if unit is payment per day
*No other units reported
*Animal rent and machine rent
egen value_animal_rent = rowtotal(paid_cash paid_inkind s11c2q25)
egen value_machine_rent = rowtotal(s11c2q32 s11c2q33)
*Generating gender vars
foreach i in value_pesticide value_pesticide_free value_herbicide value_herbicide_free value_animal_rent value_machine_rent{
	gen `i'_male = `i' if dm_gender==1
	gen `i'_female = `i' if dm_gender==2
	gen `i'_mixed = `i' if dm_gender==3
}
collapse (sum) value_*, by(hhid)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_inputs.dta", replace

* Fert/Pest
use "${Nigeria_GHS_W3_raw_data}/secta11d_harvestw3.dta", clear
ren plotid plot_id
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", nogen keep(1 3) keepusing(dm_gender)
*First commercial source:
egen commercial_fert_total = rowtotal(s11dq16a s11dq28a)			// total quantity
egen commercial_fert_purchased = rowtotal(s11dq19 s11dq29)			// total PAID
replace commercial_fert_total = commercial_fert_total/1000 if s11dq16b==2			// grams to kilograms
recode s11dq16b (2=1)				// recoding units, as well
gen fert_price = commercial_fert_purchased/commercial_fert_total
gen fert_price_kg = fert_price if s11dq16b==1
gen fert_price_l = fert_price if s11dq16b==3
*Getting a household average price (summing across plots)
preserve
gen fert_purchased_kg = commercial_fert_total if s11dq16b==1		// total kg purchased
gen fert_purchased_l = commercial_fert_total if s11dq16b==3			// total l purchased
gen fert_paid_kg = commercial_fert_purchased if s11dq16b==1			// total paid for kg
gen fert_paid_l = commercial_fert_purchased if s11dq16b==3			// total paid for l
collapse (sum) fert_purchased_* fert_paid_*, by(hhid)
gen fert_price_hh = fert_paid_kg/fert_purchased_kg					// total paid per unit
replace fert_price_hh = fert_paid_l/fert_purchased_l if fert_price_hh==.
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fert_price_hh.dta", replace
restore
*Merging prices back in immediately
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fert_price_hh.dta", nogen assert(3)
*Geographic price medians
foreach i in kg l{
	recode fert_price_`i' (0=.)
	bys zone state lga sector: egen `i'_fert_count_sect = count(fert_price_`i')
	bys zone state lga sector: egen `i'_fert_price_sect = median(fert_price_`i')
	bys zone state lga: egen `i'_fert_count_lga = count(fert_price_`i')
	bys zone state lga: egen `i'_fert_price_lga = median(fert_price_`i')
	bys zone state: egen `i'_fert_count_state = count(fert_price_`i')
	bys zone state: egen `i'_fert_price_state = median(fert_price_`i')
	bys zone: egen `i'_fert_count_zone = count(fert_price_`i')
	bys zone: egen `i'_fert_price_zone = median(fert_price_`i')
	egen `i'_fert_price_nat = median(fert_price_`i')
	gen `i'_price = `i'_fert_price_sect if `i'_fert_count_sect>=10
	replace `i'_price = `i'_fert_price_lga if `i'_fert_count_lga>=10 & `i'_price==.
	replace `i'_price = `i'_fert_price_state if `i'_fert_count_state>=10 & `i'_price==.
	replace `i'_price = `i'_fert_price_zone if `i'_fert_count_zone>=10 & `i'_price==.
	replace `i'_price = `i'_fert_price_nat if `i'_price==.
}
*"Left over" fertilizer
gen left_fert = s11dq4a
replace left_fert = s11dq4a/1000 if s11dq4b==2			// g to kg
gen value_fert_leftover = left_fert*kg_price if s11dq4b==1 | s11dq4b==2
replace value_fert_leftover = left_fert*l_price if s11dq4b==3
replace value_fert_leftover = left_fert*fert_price_hh if fert_price_hh!=0 & fert_price_hh!=.		// replacing with household value when available
*"Free" fertilizer
gen free_fert = sect11dq8a
replace free_fert = sect11dq8a/1000 if sect11dq8b==2			// g to kg
gen value_fert_free = free_fert*kg_price
replace value_fert_free = free_fert*fert_price_hh if fert_price_hh!=0 & fert_price_hh!=.			// replacing with household value when available
egen value_inorg_purchased = rowtotal(s11dq5d commercial_fert_purchased s11dq10 s11dq17 s11dq31)		// includes all payments (including transport for free fertilizer)
egen value_inorg_notpurchased = rowtotal(value_fert_left value_fert_free)
*Total inorganic fertilizer applied
*Commercial fertilizer
*NOTE: Treating 1 L = 1 KG
gen fert1_kg = s11dq16a		// all l and kg
gen fert2_kg = s11dq28a if s11dq28b==1 | s11dq28b==3		// l and kg
replace fert2_kg = s11dq28a/1000 if s11dq28b==2			// g
egen commercial_fert_kg = rowtotal(fert1_kg fert2_kg)
*"E-wallet subsidy" fertilizer
*All are already in kg
tab s11dq5c2
gen subsidy_fert = s11dq5c1				// all are kg
*"Left over" fertilizer
*NOTE: Treating 1 L = 1 KG
gen left_fert_kg = s11dq4a if s11dq4b==1 | s11dq4b==3	// kg and l
replace left_fert_kg = s11dq4a/1000 if s11dq4b==2		// g
*"Free" fertilizer
*NOTE: No liters here
gen free_fert_kg = sect11dq8a if sect11dq8b==1
replace free_fert_kg = sect11dq8a/1000 if sect11dq8b==2		// g
*Now getting total - four types of inorganic (commercial, leftover, free, and subsidy)
egen fert_inorg_kg = rowtotal(commercial_fert_kg left_fert_kg free_fert_kg subsidy_fert)
gen fert_inorg_kg_male = fert_inorg_kg if dm_gender==1
gen fert_inorg_kg_female = fert_inorg_kg if dm_gender==2
gen fert_inorg_kg_mixed = fert_inorg_kg if dm_gender==3
*Organic Fertilizer
replace s11dq37a = s11dq37a/1000 if s11dq37b==2			// to kg
recode s11dq37b (2=1)			// to kg
gen fert_org_kg = s11dq37a
*Purchased organic fert
replace s11dq38a = s11dq38a/1000 if s11dq38b==2			// to kg
recode s11dq38b (2=1)			// to kg
gen value_org_purchased = s11dq39
gen org_price_kg = value_org_purchased/s11dq38a
recode org_price_kg (0=.)
*Want to use household prices where available
preserve
replace s11dq38a = . if value_org_purchased==. | value_org_purchased==0
collapse (sum) value_org_purchased s11dq38a, by(hhid)
gen org_price_hh = value_o/s11dq38a
keep hhid org_price_hh
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_org_fert_price_hh.dta", replace
restore
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_org_fert_price_hh.dta", nogen assert(3)
bys zone state lga sector: egen org_count_sect = count(org_price_kg)
bys zone state lga sector: egen org_price_sect = median(org_price_kg)
bys zone state lga: egen org_count_lga = count(org_price_kg)
bys zone state lga: egen org_price_lga = median(org_price_kg)
bys zone state: egen org_count_state = count(org_price_kg)
bys zone state: egen org_price_state = median(org_price_kg)
bys zone: egen org_count_zone = count(org_price_kg)
bys zone: egen org_price_zone = median(org_price_kg)
egen org_price_nat = median(org_price_kg)
gen org_price = org_price_sect if org_count_sect>=10
replace org_price = org_price_lga if org_count_lga>=10 & org_price==.
replace org_price = org_price_state if org_count_state>=10 & org_price==.
replace org_price = org_price_zone if org_count_zone>=10 & org_price==.
replace org_price = org_price_nat if org_price==.
recode s11dq37a s11dq38a (.=0)
gen org_notpurchased = s11dq37a-s11dq38a
replace org_notpurchased = 0 if org_notpurchased<0			// not allowing negatives
gen value_org_notpurchased = org_price*org_notpurchased
replace value_org_notpurchased = org_price_hh*org_notpurchased if org_price_hh!=0 & org_price_hh!=.			// replace with household value when available
recode s11dq41 (.=0)
replace value_org_purchased = value_org_purchased + s11dq41			// including transport costs in purchased value
preserve
recode fert_inorg_kg fert_org_kg (.=0)
collapse (sum) fert_inorg_kg* fert_org_kg, by(hhid)
save "$Nigeria_GHS_W3_created_data/Nigeria_GHS_W3_hh_fert.dta", replace
restore
foreach i in value_inorg_purchased value_inorg_notpurchased value_org_purchased value_org_notpurchased{
	gen `i'_male = `i' if dm_gender==1
	gen `i'_female = `i' if dm_gender==2
	gen `i'_mixed = `i' if dm_gender==3
}

collapse (sum) value_inorg_purchased* value_inorg_notpurchased* value_org_purchased* value_org_notpurchased*, by(hhid)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_fert.dta", replace


use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_land.dta", clear
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_rental_rate.dta", nogen
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_seed.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_prep_labor.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_mid_labor.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_harv_labor.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_fert.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_inputs.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_male_head.dta", nogen keep(1 3)
recode ha_planted* (0=.)
*Explicit and implicit costs at the plot level
egen cost_total = rowtotal(value_owned_land value_rented_land value_fam_labor value_hired_labor value_fam_mid_labor ///
value_hired_mid_labor value_fam_harv_labor value_hired_harv_labor value_inorg_notpurchased value_inorg_purchased value_org_notpurchased ///
value_org_purchased value_herbicide_free value_herbicide value_pesticide_free value_pesticide value_animal_rent value_machine_rent value_seeds_purchased)
lab var cost_total "Explicit + implicit costs of crop production (can be disaggregated at the plot level)"
*Creating total costs by gender
foreach i in male female mixed{
	egen cost_total_`i' = rowtotal (value_owned_land_`i' value_rented_land_`i' value_fam_labor_`i' value_hired_labor_`i' value_fam_mid_labor_`i' ///
	value_hired_mid_labor_`i' value_fam_harv_labor_`i' value_hired_harv_labor_`i' value_inorg_notpurchased_`i' value_inorg_purchased_`i' value_org_notpurchased_`i' ///
	value_org_purchased_`i' value_herbicide_free_`i' value_herbicide_`i' value_pesticide_free_`i' value_pesticide_`i' value_animal_rent_`i' value_machine_rent_`i' value_seeds_purchased_`i')
	lab var cost_total_`i' "Explicit + implicit costs of crop production (`i'-managed plots)"
}
*Explicit costs at the plot level
egen cost_expli = rowtotal(value_rented_land value_hired_labor value_hired_mid_labor value_hired_harv_labor value_inorg_purchased ///
value_org_purchased value_herbicide value_pesticide value_animal_rent value_machine_rent value_seeds_purchased )
lab var cost_expli "Total explicit crop production (household level)"
*Creating total costs by gender
foreach i in male female mixed{
	egen cost_expli_`i' = rowtotal(value_rented_land_`i' value_hired_labor_`i' value_hired_mid_labor_`i' value_hired_harv_labor_`i' value_inorg_purchased_`i' ///
	value_org_purchased_`i' value_herbicide_`i' value_pesticide_`i' value_animal_rent_`i' value_machine_rent_`i' value_seeds_purchased_`i' )
	lab var cost_expli_`i' "Crop production costs per hectare, explicit costs (`i'-managed plots)"
}

*Explicit costs at the household level
egen cost_expli_hh = rowtotal(value_rented_land value_hired_labor value_hired_mid_labor value_hired_harv_labor value_inorg_purchased value_org_purchased ///
value_herbicide value_pesticide value_animal_rent value_machine_rent value_seeds_purchased)
lab var cost_expli_hh "Total explicit crop production"
*Recoding zeros as missings
recode cost_total* (0=.)		// should be no zeros for implicit costs
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_cropcosts.dta", replace


********************************************************************************
* RATE OF FERTILIZER APPLICATION *
********************************************************************************
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_fert.dta", clear
append using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_cost_land.dta"
collapse (sum) ha_planted* fert_*, by(hhid)
recode ha_planted* (0=.)
merge m:1 hhid using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hhids.dta", keep (1 3) nogen
_pctile ha_planted [aw=weight]  if ha_planted!=0 , p($wins_lower_thres $wins_upper_thres)
foreach x of varlist ha_planted ha_planted_male ha_planted_female ha_planted_mixed {
		replace `x' =r(r1) if `x' < r(r1)   & `x' !=. &  `x' !=0
		replace `x' = r(r2) if  `x' > r(r2) & `x' !=.
}
lab var fert_inorg_kg "Inorganic fertilizer (kgs) for (household)"
lab var fert_inorg_kg_male "Inorganic fertilizer (kgs) for (male-managed plots)"
lab var fert_inorg_kg_female "Inorganic fertilizer (kgs) for (female-managed plots)"
lab var fert_inorg_kg_mixed "Inorganic fertilizer (kgs) for (mixed-managed plots)"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fertilizer_application.dta", replace


********************************************************************************
*WOMEN'S DIET QUALITY
********************************************************************************
*Women's diet quality: proportion of women consuming nutrient-rich foods (%)
*Information not available


********************************************************************************
*HOUSEHOLD'S DIET DIVERSITY SCORE
********************************************************************************
* since the diet variable is available in both PP and PH datasets, we first append the two together
use "${Nigeria_GHS_W3_raw_data}/sect7b_plantingw3.dta" , clear
keep zone state lga sector ea hhid item_cd item_desc s7bq1
gen survey="PP"
preserve
use "${Nigeria_GHS_W3_raw_data}/sect10b_harvestw3.dta" , clear
keep zone state lga sector ea hhid item_cd item_desc s10bq1
ren  s10bq1  s7bq1 // ren the variable indicating household consumption of food items to harminize accross data set
gen survey="PH"
tempfile diet_ph
save `diet_ph'
restore
append using `diet_ph'
* We recode food items to map to India food groups used as reference
recode item_cd 	    (10 11 13 14 16 19 20/23 25 28   		=1	"CEREALS")  ///
					(17 18 30/38    						=2	"WHITE ROOTS,TUBERS AND OTHER STARCHES")  ///
					(78  70/77 79	 						=3	"VEGETABLES")  ///
					( 60/69 145/147 601						=4	"FRUITS")  ///
					(80/82 90/96 29 						=5	"MEAT")  ///
					(83/85									=6	"EGGS")  ///
					(100/107  								=7  "FISH") ///
					(43/48 40/42   							=8  "LEGUMES, NUTS AND SEEDS") ///
					(110/115								=9	"MILK AND MILK PRODUCTS")  ///
					(50/56   								=10	"OILS AND FATS")  ///
					(26 27 130/133 121 152/155				=11	"SWEETS")  ///
					(76 77 140/144 120 122 150 151 160/164	=12	"SPICES, CONDIMENTS, BEVERAGES"	) ///
					(150 151 								=. ) ///
					,generate(Diet_ID)
gen adiet_yes=(s7bq1==1)
ta Diet_ID
** Now, we collapse to food group level assuming that if an a household consumes at least one food item in a food group,
* then he has consumed that food group. That is equivalent to taking the MAX of adiet_yes
collapse (max) adiet_yes, by(hhid survey Diet_ID)
label define YesNo 1 "Yes" 0 "No"
label val adiet_yes YesNo
* Now, estimate the number of food groups eaten by each individual
collapse (sum) adiet_yes, by(hhid survey )
collapse (mean) adiet_yes, by(hhid )
/*
There are no established cut-off points in terms of number of food groups to indicate
adequate or inadequate dietary diversity for the HDDS.
Can use either cut-off or 6 (=12/2) or cut-off=mean(socore)
*/
ren adiet_yes number_foodgroup
local cut_off1=6
sum number_foodgroup
local cut_off2=round(r(mean))
gen household_diet_cut_off1=(number_foodgroup>=`cut_off1')
gen household_diet_cut_off2=(number_foodgroup>=`cut_off2')
lab var household_diet_cut_off1 "1= houseold consumed at least `cut_off1' of the 12 food groups last week - average PP and PH"
lab var household_diet_cut_off2 "1= houseold consumed at least `cut_off2PP' of the 12 food groups last week - average PP and PH"
label var number_foodgroup "Number of food groups individual consumed last week HDDS="
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_household_diet.dta", replace


********************************************************************************
*WOMEN'S CONTROL OVER INCOME
********************************************************************************
*Code as 1 if a woman is listed as one of the decision-makers for at least 1 income-related area;
*can report on % of women who make decisions, taking total number of women HH members as denominator
*Inmost cases, NGA LSMS 3 lsit the first TWO decision makers.
*Indicator may be biased downward if some women would participate in decisions about the use of income
*but are not listed among the first two

/*
Areas of decision making to be considered
Decision-making areas
*	Control over crop production income
*	Control over livestock production income
*	Control over fish production income
*	Control over farm (all) production income
*	Control over wage income
*	Control over business income
*	Control over nonfarm (all) income
*	Control over (all) income
*/
* First append all files with information on who control various types of income
use "${Nigeria_GHS_W3_raw_data}/secta3i_harvestw3", clear
append using "${Nigeria_GHS_W3_raw_data}/secta3ii_harvestw3"
append using "${Nigeria_GHS_W3_raw_data}/secta8_harvestw3"
append using "${Nigeria_GHS_W3_raw_data}/sect11k_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect11i_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/secta8_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect11k_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect9_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect3_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect3_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect13_harvestw3.dta"
gen type_decision=""
gen controller_income1=.
gen controller_income2=.
* control of harvest from annual crops
replace type_decision="control_annualharvest" if  !inlist( sa3iq6e1, .,0,99, 98) |  !inlist( sa3iq6e2, .,0,99, 98)
replace controller_income1=sa3iq6e1 if !inlist(sa3iq6e1, .,0,99, 98)
replace controller_income2=sa3iq6e2 if !inlist(sa3iq6e2, .,0,99, 98)
* control_annualsales
replace type_decision="control_annualsales" if  !inlist( sa3iiq9a, .,0,99, 98) |  !inlist( sa3iiq9b, .,0,99, 98)
replace controller_income1=sa3iiq9a if !inlist( sa3iiq9a, .,0,99, 98)
replace controller_income2=sa3iiq9b if !inlist( sa3iiq9b, .,0,99, 98)
* append who controls earning from sale to customer 2
preserve
replace type_decision="control_annualsales" if  !inlist( sa3iiq23a, .,0,99, 98) |  !inlist( sa3iiq23b, .,0,99, 98)
replace controller_income1=sa3iiq23a if !inlist( sa3iiq23a, .,0,99, 98)
replace controller_income2=sa3iiq23b if !inlist( sa3iiq23b, .,0,99, 98)
keep if !inlist(sa3iiq23a, .,0,99, 98) |  !inlist(sa3iiq23b, .,0,99, 98)
keep hhid type_decision controller_income1 controller_income2
tempfile control_annualsales2
save `control_annualsales2'
restore
append using `control_annualsales2'
* control_processedsales (both in PP and PH)
replace type_decision="control_processedsales" if ( !inlist( sa8q8a, .,0,99, 98) |  !inlist( sa8q8b, .,0,99, 98))
replace controller_income1=sa8q8a if !inlist( sa8q8a, .,0,99, 98)
replace controller_income2=sa8q8b if !inlist( sa8q8b, .,0,99, 98)
* append who control earning from sales of processed crops PHs
preserve
replace type_decision="control_processedsales" if ( !inlist( s11kq7a, .,0,99, 98) |  !inlist( s11kq7b, .,0,99, 98) )
replace controller_income1=s11kq7a if !inlist( s11kq7a, .,0,99, 98)
replace controller_income2=s11kq7b if !inlist( s11kq7b, .,0,99, 98)
keep if (!inlist(s11kq7a, .,0,99, 98) |  !inlist(s11kq7b, .,0,99, 98))
keep hhid type_decision controller_income1 controller_income2
tempfile control_processedsales2
save `control_processedsales2'
restore
append using `control_processedsales2'
* control_livestocksales
replace type_decision="control_livestocksales" if  !inlist( s11iq4a, .,0,99, 98) |  !inlist( s11iq4b, .,0,99, 98)
replace controller_income1=s11iq4a if !inlist(s11iq4a, .,0,99, 98)
replace controller_income2=s11iq4b if !inlist(s11iq4b, .,0,99, 98)
* control_otherlivestock_sales (both in PP and PH)
replace type_decision="control_otherlivestock_sales" if ( !inlist( sa8q8a, .,0,99, 98) |  !inlist( sa8q8b, .,0,99, 98))  &  !inlist(byprod_cd, 6,7,8)
replace controller_income1=sa8q8a if !inlist( sa8q8a, .,0,99, 98)   &  !inlist(byprod_cd, 6,7,8)
replace controller_income2=sa8q8b if !inlist( sa8q8b, .,0,99, 98) &  !inlist(byprod_cd, 6,7,8)
* append who controle earning from sales of processed crops PHs
preserve
replace type_decision="control_otherlivestock_sales" if ( !inlist( s11kq7a, .,0,99, 98) |  !inlist( s11kq7b, .,0,99, 98) )  &  !inlist(byprod_cd, 6,7,8)
replace controller_income1=s11kq7a if !inlist( s11kq7a, .,0,99, 98)   &  !inlist(byprod_cd, 6,7,8)
replace controller_income2=s11kq7b if !inlist( s11kq7b, .,0,99, 98)  &  !inlist(byprod_cd, 6,7,8)
keep if (!inlist(s11kq7a, .,0,99, 98) |  !inlist(s11kq7b, .,0,99, 98)) &  !inlist(byprod_cd, 6,7,8)
keep hhid type_decision controller_income1 controller_income2
tempfile control_otherlivestock_sales2
save `control_otherlivestock_sales2'
restore
append using `control_otherlivestock_sales2'
* control_businessincome
replace type_decision="control_businessincome" if  !inlist( s9q5a1, .,0,99, 98) |  !inlist( s9q5a2, .,0,99, 98)
replace controller_income1=s9q5a1 if !inlist( s9q5a1, .,0,99, 98)
replace controller_income2=s9q5a2 if !inlist( s9q5a2, .,0,99, 98)
* append who controle earning
preserve
replace type_decision="control_businessincome" if  !inlist( s9q5b1, .,0,99, 98) |  !inlist( s9q5b2, .,0,99, 98)
replace controller_income1=s9q5b1 if !inlist( s9q5b1, .,0,99, 98)
replace controller_income2=s9q5b2 if !inlist( s9q5b2, .,0,99, 98)
keep if !inlist(s9q5b1, .,0,99, 98) |  !inlist(s9q5b2, .,0,99, 98)
keep hhid type_decision controller_income1 controller_income2
tempfile control_businessincome2
save `control_businessincome2'
restore
append using `control_businessincome2'
* control_wageincome
replace type_decision="control_wageincome" if  !inlist( s3q22a, .,0,99, 98) |  !inlist( s3q22b, .,0,99, 98)
replace controller_income1=s3q22a if !inlist( s3q22a, .,0,99, 98)
replace controller_income2=s3q22b if !inlist( s3q22b, .,0,99, 98)
* append who controle earning
preserve
replace type_decision="control_wageincome" if  !inlist( s3q35a, .,0,99, 98) |  !inlist( s3q35b, .,0,99, 98)
replace controller_income1=s3q35a if !inlist( s3q35a, .,0,99, 98)
replace controller_income2=s3q35b if !inlist( s3q35b, .,0,99, 98)
keep if !inlist(s3q35a, .,0,99, 98) |  !inlist(s3q35b, .,0,99, 98)
keep hhid type_decision controller_income1 controller_income2
tempfile control_wageincome2
save `control_wageincome2'
restore
append using `control_wageincome2'
* control_otherincome
replace type_decision="control_otherincome" if  !inlist( s13q2b1, .,0,99, 98) |  !inlist( s13q2b2, .,0,99, 98)
replace controller_income1=s13q2b1 if !inlist( s13q2b1, .,0,99, 98)
replace controller_income2=s13q2b2 if !inlist( s13q2b2, .,0,99, 98)
* append who controle other income 2
preserve
replace type_decision="control_otherincome" if  !inlist( s13q5b1, .,0,99, 98) |  !inlist( s13q5b2, .,0,99, 98)
replace controller_income1=s13q5b1 if !inlist( s13q5b1, .,0,99, 98)
replace controller_income2=s13q5b2 if !inlist( s13q5b2, .,0,99, 98)
keep if !inlist(s13q5b1, .,0,99, 98) |  !inlist(s13q5b2, .,0,99, 98)
keep hhid type_decision controller_income1 controller_income2
tempfile control_otherincome2
save `control_otherincome2'
restore
* append who controle other income 3
preserve
replace type_decision="control_otherincome" if  !inlist( s13q8b1, .,0,99, 98) |  !inlist( s13q8b2, .,0,99, 98)
replace controller_income1=s13q8b1 if !inlist( s13q8b1, .,0,99, 98)
replace controller_income2=s13q8b2 if !inlist( s13q8b2, .,0,99, 98)
keep if !inlist(s13q8b1, .,0,99, 98) |  !inlist(s13q8b2, .,0,99, 98)
keep hhid type_decision controller_income1 controller_income2
tempfile control_otherincome3
save `control_otherincome3'
restore
append using `control_otherincome2'
append using `control_otherincome3'
keep hhid type_decision controller_income1 controller_income2
preserve
keep hhid type_decision controller_income2
drop if controller_income2==.
ren controller_income2 controller_income
tempfile controller_income2
save `controller_income2'
restore
keep hhid type_decision controller_income1
drop if controller_income1==.
ren controller_income1 controller_income
append using `controller_income2'
* Create group
gen control_cropincome=1 if  type_decision=="control_harvest" ///
							| type_decision=="control_cropsales" ///
							| type_decision=="control_processedsales"
recode 	control_cropincome (.=0)
gen control_livestockincome=1 if  type_decision=="control_livestocksales" ///
							| type_decision=="control_otherlivestock_sales"
recode 	control_livestockincome (.=0)
gen control_farmincome=1 if  control_cropincome==1 | control_livestockincome==1
recode 	control_farmincome (.=0)
gen control_businessincome=1 if  type_decision=="control_businessincome"
recode 	control_businessincome (.=0)

gen control_wageincome=1 if  type_decision=="control_wageincome"
recode 	control_wageincome (.=0)
gen control_nonfarmincome=1 if  type_decision=="control_otherincome" ///
							  | control_businessincome== 1 | control_wageincome==1
recode 	control_nonfarmincome (.=0)
collapse (max) control_* , by(hhid controller_income )  //any decision
gen control_all_income=1 if  control_farmincome== 1 | control_nonfarmincome==1
recode 	control_all_income (.=0)
ren controller_income indiv
* Now merge with member characteristics
* Using gender from planting and harvesting sections
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_person_ids.dta", nogen
recode control_* (.=0)
lab var control_cropincome "1=invidual has control over crop income"
lab var control_livestockincome "1=invidual has control over livestock income"
lab var control_farmincome "1=invidual has control over farm (crop or livestock) income"
lab var control_businessincome "1=invidual has control over business income"
lab var control_nonfarmincome "1=invidual has control over non-farm (business or remittances) income"
lab var control_all_income "1=invidual has control over at least one type of income"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_control_income.dta", replace


********************************************************************************
*WOMEN'S PARTICIPATION IN AGRICULTURAL DECISION MAKING
********************************************************************************
* Code as 1 if a woman is listed as one of the decision-makers for at least 2 plots, crops, or livestock activities;
* can report on % of women who make decisions, taking total number of women HH members as denominator
* In most cases, NGA LSMS 3 lists the first TWO decision makers.
* Indicator may be biased downward if some women would participate in decisions but are not listed among the first two
* first append all files related to agricultural activities with income in who participate in the decision making
* planting_input
use "${Nigeria_GHS_W3_raw_data}/sect11a1_plantingw3.dta", clear
append using "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect11e_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/secta1_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/secta11d_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/secta3i_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/secta3ii_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/secta8_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect11k_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect11i_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/secta8_harvestw3.dta"
gen type_decision=""
gen decision_maker1=.
gen decision_maker2=.
* planting_input - manage plot
replace type_decision="planting_input" if  !inlist( s11aq6a, .,0,99, 98) |  !inlist( s11aq6b, .,0,99, 98)
replace decision_maker1=s11aq6a if !inlist( s11aq6a, .,0,99, 98)
replace decision_maker2=s11aq6b if !inlist( s11aq6b, .,0,99, 98)
* append who make decision about plot
preserve
replace type_decision="planting_input" if  !inlist( s11b1q12a, .,0,99, 98) |  !inlist( s11b1q12b, .,0,99, 98) |  !inlist( s11b1q12c, .,0,99, 98)
replace decision_maker1=s11b1q12a if !inlist( s11b1q12a, .,0,99, 98)
replace decision_maker2=s11b1q12b if !inlist( s11b1q12b, .,0,99, 98)
replace decision_maker2=s11b1q12c if !inlist( s11b1q12c, .,0,99, 98)
keep if  !inlist( s11b1q12a, .,0,99, 98) |  !inlist( s11b1q12b, .,0,99, 98) |  !inlist( s11b1q12c, .,0,99, 98)
keep hhid type_decision decision_maker*
tempfile planting_input2
save `planting_input2'
restore
append using `planting_input2'
* append who make decision about plot (others2)
preserve
replace type_decision="planting_input" if  !inlist( s11b1q16b1, .,0,99, 98) |  !inlist( s11b1q16b2, .,0,99, 98)
replace decision_maker1=s11b1q16b1 if !inlist( s11b1q16b1, .,0,99, 98)
replace decision_maker2=s11b1q16b2 if !inlist( s11b1q16b2, .,0,99, 98)
keep if  !inlist( s11b1q16b1, .,0,99, 98) |  !inlist( s11b1q16b2, .,0,99, 98)
keep hhid type_decision decision_maker*
tempfile planting_input3
save `planting_input3'
restore
append using `planting_input3'
* append who make decision about input (chose seed)
preserve
replace type_decision="planting_input" if  !inlist( s11eq15a, .,0,99, 98) |  !inlist( s11eq15b, .,0,99, 98)
replace decision_maker1=s11eq15a if !inlist( s11eq15a, .,0,99, 98)
replace decision_maker2=s11eq15b if !inlist( s11eq15b, .,0,99, 98)
keep if  !inlist( s11eq15a, .,0,99, 98) |  !inlist( s11eq15b, .,0,99, 98)
keep hhid type_decision decision_maker*
tempfile planting_input4
save `planting_input4'
restore
append using `planting_input4'
* append who make decision about input (paid seed)
preserve
replace type_decision="planting_input" if  !inlist( s11eq27a, .,0,99, 98) |  !inlist( s11eq27b, .,0,99, 98)
replace decision_maker1=s11eq27a if !inlist( s11eq27a, .,0,99, 98)
replace decision_maker2=s11eq27b if !inlist( s11eq27b, .,0,99, 98)
keep if  !inlist( s11eq27a, .,0,99, 98) |  !inlist( s11eq27b, .,0,99, 98)
keep hhid type_decision decision_maker*
tempfile planting_input5
save `planting_input5'
restore
append using `planting_input5'
* append who make decision about input (manage plot)
preserve
replace type_decision="planting_input" if  !inlist( sa1q11, .,0,99, 98) |  !inlist( sa1q11b, .,0,99, 98)
replace decision_maker1=sa1q11 if !inlist( sa1q11, .,0,99, 98)
replace decision_maker2=sa1q11b if !inlist( sa1q11b, .,0,99, 98)
keep if  !inlist( sa1q11, .,0,99, 98) |  !inlist( sa1q11b, .,0,99, 98)
keep hhid type_decision decision_maker*
tempfile planting_input6
save `planting_input6'
restore
append using `planting_input6'
* append who make decision about (owner plot)
preserve
replace type_decision="planting_input" if  !inlist( sa1q14, .,0,99, 98) |  !inlist( sa1q14b, .,0,99, 98)
replace decision_maker1=sa1q14 if !inlist( sa1q14, .,0,99, 98)
replace decision_maker2=sa1q14b if !inlist( sa1q14b, .,0,99, 98)
keep if  !inlist( sa1q14, .,0,99, 98) |  !inlist( sa1q14b, .,0,99, 98)
keep hhid type_decision decision_maker*
tempfile planting_input7
save `planting_input7'
restore
append using `planting_input7'
* append who make decision about plot (decsision maker)
preserve
replace type_decision="planting_input" if  !inlist( sa1q22a, .,0,99, 98) |  !inlist( sa1q22b, .,0,99, 98)  |  !inlist( sa1q22c, .,0,99, 98) |  !inlist( sa1q22d, .,0,99, 98)
replace decision_maker1=sa1q22a if !inlist( sa1q22a, .,0,99, 98)
replace decision_maker2=sa1q22b if !inlist( sa1q22b, .,0,99, 98)
replace decision_maker1=sa1q22c if !inlist( sa1q22c, .,0,99, 98)
replace decision_maker2=sa1q22d if !inlist( sa1q22d, .,0,99, 98)
keep if  !inlist( sa1q22a, .,0,99, 98) |  !inlist( sa1q22b, .,0,99, 98)
keep hhid type_decision decision_maker*
tempfile planting_input8
save `planting_input8'
restore
append using `planting_input8'
* append who make decision about plot (manage)
preserve
replace type_decision="planting_input" if  !inlist( sa1q24a, .,0,99, 98) |  !inlist( sa1q24b, .,0,99, 98) |  !inlist( sa1q24c, .,0,99, 98)
replace decision_maker1=sa1q24a if !inlist( sa1q24a, .,0,99, 98)
replace decision_maker2=sa1q24b if !inlist( sa1q24b, .,0,99, 98)
replace decision_maker2=sa1q24c if !inlist( sa1q24c, .,0,99, 98)
keep if  !inlist( sa1q24a, .,0,99, 98) |  !inlist( sa1q24b, .,0,99, 98) |  !inlist( sa1q24c, .,0,99, 98)
keep hhid type_decision decision_maker*
tempfile planting_input9
save `planting_input9'
restore
append using `planting_input9'
* append who make decision about input (fertilizer)
preserve
replace type_decision="planting_input" if  !inlist( s11dq25a, .,0,99, 98) |  !inlist( s11dq25b, .,0,99, 98)
replace decision_maker1=s11dq25a if !inlist( s11dq25a, .,0,99, 98)
replace decision_maker2=s11dq25b if !inlist( s11dq25b, .,0,99, 98)
keep if  !inlist( s11dq25a, .,0,99, 98) |  !inlist( s11dq25b, .,0,99, 98)
keep hhid type_decision decision_maker*
tempfile planting_input10
save `planting_input10'
restore
append using `planting_input10'
* sales_crop
replace type_decision="sales_crop" if  !inlist( sa3iiq8a, .,0,99, 98) |  !inlist( sa3iiq8b, .,0,99, 98)
replace decision_maker1=sa3iiq8a if !inlist( sa3iiq8a, .,0,99, 98)
replace decision_maker2=sa3iiq8b if !inlist( sa3iiq8b, .,0,99, 98)
* sales_processcrop
replace type_decision="sales_processcrop" if  (!inlist( sa8q7a, .,0,99, 98) |  !inlist( sa8q7b, .,0,99, 98))  & inlist(byprod_cd, 6,7,8)
replace decision_maker1=sa8q7a if !inlist( sa8q7a, .,0,99, 98)  & inlist(byprod_cd, 6,7,8)
replace decision_maker2=sa8q7b if !inlist( sa8q7b, .,0,99, 98)  & inlist(byprod_cd, 6,7,8)
* keep/manage livesock
replace type_decision="livestockowners" if  !inlist( s11iq4a, .,0,99, 98) |  !inlist( s11iq4b, .,0,99, 98)
replace decision_maker1=s11iq4a if !inlist( s11iq4a, .,0,99, 98)
replace decision_maker2=s11iq4b if !inlist( s11iq4b, .,0,99, 98)
* Append who make decision about plot
preserve
replace type_decision="livestockowners" if  !inlist( s11iq5a, .,0,99, 98) |  !inlist( s11iq5b, .,0,99, 98)
replace decision_maker1=s11iq5a if !inlist( s11iq5a, .,0,99, 98)
replace decision_maker2=s11iq5b if !inlist( s11iq5b, .,0,99, 98)
keep if  !inlist( s11iq5a, .,0,99, 98) |  !inlist( s11iq5b, .,0,99, 98)
keep hhid type_decision decision_maker*
tempfile livestockowners2
save `livestockowners2'
restore
append using `livestockowners2'
* otherlivestock_sales
replace type_decision="otherlivestock_sales" if  (!inlist( sa8q7a, .,0,99, 98) |  !inlist( sa8q7b, .,0,99, 98))  & !inlist(byprod_cd, 6,7,8)
replace decision_maker1=sa8q7a if !inlist( sa8q7a, .,0,99, 98)   & !inlist(byprod_cd, 6,7,8)
replace decision_maker2=sa8q7b if !inlist( sa8q7b, .,0,99, 98)  & !inlist(byprod_cd, 6,7,8)
keep hhid type_decision decision_maker1 decision_maker2
preserve
keep hhid type_decision decision_maker2
drop if decision_maker2==.
ren decision_maker2 decision_maker
tempfile decision_maker2
save `decision_maker2'
restore
keep hhid type_decision decision_maker1
drop if decision_maker1==.
ren decision_maker1 decision_maker
append using `decision_maker2'
bysort hhid decision_maker : egen nb_decision_participation=count(decision_maker)
drop if nb_decision_participation==1
*	Create group
gen make_decision_crop=1 if  type_decision=="planting_input" ///
							| type_decision=="harvest" ///
							| type_decision=="sales_crop" ///
							| type_decision=="sales_processcrop"
recode 	make_decision_crop (.=0)
gen make_decision_livestock=1 if  type_decision=="livestockowners" | type_decision=="otherlivestock_sales"
recode 	make_decision_livestock (.=0)
gen make_decision_ag=1 if make_decision_crop==1 | make_decision_livestock==1
recode 	make_decision_ag (.=0)
collapse (max) make_decision_* , by(hhid decision_maker )  //any decision
ren decision_maker indiv
*	Now merge with member characteristics
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_person_ids.dta", nogen
recode make_decision_* (.=0)
keep make_decision_crop make_decision_livestock make_decision_ag female age  hhid indiv
lab var make_decision_crop "1=invidual makes decision about crop production activities"
lab var make_decision_livestock "1=invidual makes decision about livestock production activities"
lab var make_decision_ag "1=invidual makes decision about agricultural (crop or livestock) production activities"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_make_ag_decision.dta", replace


********************************************************************************
*WOMEN'S OWNERSHIP OF ASSETS
********************************************************************************
* Code as 1 if a woman is sole or joint owner of any specified productive asset;
* can report on % of women who own, taking total number of women HH members as denominator
* In most cases, NGA LSMS 3 as the first TWO owners.
* Indicator may be biased downward if some women would have been not listed among the two the first 2 asset-owners can also claim ownership of some assets
*First, append all files with information on asset ownership
use "${Nigeria_GHS_W3_raw_data}/sect11b1_plantingw3.dta", clear
append using "${Nigeria_GHS_W3_raw_data}/sect11e_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/secta1_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect11i_plantingw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/secta4_harvestw3.dta"
append using "${Nigeria_GHS_W3_raw_data}/sect5_plantingw3.dta"
gen type_asset=""
gen asset_owner1=.
gen asset_owner2=.
gen asset_owner3=.
gen asset_owner4=.
* Ownership of land.
replace type_asset="landowners" if  !inlist( s11b1q6a, .,0,99, 98) |  !inlist( s11b1q6b, .,0,99, 98)
replace asset_owner1=s11b1q6a if !inlist( s11b1q6a, .,0,99, 98)
replace asset_owner2=s11b1q6b if !inlist( s11b1q6b, .,0,99, 98)
replace type_asset="landowners" if  !inlist( sa1q14, .,0,99, 98) |  !inlist( sa1q14b, .,0,99, 98)
replace asset_owner1=sa1q14 if !inlist( sa1q14, .,0,99, 98)
replace asset_owner2=sa1q14b if !inlist( sa1q14b, .,0,99, 98)
* append who hss right to sell or use
preserve
replace type_asset="landowners" if  !inlist( s11b1q22a, .,0,99, 98) |  !inlist( s11b1q22b, .,0,99, 98)  |  !inlist( s11b1q22c, .,0,99, 98)
replace asset_owner1=s11b1q22a if !inlist( s11b1q22a, .,0,99, 98)
replace asset_owner2=s11b1q22b if !inlist( s11b1q22b, .,0,99, 98)
replace asset_owner3=s11b1q22c if !inlist( s11b1q22c, .,0,99, 98)
replace type_asset="landowners" if  !inlist( sa1q18a, .,0,99, 98) |  !inlist( sa1q18b, .,0,99, 98)  |  !inlist( sa1q18c, .,0,99, 98)
replace asset_owner1=sa1q18a if !inlist( sa1q18a, .,0,99, 98)
replace asset_owner2=sa1q18b if !inlist( sa1q18b, .,0,99, 98)
replace asset_owner3=sa1q18c if !inlist( sa1q18c, .,0,99, 98)
keep if  !inlist( s11b1q22a, .,0,99, 98) |  !inlist( s11b1q22b, .,0,99, 98)  |  !inlist( s11b1q22c, .,0,99, 98) |  !inlist( sa1q18a, .,0,99, 98) |  !inlist( sa1q18b, .,0,99, 98)  |  !inlist( sa1q18c, .,0,99, 98)
keep hhid type_asset asset_owner*
tempfile land2
save `land2'
restore
append using `land2'
* Append who has title
preserve
replace type_asset="landowners" if  !inlist( s11b1q8b1, .,0,99, 98) |  !inlist( s11b1q8b2, .,0,99, 98)  |  !inlist( s11b1q8b3, .,0,99, 98)
replace asset_owner1=s11b1q8b1 if !inlist( s11b1q8b1, .,0,99, 98)
replace asset_owner2=s11b1q8b2 if !inlist( s11b1q8b2, .,0,99, 98)
replace asset_owner3=s11b1q8b3 if !inlist( s11b1q8b3, .,0,99, 98)
keep if !inlist( s11b1q8b1, .,0,99, 98) |  !inlist( s11b1q8b2, .,0,99, 98)  |  !inlist( s11b1q8b3, .,0,99, 98)
keep hhid type_asset asset_owner*
tempfile land3
save `land3'
restore
append using `land3'
* Livestock owners
replace type_asset="livestockowners" if  !inlist( s11iq4a, .,0,99, 98) |  !inlist( s11iq4b, .,0,99, 98)
replace asset_owner1=s11iq4a if !inlist( s11iq4a, .,0,99, 98)
replace asset_owner2=s11iq4b if !inlist( s11iq4b, .,0,99, 98)
* AGRICULTURAL CAPITAL
replace type_asset="agcapialowner" if  !inlist( sa4q2a, .,0,99, 98) |  !inlist( sa4q2b, .,0,99, 98) |  !inlist( sa4q2c, .,0,99, 98) |  !inlist( sa4q2d, .,0,99, 98)
replace asset_owner1=sa4q2a if !inlist( sa4q2a, .,0,99, 98)
replace asset_owner2=sa4q2b if !inlist( sa4q2b, .,0,99, 98)
replace asset_owner3=sa4q2c if !inlist( sa4q2c, .,0,99, 98)
replace asset_owner4=sa4q2d if !inlist( sa4q2d, .,0,99, 98)
* Non farm assets (equipment)
drop if inlist(item_cd, 301 , 302 , 303, 304 , 305 ,  306, 321,  322 , 323, 324, 326, 325,  327,  329)
replace type_asset="nonfarm_asset" if  !inlist( s5q2, .,0,99, 98) |  !inlist( s5q2b, .,0,99, 98)
replace asset_owner1=s5q2 if !inlist( s5q2, .,0,99, 98)
replace asset_owner2=s5q2b if !inlist( s5q2b, .,0,99, 98)
keep hhid type_asset asset_owner1  asset_owner2 asset_owner3 asset_owner4
preserve
keep hhid type_asset asset_owner2
drop if asset_owner2==.
ren asset_owner2 asset_owner
tempfile asset_owner2
save `asset_owner2'
restore
preserve
keep hhid type_asset asset_owner3
drop if asset_owner3==.
ren asset_owner3 asset_owner
tempfile asset_owner3
save `asset_owner3'
restore
preserve
keep hhid type_asset asset_owner4
drop if asset_owner4==.
ren asset_owner4 asset_owner
tempfile asset_owner4
save `asset_owner4'
restore
keep hhid type_asset asset_owner1
drop if asset_owner1==.
ren asset_owner1 asset_owner
append using `asset_owner2'
append using `asset_owner3'
append using `asset_owner4'
gen own_asset=1
collapse (max) own_asset, by(hhid asset_owner)
ren asset_owner indiv
* Now merge with member characteristics
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_raw_data}/sect1_plantingw3.dta", nogen
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_raw_data}/sect1_harvestw3.dta"
gen female = s1q2 ==2
recode own_asset (.=0)
lab var own_asset "1=invidual owns an assets (land or livestock)"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_ownasset.dta", replace


********************************************************************************
*AGRICULTURAL WAGES
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect11c1_plantingw3.dta", clear
merge 1:1 hhid plotid using  "${Nigeria_GHS_W3_raw_data}/secta2_harvestw3.dta", nogen
recode s11c1q4 s11c1q7 s11c1q10 (0=.)
*To be consistent with other instrument focus the analysis only on wage for male and female and average wage accross gender
* The question asked total wage paid. Daily wage is obtained by dividing total paid/number of worker
ren s11c1q2 hired_male_planting
ren s11c1q4 wage_paid_male_planting
ren s11c1q5 hired_female_planting
ren s11c1q7 wage_paid_female_planting
ren sa2q1c hired_male_mid
ren sa2q1e wage_paid_male_mid
ren sa2q1f hired_female_mid
ren sa2q1h wage_paid_female_mid
ren sa2q2 hired_male_harvest
ren sa2q4 wage_paid_male_harvest
ren sa2q5 hired_female_harvest
ren sa2q7 wage_paid_female_harvest
recode wage_* hired_* (.=0)
*first collapse accross plot  to houshold level
collapse (sum) wage_* hired_* , by(hhid)
* get weighted average average accross group of activities to get paid wage at household level
gen wage_paid_male=wage_paid_male_planting + wage_paid_male_mid+wage_paid_male_harvest
gen hired_male=hired_male_planting + hired_male_mid+hired_male_harvest
gen wage_paid_aglabor_male=wage_paid_male/hired_male
gen wage_paid_female=wage_paid_female_planting + wage_paid_female_mid+wage_paid_female_harvest
gen hired_female=hired_female_planting + hired_female_mid+hired_female_harvest
gen wage_paid_aglabor_female=wage_paid_female/hired_female
gen wage_paid_all=wage_paid_male+wage_paid_female
gen hired_all=(hired_male+hired_female)
gen wage_paid_aglabor=wage_paid_all/hired_all
*later will use hired_labor*weight for the summary stats on wage
keep hhid hired_male- wage_paid_aglabor
lab var wage_paid_aglabor "Daily agricultural wage paid for hired labor (local currency)"
lab var wage_paid_aglabor_female "Daily agricultural wage paid for hired labor - female workers(local currency)"
lab var wage_paid_aglabor_male "Daily agricultural wage paid for hired labor - male workers (local currency)"
lab var hired_all "Total hired labor (number of persons)"
lab var hired_female "Total hired labor (number of persons) -female workers"
lab var hired_male "Total hired labor (number of persons) -male workers"
keep hhid wage_paid_aglabor wage_paid_aglabor_female wage_paid_aglabor_male
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_ag_wage.dta", replace


********************************************************************************
*CROP YIELDS
********************************************************************************
*Now getting area planted
use "${Nigeria_GHS_W3_raw_data}/sect11f_plantingw3.dta", clear
ren plotid plot_id
*including monocropping and relay cropping (plant one crop, harvest, then plant another) as monocropping
*including tree crops as mono-cropped, but we aren't currently including them in the rescaling decisions
gen purestand= 1
replace purestand= 0 if s11fq2==2 | s11fq2==4 | s11fq2==5 | s11fq2==6
gen any_pure= purestand==1
gen any_mixed = purestand==0
*Merging in gender of plot manager
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas", nogen keep(1 3)
*There are a lot of unconventional measurements
*Using conversion factors from BID
*Heaps
gen conversion = 0.00012 if zone==1 & s11fq1b==1 | s11fq4b==1
replace conversion = 0.00016 if zone==2 & s11fq1b==1 | s11fq4b==1
replace conversion = 0.00011 if zone==3 & s11fq1b==1 | s11fq4b==1
replace conversion = 0.00019 if zone==4 & s11fq1b==1 | s11fq4b==1
replace conversion = 0.00021 if zone==5 & s11fq1b==1 | s11fq4b==1
replace conversion = 0.00012 if zone==6 & s11fq1b==1 | s11fq4b==1
*Ridges
replace conversion = 0.0027 if zone==1 & s11fq1b==2 | s11fq4b==2
replace conversion = 0.004 if zone==2 & s11fq1b==2 | s11fq4b==2
replace conversion = 0.00494 if zone==3 & s11fq1b==2 | s11fq4b==2
replace conversion = 0.0023 if zone==4 & s11fq1b==2 | s11fq4b==2
replace conversion = 0.0023 if zone==5 & s11fq1b==2 | s11fq4b==2
replace conversion = 0.00001 if zone==6 & s11fq1b==2 | s11fq4b==2
*Stands
replace conversion = 0.00006 if zone==1 & s11fq1b==3 | s11fq4b==3
replace conversion = 0.00016 if zone==2 & s11fq1b==3 | s11fq4b==3
replace conversion = 0.00004 if zone==3 & s11fq1b==3 | s11fq4b==3
replace conversion = 0.00004 if zone==4 & s11fq1b==3 | s11fq4b==3
replace conversion = 0.00013 if zone==5 & s11fq1b==3 | s11fq4b==3
replace conversion = 0.00041 if zone==6 & s11fq1b==3 | s11fq4b==3
*Plots
replace conversion = 0.0667 if s11fq1b==4 | s11fq4b==4
*Acres
replace conversion = 0.404686 if s11fq1b==5 | s11fq4b==5
*Hectares
replace conversion = 1 if s11fq1b==6 | s11fq4b==6
*Square meters
replace conversion = 0.0001 if s11fq1b==7 | s11fq4b==7
gen ha_planted = s11fq1a*conversion
gen perm_crop=(s11fc5==2)		//991 tree crop observations
replace ha_planted = s11fq4a*conversion if ha_planted==.
recode ha_planted (.=0)
merge m:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", nogen keep(1 3)
*Area planted by crop here
ren cropcode crop_code
recode crop_code (2170=2030)
ren s11fq5 number_trees_planted
preserve
*dropping permanent crops for rescaling
drop if perm_crop==1

*Start by capping area planted of each individual crop at plot area if GPS measurements are available
gen over_planted = ha_planted>field_size & ha_planted!=. & gps_meas==1
gen over_planted_scaling = field_size/ha_planted if over_planted==1
bys hhid plot_id: egen mean_planted_scaling = mean(over_planted_scaling)
replace mean_planted_scaling =1 if missing(mean_planted_scaling)

replace ha_planted = field_size if over_planted==1
replace ha_planted = ha_planted*mean_planted_scaling if over_planted==0
//72 observations where ha_planted=0, there shouldn't be any of these - most of these are missing an area or unit
//only 11 observations that have both area and unit that are missing, 9 of these report an area planted of 0

//Rescaling area planted assuming non-intercropped areas are accurately reported and intercropped crops take up the remainder of the plot
gen intercropped_yn = 1 if ~missing(s11fq2)
replace intercropped_yn =0 if s11fq2 == 1 | s11fq2==3
gen percent_field=ha_planted/field_size
gen mono_field = percent_field if intercropped_yn==0
gen int_field = percent_field if intercropped_yn==1
*Generating total percent of purestand and monocropped on a field
bys hhid plot_id: egen total_percent_int_sum = total(int_field)
bys hhid plot_id: egen total_percent_mono = total(mono_field)
//about 60% of plots have a total intercropped sum greater than 1
//about 3% of plots have a total monocropped sum greater than 1
//Dealing with crops which have monocropping larger than plot size or monocropping that fills plot size and still has intercropping to add
generate oversize_plot = (total_percent_mono >1)
replace oversize_plot = 1 if total_percent_mono >=1 & total_percent_int_sum >0
bys hhid plot_id: egen total_percent_field = total(percent_field)
replace percent_field = percent_field/total_percent_field if total_percent_field>1 & oversize_plot ==1
//407 changes made
//Rescaling intercropped crops to fit on remainder of plot after monocropped crops are accounted for
replace total_percent_mono = 1 if total_percent_mono>1
gen total_percent_inter = 1-total_percent_mono
bys hhid plot_id: egen inter_crop_number = total(intercropped_yn)
gen percent_inter = (int_field/total_percent_int_sum)*total_percent_inter if total_percent_field >1
replace percent_inter = int_field if total_percent_field<=1
//1,346 changes
replace percent_inter = percent_field if oversize_plot ==1 & intercropped_yn==1
//79 changes
ren cultivate field_cultivated
gen field_area_cultivated = field_size if field_cultivated==1
gen crop_area_planted = percent_field*field_area_cultivated  if intercropped_yn == 0
replace crop_area_planted = percent_inter*field_area_cultivated  if intercropped_yn == 1
gen us_total_area_planted = total_percent_field*field_area_cultivated
gen us_inter_area_planted = total_percent_int_sum*field_area_cultivated
tempfile annual_crop_area
save `annual_crop_area'
restore

*adding permanent crops back in
merge 1:1 hhid plot_id cropid using `annual_crop_area', nogen
*Generating crop area planted for permanent crops
replace crop_area_planted = ha_planted if perm_crop==1
// crop_area_planted is the RESCALED area planted and ha_planted is the non-rescaled area planted
*dropping raw variables
drop s11fc5-s11fq4b s11fq6-s11fq15 s11aq4a1-sa1q8 sa1q10a-sa1q25b
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_area_planted", replace


////Now to harvest////
use "${Nigeria_GHS_W3_raw_data}/secta3i_harvestw3.dta",clear
ren cropname crop_name
ren cropcode crop_code
ren sa3iq3 harvest_yesno
ren sa3iq6i quantity_harvested
ren sa3iq6ii quantity_harvested_unit
ren sa3iq6ii_os quantity_harvested_unit_other
ren sa3iq6a value_harvested
ren sa3iq5a area_harv
ren sa3iq5b area_harv_unit
ren plotid plot_id
recode crop_code (2170=2030)
gen percent_harv=sa3iq5c/100
*merging in field sizes
merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta", nogen keep(1 3)
*merging in planted areas
merge 1:1 hhid plot_id cropid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_area_planted.dta",gen(plant_harv_merge) keep(1 3)
//There are 199 observations that are in the harvest file but not the planted file - we don't have intercropping information on these observations
*generating area harvested as percent of plot area
gen area_harv_ha= field_size*(percent_harv)
*replacing area harvested with area reported by farmer
replace area_harv_ha= area_harv if area_harv_unit==6 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.0667 if area_harv_unit==4	& area_harv_ha ==.		//reported in plots
replace area_harv_ha = area_harv*0.404686 if area_harv_unit==5 & area_harv_ha ==.			//reported in acres
replace area_harv_ha = area_harv*0.0001 if area_harv_unit==7	& area_harv_ha ==.		//reported in square meters
replace area_harv_ha = area_harv*0.00012 if area_harv_unit==1 & zone==1 & area_harv_ha ==.		//reported in heaps
replace area_harv_ha = area_harv*0.00016 if area_harv_unit==1 & zone==2 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00011 if area_harv_unit==1 & zone==3 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00019 if area_harv_unit==1 & zone==4 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00021 if area_harv_unit==1 & zone==5 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00012 if area_harv_unit==1 & zone==6 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.0027 if area_harv_unit==2 & zone==1 & area_harv_ha ==.			//reported in ridges
replace area_harv_ha = area_harv*0.004 if area_harv_unit==2 & zone==2 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00494 if area_harv_unit==2 & zone==3 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.0023 if area_harv_unit==2 & zone==4 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.0023 if area_harv_unit==2 & zone==5 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00001 if area_harv_unit==2 & zone==6 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00006 if area_harv_unit==3 & zone==1 & area_harv_ha ==.			//reported in stands
replace area_harv_ha = area_harv*0.00016 if area_harv_unit==3 & zone==2 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00004 if area_harv_unit==3 & zone==3 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00004 if area_harv_unit==3 & zone==4 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00013 if area_harv_unit==3 & zone==5 & area_harv_ha ==.
replace area_harv_ha = area_harv*0.00041 if area_harv_unit==3 & zone==6 & area_harv_ha ==.
drop area_harv

//We are capping area harvested at field size - adding in only for GPS measured plots
//Capping Code:
gen over_harvest = area_harv_ha>field_size & area_harv_ha!=. & gps_meas==1
gen over_harvest_scaling = field_size/area_harv_ha if over_harvest == 1
bys hhid plot_id: egen mean_harvest_scaling = mean(over_harvest_scaling)
replace mean_harvest_scaling =1 if missing(mean_harvest_scaling)
replace area_harv_ha = field_size if over_harvest == 1
//589 changes
replace area_harv_ha = area_harv_ha*mean_harvest_scaling if over_harvest == 0
//46 changes
//Intercropping Scaling Code (Method 4):
bys hhid plot_id: egen over_harv_plot = max(over_harvest)
gen int_f_harv = area_harv_ha if intercropped_yn==1
bys hhid plot_id: egen total_area_int_sum_hv = total(int_f_harv)
bys hhid plot_id: egen total_area_hv = total(area_harv_ha)
replace us_total_area_planted = total_area_hv if over_harv_plot ==1
replace us_inter_area_planted = total_area_int_sum_hv if over_harv_plot ==1
drop int_f_harv total_area_int_sum_hv total_area_hv oversize_plot
gen mono_f_harv = area_harv_ha if intercropped_yn==0
gen int_f_harv = area_harv_ha if intercropped_yn==1
bys hhid plot_id: egen total_area_int_sum_hv = total(int_f_harv)
bys hhid plot_id: egen total_area_mono_hv = total(mono_f_harv)

//Oversize Plots
generate oversize_plot = total_area_mono_hv > field_area
replace oversize_plot = 1 if total_area_mono_hv >=1 & total_area_int_sum_hv >0
bys hhid plot_id: egen total_area_harv = total(area_harv_ha)
replace area_harv_ha = (area_harv_ha/us_total_area_planted)*field_area if oversize_plot ==1
generate total_area_int_hv = field_area - total_area_mono_hv
replace area_harv_ha = (int_f_harv/us_inter_area_planted)*total_area_int_hv if intercropped_yn==1 & oversize_plot !=1
*Replacing all area harvested of 0 as missing
replace area_harv_ha=. if area_harv_ha==0
replace crop_area_planted=area_harv_ha if crop_area_planted==. & area_harv_ha!=.


*caping area harvested at area planted
count if area_harv_ha>crop_area_planted & area_harv_ha!=.
replace area_harv_ha = crop_area_planted if area_harv_ha>crop_area_planted  & area_harv_ha!=.

//Starting amount harvested//
*renaming unit code for merge
ren quantity_harvested_unit unit_cd
*merging in conversion factors
merge m:1 crop_code unit_cd zone using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_ng3_cf.dta", gen(cf_merge)
gen quant_harv_kg= quantity_harvested*conv_fact
replace quant_harv_kg = 0 if harvest_yesno==2 & (sa3iq4== 1 | sa3iq4== 2 | sa3iq4== 3 | sa3iq4== 4)
replace quant_harv_kg = . if harvest_yesno==2 & (sa3iq4== 5 | sa3iq4== 6 | sa3iq4== 7 | sa3iq4== 8 | sa3iq4== 9 | sa3iq4== 10 | sa3iq4== 11)
bys unit_cd zone state: egen state_conv_unit = median(conv_fact)
bys unit_cd zone: egen zone_conv_unit = median(conv_fact)
bys unit_cd: egen national_conv = median(conv_fact)
replace conv_fact = state_conv_unit if conv_fact==. & unit_cd!=900
replace conv_fact = zone_conv_unit if conv_fact==. & unit_cd!=900
replace conv_fact = national_conv if conv_fact==. & unit_cd!=900
replace quant_harv_kg= quantity_harvested*conv_fact
replace quant_harv_kg= quantity_harvested if unit_cd==1
replace quant_harv_kg= quantity_harvested/1000 if unit_cd==2
drop if quant_harv_kg==.
preserve
collapse (sum) kgs_harvest=quant_harv_kg, by(hhid crop_code)
lab var kgs_harvest "Kgs harvested of this crop"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_kgs_harvest", replace
restore
*merging in gender variables
merge m:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", gen(_merge_gender)
drop if quant_harv_kg==.
replace area_harv_ha = crop_area_planted if area_harv_ha==. // Couldn't missing area just be no area harvested??

*Creating area and quantity variables by decision-maker and type of planting
ren quant_harv_kg harvest
ren area_harv_ha area_harv
ren any_mixed inter
gen harvest_male = harvest if dm_gender==1
gen area_harv_male = area_harv if dm_gender==1
gen harvest_female = harvest if dm_gender==2
gen area_harv_female = area_harv if dm_gender==2
gen harvest_mixed = harvest if dm_gender==3
gen area_harv_mixed = area_harv if dm_gender==3
gen area_harv_inter= area_harv if inter==1
gen area_harv_pure= area_harv if inter==0
gen harvest_inter= harvest if inter==1
gen harvest_pure= harvest if inter==0
gen harvest_inter_male= harvest if dm_gender==1 & inter==1
gen harvest_pure_male= harvest if dm_gender==1 & inter==0
gen harvest_inter_female= harvest if dm_gender==2 & inter==1
gen harvest_pure_female= harvest if dm_gender==2 & inter==0
gen harvest_inter_mixed= harvest if dm_gender==3 & inter==1
gen harvest_pure_mixed= harvest if dm_gender==3 & inter==0
gen area_harv_inter_male= area_harv if dm_gender==1 & inter==1
gen area_harv_pure_male= area_harv if dm_gender==1 & inter==0
gen area_harv_inter_female= area_harv if dm_gender==2 & inter==1
gen area_harv_pure_female= area_harv if dm_gender==2 & inter==0
gen area_harv_inter_mixed= area_harv if dm_gender==3 & inter==1
gen area_harv_pure_mixed= area_harv if dm_gender==3 & inter==0
ren crop_area_planted area_plan
gen area_plan_male = area_plan if dm_gender==1
gen area_plan_female = area_plan if dm_gender==2
gen area_plan_mixed = area_plan if dm_gender==3
gen area_plan_inter= area_plan if inter==1
gen area_plan_pure= area_plan if inter==0
gen area_plan_inter_male= area_plan if dm_gender==1 & inter==1
gen area_plan_pure_male= area_plan if dm_gender==1 & inter==0
gen area_plan_inter_female= area_plan if dm_gender==2 & inter==1
gen area_plan_pure_female= area_plan if dm_gender==2 & inter==0
gen area_plan_inter_mixed= area_plan if dm_gender==3 & inter==1
gen area_plan_pure_mixed= area_plan if dm_gender==3 & inter==0
collapse (sum) harvest* area_harv* area_plan* number_trees_planted, by(hhid crop_code)
*Saving area planted for Shannon Diversity index
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_area_plan.dta", replace


*Total planted and harvested area summed accross all plots, crops, and seasons.
preserve
collapse (sum) all_area_harvested=area_harv all_area_planted=area_plan, by(hhid)
replace all_area_harvested=all_area_planted if all_area_harvested>all_area_planted & all_area_harvested!=.
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_area_planted_harvested_allcrops.dta", replace
restore
keep if inlist(crop_code, $comma_topcrop_area)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_harvest_area_yield.dta", replace

*Yield at the household level
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_harvest_area_yield.dta", clear
*Value of crop production
merge 1:1 hhid crop_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_values_production.dta", nogen keep(1 3)
ren value_crop_production value_harv
ren value_crop_sales value_sold
merge 1:1 hhid crop_code using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_kgs_harvest.dta", nogen keep(1 3)
gen total_harv_area=area_harv
gen total_planted_area=area_plan
drop harvest_yesno area_harv_unit
local ncrop : word count $topcropname_area
foreach v of varlist  harvest*  area_harv* area_plan* total_planted_area total_harv_area kgs_harvest* value_harv value_sold {
	separate `v', by(crop_code)
	forvalues i=1(1)`ncrop' {
		local p : word `i' of  $topcrop_area
		local np : word `i' of  $topcropname_area
		local `v'`p' = subinstr("`v'`p'","`p'","_`np'",1)
		ren `v'`p'  ``v'`p''
	}
}
gen number_trees_planted_banana = number_trees_planted if crop_code==2030
gen number_trees_planted_cassava = number_trees_planted if crop_code==1020
gen number_trees_planted_cocoa = number_trees_planted if crop_code==3040
recode number_trees_planted_banana number_trees_planted_cassava number_trees_planted_cocoa (.=0)
collapse (firstnm) harvest* area_harv*  area_plan* total_planted_area* total_harv_area* kgs_harvest*   value_harv* value_sold* (sum) number_trees_planted*  , by(hhid)
recode harvest*   area_harv* area_plan* kgs_harvest* total_planted_area* total_harv_area*    value_harv* value_sold* (0=.)
la var kgs_harvest "Quantity harvested of all crops (kgs) (household) (summed accross all seasons)"

*ren variable
foreach p of global topcropname_area {
	lab var value_harv_`p' "Value harvested of `p' (TSH) (household)"
	lab var value_sold_`p' "Value sold of `p' (TSH) (household)"
	lab var kgs_harvest_`p'  "Quantity harvested of `p' (kgs) (household) (summed accross all seasons)"
	lab var total_harv_area_`p'  "Total area harvested of `p' (ha) (household) (summed accross all seasons)"
	lab var total_planted_area_`p'  "Total area planted of `p' (ha) (household) (summed accross all seasons)"
	lab var harvest_`p' "Quantity harvested of `p' (kgs) (household)"
	lab var harvest_male_`p' "Quantity harvested of `p' (kgs) (male-managed plots)"
	lab var harvest_female_`p' "Quantity harvested of `p' (kgs) (female-managed plots)"
	lab var harvest_mixed_`p' "Quantity harvested of `p' (kgs) (mixed-managed plots)"
	lab var harvest_pure_`p' "Quantity harvested of `p' (kgs) - purestand (household)"
	lab var harvest_pure_male_`p'  "Quantity harvested of `p' (kgs) - purestand (male-managed plots)"
	lab var harvest_pure_female_`p'  "Quantity harvested of `p' (kgs) - purestand (female-managed plots)"
	lab var harvest_pure_mixed_`p'  "Quantity harvested of `p' (kgs) - purestand (mixed-managed plots)"
	lab var harvest_inter_`p' "Quantity harvested of `p' (kgs) - intercrop (household)"
	lab var harvest_inter_male_`p' "Quantity harvested of `p' (kgs) - intercrop (male-managed plots)"
	lab var harvest_inter_female_`p' "Quantity harvested of `p' (kgs) - intercrop (female-managed plots)"
	lab var harvest_inter_mixed_`p' "Quantity harvested  of `p' (kgs) - intercrop (mixed-managed plots)"
	lab var area_harv_`p' "Area harvested of `p' (ha) (household)"
	lab var area_harv_male_`p' "Area harvested of `p' (ha) (male-managed plots)"
	lab var area_harv_female_`p' "Area harvested of `p' (ha) (female-managed plots)"
	lab var area_harv_mixed_`p' "Area harvested of `p' (ha) (mixed-managed plots)"
	lab var area_harv_pure_`p' "Area harvested of `p' (ha) - purestand (household)"
	lab var area_harv_pure_male_`p'  "Area harvested of `p' (ha) - purestand (male-managed plots)"
	lab var area_harv_pure_female_`p'  "Area harvested of `p' (ha) - purestand (female-managed plots)"
	lab var area_harv_pure_mixed_`p'  "Area harvested of `p' (ha) - purestand (mixed-managed plots)"
	lab var area_harv_inter_`p' "Area harvested of `p' (ha) - intercrop (household)"
	lab var area_harv_inter_male_`p' "Area harvested of `p' (ha) - intercrop (male-managed plots)"
	lab var area_harv_inter_female_`p' "Area harvested of `p' (ha) - intercrop (female-managed plots)"
	lab var area_harv_inter_mixed_`p' "Area harvested  of `p' (ha) - intercrop (mixed-managed plots)"
	lab var area_plan_`p' "Area planted of `p' (ha) (household)"
	lab var area_plan_male_`p' "Area planted of `p' (ha) (male-managed plots)"
	lab var area_plan_female_`p' "Area planted of `p' (ha) (female-managed plots)"
	lab var area_plan_mixed_`p' "Area planted of `p' (ha) (mixed-managed plots)"
	lab var area_plan_pure_`p' "Area planted of `p' (ha) - purestand (household)"
	lab var area_plan_pure_male_`p'  "Area planted of `p' (ha) - purestand (male-managed plots)"
	lab var area_plan_pure_female_`p'  "Area planted of `p' (ha) - purestand (female-managed plots)"
	lab var area_plan_pure_mixed_`p'  "Area planted of `p' (ha) - purestand (mixed-managed plots)"
	lab var area_plan_inter_`p' "Area planted of `p' (ha) - intercrop (household)"
	lab var area_plan_inter_male_`p' "Area planted of `p' (ha) - intercrop (male-managed plots)"
	lab var area_plan_inter_female_`p' "Area planted of `p' (ha) - intercrop (female-managed plots)"
	lab var area_plan_inter_mixed_`p' "Area planted  of `p' (ha) - intercrop (mixed-managed plots)"
}
drop if hhid== 200156 | hhid==200190 | hhid==310091 // households that have an area planted or harvested but indicated that they rented out or did not cultivate
foreach p of global topcropname_area {
	gen grew_`p'=(total_harv_area_`p'!=. & total_harv_area_`p'!=.0 ) | (total_planted_area_`p'!=. & total_planted_area_`p'!=.0)
	lab var grew_`p' "1=Household grew `p'"
	gen harvested_`p'= (total_harv_area_`p'!=. & total_harv_area_`p'!=.0 )
	lab var harvested_`p' "1= Household harvested `p'"
}
replace grew_banana =1 if  number_trees_planted_banana!=0 & number_trees_planted_banana!=.
replace grew_cassav =1 if number_trees_planted_cassava!=0 & number_trees_planted_cassava!=.
replace grew_cocoa =1 if number_trees_planted_cocoa!=0 & number_trees_planted_cocoa!=.
drop harvest- harvest_pure_mixed area_harv- area_harv_pure_mixed area_plan- area_plan_pure_mixed value_harv value_sold total_planted_area total_harv_area
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_yield_hh_crop_level.dta", replace


********************************************************************************
*SHANNON DIVERSITY INDEX
********************************************************************************
*Area planted
*Bringing in area planted for LRS
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_area_plan.dta", clear
*Some households have crop observations, but the area planted=0. These are permanent crops. Right now they are not included in the SDI unless they are the only crop on the plot, but we could include them by estimating an area based on the number of trees planted
drop if area_plan==0
*generating area planted of each crop as a proportion of the total area
preserve
collapse (sum) area_plan_hh=area_plan area_plan_female_hh=area_plan_female area_plan_male_hh=area_plan_male area_plan_mixed_hh=area_plan_mixed, by(hhid)
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_area_plan_shannon.dta", replace
restore
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_area_plan_shannon.dta", nogen		//all matched
recode area_plan_female area_plan_male area_plan_female_hh area_plan_male_hh area_plan_mixed area_plan_mixed_hh (0=.)
gen prop_plan = area_plan/area_plan_hh
gen prop_plan_female=area_plan_female/area_plan_female_hh
gen prop_plan_male=area_plan_male/area_plan_male_hh
gen prop_plan_mixed=area_plan_mixed/area_plan_mixed_hh
gen sdi_crop = prop_plan*ln(prop_plan)
gen sdi_crop_female = prop_plan_female*ln(prop_plan_female)
gen sdi_crop_male = prop_plan_male*ln(prop_plan_male)
gen sdi_crop_mixed = prop_plan_mixed*ln(prop_plan_mixed)
*tagging those that are missing all values
bysort hhid (sdi_crop_female) : gen allmissing_female = mi(sdi_crop_female[1])
bysort hhid (sdi_crop_male) : gen allmissing_male = mi(sdi_crop_male[1])
bysort hhid (sdi_crop_mixed) : gen allmissing_mixed = mi(sdi_crop_mixed[1])
*Generating number of crops per household
bysort hhid crop_code : gen nvals_tot = _n==1
gen nvals_female = nvals_tot if area_plan_female!=0 & area_plan_female!=.
gen nvals_male = nvals_tot if area_plan_male!=0 & area_plan_male!=.
gen nvals_mixed = nvals_tot if area_plan_mixed!=0 & area_plan_mixed!=.
collapse (sum) sdi=sdi_crop sdi_female=sdi_crop_female sdi_male=sdi_crop_male sdi_mixed=sdi_crop_mixed num_crops_hh=nvals_tot num_crops_female=nvals_female ///
num_crops_male=nvals_male num_crops_mixed=nvals_mixed (max) allmissing_female allmissing_male allmissing_mixed, by(hhid)
la var sdi "Shannon diversity index"
la var sdi_female "Shannon diversity index on female managed plots"
la var sdi_male "Shannon diversity index on male managed plots"
la var sdi_mixed "Shannon diversity index on mixed managed plots"
replace sdi_female=. if allmissing_female==1
replace sdi_male=. if allmissing_male==1
replace sdi_mixed=. if allmissing_mixed==1
gen encs = exp(-sdi)
gen encs_female = exp(-sdi_female)
gen encs_male = exp(-sdi_male)
gen encs_mixed = exp(-sdi_mixed)
la var encs "Effective number of crop species per household"
la var encs_female "Effective number of crop species on female managed plots per household"
la var encs_male "Effective number of crop species on male managed plots per household"
la var encs_mixed "Effective number of crop species on mixed managed plots per household"
la var num_crops_hh "Number of crops grown by the household"
la var num_crops_female "Number of crops grown on female managed plots"
la var num_crops_male "Number of crops grown on male managed plots"
la var num_crops_mixed "Number of crops grown on mixed managed plots"
gen multiple_crops = (num_crops_hh>1 & num_crops_hh!=.)
la var multiple_crops "Household grows more than one crop"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_shannon_diversity_index.dta", replace


********************************************************************************
*CONSUMPTION
********************************************************************************
*first get adult equivalent
use "${Nigeria_GHS_W3_raw_data}/PTrack.dta", clear
ren sex gender
gen adulteq=.
replace adulteq=0.4 if (age<3 & age>=0)
replace adulteq=0.48 if (age<5 & age>2)
replace adulteq=0.56 if (age<7 & age>4)
replace adulteq=0.64 if (age<9 & age>6)
replace adulteq=0.76 if (age<11 & age>8)
replace adulteq=0.80 if (age<12 & age>10) & gender==1		//1=male, 2=female
replace adulteq=0.88 if (age<12 & age>10) & gender==2
replace adulteq=1 if (age<15 & age>12)
replace adulteq=1.2 if (age<19 & age>14) & gender==1
replace adulteq=1 if (age<19 & age>14) & gender==2
replace adulteq=1 if (age<60 & age>18) & gender==1
replace adulteq=0.88 if (age<60 & age>18) & gender==2
replace adulteq=0.8 if (age>59 & age!=.) & gender==1
replace adulteq=0.72 if (age>59 & age!=.) & gender==2
replace adulteq=. if age==999
collapse (sum) adulteq, by(hhid)
lab var adulteq "Adult-Equivalent"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_adulteq.dta", replace


use "${Nigeria_GHS_W3_raw_data}/cons_agg_wave3_visit1.dta", clear
ren  totcons totcons_v1
merge 1:1 hhid using "${Nigeria_GHS_W3_raw_data}/cons_agg_wave3_visit2.dta", nogen
ren  totcons totcons_v2
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_adulteq.dta"
*Per the Nigeria BID in Wave 2, we should average the consumption aggregat for the tow visits
egen totcons=rowmean(totcons_v1 totcons_v2)
gen percapita_cons = totcons
gen daily_percap_cons = percapita_cons/365
gen total_cons = (totcons *hhsize)
gen peraeq_cons = total_cons/adulteq
gen daily_peraeq_cons = peraeq_cons/365
la var percapita_cons "Yearly HH consumption per person"
la var total_cons "Total yearly HH consumption - averaged over two visits"
la var peraeq_cons "Yearly HH consumption per adult equivalent"
la var daily_peraeq_cons "Daily HH consumption per adult equivalent"
la var daily_percap_cons "Daily HH consumption per person"
keep hhid adulteq totcons percapita_cons daily_percap_cons total_cons peraeq_cons daily_peraeq_cons
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_consumption.dta", replace


********************************************************************************
*HOUSEHOLD FOOD PROVISION*
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect12_harvestw3.dta", clear
foreach i in a b c d e f{
	gen food_insecurity_`i' = (s12q6`i'!=.)
}
egen months_food_insec = rowtotal (food_insecurity_*)
lab var months_food_insec "Number of months where the household experienced any food insecurity"
keep hhid months_food_insec
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_food_insecurity.dta", replace


********************************************************************************
*HOUSEHOLD ASSETS*
********************************************************************************
use "${Nigeria_GHS_W3_raw_data}/sect5_plantingw3.dta", clear
ren s5q4 value_today
ren s5q1 number_items_owned
ren s5q3 age_item
gen value_assets = value_today*number_items_owned
collapse (sum) value_assets=value_today, by(hhid)
la var value_assets "Value of household assets"
save "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_assets.dta", replace


********************************************************************************
*HOUSEHOLD VARIABLES
********************************************************************************
//setting up empty variable list: create these with a value of missing and then recode all of these to missing at the end of the HH section (some may be recoded to 0 in this section)
global empty_vars ""
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hhids.dta", clear
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_adulteq.dta", nogen keep(1 3)
*Gross crop income
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_crop_production.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_crop_losses.dta", nogen keep(1 3)
recode value_crop_production crop_value_lost (.=0)

*Crop costs
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_asset_rental_costs.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_rental_costs.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_seed_costs.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_manure_costs.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_chemical_costs.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fertilizer_costs.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_wages_postplanting.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_wages_postharvest.dta", nogen keep(1 3)
recode animal_rent_paid rental_cost_ag_assets rental_cost_land cost_seed cost_transportation_seed value_manure_purchased /*
*/ cost_transport_manure expenditure_subsidized_fert value_fertilizer cost_transport_fertilizer cost_transport_free_fert /*
*/ value_herbicide value_pesticide wages_paid_aglabor_postplant wages_paid_aglabor_postharvest (.=0)
egen crop_production_expenses = rowtotal(animal_rent_paid rental_cost_ag_assets rental_cost_land cost_seed cost_transportation_seed  /*
*/ value_manure_purchased cost_transport_manure expenditure_subsidized_fert value_fertilizer cost_transport_fertilizer /*
*/ cost_transport_free_fert value_herbicide value_pesticide wages_paid_aglabor_postplant wages_paid_aglabor_postharvest)
gen crop_income = value_crop_production - crop_production_expenses - crop_value_lost
lab var crop_production_expenses "Crop production expenditures (explicit)"
lab var crop_income "Net crop revenue (value of production minus crop expenses)"
*top crop costs by area planted
foreach c in $topcropname_area {
	merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_rental_costs_`c'.dta", nogen keep(1 3)
	merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_seed_costs_`c'.dta", nogen keep(1 3)
	merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fertilizer_costs_`c'.dta", nogen keep(1 3)
	merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_chemical_costs_`c'.dta", nogen keep(1 3)
	merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_manure_costs_`c'.dta", nogen keep(1 3)
	merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_wages_postplanting_`c'.dta", nogen keep(1 3)
	merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_wages_postharvest_`c'.dta", nogen keep(1 3)
	merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_`c'_monocrop_hh_area.dta", nogen keep(1 3)
}

foreach c in $topcropname_area {
	recode `c'_monocrop (.=0)
	egen `c'_exp = rowtotal(rental_cost_land_`c' cost_seed_`c' value_fertilizer_`c' cost_trans_fert_`c' value_herbicide_`c' value_pesticide_`c' value_manure_purch_`c' cost_trans_manure_`c' wages_paid_pp_`c' wages_paid_ph_`c')
	lab var `c'_exp "Crop production expenditures (explicit) - Monocropped `c' plots only"
	la var `c'_monocrop_ha "Total `c' monocrop hectares planted - Household"

*disaggregate by gender of plot manager
foreach i in male female mixed {
	egen `c'_exp_`i' = rowtotal(rental_cost_land_`c'_`i' cost_seed_`c'_`i' cost_trans_fert_`c'_`i' value_fertilizer_`c'_`i' value_herbicide_`c'_`i' value_pesticide_`c'_`i' value_manure_purch_`c'_`i' cost_trans_manure_`c'_`i' wages_paid_pp_`c'_`i' wages_paid_ph_`c'_`i')
	lab var  `c'_exp_`i'  "Crop production expenditures (explicit) - Monocropped `c' `i' managed plots"
}
replace `c'_exp = . if `c'_monocrop_ha==.			// set to missing if the household does not have any monocropped maize plots
foreach i in male female mixed{
	replace `c'_exp_`i' = . if `c'_monocrop_ha_`i'==.
	}
}
drop rental_cost_land* cost_seed* value_fertilizer* cost_trans_fert* value_herbicide* value_pesticide* value_manure_purch* cost_trans_manure*

*Land rights
merge 1:1 hhid using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_rights_hh.dta", nogen keep(1 3)
la var formal_land_rights_hh "Household has documentation of land rights (at least one plot)"

*Fish income
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fish_income.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fishing_expenses_1.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fishing_expenses_2.dta", nogen keep(1 3)
gen fish_income_fishfarm = value_fish_harvest - fish_expenses_1 - fish_expenses_2
gen fish_income_fishing = value_fish_caught - fish_expenses_1 - fish_expenses_2
gen fishing_income = fish_income_fishing
recode fishing_income fish_income_fishing fish_income_fishfarm (.=0)
lab var fish_income_fishing "Net fishing income (value of production and consumption minus expenditures)"
lab var fish_income_fishfarm "Net fish farm income (value of production minus expenditures)"
lab var fishing_income "Net fishing income (value of production and consumption minus expenditures)"

*Livestock income
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_sales.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_expenses.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_products.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_TLU.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_herd_characteristics.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_TLU_Coefficients.dta", nogen keep(1 3)
lab var sales_livestock_products "Value of sales of livestock products"
lab var value_livestock_products "Value of livestock products"
recode value_livestock_sales value_livestock_purchases value_milk_produced  value_eggs_produced value_other_produced fish_income_fishfarm  cost_*livestock (.=0)
gen livestock_income = value_slaughtered + value_lvstck_sold - value_livestock_purchases /*
*/ + ( value_milk_produced + value_eggs_produced + value_other_produced) /*
*/ - ( cost_hired_labor_livestock + cost_fodder_livestock + cost_vaccines_livestock + cost_other_livestock) + fish_income_fishfarm
recode livestock_income (.=0)
lab var livestock_income "Net livestock income (value of production and consumption minus expenditures)"
gen livestock_expenses = ( cost_hired_labor_livestock + cost_fodder_livestock + cost_vaccines_livestock + cost_other_livestock)
lab var livestock_expenses "Expenditures on livestock purchases and maintenance"
ren cost_vaccines_livestock ls_exp_vac
gen livestock_product_revenue = ( value_milk_produced + value_eggs_produced + value_other_produced)
lab var livestock_product_revenue "Gross revenue from sale of livestock products"
lab var sales_livestock_products "Value of sales of livestock products"
lab var value_livestock_products "Value of livestock products"
gen animals_lost12months =0
gen mean_12months=0
la var animals_lost12months "Total number of livestock  lost to disease"
la var mean_12months "Average number of livestock  today and 1  year ago"
gen any_imp_herd_all = .
foreach v in ls_exp_vac any_imp_herd{
foreach i in lrum srum poultry {
	gen `v'_`i' = .
	}
}
//adding - starting list of missing variables - recode all of these to missing at end of HH level file
global empty_vars $empty_vars animals_lost12months mean_12months *ls_exp_vac_lrum* *ls_exp_vac_srum* *ls_exp_vac_poultry* any_imp_herd_*

*Self-employment income
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_self_employment_income.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_agproduct_income.dta", nogen keep(1 3)
egen self_employment_income = rowtotal(profit_processed_crop_sold annual_selfemp_profit)
recode self_employment_income (.=0)
lab var self_employment_income "Income from self-employment (business)"

*Wage income
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_agwage_income.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_wage_income.dta", nogen keep(1 3)
recode annual_salary annual_salary_agwage (.=0)
ren annual_salary nonagwage_income
ren annual_salary_agwage agwage_income

*Off-farm hours
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_off_farm_hours.dta", nogen keep(1 3)

*Other income
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_other_income.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_remittance_income.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_other_income.dta", nogen keep(1 3)
egen transfers_income = rowtotal (remittance_income assistance_income)
lab var transfers_income "Income from transfers including pension, remittances, and assisances)"
egen all_other_income = rowtotal (investment_income rental_income_buildings other_income  rental_income_assets)
lab var all_other_income "Income from other revenue streams not captured elsewhere"
drop other_income

*Farm size
merge 1:1 hhid using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_size.dta", nogen keep(1 3)
merge 1:1 hhid using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_size_all.dta", nogen keep(1 3)
merge 1:1 hhid using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmsize_all_agland.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_size_total.dta", nogen
recode land_size (.=0)
recode farm_size_agland (.=0)
gen  farm_size_0_0=farm_size_agland==0
gen  farm_size_0_1=farm_size_agland>0 & farm_size_agland<=1
gen  farm_size_1_2=farm_size_agland>1 & farm_size_agland<=2
gen  farm_size_2_4=farm_size_agland>2 & farm_size_agland<=4
gen  farm_size_4_more=farm_size_agland>4
lab var farm_size_0_0 "1=Household has no farm"
lab var farm_size_0_1 "1=Household farm size > 0 Ha and <=1 Ha"
lab var farm_size_1_2 "1=Household farm size > 1 Ha and <=2 Ha"
lab var farm_size_2_4 "1=Household farm size > 2 Ha and <=4 Ha"
lab var farm_size_4_more "1=Household farm size > 4 Ha"

*Labor
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_family_hired_labor.dta", nogen keep(1 3)
recode labor_hired labor_family (.=0)

*Household size
merge 1:1 hhid using  "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hhsize.dta", nogen keep(1 3)

*Rates of vaccine usage, improved seeds, etc.
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_vaccine.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fert_use.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_improvedseed_use.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_any_ext.dta", nogen keep(1 3)
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fin_serv.dta", nogen keep(1 3)
recode use_fin_serv* ext_reach* use_inorg_fert imprv_seed_use vac_animal (.=0)
replace vac_animal=. if tlu_today==0
replace use_inorg_fert=. if farm_area==0 | farm_area==. // Area cultivated this year
recode ext_reach* (0 1=.) if (value_crop_production==0 & livestock_income==0 & farm_area==0 & farm_area==. &  tlu_today==0)
replace imprv_seed_use=. if farm_area==.
global empty_vars $empty_vars hybrid_seed*

*Milk productivity
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_milk_animals.dta", nogen keep(1 3)
gen costs_dairy = .
gen costs_dairy_percow = .
la var costs_dairy "Dairy production cost (explicit)"
la var costs_dairy_percow "Dairy production cost (explicit) per cow"
gen liters_per_cow = .
gen liters_per_buffalo = .
gen share_imp_dairy = .
gen milk_animals = .
global empty_vars $empty_vars *costs_dairy* *costs_dairy_percow* share_imp_dairy *liters_per_cow *liters_per_buffalo milk_animals

*Egg productivity
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_egg_animals.dta", nogen keep(1 3)
gen liters_milk_produced = milk_months_produced * milk_quantity_produced
lab var liters_milk_produced "Total quantity (liters) of milk per year (household)"
gen eggs_total_year =eggs_quantity_produced * eggs_months_produced
lab var eggs_total_year "Total number of eggs that was produced (household)"
gen egg_poultry_year = .
gen poultry_owned = .
global empty_vars $empty_vars *egg_poultry_year poultry_owned

*Costs of crop production per hectare
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_cropcosts.dta", nogen keep(1 3)

*Rate of fertilizer application
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_fertilizer_application.dta", nogen keep(1 3)

*Agricultural wage rate
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_ag_wage.dta", nogen keep(1 3)

*Crop yields
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_yield_hh_crop_level.dta", nogen keep(1 3)

*Total area planted and harvested accross all crops, plots, and seasons
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_area_planted_harvested_allcrops.dta", nogen keep(1 3)

*Household diet
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_household_diet.dta", nogen keep(1 3)

*consumption
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_consumption.dta", nogen keep(1 3)

*Household assets
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hh_assets.dta", nogen keep(1 3)

*Food insecurity
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_food_insecurity.dta", nogen keep(1 3)
gen hhs_little = .
gen hhs_moderate = .
gen hhs_severe = .
gen hhs_total = .
global empty_vars $empty_vars hhs_*

*Distance to agrodealer // cannot construct
gen dist_agrodealer = .
global empty_vars $empty_vars *dist_agrodealer

*Livestock health
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_livestock_diseases.dta", nogen keep(1 3)

*livestock feeding, water, and housing
*cannot construct
gen feed_grazing = .
gen water_source_nat = .
gen water_source_const = .
gen water_source_cover = .
gen lvstck_housed = .
foreach v in feed_grazing water_source_nat water_source_const water_source_cover lvstck_housed {
foreach i in lrum srum poultry {
	gen `v'_`i' = .
	}
}
global empty_vars $empty_vars feed_grazing* water_source* lvstck_housed*

*Shannon Diversity index
merge 1:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_shannon_diversity_index.dta", nogen keep(1 3)

*Farm Production
gen value_farm_production = value_crop_production + value_livestock_products + value_slaughtered + value_lvstck_sold
lab var value_farm_production "Total value of farm production (crops + livestock products)"
gen value_farm_prod_sold = value_crop_sales + sales_livestock_products + value_livestock_sales
lab var value_farm_prod_sold "Total value of farm production that is sold"
replace value_farm_prod_sold = 0 if value_farm_prod_sold==. & value_farm_production!=.

*Agricultural households
recode value_crop_production livestock_income farm_area tlu_today (.=0)
gen ag_hh = (value_crop_production!=0 | livestock_income!=0 | farm_area!=0 | tlu_today!=0)
lab var ag_hh "1= Household has some land cultivated, some livestock, some crop income, or some livestock income"

*household with egg-producing animals
gen egg_hh = (value_eggs_produced>0 & value_eggs_produced!=.)
lab var egg_hh "1=Household engaged in egg production"
*household engaged in dairy production
gen dairy_hh = (value_milk_produced>0 & value_milk_produced!=.)
lab var dairy_hh "1= Household engaged in dairy production"

*Households engaged in ag activities including working in paid ag jobs
gen agactivities_hh =ag_hh==1 | (agwage_income!=0 & agwage_income!=.)
lab var agactivities_hh "1=Household has some land cultivated, livestock, crop income, livestock income, or ag wage income"

*Creating crop households and livestock households
gen crop_hh = (value_crop_production!=0  | farm_area!=0)
lab var crop_hh "1= Household has some land cultivated or some crop income"
gen livestock_hh = (livestock_income!=0 | tlu_today!=0)
lab  var livestock_hh "1= Household has some livestock or some livestock income"
recode fishing_income (.=0)
gen fishing_hh = (fishing_income!=0)
lab  var fishing_hh "1= Household has some fishing income"

****getting correct subpopulations*****
*Recoding missings to 0 for households growing crops
recode grew* (.=0)
*all rural households growing specific crops
forvalues k=1(1)$nb_topcrops {
	local cn: word `k' of $topcropname_area
	recode value_harv_`cn' value_sold_`cn' kgs_harvest_`cn' total_planted_area_`cn' total_harv_area_`cn' `cn'_exp (.=0) if grew_`cn'==1
	recode value_harv_`cn' value_sold_`cn' kgs_harvest_`cn' total_planted_area_`cn' total_harv_area_`cn' `cn'_exp (nonmissing=.) if grew_`cn'==0
}
*all rural households engaged in livestcok production of a given species
foreach i in lrum srum poultry{
	recode lost_disease_`i' ls_exp_vac_`i' disease_animal_`i' feed_grazing_`i' water_source_nat_`i' water_source_const_`i' water_source_cover_`i' lvstck_housed_`i' (nonmissing=.) if lvstck_holding_`i'==0
	recode lost_disease_`i' ls_exp_vac_`i' disease_animal_`i' feed_grazing_`i' water_source_nat_`i' water_source_const_`i' water_source_cover_`i' lvstck_housed_`i'(.=0) if lvstck_holding_`i'==1
}
*households engaged in crop production
recode cost_expli_hh value_crop_production value_crop_sales labor_hired labor_family farm_size_agland all_area_harvested all_area_planted  encs num_crops_hh multiple_crops (.=0) if crop_hh==1
recode cost_expli_hh value_crop_production value_crop_sales labor_hired labor_family farm_size_agland all_area_harvested all_area_planted  encs num_crops_hh multiple_crops (nonmissing=.) if crop_hh==0
*all rural households engaged in livestock production
recode animals_lost12months* mean_12months* livestock_expenses disease_animal feed_grazing water_source_nat water_source_const water_source_cover lvstck_housed (.=0) if livestock_hh==1
recode animals_lost12months* mean_12months* livestock_expenses disease_animal feed_grazing water_source_nat water_source_const water_source_cover lvstck_housed (nonmissing=.) if livestock_hh==0
*all rural households
recode off_farm_hours crop_income livestock_income self_employment_income nonagwage_income agwage_income fishing_income transfers_income all_other_income value_assets (.=0)
*all rural households engaged in dairy production
recode costs_dairy liters_milk_produced value_milk_produced (.=0) if dairy_hh==1
recode costs_dairy liters_milk_produced value_milk_produced (nonmissing=.) if dairy_hh==0
*all rural households eith egg-producing animals
recode eggs_total_year value_eggs_produced (.=0) if egg_hh==1
recode eggs_total_year value_eggs_produced (nonmissing=.) if egg_hh==0

global gender "female male mixed"
*Variables winsorized at the top 1% only
global wins_var_top1 /*
*/ value_crop_production value_crop_sales value_harv* value_sold* kgs_harvest* kgs_harv_mono* total_planted_area* total_harv_area* /*
*/ labor_hired labor_family /*
*/ animals_lost12months mean_12months lost_disease* /*
*/ liters_milk_produced costs_dairy /*
*/ eggs_total_year value_eggs_produced value_milk_produced /*
*/ off_farm_hours crop_production_expenses value_assets cost_expli_hh /*
*/ livestock_expenses ls_exp_vac* sales_livestock_products value_livestock_products value_livestock_sales /*
*/ value_farm_production value_farm_prod_sold

gen wage_paid_aglabor_mixed=. //create this just to make the loop work and delete after
foreach v of varlist $wins_var_top1 {
	_pctile `v' [aw=weight] , p($wins_upper_thres)
	gen w_`v'=`v'
	replace  w_`v' = r(r1) if  w_`v' > r(r1) &  w_`v'!=.
	local l`v' : var lab `v'
	lab var  w_`v'  "`l`v'' - Winzorized top 1%"
}

*Variables winsorized at the top 1% only - for variables disaggregated by the gender of the plot manager
global wins_var_top1_gender=""
foreach v in $topcropname_area {
	global wins_var_top1_gender $wins_var_top1_gender `v'_exp
}
global wins_var_top1_gender $wins_var_top1_gender cost_total cost_expli fert_inorg_kg wage_paid_aglabor

foreach v of varlist $wins_var_top1_gender {
	_pctile `v' [aw=weight] , p($wins_upper_thres)
	gen w_`v'=`v'
	replace  w_`v' = r(r1) if  w_`v' > r(r1) &  w_`v'!=.
	local l`v' : var lab `v'
	lab var  w_`v'  "`l`v'' - Winzorized top 1%"

	*some variables are disaggreated by gender of plot manager. For these variables, we use the top 1% percentile to winsorize gender-disagregated variables
	foreach g of global gender {
		gen w_`v'_`g'=`v'_`g'
		replace  w_`v'_`g' = r(r1) if w_`v'_`g' > r(r1) & w_`v'_`g'!=.
		local l`v'_`g' : var lab `v'_`g'
		lab var  w_`v'_`g'  "`l`v'_`g'' - Winzorized top 1%"
	}
}

drop *wage_paid_aglabor_mixed
egen w_labor_total=rowtotal(w_labor_hired w_labor_family)
local llabor_total : var lab labor_total
lab var w_labor_total "`llabor_total' - Winzorized top 1%"

*Variables winsorized both at the top 1% and bottom 1%
global wins_var_top1_bott1  /*
*/ farm_area farm_size_agland all_area_harvested all_area_planted ha_planted /*
*/ crop_income livestock_income fishing_income self_employment_income nonagwage_income agwage_income transfers_income all_other_income total_cons percapita_cons daily_percap_cons peraeq_cons daily_peraeq_cons /*
*/ *_monocrop_ha* dist_agrodealer land_size_total

foreach v of varlist $wins_var_top1_bott1 {
	_pctile `v' [aw=weight] , p($wins_lower_thres $wins_upper_thres)
	gen w_`v'=`v'
	replace w_`v'= r(r1) if w_`v' < r(r1) & w_`v'!=. & w_`v'!=0  /* we want to keep actual zeros */
	replace w_`v'= r(r2) if  w_`v' > r(r2)  & w_`v'!=.
	local l`v' : var lab `v'
	lab var  w_`v'  "`l`v'' - Winzorized top and bottom 1%"
	*some variables  are disaggreated by gender of plot manager. For these variables, we use the top and bottom 1% percentile to winsorize gender-disagregated variables
	if "`v'"=="ha_planted" {
		foreach g of global gender {
			gen w_`v'_`g'=`v'_`g'
			replace w_`v'_`g'= r(r1) if w_`v'_`g' < r(r1) & w_`v'_`g'!=. & w_`v'_`g'!=0  /* we want to keep actual zeros */
			replace w_`v'_`g'= r(r2) if  w_`v'_`g' > r(r2)  & w_`v'_`g'!=.
			local l`v'_`g' : var lab `v'_`g'
			lab var  w_`v'_`g'  "`l`v'_`g'' - Winzorized top and bottom 1%"
		}
	}
}

*Winsorizing variables that go into yield at the top and bottom 5% due to extreme outliers
global allyield male female mixed inter inter_male inter_female inter_mixed pure  pure_male pure_female pure_mixed
global wins_var_top1_bott1_2 area_harv  area_plan harvest
foreach v of global wins_var_top1_bott1_2 {
	foreach c of global topcropname_area {
		_pctile `v'_`c'  [aw=weight] , p(5 95)
		gen w_`v'_`c'=`v'_`c'
		replace w_`v'_`c' = r(r1) if w_`v'_`c' < r(r1)   &  w_`v'_`c'!=0
		replace w_`v'_`c' = r(r2) if (w_`v'_`c' > r(r2) & w_`v'_`c' !=.)
		local l`v'_`c'  : var lab `v'_`c'
		lab var  w_`v'_`c' "`l`v'_`c'' - Winzorized top and bottom 5%"
		* now use pctile from area for all to trim gender/inter/pure area
		foreach g of global allyield {
			gen w_`v'_`g'_`c'=`v'_`g'_`c'
			replace w_`v'_`g'_`c' = r(r1) if w_`v'_`g'_`c' < r(r1) &  w_`v'_`g'_`c'!=0
			replace w_`v'_`g'_`c' = r(r2) if (w_`v'_`g'_`c' > r(r2) & w_`v'_`g'_`c' !=.)
			local l`v'_`g'_`c'  : var lab `v'_`g'_`c'
			lab var  w_`v'_`g'_`c' "`l`v'_`g'_`c'' - Winzorized top and bottom 5%"

		}
	}
}


*Estimate variables that are ratios then winsorize top 1% and bottom 1% of the ratios (do not replace 0 by the percentitles)
*generate yield and weights for yields  using winsorized values
*Yield by Area Planted
foreach c of global topcropname_area {
	gen yield_pl_`c'=w_harvest_`c'/w_area_plan_`c'
	lab var  yield_pl_`c' "Yield by area planted of `c' (kgs/ha) (household)"
	gen ar_pl_wgt_`c' =  weight*w_area_plan_`c'
	lab var ar_pl_wgt_`c' "Planted area-adjusted weight for `c' (household)"
	foreach g of global allyield  {
		gen yield_pl_`g'_`c'=w_harvest_`g'_`c'/w_area_plan_`g'_`c'
		lab var  yield_pl_`g'_`c'  "Yield  by area planted of `c' -  (kgs/ha) (`g')"
		gen ar_pl_wgt_`g'_`c' =  weight*w_area_plan_`g'_`c'
		lab var ar_pl_wgt_`g'_`c' "Harvested area-adjusted weight for `c' (`g')"
	}
}

 *Yield by Area Harvested
foreach c of global topcropname_area {
	gen yield_hv_`c'=w_harvest_`c'/w_area_harv_`c'
	lab var  yield_hv_`c' "Yield by area harvested of `c' (kgs/ha) (household)"
	gen ar_h_wgt_`c' =  weight*w_area_harv_`c'
	lab var ar_h_wgt_`c' "Harvested area-adjusted weight for `c' (household)"
	foreach g of global allyield  {
		gen yield_hv_`g'_`c'=w_harvest_`g'_`c'/w_area_harv_`g'_`c'
		lab var  yield_hv_`g'_`c'  "Yield by area harvested of `c' -  (kgs/ha) (`g')"
		gen ar_h_wgt_`g'_`c' =  weight*w_area_harv_`g'_`c'
		lab var ar_h_wgt_`g'_`c' "Harvested area-adjusted weight for `c' (`g')"
	}
}


*generate inorg_fert_rate, costs_total_ha, and costs_explicit_ha using winsorized values
gen inorg_fert_rate=w_fert_inorg_kg/w_ha_planted
gen cost_total_ha = w_cost_total / w_ha_planted
gen cost_expli_ha = w_cost_expli / w_ha_planted

foreach g of global gender {
	gen inorg_fert_rate_`g'=w_fert_inorg_kg_`g'/ w_ha_planted_`g'
	gen cost_total_ha_`g'=w_cost_total_`g'/ w_ha_planted_`g'
	gen cost_expli_ha_`g'=w_cost_expli_`g'/ w_ha_planted_`g'
}
lab var inorg_fert_rate "Rate of fertilizer application (kgs/ha) (household level)"
lab var inorg_fert_rate_male "Rate of fertilizer application (kgs/ha) (male-managed crops)"
lab var inorg_fert_rate_female "Rate of fertilizer application (kgs/ha) (female-managed crops)"
lab var inorg_fert_rate_mixed "Rate of fertilizer application (kgs/ha) (mixed-managed crops)"
lab var cost_total_ha "Explicit + implicit costs (per ha) of crop production costs that can be disaggregated at the plot manager level"
lab var cost_total_ha_male "Explicit + implicit costs (per ha) of crop production (male-managed plots)"
lab var cost_total_ha_female "Explicit + implicit costs (per ha) of crop production (female-managed plots)"
lab var cost_total_ha_mixed "Explicit + implicit costs (per ha) of crop production (mixed-managed plots)"
lab var cost_expli_ha "Explicit costs (per ha) of crop production costs that can be disaggregated at the plot manager level"
lab var cost_expli_ha_male "Explicit costs (per ha) of crop production (male-managed plots)"
lab var cost_expli_ha_female "Explicit costs (per ha) of crop production (female-managed plots)"
lab var cost_expli_ha_mixed "Explicit costs (per ha) of crop production (mixed-managed plots)"

*mortality rate
global animal_species lrum srum pigs equine  poultry
foreach s of global animal_species {
	gen mortality_rate_`s' = animals_lost_agseas_`s'/mean_agseas_`s'
	lab var mortality_rate_`s' "Mortality rate - `s'"
}

*generating top crop expenses using winsoried values (monocropped)
foreach c in $topcropname_area{
	gen `c'_exp_ha =w_`c'_exp /w_`c'_monocrop_ha
	la var `c'_exp_ha "Costs per hectare - Monocropped `c' plots"
	foreach  g of global gender{
		gen `c'_exp_ha_`g' =w_`c'_exp_`g'/w_`c'_monocrop_ha
		la var `c'_exp_ha_`g' "Costs per hectare - Monocropped `c' `g' managed plots"
	}
}

*Off farm hours per capita using winsorized version off_farm_hours
gen off_farm_hours_pc_all = w_off_farm_hours/member_count
gen off_farm_hours_pc_any = w_off_farm_hours/off_farm_any_count
la var off_farm_hours_pc_all "Off-farm hours per capita, all members>5 years"
la var off_farm_hours_pc_any "Off-farm hours per capita, only members>5 years workings"

*generating total crop production costs per hectare
gen cost_expli_hh_ha = w_cost_expli_hh / w_ha_planted
lab var cost_expli_hh_ha "Explicit costs (per ha) of crop production (household level)"

*land and labor productivity
gen land_productivity = w_value_crop_production/w_farm_area
gen labor_productivity = w_value_crop_production/w_labor_total
lab var land_productivity "Land productivity (value production per ha cultivated)"
lab var labor_productivity "Labor productivity (value production per labor-day)"

*milk productivity
gen liters_per_largeruminant= .
la var liters_per_largeruminant "Average quantity (liters) per year (household)"
global empty_vars $empty_vars liters_per_largeruminant

*crop value sold
gen w_proportion_cropvalue_sold = w_value_crop_sales /  w_value_crop_production
replace w_proportion_cropvalue_sold = 1 if w_proportion_cropvalue_sold > 1 & w_proportion_cropvalue_sold != .
lab var w_proportion_cropvalue_sold "Proportion of crop value produced (winsorized) that has been sold"

*livestock value sold
gen w_share_livestock_prod_sold = w_sales_livestock_products / w_value_livestock_products
replace w_share_livestock_prod_sold = 1 if w_share_livestock_prod_sold>1 & w_share_livestock_prod_sold!=.
lab var w_share_livestock_prod_sold "Percent of production of livestock products (winsorized) that is sold"

*Propotion of farm production sold
gen w_prop_farm_prod_sold = w_value_farm_prod_sold / w_value_farm_production
replace w_prop_farm_prod_sold = 1 if w_prop_farm_prod_sold>1 & w_prop_farm_prod_sold!=.
lab var w_prop_farm_prod_sold "Proportion of farm production (winsorized) that has been sold"

*unit cost of production
*all top crops
foreach c in $topcropname_area{
	gen `c'_exp_kg = w_`c'_exp /w_kgs_harv_mono_`c'
	la var `c'_exp_kg "Costs per kg - Monocropped `c' plots"
	foreach g of global gender {
		gen `c'_exp_kg_`g'=w_`c'_exp_`g'/ w_kgs_harv_mono_`c'_`g'
		la var `c'_exp_kg_`g' "Costs per kg - Monocropped `c' `g' managed plots"
	}
}

*dairy
gen cost_per_lit_milk = costs_dairy/w_liters_milk_produced
la var cost_per_lit_milk "Dairy production cost per liter"
global empty_vars $empty_vars cost_per_lit_milk

*****getting correct subpopulations***
*all rural housseholds engaged in crop production
recode inorg_fert_rate cost_total_ha cost_expli_ha cost_expli_hh_ha land_productivity labor_productivity (.=0) if crop_hh==1
recode inorg_fert_rate cost_total_ha cost_expli_ha cost_expli_hh_ha land_productivity labor_productivity (nonmissing=.) if crop_hh==0
*all rural households engaged in livestcok production of a given species
foreach i in lrum srum poultry{
	recode mortality_rate_`i' (nonmissing=.) if lvstck_holding_`i'==0
	recode mortality_rate_`i' (.=0) if lvstck_holding_`i'==1
}
*all rural households
recode off_farm_hours_pc_all (.=0)
*households engaged in monocropped production of specific crops
forvalues k=1/$nb_topcrops {
	local cn: word `k' of $topcropname_area
	recode `cn'_exp `cn'_exp_ha `cn'_exp_kg (.=0) if `cn'_monocrop==1
	recode `cn'_exp `cn'_exp_ha `cn'_exp_kg (nonmissing=.) if `cn'_monocrop==0
}
*all rural households growing specific crops
forvalues k=1(1)$nb_topcrops {
	local cn: word `k' of $topcropname_area
	recode yield_pl_`cn' (.=0) if grew_`cn'==1
	recode yield_pl_`cn' (nonmissing=.) if grew_`cn'==0
}
*all rural households harvesting specific crops
forvalues k=1(1)$nb_topcrops {
	local cn: word `k' of $topcropname_area
	recode yield_hv_`cn' (.=0) if harvested_`cn'==1
	recode yield_hv_`cn' (nonmissing=.) if harvested_`cn'==0
}

*households growing specific crops that have also purestand plots of that crop
forvalues k=1(1)$nb_topcrops {
	local cn: word `k' of $topcropname_area
	recode yield_pl_pure_`cn' (.=0) if grew_`cn'==1 & w_area_plan_pure_`cn'!=.
	recode yield_pl_pure_`cn' (nonmissing=.) if grew_`cn'==0 | w_area_plan_pure_`cn'==.
}
*all rural households harvesting specific crops (in the long rainy season) that also have purestand plots
forvalues k=1(1)$nb_topcrops {
	local cn: word `k' of $topcropname_area
	recode yield_hv_pure_`cn' (.=0) if harvested_`cn'==1 & w_area_plan_pure_`cn'!=.
	recode yield_hv_pure_`cn' (nonmissing=.) if harvested_`cn'==0 | w_area_plan_pure_`cn'==.
}

*households engaged in dairy production
recode costs_dairy_percow cost_per_lit_milk (.=0) if dairy_hh==1
recode costs_dairy_percow cost_per_lit_milk (nonmissing=.) if dairy_hh==0

*now winsorize ratios only at top 1%
global wins_var_ratios_top1 inorg_fert_rate cost_total_ha cost_expli_ha cost_expli_hh_ha /*
*/ land_productivity labor_productivity /*
*/ mortality_rate* liters_per_largeruminant liters_per_cow liters_per_buffalo egg_poultry_year costs_dairy_percow /*
*/ off_farm_hours_pc_all off_farm_hours_pc_any cost_per_lit_milk

foreach v of varlist $wins_var_ratios_top1 {
	_pctile `v' [aw=weight] , p($wins_upper_thres)
	gen w_`v'=`v'
	replace  w_`v' = r(r1) if  w_`v' > r(r1) &  w_`v'!=.
	local l`v' : var lab `v'
	lab var  w_`v'  "`l`v'' - Winzorized top 1%"
	*some variables  are disaggreated by gender of plot manager. For these variables, we use the top 1% percentile to winsorize gender-disagregated variables
	if "`v'" =="inorg_fert_rate" | "`v'" =="cost_total_ha"  | "`v'" =="cost_expli_ha" {
		foreach g of global gender {
			gen w_`v'_`g'=`v'_`g'
			replace  w_`v'_`g' = r(r1) if w_`v'_`g' > r(r1) & w_`v'_`g'!=.
			local l`v'_`g' : var lab `v'_`g'
			lab var  w_`v'_`g'  "`l`v'_`g'' - Winzorized top 1%"
		}
	}
}

*winsorizing top crop ratios
foreach v of global topcropname_area {
	*first winsorizing costs per hectare
	_pctile `v'_exp_ha [aw=weight] , p($wins_upper_thres)
	gen w_`v'_exp_ha=`v'_exp_ha
	replace  w_`v'_exp_ha = r(r1) if  w_`v'_exp_ha > r(r1) &  w_`v'_exp_ha!=.
	local l`v'_exp_ha : var lab `v'_exp_ha
	lab var  w_`v'_exp_ha  "`l`v'_exp_ha - Winzorized top 1%"
		*now by gender using the same method as above
		foreach g of global gender {
		gen w_`v'_exp_ha_`g'= `v'_exp_ha_`g'
		replace w_`v'_exp_ha_`g' = r(r1) if w_`v'_exp_ha_`g' > r(r1) & w_`v'_exp_ha_`g'!=.
		local l`v'_exp_ha_`g' : var lab `v'_exp_ha_`g'
		lab var w_`v'_exp_ha_`g' "`l`v'_exp_ha_`g'' - winsorized top 1%"
	}
	*winsorizing cost per kilogram
	_pctile `v'_exp_kg [aw=weight] , p($wins_upper_thres)
	gen w_`v'_exp_kg=`v'_exp_kg
	replace  w_`v'_exp_kg = r(r1) if  w_`v'_exp_kg > r(r1) &  w_`v'_exp_kg!=.
	local l`v'_exp_kg : var lab `v'_exp_kg
	lab var  w_`v'_exp_kg  "`l`v'_exp_kg' - Winzorized top 1%"
		*now by gender using the same method as above
		foreach g of global gender {
		gen w_`v'_exp_kg_`g'= `v'_exp_kg_`g'
		replace w_`v'_exp_kg_`g' = r(r1) if w_`v'_exp_kg_`g' > r(r1) & w_`v'_exp_kg_`g'!=.
		local l`v'_exp_kg_`g' : var lab `v'_exp_kg_`g'
		lab var w_`v'_exp_kg_`g' "`l`v'_exp_kg_`g'' - winsorized top 1%"
	}
}

*now winsorize ratio only at top 1% - yield
foreach c of global topcropname_area {
	foreach i in yield_pl yield_hv{
		_pctile `i'_`c' [aw=weight] ,  p(95)  // WINSORIZING YIELD FOR NIGERIA AT 5 PERCENT DUE TO EXTREME OUTLIERS
		gen w_`i'_`c'=`i'_`c'
		replace  w_`i'_`c' = r(r1) if  w_`i'_`c' > r(r1) &  w_`i'_`c'!=.
		local w_`i'_`c' : var lab `i'_`c'
		lab var  w_`i'_`c'  "`w_`i'_`c'' - Winzorized top 5%"
		foreach g of global allyield  {
			gen w_`i'_`g'_`c'= `i'_`g'_`c'
			replace  w_`i'_`g'_`c' = r(r1) if  w_`i'_`g'_`c' > r(r1) &  w_`i'_`g'_`c'!=.
			local w_`i'_`g'_`c' : var lab `i'_`g'_`c'
			lab var  w_`i'_`g'_`c'  "`w_`i'_`g'_`c'' - Winzorized top 5%"
		}
	}
}

*Create final income variables using un_winzorized and un_winzorized values
egen total_income = rowtotal(crop_income livestock_income fishing_income self_employment_income nonagwage_income agwage_income transfers_income all_other_income)
egen nonfarm_income = rowtotal(fishing_income self_employment_income nonagwage_income transfers_income all_other_income)
egen farm_income = rowtotal(crop_income livestock_income agwage_income)
lab var  nonfarm_income "Nonfarm income (excludes ag wages)"
gen percapita_income = total_income/hh_members
lab var total_income "Total household income"
lab var percapita_income "Household incom per hh member per year"
lab var farm_income "Farm income"
egen w_total_income = rowtotal(w_crop_income w_livestock_income w_fishing_income w_self_employment_income w_nonagwage_income w_agwage_income w_transfers_income w_all_other_income)
egen w_nonfarm_income = rowtotal(w_fishing_income w_self_employment_income w_nonagwage_income w_transfers_income w_all_other_income)
egen w_farm_income = rowtotal(w_crop_income w_livestock_income w_agwage_income)
lab var  w_nonfarm_income "Nonfarm income (excludes ag wages) - Winzorized top 1%"
lab var w_farm_income "Farm income - Winzorized top 1%"
gen w_percapita_income = w_total_income/hh_members
lab var w_total_income "Total household income - Winzorized top 1%"
lab var w_percapita_income "Household income per hh member per year - Winzorized top 1%"
global income_vars crop livestock fishing self_employment nonagwage agwage transfers all_other
foreach p of global income_vars {
	gen `p'_income_s = `p'_income
	replace `p'_income_s = 0 if `p'_income_s < 0
	gen w_`p'_income_s = w_`p'_income
	replace w_`p'_income_s = 0 if w_`p'_income_s < 0
}
egen w_total_income_s = rowtotal(w_crop_income_s w_livestock_income_s w_fishing_income_s w_self_employment_income_s w_nonagwage_income_s w_agwage_income_s  w_transfers_income_s w_all_other_income_s)
foreach p of global income_vars {
	gen w_share_`p' = w_`p'_income_s / w_total_income_s
	lab var w_share_`p' "Share of household (winsorized) income from `p'_income"
}
egen w_nonfarm_income_s = rowtotal(w_fishing_income_s w_self_employment_income_s w_nonagwage_income_s w_transfers_income_s w_all_other_income_s)
gen w_share_nonfarm = w_nonfarm_income_s / w_total_income_s
lab var w_share_nonfarm "Share of household income (winsorized) from nonfarm sources"
foreach p of global income_vars {
	drop `p'_income_s  w_`p'_income_s
}
drop w_total_income_s w_nonfarm_income_s

***getting correct subpopulations
*all rural households
//note that consumption indicators are not included because there is missing consumption data and we do not consider 0 values for consumption to be valid
recode w_total_income w_percapita_income w_crop_income w_livestock_income w_fishing_income w_nonagwage_income w_agwage_income w_self_employment_income w_transfers_income w_all_other_income /*
*/ w_share_crop w_share_livestock w_share_fishing w_share_nonagwage w_share_agwage w_share_self_employment w_share_transfers w_share_all_other w_share_nonfarm /*
*/ use_fin_serv* use_inorg_fert imprv_seed_use /*
*/ formal_land_rights_hh w_off_farm_hours_pc_all months_food_insec w_value_assets /*
*/ lvstck_holding_tlu lvstck_holding_all lvstck_holding_lrum lvstck_holding_srum lvstck_holding_poultry (.=0) if rural==1


*all rural households engaged in livestock production
recode vac_animal w_share_livestock_prod_sold livestock_expenses w_ls_exp_vac (. = 0) if livestock_hh==1
recode vac_animal w_share_livestock_prod_sold livestock_expenses w_ls_exp_vac (nonmissing = .) if livestock_hh==0

*all rural households engaged in livestcok production of a given species
foreach i in lrum srum poultry{
	recode vac_animal_`i' any_imp_herd_`i' w_lost_disease_`i' w_ls_exp_vac_`i' (nonmissing=.) if lvstck_holding_`i'==0
	recode vac_animal_`i' any_imp_herd_`i' w_lost_disease_`i' w_ls_exp_vac_`i' (.=0) if lvstck_holding_`i'==1
}

*households engaged in crop production
recode w_proportion_cropvalue_sold w_farm_size_agland w_labor_family w_labor_hired /*
*/ imprv_seed_use use_inorg_fert w_labor_productivity w_land_productivity /*
*/ w_inorg_fert_rate w_cost_expli_hh w_cost_expli_hh_ha w_cost_expli_ha w_cost_total_ha /*
*/ w_value_crop_production w_value_crop_sales w_all_area_planted w_all_area_harvested (.=0) if crop_hh==1
recode w_proportion_cropvalue_sold w_farm_size_agland w_labor_family w_labor_hired /*
*/ imprv_seed_use use_inorg_fert w_labor_productivity w_land_productivity /*
*/ w_inorg_fert_rate w_cost_expli_hh w_cost_expli_hh_ha w_cost_expli_ha w_cost_total_ha /*
*/ w_value_crop_production w_value_crop_sales w_all_area_planted w_all_area_harvested (nonmissing= . ) if crop_hh==0

*hh engaged in crop or livestock production
recode ext_reach* (.=0) if (crop_hh==1 | livestock_hh==1)
recode ext_reach* (nonmissing=.) if crop_hh==0 & livestock_hh==0

*all rural households growing specific crops
forvalues k=1(1)$nb_topcrops {
	local cn: word `k' of $topcropname_area
	recode imprv_seed_`cn' hybrid_seed_`cn' w_yield_pl_`cn' /*
	*/ w_value_harv_`cn' w_value_sold_`cn' w_kgs_harvest_`cn' w_total_planted_area_`cn' w_total_harv_area_`cn' (.=0) if grew_`cn'==1
	recode imprv_seed_`cn' hybrid_seed_`cn' w_yield_pl_`cn' /*
	*/ w_value_harv_`cn' w_value_sold_`cn' w_kgs_harvest_`cn' w_total_planted_area_`cn' w_total_harv_area_`cn' (nonmissing=.) if grew_`cn'==0
}
*all rural households that harvested specific crops
forvalues k=1(1)$nb_topcrops {
	local cn: word `k' of $topcropname_area
	recode w_yield_hv_`cn' (.=0) if harvested_`cn'==1
	recode w_yield_hv_`cn' (nonmissing=.) if harvested_`cn'==0
}

*households engaged in monocropped production of specific crops
forvalues k=1/$nb_topcrops {
	local cn: word `k' of $topcropname_area
	recode w_`cn'_exp w_`cn'_exp_ha w_`cn'_exp_kg (.=0) if `cn'_monocrop==1
	recode w_`cn'_exp w_`cn'_exp_ha w_`cn'_exp_kg (nonmissing=.) if `cn'_monocrop==0
}

*all rural households engaged in dairy production
recode costs_dairy liters_milk_produced value_milk_produced (.=0) if dairy_hh==1
recode costs_dairy liters_milk_produced value_milk_produced (nonmissing=.) if dairy_hh==0
*all rural households eith egg-producing animals
recode w_eggs_total_year value_eggs_produced (.=0) if egg_hh==1
recode w_eggs_total_year value_eggs_produced (nonmissing=.) if egg_hh==0

*Identify smallholder farmers (RULIS definition)
global small_farmer_vars land_size tlu_today total_income
foreach p of global small_farmer_vars {
	gen `p'_aghh = `p' if ag_hh==1
	_pctile `p'_aghh  [aw=weight] , p(40)
	gen small_`p' = (`p' <= r(r1))
	replace small_`p' = . if ag_hh!=1
}
gen small_farm_household = (small_land_size==1 & small_tlu_today==1 & small_total_income==1)
replace small_farm_household = . if ag_hh != 1
sum small_farm_household if ag_hh==1
drop land_size_aghh small_land_size tlu_today_aghh small_tlu_today total_income_aghh small_total_income
lab var small_farm_household "1= HH is in bottom 40th percentiles of land size, TLU, and total revenue"

*create different weights
gen w_labor_weight=weight*w_labor_total
lab var w_labor_weight "labor-adjusted household weights"
gen w_land_weight=weight*w_farm_area
lab var w_land_weight "land-adjusted household weights"
gen w_aglabor_weight_all=w_labor_hired*weight
lab var w_aglabor_weight_all "Hired labor-adjusted household weights"
gen w_aglabor_weight_female=. // cannot create in this instrument
lab var w_aglabor_weight_female "Hired labor-adjusted household weights -female workers"
gen w_aglabor_weight_male=. // cannot create in this instrument
lab var w_aglabor_weight_male "Hired labor-adjusted household weights -male workers"
gen weight_milk=. //cannot create in this instrument
gen weight_egg=. //cannot create in this instrument
*generate area weights for monocropped plots
foreach cn in $topcropname_area {
	gen ar_pl_mono_wgt_`cn'_all = weight*`cn'_monocrop_ha
	gen kgs_harv_wgt_`cn'_all = weight*kgs_harv_mono_`cn'
	foreach g in male female mixed {
		gen ar_pl_mono_wgt_`cn'_`g' = weight*`cn'_monocrop_ha_`g'
		gen kgs_harv_wgt_`cn'_`g' = weight*kgs_harv_mono_`cn'_`g'
	}
}
gen w_ha_planted_all = ha_planted
foreach  g in all female male mixed {
	gen area_weight_`g'=weight*w_ha_planted_`g'
}
gen w_ha_planted_weight=w_ha_planted_all*weight
drop w_ha_planted_all
gen individual_weight=hh_members*weight
gen adulteq_weight=adulteq*weight

*Rural poverty headcount ratio
*First, we convert $1.90/day to local currency in 2011 using https://data.worldbank.org/indicator/PA.NUS.PRVT.PP?end=2011&locations=TZ&start=1990
	// 1.90 * 79.531 = 151.1089
*NOTE: this is using the "Private Consumption, PPP" conversion factor because that's what we have been using.
* This can be changed this to the "GDP, PPP" if we change the rest of the conversion factors.
*The global poverty line of $1.90/day is set by the World Bank
*http://www.worldbank.org/en/topic/poverty/brief/global-poverty-line-faq
*Second, we inflate the local currency to the year that this survey was carried out using the CPI inflation rate using https://data.worldbank.org/indicator/FP.CPI.TOTL?end=2017&locations=TZ&start=2003
	// 1+(134.925 - 110.84)/110.84 = 1.6587243
	// 151.1089* 1.6587243 = 250.648 N
*NOTE: if the survey was carried out over multiple years we use the last year
*This is the poverty line at the local currency in the year the survey was carried out
gen poverty_under_1_9 = (daily_percap_cons<250.648)
la var poverty_under_1_9 "Household has a percapita conumption of under $1.90 in 2011 $ PPP)"
*average consumption expenditure of the bottom 40% of the rural consumption expenditure distribution
*First, generating variable that reports the individuals in the bottom 40% of rural consumption expenditures
*By per capita consumption
_pctile w_daily_percap_cons [aw=individual_weight] if rural==1, p(40)
gen bottom_40_percap = 0
replace bottom_40_percap = 1 if r(r1) > w_daily_percap_cons & rural==1

*By peraeq consumption
_pctile w_daily_peraeq_cons [aw=adulteq_weight] if rural==1, p(40)
gen bottom_40_peraeq = 0
replace bottom_40_peraeq = 1 if r(r1) > w_daily_peraeq_cons & rural==1

****Currency Conversion Factors***
gen ccf_loc = 1
lab var ccf_loc "currency conversion factor - 2016 $NGN"
gen ccf_usd = 1/$Nigeria_GHS_W3_exchange_rate
lab var ccf_usd "currency conversion factor - 2016 $USD"
gen ccf_1ppp = 1/ $Nigeria_GHS_W3_cons_ppp_dollar
lab var ccf_1ppp "currency conversion factor - 2016 $Private Consumption PPP"
gen ccf_2ppp = 1/ $Nigeria_GHS_W3_gdp_ppp_dollar
lab var ccf_2ppp "currency conversion factor - 2016 $GDP PPP"

*generating clusterid and strataid
gen clusterid=ea
gen strataid=state

*dropping unnecessary varables
drop *_inter_*

*create missing crop variables (no cowpea or yam)
foreach x of varlist *maize* {
	foreach c in wheat beans {
		gen `x'_xx = .
		ren *maize*_xx *`c'*
	}
}

global empty_vars $empty_vars *wheat* *beans*

*Recode to missing any variables that cannot be created in this instrument
*replace empty vars with missing
foreach v of varlist $empty_vars {
	replace `v' = .
}

// Removing intermediate variables to get below 5,000 vars
keep hhid fhh clusterid strataid *weight* *wgt* zone state lga ea rural farm_size* *total_income* /*
*/ *percapita_income* *percapita_cons* *daily_percap_cons* *peraeq_cons* *daily_peraeq_cons* /*
*/ *income* *share* *proportion_cropvalue_sold *farm_size_agland hh_members adulteq *labor_family *labor_hired use_inorg_fert vac_* /*
*/ feed* water* lvstck_housed* ext_* use_fin_* lvstck_holding* *mortality_rate* *lost_disease* disease* any_imp* formal_land_rights_hh /*
*/ *livestock_expenses* *ls_exp_vac* *prop_farm_prod_sold *off_farm_hours_pc* months_food_insec *value_assets* hhs_* *dist_agrodealer /*
*/ encs* num_crops_* multiple_crops* imprv_seed_* hybrid_seed_* *labor_total *farm_area *labor_productivity* *land_productivity* /*
*/ *wage_paid_aglabor* *labor_hired ar_h_wgt_* *yield_hv_* ar_pl_wgt_* *yield_pl_* *liters_per_* milk_animals poultry_owned *costs_dairy* *cost_per_lit* /*
*/ *egg_poultry_year* *inorg_fert_rate* *ha_planted* *cost_expli_hh* *cost_expli_ha* *monocrop_ha* *kgs_harv_mono* *cost_total_ha* /*
*/ *_exp* poverty_under_1_9 *value_crop_production* *value_harv* *value_crop_sales* *value_sold* *kgs_harvest* *total_planted_area* *total_harv_area* /*
*/ *all_area_* grew_* agactivities_hh ag_hh crop_hh livestock_hh fishing_hh *_milk_produced* *eggs_total_year *value_eggs_produced* /*
*/ *value_livestock_products* *value_livestock_sales* *total_cons* nb_cattle_today nb_poultry_today bottom_40_percap bottom_40_peraeq /*
*/ ccf_loc ccf_usd ccf_1ppp ccf_2ppp *sales_livestock_products


//////////Identifier Variables ////////
*Add variables and ren household id so dta file can be appended with dta files from other instruments
gen hhid_panel = hhid
lab var hhid_panel "panel hh identifier"
gen geography = "Nigeria"
la var geography "Location of survey"
gen survey = "LSMS-ISA"
la var survey "Survey type (LSMS or AgDev)"
gen year = "2015-16"
la var year "Year survey was carried out"
gen instrument = 10
la var instrument "Wave and location of survey"
label define instrument 1 "Tanzania NPS Wave 1" 2 "Tanzania NPS Wave 2" 3 "Tanzania NPS Wave 3" 4 "Tanzania NPS Wave 4" /*
	*/ 5 "Ethiopia ESS Wave 1" 6 "Ethiopia ESS Wave 2" 7 "Ethiopia ESS Wave 3" /*
	*/ 8 "Nigeria GHS Wave 1" 9 "Nigeria GHS Wave 2" 10 "Nigeria GHS Wave 3" /*
	*/ 11 "Tanzania TBS AgDev (Lake Zone)" 12 "Tanzania TBS AgDev (Northern Zone)" 13 "Tanzania TBS AgDev (Southern Zone)" /*
	*/ 14 "Ethiopia ACC Baseline" /*
	*/ 15 "India RMS Baseline (Bihar)" 16 "India RMS Baseline (Odisha)" 17 "India RMS Baseline (Uttar Pradesh)" 18 "India RMS Baseline (West Bengal)" /*
	*/ 19 "Nigeria NIBAS AgDev (Nassarawa)" 20 "Nigeria NIBAS AgDev (Benue)" 21 "Nigeria NIBAS AgDev (Kaduna)" /*
	*/ 22 "Nigeria NIBAS AgDev (Niger)" 23 "Nigeria NIBAS AgDev (Kano)" 24 "Nigeria NIBAS AgDev (Katsina)"
label values instrument instrument
saveold "${Nigeria_GHS_W3_final_data}/Nigeria_GHS_W3_household_variables.dta", replace

********************************************************************************
*INDIVIDUAL-LEVEL VARIABLES
********************************************************************************
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_person_ids.dta", clear
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_control_income.dta", nogen  keep(1 3)
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_make_ag_decision.dta", nogen  keep(1 3)
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_ownasset.dta", nogen  keep(1 3)
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hhsize.dta", nogen keep (1 3)
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmer_fert_use.dta", nogen  keep(1 3)
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmer_improvedseed_use.dta", nogen  keep(1 3)
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_farmer_vaccine.dta", nogen  keep(1 3)
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_hhids.dta", nogen keep (1 3)

*Land rights
merge 1:1 hhid indiv using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_land_rights_ind.dta", nogen
recode formal_land_rights_f (.=0) if female==1
la var formal_land_rights_f "Individual has documentation of land rights (at least one plot) - Women only"

*getting correct subpopulations (women aged 18 or above in rural households)
recode control_all_income make_decision_ag own_asset formal_land_rights_f (.=0) if female==1
recode control_all_income make_decision_ag own_asset formal_land_rights_f (nonmissing=.) if female==0

*merge in hh variable to determine ag household
preserve
use "${Nigeria_GHS_W3_final_data}/Nigeria_GHS_W3_household_variables.dta", clear
keep hhid ag_hh
tempfile ag_hh
save `ag_hh'
restore
merge m:1 hhid using `ag_hh', nogen keep (1 3)

replace   make_decision_ag =. if ag_hh==0

* NA in NG_LSMS-ISA
gen women_diet=.
gen  number_foodgroup=.

*Set improved seed adoption to missing if household is not growing crop
foreach v in $topcropname_area {
	replace all_imprv_seed_`v' =. if `v'_farmer==0 | `v'_farmer==.
	recode all_imprv_seed_`v' (.=0) if `v'_farmer==1
	replace all_hybrid_seed_`v' =. if  `v'_farmer==0 | `v'_farmer==.
	recode all_hybrid_seed_`v' (.=0) if `v'_farmer==1
	gen female_imprv_seed_`v'=all_imprv_seed_`v' if female==1
	gen male_imprv_seed_`v'=all_imprv_seed_`v' if female==0
	gen female_hybrid_seed_`v'=all_hybrid_seed_`v' if female==1
	gen male_hybrid_seed_`v'=all_hybrid_seed_`v' if female==0
}

*generate missings
foreach g in all male female{
	foreach c in wheat beans{
	gen `g'_imprv_seed_`c' = .
	gen `g'_hybrid_seed_`c' = .
	}
}

gen female_use_inorg_fert=all_use_inorg_fert if female==1
gen male_use_inorg_fert=all_use_inorg_fert if female==0
lab var male_use_inorg_fert "1 = Individual male farmers (plot manager) uses inorganic fertilizer"
lab var female_use_inorg_fert "1 = Individual female farmers (plot manager) uses inorganic fertilizer"
gen female_imprv_seed_use=all_imprv_seed_use if female==1
gen male_imprv_seed_use=all_imprv_seed_use if female==0
lab var male_imprv_seed_use "1 = Individual male farmer (plot manager) uses improved seeds"
lab var female_imprv_seed_use "1 = Individual female farmer (plot manager) uses improved seeds"

gen female_vac_animal=all_vac_animal if female==1
gen male_vac_animal=all_vac_animal if female==0
lab var male_vac_animal "1 = Individual male farmers (livestock keeper) uses vaccines"
lab var female_vac_animal "1 = Individual female farmers (livestock keeper) uses vaccines"


*replace empty vars with missing
global empty_vars *hybrid_seed* women_diet number_foodgroup
foreach v of varlist $empty_vars {
	replace `v' = .
}


//////////Identifier Variables ////////
*Add variables and ren household id so dta file can be appended with dta files from other instruments
gen hhid_panel = hhid
lab var hhid_panel "panel hh identifier"
ren indiv indid
gen geography = "Nigeria"
gen survey = "LSMS-ISA"
gen year = "2015-16"
gen instrument = 10
label define instrument 1 "Tanzania NPS Wave 1" 2 "Tanzania NPS Wave 2" 3 "Tanzania NPS Wave 3" 4 "Tanzania NPS Wave 4" /*
	*/ 5 "Ethiopia ESS Wave 1" 6 "Ethiopia ESS Wave 2" 7 "Ethiopia ESS Wave 3" /*
	*/ 8 "Nigeria GHS Wave 1" 9 "Nigeria GHS Wave 2" 10 "Nigeria GHS Wave 3" /*
	*/ 11 "Tanzania TBS AgDev (Lake Zone)" 12 "Tanzania TBS AgDev (Northern Zone)" 13 "Tanzania TBS AgDev (Southern Zone)" /*
	*/ 14 "Ethiopia ACC Baseline" /*
	*/ 15 "India RMS Baseline (Bihar)" 16 "India RMS Baseline (Odisha)" 17 "India RMS Baseline (Uttar Pradesh)" 18 "India RMS Baseline (West Bengal)" /*
	*/ 19 "Nigeria NIBAS AgDev (Nassarawa)" 20 "Nigeria NIBAS AgDev (Benue)" 21 "Nigeria NIBAS AgDev (Kaduna)" /*
	*/ 22 "Nigeria NIBAS AgDev (Niger)" 23 "Nigeria NIBAS AgDev (Kano)" 24 "Nigeria NIBAS AgDev (Katsina)"
label values instrument instrument
gen strataid=state
gen clusterid=ea
saveold "${Nigeria_GHS_W3_final_data}/Nigeria_GHS_W3_individual_variables.dta", replace


********************************************************************************
*PLOT -LEVEL VARIABLES
********************************************************************************
*GENDER PRODUCTIVITY GAP
use "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_areas.dta", clear
merge m:1 hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_weights.dta", keep (1 3) nogen
merge 1:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_cropvalue.dta", keep (1 3) nogen
merge 1:1 hhid plot_id using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_decision_makers", keep (1 3) nogen // Bring in the gender file
merge 1:1 plot_id hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_farmlabor_postharvest.dta", keep (1 3) nogen
merge 1:1 plot_id  hhid using "${Nigeria_GHS_W3_created_data}/Nigeria_GHS_W3_plot_farmlabor_postplanting.dta", keep (1 3) nogen
keep if cultivate==1
ren field_size  area_meas_hectares
egen labor_total = rowtotal(days_hired_postplant days_famlabor_postplant days_hired_postplant days_famlabor_postplant days_hired_postharvest days_famlabor_postharvest days_exchange_labor_postharvest)
global winsorize_vars area_meas_hectares  labor_total
foreach p of global winsorize_vars {
	gen w_`p' =`p'
	local l`p' : var lab `p'
	_pctile w_`p'   [aw=weight] if w_`p'!=0 , p($wins_lower_thres $wins_upper_thres)
	replace w_`p' = r(r1) if w_`p' < r(r1)  & w_`p'!=. & w_`p'!=0
	replace w_`p' = r(r2) if w_`p' > r(r2)  & w_`p'!=.
	lab var w_`p' "`l`p'' - Winsorized top and bottom 1%"
}

_pctile plot_value_harvest  [aw=weight] , p($wins_upper_thres)
gen w_plot_value_harvest=plot_value_harvest
replace w_plot_value_harvest = r(r1) if w_plot_value_harvest > r(r1) & w_plot_value_harvest != .
lab var w_plot_value_harvest "Value of crop harvest on this plot - Winsorized top 1%"

*Generate land and labor productivity using winsorized values
gen plot_productivity = w_plot_value_harvest/ w_area_meas_hectares
lab var plot_productivity "Plot productivity Value production/hectare"

*Productivity at the plot level
gen plot_labor_prod = w_plot_value_harvest/w_labor_total
lab var plot_labor_prod "Plot labor productivity (value production/labor-day)"

*Winsorize both land and labor productivity at top 1% only
gen plot_weight=w_area_meas_hectares*weight
lab var plot_weight "Weight for plots (weighted by plot area)"
foreach v of varlist  plot_productivity  plot_labor_prod {
	_pctile `v' [aw=plot_weight] , p($wins_upper_thres)
	gen w_`v'=`v'
	replace  w_`v' = r(r1) if  w_`v' > r(r1) &  w_`v'!=.
	local l`v' : var lab `v'
	lab var  w_`v'  "`l`v'' - Winzorized top 1%"
}

*Convert monetary values to USD and PPP
global monetary_val plot_value_harvest plot_productivity  plot_labor_prod
foreach p of global monetary_val {
	gen `p'_1ppp = (1) * `p' / $Nigeria_GHS_W3_cons_ppp_dollar
	gen `p'_2ppp = (1) * `p' / $Nigeria_GHS_W3_gdp_ppp_dollar
	gen `p'_usd = (1) * `p' / $Nigeria_GHS_W3_exchange_rate
	gen `p'_loc = (1) * `p'
	local l`p' : var lab `p'
	lab var `p'_1ppp "`l`p'' (2016 $ Private Consumption PPP)"
	lab var `p'_2ppp "`l`p'' (2016 $ GDP PPP)"
	lab var `p'_usd "`l`p'' (2016 $ USD)"
	lab var `p'_loc "`l`p'' 2016 (NGN)"
	lab var `p' "`l`p'' (NGN)"
	gen w_`p'_1ppp = (1) * w_`p' / $Nigeria_GHS_W3_cons_ppp_dollar
	gen w_`p'_2ppp = (1) * w_`p' / $Nigeria_GHS_W3_gdp_ppp_dollar
	gen w_`p'_usd = (1) * w_`p' / $Nigeria_GHS_W3_exchange_rate
	gen w_`p'_loc = (1) * w_`p'
	local lw_`p' : var lab w_`p'
	lab var w_`p'_1ppp "`lw_`p'' (2016 $ Private Consumption PPP)"
	lab var w_`p'_2ppp "`lw_`p'' (2016 $ GDP PPP)"
	lab var w_`p'_usd "`lw_`p'' (2016 $ USD)"
	lab var w_`p'_loc "`lw_`p'' 2106 (NGN)"
	lab var w_`p' "`lw_`p'' (NGN)"
}

*We are reporting two variants of gender-gap
* mean difference in log productivitity without and with controls (plot size and region/state)
* both can be obtained using a simple regression.
* use clustered standards errors
gen clusterid=ea
gen strataid=state
qui svyset clusterid [pweight=plot_weight], strata(strataid) singleunit(centered) // get standard errors of the mean

* SIMPLE MEAN DIFFERENCE
gen male_dummy=dm_gender==1  if  dm_gender!=3 & dm_gender!=. //generate dummy equals to 1 if plot managed by male only and 0 if managed by female only

*Gender-gap 1a  here we first take to log of plot productivity. This allows the distribution to be less skewed and less sensitive to extreme values

gen lplot_productivity_usd=ln(plot_productivity_usd)
lab var lplot_productivity_usd "Log Value of crop production per hectare"
gen larea_meas_hectares=ln(area_meas_hectares)
lab var larea_meas_hectares "Log plot area hectare"
svy, subpop(if rural==1): reg  lplot_productivity_usd male_dummy
matrix b1a=e(b)
gen gender_prod_gap1a=100*el(b1a,1,1)
sum gender_prod_gap1a
lab var gender_prod_gap1a "Gender productivity gap (%) - regression in logs with no controls"
matrix V1a=e(V)
gen segender_prod_gap1a= 100*sqrt(el(V1a,1,1))
sum segender_prod_gap1a
lab var segender_prod_gap1a "SE Gender productivity gap (%) - regression in logs with no controls"

*Gender-gap 1b
svy, subpop(if rural==1) : reg  lplot_productivity_usd male_dummy larea_meas_hectares i.state
matrix b1b=e(b)
gen gender_prod_gap1b=100*el(b1b,1,1)
sum gender_prod_gap1b
lab var gender_prod_gap1b "Gender productivity gap (%) - regression in logs with controls"
matrix V1b=e(V)
gen segender_prod_gap1b= 100*sqrt(el(V1b,1,1))
sum segender_prod_gap1b
lab var segender_prod_gap1b "SE Gender productivity gap (%) - regression in logs with controls"

foreach i in 1ppp 2ppp loc{
	gen w_plot_productivity_all_`i'=w_plot_productivity_`i'
	gen w_plot_productivity_female_`i'=w_plot_productivity_`i' if dm_gender==2
	gen w_plot_productivity_male_`i'=w_plot_productivity_`i' if dm_gender==1
	gen w_plot_productivity_mixed_`i'=w_plot_productivity_`i' if dm_gender==3
}

*Create weight
gen plot_labor_weight= w_labor_total*weight


//////////Identifier Variables ////////
*Add variables and ren household id so dta file can be appended with dta files from other instruments
gen hhid_panel = hhid
lab var hhid_panel "panel hh identifier"
gen geography = "Nigeria"
gen survey = "LSMS-ISA"
gen year = "2015-16"
gen instrument = 10
label define instrument 1 "Tanzania NPS Wave 1" 2 "Tanzania NPS Wave 2" 3 "Tanzania NPS Wave 3" 4 "Tanzania NPS Wave 4" /*
	*/ 5 "Ethiopia ESS Wave 1" 6 "Ethiopia ESS Wave 2" 7 "Ethiopia ESS Wave 3" /*
	*/ 8 "Nigeria GHS Wave 1" 9 "Nigeria GHS Wave 2" 10 "Nigeria GHS Wave 3" /*
	*/ 11 "Tanzania TBS AgDev (Lake Zone)" 12 "Tanzania TBS AgDev (Northern Zone)" 13 "Tanzania TBS AgDev (Southern Zone)" /*
	*/ 14 "Ethiopia ACC Baseline" /*
	*/ 15 "India RMS Baseline (Bihar)" 16 "India RMS Baseline (Odisha)" 17 "India RMS Baseline (Uttar Pradesh)" 18 "India RMS Baseline (West Bengal)" /*
	*/ 19 "Nigeria NIBAS AgDev (Nassarawa)" 20 "Nigeria NIBAS AgDev (Benue)" 21 "Nigeria NIBAS AgDev (Kaduna)" /*
	*/ 22 "Nigeria NIBAS AgDev (Niger)" 23 "Nigeria NIBAS AgDev (Kano)" 24 "Nigeria NIBAS AgDev (Katsina)"
label values instrument instrument
saveold "${Nigeria_GHS_W3_final_data}/Nigeria_GHS_W3_field_plot_variables.dta", replace
