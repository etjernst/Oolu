

* Prep Oolu data

import excel using "D:\Dropbox\Collaborations\Oolu\Background\Oolu/Sales_last12months_bystate.xlsx", clear first

* Oolu data divides Delta into two, not sure why
replace State = "DELTA" if inlist(State,"DELTA-NORTH","DELTA-SOUTH")

* This isn't the best way to get the means, but they aren't dramatically different anyway
egen mean_Cash = mean(Cash), by(State)
replace Cash = mean_Cash
egen mean_Annual = mean(Annual), by(State)
replace Annual = mean_Annual
egen mean_Monthly = mean(Monthly), by(State)
replace Monthly = mean_Monthly
egen mean_Sales = mean(Sales), by(State)
replace Sales = mean_Sales

drop mean_*
duplicates drop

replace State = "FCT ABUJA" if State=="ABUJA"

save oolu_state_data, replace

* Set to wherever the DHS household file is
cd "D:/Downloads/NGHR7ADT"

use "NGHR7AFL", clear

* State variable is: shstate
* Generator variable is: sh121n
* Electricity variable is: hv206
* Wealth index: hv270
* Urban/rural: hv025
* Household sample weight: hv005

preserve
keep shstate
decode shstate, gen(state_labels)
duplicates drop
save state_labels, replace
restore

g wgt = hv005 / 1000000

* This is probably a really dumb way to get weighted means by state, but it works...
mean sh121n [iw=wgt], over(shstate)
mat sh121n_means = r(table)["b",.]

mean hv270 [iw=wgt], over(shstate)
mat hv270_means = r(table)["b",.]

mean hv206 [iw=wgt], over(shstate)
mat hv206_means = r(table)["b",.]

clear

svmat sh121n_means
svmat hv270_means
svmat hv206_means

g i = _n

reshape long sh121n_means hv270_means hv206_means, i(i) j(j)

drop i

replace j = j * 10
rename j shstate 
merge 1:1 shstate using state_labels
drop _m

la variable state_labels "State" 
la variable sh121n_means "Generator ownership (%)"
la variable hv270_means "Wealth index (1-5)"
la variable hv206_means "Electricity access (%)"

export excel state_labels sh121n_means hv206_means hv270_means using "state_summary_stats_dhs2018.xlsx", replace first(varlabels)

rename state_labels State 
replace State = upper(State)

merge 1:1 State using oolu_state_data

la var Sales "Oolu sales, last 12 months"
la var Cash "Oolu % Cash sales"
la var Annual "Oolu % Annual payment sales"
la var Monthly "Oolu % Monthly sales"

export excel State sh121n_means hv206_means hv270_means Sales Cash Annual Monthly using "D:\Dropbox\Collaborations\Oolu\Data\Proposal Planning/state_level_stats.xlsx", replace first(varlabels)