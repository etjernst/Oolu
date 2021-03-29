
use "D:\Nigeria LSMS 2018\Household\sect07_30day.dta" , clear

* Keep petrol and diesel expenditures
keep if inlist(item_cd,209,210)

* Petrol expenditures
sum s07q04 if item_cd==209, detail

tab s07q03 if item_cd==209

tab s07q03 if item_cd==209 & sector==1

* Diesel expenditures
sum s07q04 if item_cd==210, detail

tab s07q03 if item_cd==210
tab s07q03 if item_cd==210 & sector==1

use "D:\Nigeria LSMS 2018\Household\sect10_assets.dta" , clear

keep if asset_cd==320

tab s10q01

tab s10q01 if sector==1