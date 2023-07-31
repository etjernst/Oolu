* ==============================================================================
*  Date	   : June 28th, 2023
*  Purpose : KCAI Milestone Report          
*  Author  : Lauriane Yehouenou
* ==============================================================================
cap log close
clear all 
set more off

cd "C:\Users\lsy2011\Dropbox\Laury_NU-UF-OCI\Documents\GPRL NU\Lori Works\Oolu\Data Collection\Clean Data" 

* ==============================================================================
*                      			MAIN SURVEY
* ==============================================================================
***Checking for unique identification***
use sustainable_spillover_main, clear
isid resp_id
tab b10_repeat_count
tab b27_repeat_count

***Changing first sub data dataset from long to wide***
use main_ss_moduleb-b10_repeat, clear
sort resp_id
drop KEY2 SET_OF_b10_repeat b16_oth b19_oth b21a_oth b21c_oth
rename b16_11 b16_011
reshape wide b10 b11 b12 b12a b12c b13 b13a b14 b15 b16 b16_1 b16_2 b16_3 b16_4 b16_5 b16_6 b16_7 b16_8 b16_9 b16_10 b16_011 b16_96 b17 b18 b19 b20 b21a b21b b21c b21ci b21d, i(resp_id) j(calc_b10)
isid resp_id
save Moduleb10_reshaped, replace

***Changing second sub data dataset from long to wide***
use main_ss_moduleb-b27_repeat, clear
sort resp_id
rename b31_11 b31_011
rename b31_96 b31_096
reshape wide b26 b27 b28 b28a b28bi b28b b29 b30 b31 b31_1 b31_2 b31_3 b31_4 b31_5 b31_6 b31_7 b31_8 b31_9 b31_10 b31_011 b31_096 b31_oth b32 b33 b34 b35 b36 b37 b38 b38_oth KEY2 SET_OF_b27_repeat , i(resp_id) j(calc_b26)
isid resp_id
save Moduleb27_reshaped, replace

***MERGING**
use sustainable_spillover_main, clear
merge 1:1 resp_id using Moduleb10_reshaped
drop _merge
merge 1:1 resp_id using Moduleb27_reshaped
drop _merge
save mainsurvey_complete, replace

***VERIFICATION**
g id=_n
egen tag = tag(id resp_id)
egen distinct = total(tag), by(resp_id)
order distinct, after (resp_id)
tab distinct

***************Ordering Variables********************
use mainsurvey_complete, clear

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
	
*Electricity paid bill per month*
gen sum_bill = .
	replace sum_bill = (b06/b07)*30 if b07a == 1
	replace sum_bill = (b06/b07)*4 if b07a == 2
	replace sum_bill = (b06/b07) if b07a == 3
	label var sum_bill "Electricity bill per month"

* =========== GENERATOR =========== 

*Generator Ownership Yes/No=1/0*
tab b08
gen sum_generator = b08 ==1
	order sum_generator, after (b08)
	label var sum_generator "Generator Ownership"
	
*Number of Generators*
gen sum_numgenerator = b09
	label var sum_numgenerator "Number of Generators"
	
*Generators Year of Purchase*
tab1 b10*

*Generator State New/Used*
tab1 b11*

*Generator Purchase Price*
replace b121=. if b121== -88
replace b122=. if b122== -88
replace b123=. if b123== -88
replace b124=. if b124== -88
sum b121 b122 b123 b124
/*gen sum_geneprice = ((97584.43*122) + (97592.27*22) + (210600*5))/(122+22+5) =  101378.1
This is the average considering all the generators reported irrespective of the number of respondents*/

*Was the generator a gift?*
tab1 b12a*

*Generator Capacity*
tab1 b13*
tab1 b13a*

***BY NUMBER OF GENERATORS REPORTED***
replace b131=. if b131== -88
replace b131= (b131*1000) if b13a1==1 
replace b131= b131 if b13a1== 2

replace b132=. if b132== -88
replace b132= (b132*1000) if b13a2==1 
replace b132= b132 if b13a2== 2

replace b133=. if b133== -88
replace b133= (b133*1000) if b13a3==1 
replace b133= b133 if b13a3== 2

replace b134=. if b134== -88
replace b134= (b134*1000) if b13a4==1 
replace b134= b134 if b13a4== 2

sum b131 b132 b133 b134
*gen sum_genecapacity= ((510591.2*105) + (750003.2*16) + (360004.1*5))/(105+16+5)
/* Average = 535017.1 kilowatt considering all the generators reported irrespective of the number of respondents*/

***BY THE NUMBER OF RESPONDENTS IN THE SAMPLE***
gen sum_genecapacity1=.
	/*Converting Megawatt to Kilowatt*/
	replace sum_genecapacity1= (b131*1000) if b13a1==1 
	replace sum_genecapacity1=b131 if b13a1==2
	label var sum_genecapacity1 "Average Generator Capacity" /*for the first generator/respondent. Average = 510591.2 Kilowatt*/

*Generator weekly use*
tab1 b14*
sum b14*

*Generator daily hours use*
tab1 b15*
sum b15*
	
*Appliances powered by Generators*
tab1 b16_*
gen sum_appliance_1 = b16_11 == 1| b16_12 == 1| b16_13 == 1| b16_14 == 1 
	label var sum_appliance_1 "Blender or food processor"
gen sum_appliance_2 = b16_21 == 1| b16_22 == 1| b16_23 == 1| b16_24 == 1
	label var sum_appliance_2 "Electric cooker"
gen sum_appliance_3 = b16_31 == 1| b16_32 == 1| b16_33 == 1| b16_34 == 1
	label var sum_appliance_3 "Freezer"
gen sum_appliance_4 = b16_41 == 1| b16_42 == 1| b16_43 == 1| b16_44 == 1
	label var sum_appliance_4 "Refrigerator"
gen sum_appliance_5 = b16_51 == 1| b16_52 == 1| b16_53 == 1| b16_54 == 1
	label var sum_appliance_5 "Microwave"
gen sum_appliance_6 = b16_61 == 1| b16_62 == 1| b16_63 == 1| b16_64 == 1
	label var sum_appliance_6 "Standing/Ceiling Fan"
gen sum_appliance_7 = b16_71 == 1| b16_72 == 1| b16_73 == 1| b16_74 == 1
	label var sum_appliance_7 "TV Set"
gen sum_appliance_8 = b16_81 == 1| b16_82 == 1| b16_83 == 1| b16_84 == 1
	label var sum_appliance_8 "Washing machine"
gen sum_appliance_9 = b16_91 == 1| b16_92 == 1| b16_93 == 1| b16_94 == 1
	label var sum_appliance_9 "Bulbs"
gen sum_appliance_10 = b16_101 == 1| b16_102 == 1| b16_103 == 1| b16_104 == 1
	label var sum_appliance_10 "Charging electrical devices"
gen sum_appliance_11 = b16_0111 == 1| b16_0112 == 1| b16_0113 == 1| b16_0114 == 1
	label var sum_appliance_11 "Water pumps"
gen sum_appliance_96 = b16_961 == 1| b16_962 == 1| b16_963 == 1| b16_964 == 1
	label var sum_appliance_96 "Others"
	
*Last week purchase of fuel (in liter)*
sum b17*
	
*Types of Fuel -Gasoline/Petrole (1) vs Diesel(2)*
gen sum_fueltype =.
	replace sum_fueltype = 1 if b191 == 1| b192 == 1| b193 == 1| b194 == 1 
	replace sum_fueltype = 0 if b191 == 2| b192 == 2| b193 == 2| b194 == 2 
	label var sum_fueltype "Types of Fuel"
	
*Fuel place of purchase - Fuel Station (1) vs Black market(2)*
gen sum_fuelplace =.
	replace sum_fuelplace = 1 if b201 == 1| b202 == 1| b203 == 1| b204 == 1 
	replace sum_fuelplace = 0 if b201 == 2| b202 == 2| b203 == 2| b204 == 2 
	label var sum_fuelplace "Fuel place of purchase"

*Fuel price per liter*
tab1 b18*
sum b18*
gen sum_fuelprice =.
	replace sum_fuelprice = b181  
	label var sum_fuelprice "Fuel price per liter"	

* =========== SOLAR SYSTEM =========== 
	
*Solar Energy Installed Yes/No=1/0*
gen sum_solar = b22 ==1
	order sum_solar, after (b22)
	label var sum_solar "Solar Energy Installed"
	
*Number of Solar Energy*
tab b25
gen sum_solarnum = b25
	order sum_solarnum, after (b25)
	label var sum_solarnum "Number of Solar Energy"
	
*Solar System Year of Purchase*
tab1 b26*
gen sum_yearsolar =.
	replace sum_year = 0 if b261<2020
	replace sum_year = 1 if b261>=2020
	label var sum_year "Solar System Year of Purchase"

*Solar System Purchase Price*
sum b27*
/*gen sum_solarprice = ((66338.1*252) + (85185.32*62) + (63909.09*11)+ (146666.7*3) + 45000 + 45000)/(252+62+11+5) =  70399.06
This is the average considering all the solars reported irrespective of the number of respondents*/
	
*Solar system Capacity*
tab1 b281 b282 b283 b284 b285 b286
tab1 b28a*

***BY NUMBER OF GENERATORS REPORTED***
replace b281=. if b281== -88
replace b281= (b281*1000) if b28a1==1 
replace b281= b281 if b28a1== 2

replace b282=. if b282== -88
replace b282= (b282*1000) if b28a2==1 
replace b282= b282 if b28a2== 2

sum b281 b282
*gen sum_solarcapacity= ((116023.9*45) + (300204*6))/(45+6)
/* Average = 137692.1 kilowatt considering all the solars reported irrespective of the number of respondents*/

*Solar System weekly use*
*tab1 b29*
sum b29*
gen sum_solarUse = b291
	order sum_solarUse, after (b29)
	label var sum_solarUse "Solar System weekly use"
	
*Solar daily hours use*
*tab1 b30*
sum b30*
gen sum_solarHourUse = b301
	order sum_solarHourUse, after (b30)
	label var sum_solarHourUse "Solar System daily hours use"
	
*Appliances powered by Solar System Yes/No=1/0*

tab1 b31_*
gen sum_solappliance_1 = b31_11 == 1| b31_12 == 1| b31_13 == 1| b31_14 == 1| b31_15 == 1| b31_16 == 1  
	label var sum_solappliance_1 "S Blender or food processor"
gen sum_solappliance_2 = b31_21 == 1| b31_22 == 1| b31_23 == 1| b31_24 == 1| b31_25 == 1| b31_26 == 1  
	label var sum_solappliance_2 "S Electric cooker"
gen sum_solappliance_3 = b31_31 == 1| b31_32 == 1| b31_33 == 1| b31_34 == 1| b31_35 == 1| b31_36 == 1  
	label var sum_solappliance_3 "S Freezer"
gen sum_solappliance_4 = b31_41 == 1| b31_42 == 1| b31_43 == 1| b31_44 == 1| b31_45 == 1| b31_46 == 1  
	label var sum_solappliance_4 "S Refrigerator"
gen sum_solappliance_5 = b31_51 == 1| b31_52 == 1| b31_53 == 1| b31_54 == 1| b31_55 == 1| b31_56 == 1  
	label var sum_solappliance_5 "S Microwave"
gen sum_solappliance_6 = b31_61 == 1| b31_62 == 1| b31_63 == 1| b31_64 == 1| b31_65 == 1| b31_66 == 1  
	label var sum_solappliance_6 "S Standing/Ceiling Fan"
gen sum_solappliance_7 = b31_71 == 1| b31_72 == 1| b31_73 == 1| b31_74 == 1| b31_75 == 1| b31_76 == 1  
	label var sum_solappliance_7 "S TV Set"
gen sum_solappliance_8 = b31_81 == 1| b31_82 == 1| b31_83 == 1| b31_84 == 1| b31_85 == 1| b31_86 == 1  
	label var sum_solappliance_8 "S Washing machine"
gen sum_solappliance_9 = b31_91 == 1| b31_92 == 1| b31_93 == 1| b31_94 == 1| b31_95 == 1| b31_96 == 1  
	label var sum_solappliance_9 "S Bulbs"
gen sum_solappliance_10 = b31_101 == 1| b31_102 == 1| b31_103 == 1| b31_104 == 1| b31_105 == 1| b31_106 == 1  
replace sum_solappliance_10 = 1 if b31_oth1 == "Charge one phone"| b31_oth2 == "Charge one phone"| b31_oth3 == "Charge one phone"| b31_oth4 == "Charge one phone"| b31_oth5 == "Charge one phone"| b31_oth6 == "Charge one phone"
replace sum_solappliance_10 = 1 if b31_oth1 == "Charging of my phones"| b31_oth2 == "Charging of my phones"| b31_oth3 == "Charging of my phones"| b31_oth4 == "Charging of my phones"| b31_oth5 == "Charging of my phones"| b31_oth6 == "Charging of my phones"
replace sum_solappliance_10 = 1 if b31_oth1 == "Charging of phone"| b31_oth2 == "Charging of phone"| b31_oth3 == "Charging of phone"| b31_oth4 == "Charging of phone"| b31_oth5 == "Charging of phone"| b31_oth6 == "Charging of phone"
replace sum_solappliance_10 = 1 if b31_oth1 == "Charging of phones"| b31_oth2 == "Charging of phones"| b31_oth3 == "Charging of phones"| b31_oth4 == "Charging of phones"| b31_oth5 == "Charging of phones"| b31_oth6 == "Charging of phones"
replace sum_solappliance_10 = 1 if b31_oth1 == "Charging phone and mp3"| b31_oth2 == "Charging phone and mp3"| b31_oth3 == "Charging phone and mp3"| b31_oth4 == "Charging phone and mp3"| b31_oth5 == "Charging phone and mp3"| b31_oth6 == "Charging phone and mp3"
replace sum_solappliance_10 = 1 if b31_oth1 == "Laptops,phones."| b31_oth2 == "Laptops,phones."| b31_oth3 == "Laptops,phones."| b31_oth4 == "Laptops,phones."| b31_oth5 == "Laptops,phones."| b31_oth6 == "Laptops,phones."
replace sum_solappliance_10 = 1 if b31_oth1 == "Phones"| b31_oth2 == "Phones"| b31_oth3 == "Phones"| b31_oth4 == "Phones"| b31_oth5 == "Phones"| b31_oth6 == "Phones"
replace sum_solappliance_10 = 1 if b31_oth1 == "To charge Phone"| b31_oth2 == "To charge Phone"| b31_oth3 == "To charge Phone"| b31_oth4 == "To charge Phone"| b31_oth5 == "To charge Phone"| b31_oth6 == "To charge Phone"
	label var sum_solappliance_10 "S Charging electrical devices"
gen sum_solappliance_11 = b31_0111 == 1| b31_0112 == 1| b31_0113 == 1| b31_0114 == 1| b31_0115 == 1| b31_0116 == 1  
	label var sum_solappliance_11 "S Water pumps"
gen sum_solappliance_96 = b31_0961 == 1| b31_0962 == 1| b31_0963 == 1| b31_0964 == 1| b31_0965 == 1| b31_0966 == 1  
	label var sum_solappliance_96 "S Others"
*tab1 b31_oth*

*Solar Energy Ownership Own/Paying it off=1/2*
tab1 b32*
	
*Solar Energy Payment frequency*
tab1 b33*
qui tab b331, gen (sum_solarfreq_)
	label var sum_solarfreq_1 "Monthly Payment"
	replace sum_solarfreq_1 = 1 if b361 == 4
	label var sum_solarfreq_2 "Anually Payment"
	replace sum_solarfreq_2 = 1 if b361 == 6
	label var sum_solarfreq_3 "Quaterly Payment"
	replace sum_solarfreq_3 = 0 if b361 == 2 | b361 == 4 | b361 == 6
	
*Solar Energy average monthly Payment*
gen sum_monthpayment =.
	replace sum_monthpayment = b341 if b331 == 1 
	replace sum_monthpayment = b371 if b361 == 4
	replace sum_monthpayment = (b351/12) if b331 == 2
	replace sum_monthpayment = (b371/12) if b361 == 6
	replace sum_monthpayment = (b371/3) if b361 == 5
	replace sum_monthpayment = (b371*4) if b361 == 2
	label var sum_monthpayment "Solar Energy average monthly Payment"
	
*Solar Energy Seller*
qui tab b381, gen (sum_solarSeller)
	label var sum_solarSeller1 "Ecozar Technologies"
	label var sum_solarSeller2 "Oolu Energy Nigeria Limited"
	label var sum_solarSeller3 "MTN Lumos Solar Mobile Electricity"
	label var sum_solarSeller4 "Sunking"
	label var sum_solarSeller5 "Baobab solar energy"
	label var sum_solarSeller6 "Others Specify"

*Use of Solar Energy + Generator - Yes/No=1/0**
tab b39
gen sum_solargene = b39 ==1
	replace sum_solargene =. if b39 ==.
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
