* ==============================================================================
*  Date	   : June 28th, 2023
*  Purpose : KCAI Milestone Report          
*  Author  : Lauriane Yehouenou
* ==============================================================================
cap log close
clear all 
set more off

*cd "C:\Users\lsy2011\Dropbox\Laury_NU-UF-OCI\Documents\GPRL NU\Lori Works\Oolu\Data Collection\Clean Data" 

cd "D:\Dropbox\Collaborations\Solar_Data\clean"

* ==============================================================================
*                      			MAIN SURVEY
* ==============================================================================
***Checking for unique identification***
use sustainable_spillover_main, clear
isid resp_id
tab b10_repeat_count
tab b27_repeat_count
use main_ss_moduleb-b10_repeat, clear

g fuel_paid = b17*b18

collapse (sum) fuel_total_week = b17 fuel_paid_week = fuel_paid (max) max_gen_days=b14, by(resp_id)

save generators_sum, replace

*isid resp_id
use main_ss_moduleb-b27_repeat, clear

sum b27, detail

collapse (max) max_solar_days=b29, by(resp_id)

save solar_sum, replace

*isid resp_id

***RUN CODE FROM HERE**
// use sustainable_spillover_main, clear
// merge 1:m resp_id using main_ss_moduleb-b10_repeat
// drop _merge
// merge m:m resp_id using main_ss_moduleb-b27_repeat
// *joinby resp_id using main_ss_moduleb-b27_repeat
// keep if _merge==3
// drop _merge
//
// save mainsurvey_complete, replace
// g id=_n
// egen tag = tag(id resp_id)
// egen distinct = total(tag), by(resp_id)
// order distinct, after (resp_id)
// tab distinct

***************Ordering Variables********************
use sustainable_spillover_main, clear

merge 1:1 resp_id using generators_sum
drop _merge
merge 1:1 resp_id using solar_sum

order _all, alphabetic
order SubmissionDate todaysdate enum_label resp_id state lga village status main finaltext consent2
	
	ds, has(type numeric)

	foreach var of varlist `r(varlist)' {
		replace `var' = .d  if `var' == -999
	}

***************Main Survey Demographics********************
tab1 d0*
*Gender*
	gen sum_female = d01 == 1
		label var sum_female "Female"
	gen sum_male = d01 == 2
		label var sum_male "Male"

*Role in HH*
	qui tab d02, gen(sum_hhrole)
		label var sum_hhrole1 "Household head"
		label var sum_hhrole2 "Spouse of household head"
		label var sum_hhrole3 "Child of household head"
		label var sum_hhrole4 "Other"
		
*Education level*
	qui tab d03, gen(sum_edu)
		label var sum_edu1 "No formal education"
		label var sum_edu2 "Completed primary"
		label var sum_edu3 "Not completed primary" 
		label var sum_edu4 "Completed Secondary" 
		label var sum_edu5 "Not completed Secondary"
		label var sum_edu6 "Completed Tertiary"
		label var sum_edu7 "Not completed Tertiary"

*HH size*
	gen sum_hhsize= d04 + d06
	
*Other HH characteristics*
tab1 e0*

* =========== ELECTRICITY =========== 

*Electricity Grid*
gen sum_grid = b01
	label var sum_grid "Electricity Grid"
	
*Length Grid*
tab b02
gen sum_length =.
	order sum_length, after (b02)
	replace sum_length = 0 if b02<2000
	replace sum_length = 1 if b02>=2000
	label var sum_length "Length Grid"

	
*Electricity whole day*
gen sum_whole = b03
	label var sum_whole "Electricity whole day"
	
*Electricity only part of the day*
gen sum_part = b04
	label var sum_whole "Electricity only part of the day"
	
*Electricity hours per day*
gen sum_numhours = b05
	label var sum_numhours "Electricity hours per day"
	
* Generate a single summary variable for electricity per week
g hours_week = 0 if b01==1
replace hours_week = hours_week + (b03*7) if !missing(b03) // # of days of full electricity 
replace hours_week = hours_week + (b04*b05) if !missing(b04) & !missing(b05) & b03!=7 // # of days of partial (note b04 wasn't skipped if b03 was 7, but all responses are consistent)
	
g hours_day = hours_week / 7	
	
*Electricity paid bill*
gen sum_bill = b06
	label var sum_bill "Electricity paid bill"

*Electricity bill period *
gen sum_billperiod =.
	order sum_billperiod, after (b07)
	replace sum_billperiod = b07 if b07a == 1
	replace sum_billperiod = (b07*7) if b07a == 2
	replace sum_billperiod = (b07*30) if b07a == 3
	label var sum_billperiod "Electricity bill period"
	
g bill_per_day = b06 / sum_billperiod
g bill_per_month = bill_per_day*30

* =========== GENERATOR =========== 

*Generator Ownership Yes/No=1/0*
tab b08
gen sum_generator = b08 ==1
	order sum_generator, after (b08)
	label var sum_generator "Generator Ownership"
	
*Number of Generators*
gen sum_numgenerator = b09
	label var sum_numgenerator "Number of Generators"
	
* Fuel costs
sum fuel_total_week if b08==1, detail
sum fuel_paid_week if b08==1, detail
tab max_gen_days

	
*Generators Year of Purchase*
tab b10
gen sum_year =.
	order sum_year, after (b10)
	replace sum_year = 0 if b02<2000
	replace sum_year = 1 if b02>=2000
	label var sum_year "Generators Year of Purchase"

*Generator State New/Used=1/0*
tab b11
gen sum_genestate = b11 ==1
	order sum_genestate, after (b11)
	label var sum_genestate "Generator State"
	
*Generator Purchase Price*
gen sum_geneprice = b12 if b12 != -88
	order sum_geneprice, after (b11)
	label var sum_geneprice "Generator Purchase Price"	
	
*Was the generator a gift?*
tab b12a

*Generator Capacity*

label define b13a 1 "Megawatt" 2 "Kilowatt"
label values b13a b13a
tab b13a

gen sum_genecapacity=.
	/*Converting Megawatt to Kilowatt*/
	replace sum_genecapacity= (b13*1000) if b13a==1 
	replace sum_genecapacity=b13 if b13a==2
	label var sum_genecapacity "Average Generator Capacity"

*Generator weekly use*
tab b14
gen sum_geneUse = b14
	order sum_geneUse, after (b14)
	label var sum_geneUse "Generator weekly use"

*Generator daily hours use*
tab b15
gen sum_geneHourUse = b15
	order sum_geneHourUse, after (b15)
	label var sum_geneHourUse "Generator daily hours use"
	
*Appliances powered by Generators*
///*Variable b16_1 not properly coded*///
tab1 b16_*
gen sum_appliance_1 = b16_1 == 1
	label var sum_appliance_1 "Blender or food processor"
gen sum_appliance_2 = b16_2 == 1
	label var sum_appliance_2 "Electric cooker"
gen sum_appliance_3 = b16_3 == 1
	label var sum_appliance_3 "Freezer"
gen sum_appliance_4 = b16_4 == 1
	label var sum_appliance_4 "Refrigerator"
gen sum_appliance_5 = b16_5 == 1
	label var sum_appliance_5 "Microwave"
gen sum_appliance_6 = b16_6 == 1
	label var sum_appliance_6 "Standing/Ceiling Fan"
gen sum_appliance_7 = b16_7 == 1
	label var sum_appliance_7 "TV Set"
gen sum_appliance_8 = b16_8 == 1
	label var sum_appliance_8 "Washing machine"
gen sum_appliance_9 = b16_9 == 1
	label var sum_appliance_9 "Bulbs"
gen sum_appliance_10 = b16_10 == 1
replace sum_appliance_10 = 1 if b16_oth == "Charging of phones" 
replace sum_appliance_10 = 1 if b16_oth == "School computers" 
	label var sum_appliance_10 "Charging electrical devices"
gen sum_appliance_11 = b16_11 == 1
	label var sum_appliance_11 "Water pumps"
gen sum_appliance_96 = b16_96 == 1
	label var sum_appliance_96 "Others"
	
*Last week purchase of fuel (in liter)*
gen sum_fuel = b17
	order sum_fuel, after (b17)
	label var sum_fuel "Last week purchase of fuel"
	
*Fuel price per liter*
gen sum_fuelprice = b18
	order sum_fuelprice, after (b18)
	label var sum_fuelprice "Fuel price per liter"	
	
*Types of Fuel -Gasoline/Petrole (1) vs Diesel(2)*
///*Variable b19 not properly coded*///
gen sum_fueltype = b19 == 1
	order sum_fueltype, after (b19)
	label var sum_fueltype "Types of Fuel"
	
*Fuel place of purchase - Fuel Station (1) vs Black market(2)*
///*Variable b20 not properly coded*///  I doubt the stats here unless OPM clarifies
gen sum_fuelplace = b20 == 1
	order sum_fuelplace, after (b20)
	label var sum_fuelplace "Fuel place of purchase"

* =========== SOLAR SYSTEM =========== 
	
*Solar Energy Installed Yes/No=1/0*
gen sum_solar = b22 ==1
	order sum_solar, after (b22)
	label var sum_solar "Solar Energy Installed"
	
*Number of Solar Energy*
gen sum_solarnum = b25
	order sum_solarnum, after (b25)
	label var sum_solarnum "Number of Solar Energy"
	
*Solar System Year of Purchase*
tab b26
gen sum_yearsolar =.
	order sum_year, after (b26)
	replace sum_year = 0 if b26<2020
	replace sum_year = 1 if b26>=2020
	label var sum_year "Solar System Year of Purchase"

*Solar System Purchase Price*
gen sum_solarprice = b27
	order sum_solarprice, after (b27)
	label var sum_solarprice "Solar System Purchase Price"	
	
*Solar system Capacity*
/*Variables b28 and b28a are not properly coded. Value "88" in b28 are incorrect. The units are not correct*/

gen sum_solarcapacity=.
	/*Converting Megawatt to Kilowatt*/
	replace sum_solarcapacity= (b28*1000) if b28a==1 
	replace sum_solarcapacity= b28 if b28a==2
	label var sum_solarcapacity "Average Solar Capacity"

sum max_solar_days, detail	
	
*Solar System weekly use*
gen sum_solarUse = b29
	order sum_solarUse, after (b29)
	label var sum_solarUse "Solar System weekly use"
	
*Solar daily hours use*
gen sum_solarHourUse = b30
	order sum_solarHourUse, after (b30)
	label var sum_solarHourUse "Solar System daily hours use"
	
*Appliances powered by Solar System Yes/No=1/0*
///*Variable b16_1 not properly coded*///
tab1 b31_*
gen sum_solappliance_1 = b31_1 == 1
	label var sum_solappliance_1 "S Blender or food processor"
gen sum_solappliance_2 = b31_2 == 1
	label var sum_solappliance_2 "S Electric cooker"
gen sum_solappliance_3 = b31_3 == 1
	label var sum_solappliance_3 "S Freezer"
gen sum_solappliance_4 = b31_4 == 1
	label var sum_solappliance_4 "S Refrigerator"
gen sum_solappliance_5 = b31_5 == 1
	label var sum_solappliance_5 "S Microwave"
gen sum_solappliance_6 = b31_6 == 1
	label var sum_solappliance_6 "S Standing/Ceiling Fan"
gen sum_solappliance_7 = b31_7 == 1
	label var sum_solappliance_7 "S TV Set"
gen sum_solappliance_8 = b31_8 == 1
	label var sum_solappliance_8 "S Washing machine"
gen sum_solappliance_9 = b31_9 == 1
	label var sum_solappliance_9 "S Bulbs"
gen sum_solappliance_10 = b31_10 == 1
replace sum_solappliance_10 = 1 if b31_oth == "Charge one phone"
replace sum_solappliance_10 = 1 if b31_oth == "Charging of my phones" 
replace sum_solappliance_10 = 1 if b31_oth == "Charging of phone" 
replace sum_solappliance_10 = 1 if b31_oth == "Charging of phones" 
replace sum_solappliance_10 = 1 if b31_oth == "Charging phone and mp3" 
replace sum_solappliance_10 = 1 if b31_oth == "Laptops,phones." 
replace sum_solappliance_10 = 1 if b31_oth == "Phones" 
replace sum_solappliance_10 = 1 if b31_oth == "To charge Phone"
	label var sum_solappliance_10 "S Charging electrical devices"
gen sum_solappliance_11 = b31_11 == 1
	label var sum_solappliance_11 "S Water pumps"
gen sum_solappliance_96 = b31_96 == 1
	label var sum_solappliance_96 "S Others"
*tab b31_oth

*Solar Energy Ownership Own/Paying it off=1/2*
gen sum_solarown = b32 ==1
	order sum_solarown, after (b32)
	label var sum_solarown "Solar Energy Ownership"
	
*Solar Energy Payment frequency*
qui tab b33, gen (sum_solarfreq_)
	label var sum_solarfreq_1 "Monthly Payment"
	replace sum_solarfreq_1 = 1 if b36 == 4
	label var sum_solarfreq_2 "Anually Payment"
	replace sum_solarfreq_2 = 1 if b36 == 6
	label var sum_solarfreq_3 "Quaterly Payment"
	replace sum_solarfreq_3 = 0 if b36 == 2 | b36 == 4 | b36 == 6
	*label var sum_solarfreq_3 "Other Payment" // 2 respondents pay weekly and 15 pay quarterly//

*Solar Energy average monthly Payment*
gen sum_monthpayment =.
	replace sum_monthpayment = b34 if b33 == 1 
	replace sum_monthpayment = b37 if b36 == 4
	replace sum_monthpayment = (b35/12) if b33 == 2
	replace sum_monthpayment = (b37/12) if b36 == 6
	replace sum_monthpayment = (b37/3) if b36 == 5
	replace sum_monthpayment = (b37*4) if b36 == 2
	label var sum_monthpayment "Solar Energy average monthly Payment"
	
*Solar Energy Seller*
qui tab b38, gen (sum_solarSeller)
	label var sum_solarSeller1 "Ecozar Technologies"
	label var sum_solarSeller2 "Oolu Energy Nigeria Limited"
	label var sum_solarSeller3 "MTN Lumos Solar Mobile Electricity"
	label var sum_solarSeller4 "Sunking"
	label var sum_solarSeller5 "Baobab solar energy"
	label var sum_solarSeller6 "Others"

*Use of Solar Energy + Generator - Yes/No=1/0**
gen sum_solargene = b39 ==1
	order sum_solargene, after (b39)
	label var sum_solargene "Solar Energy + Generator"
	
*Appliances powered by Generators when using Solar Energy*
tab1 b40_*
gen sum_GSappliance_1 = b40_1 == 1
	label var sum_GSappliance_1 "GS Blender or food processor"
gen sum_GSappliance_2 = b40_2 == 1
	label var sum_GSappliance_2 "GS Electric cooker"
gen sum_GSappliance_3 = b40_3 == 1
	label var sum_GSappliance_3 "GS Freezer"
gen sum_GSappliance_4 = b40_4 == 1
	label var sum_GSappliance_4 "GS Refrigerator"
gen sum_GSappliance_5 = b40_5 == 1
	label var sum_GSappliance_5 "GS Microwave"
gen sum_GSappliance_6 = b40_6 == 1
	label var sum_GSappliance_6 "GS Standing/Ceiling Fan"
gen sum_GSappliance_7 = b40_7 == 1
	label var sum_GSappliance_7 "GS TV Set"
gen sum_GSappliance_8 = b40_8 == 1
	label var sum_GSappliance_8 "GS Washing machine"
gen sum_GSappliance_9 = b40_9 == 1
	label var sum_GSappliance_9 "GS Bulbs"
gen sum_GSappliance_10 = b40_10 == 1
replace sum_GSappliance_10 = 1 if b40_oth == "Charging of phones" 
replace sum_GSappliance_10 = 1 if b40_oth == "Laptop charging" 
	label var sum_GSappliance_10 "GS Charging electrical devices"
gen sum_GSappliance_11 = b40_11 == 1
	label var sum_GSappliance_11 "GS Water pumps"
gen sum_GSappliance_96 = b40_96 == 1
	label var sum_GSappliance_96 "GS Others"

* Use less generator after having solar system installed*
gen sum_lessgene = b41
	order sum_lessgene, after (b41)
	label var sum_lessgene "Use less generator"	
	
* Fuel monthly saving after having solar system installed*
gen sum_fuelsaving = b42
	order sum_fuelsaving, after (b42)
	label var sum_fuelsaving "Fuel monthly saving"	
	
* =========== Air Quality and Generator Perceptions =========== 
gen sum_airquality = c01 == 1
*tab1 c02_*
gen sum_airpbm_1 = c02_1 == 1
	label var sum_airpbm_1 "Traffic"
gen sum_airpbm_2 = c02_2 == 1
	label var sum_airpbm_2 "Home generator use"
gen sum_airpbm_3 = c02_3 == 1
	label var sum_airpbm_3 "Business generator use"
gen sum_airpbm_4 = c02_4 == 1
	label var sum_airpbm_4 "Harmattan"
gen sum_airpbm_5 = c02_5 == 1
	label var sum_airpbm_5 "Wood stoves for home cooking"
gen sum_airpbm_6 = c02_6 == 1
	label var sum_airpbm_6 "Road dust/construction dust"
gen sum_airpbm_96 = c02_96 == 1
	label var sum_airpbm_96 "Others"
gen sum_coughHsld = c03 == 1	
gen sum_sorethroatHsld = c04 == 1
gen sum_diarrheaHsld = c05 == 1	
gen sum_noise = c06 == 1
gen sum_noiseOthers = c08 == 1
gen sum_smoke = c10 == 1
gen sum_smokeOthers = c12 == 1	
tab1 c07 c09 c11 c13

*sum sum_*
tabstat sum_*, stat(n mean sd min max) col(stat) varwidth(20) 


* ==============================================================================
*                      			NEIGBHOR SURVEY
* ==============================================================================

use neighbour_ss_survey, clear
isid resp_id
tab b10_repeat_count
tab b27_repeat_count
use neighbour_ss_moduleb-b10_repeat, clear
isid resp_id
use neighbour_ss_moduleb-b27_repeat, clear
isid resp_id

use neighbour_ss_survey, clear
merge 1:m resp_id using neighbour_ss_moduleb-b10_repeat
drop _merge
merge m:m resp_id using neighbour_ss_moduleb-b27_repeat
drop _merge

save neigbhoursurvey_complete, replace
g id=_n
egen tag = tag(id resp_id)
egen distinct = total(tag), by(resp_id)
order distinct, after (resp_id)
tab distinct


***************Ordering Variables********************
use neigbhoursurvey_complete, clear

order _all, alphabetic
order SubmissionDate todaysdate resp_id state lga village main finaltext consent2
	
	ds, has(type numeric)

