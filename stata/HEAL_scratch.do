/* -------------------------------------------------------------------------------- */
/* Project: HEAL 																	*/
/* PI: Kira Bradford, Becky Boyles													*/
/* Program: HEAL_scratch															*/
/* Programmer: Sabrina McCutchan (CDMS)												*/
/* Date Created: 2024/05/13															*/
/* Date Last Updated: 2024/10/09													*/
/* Description:	This program performs ad-hoc queries.								*/
/*																					*/
/* Notes:  																			*/
/*		- 2024/06/11 reversed order of queries so new queries are added to top of	*/
/*					 program.														*/
/*																					*/
/* -------------------------------------------------------------------------------- */


clear all 


/* ---------------------- */
/* ------- QUERY -------- */
/* ---------------------- */

/* ----- Query: 2024/10/01	----- */
/* Note: RJ over email requested "a list of independent studies and SBIR's expiring in 2025". */

* Prep study info *;
use "$der/study_lookup_table.dta", clear
drop appl_id
destring xstudy_id, generate(study_id_final)
drop xstudy_id
order study_id_final
sort study_id_final study_most_recent_appl study_hdp_id 
duplicates drop 
save "$temp/study_info.dta", replace /*n=1214*/


* Merge res_net *;
use "$der/mysql_$today.dta", clear /*n=1719*/
egen compound_key=concat(appl_id hdp_id), punct(_)
sort appl_id
merge m:1 appl_id using "$der/research_networks.dta"
drop _merge
merge 1:1 compound_key using "$doc/studyidkey.dta", keepusing(study_id_final)
drop _merge
merge m:1 study_id_final using "$temp/study_info.dta"
drop _merge

* Exclusion criteria *;
drop if entity_type!="Study" /*n=46 dropped*/
drop if merge_awards_mds==2 /*n=2 dropped*/
keep if res_net=="" /*n=739 dropped*/

* Expiring in 2025 *;
gen year_end=year(proj_end_date_date)
keep if year_end==2025 /*n=133 left*/

* Output results *;
keep appl_id hdp_id fisc_yr fund_mech year_end study_id_final study_id_final study_hdp_id study_hdp_id_appl merge_awards_mds

	browse if hdp_id=="" /* Note: these do make it into study_lookup_table */

sort fund_mech appl_id hdp_id
export delimited using "$out/appls_ending_2025.csv", quote replace




/* ----- Query: 2024/09/10	----- */
/* Note: Request from Kathy: Identify how many HEAL studies are funded by NIMH */
use "$der/study_lookup_table.dta", clear
keep appl_id study_hdp_id xstudy_id
sort appl_id study_hdp_id
duplicates drop
save "$temp/study_ids_formerge.dta", replace /*n=1481*/

* Add study ID to full dataset *;
use "$der/mysql_$today.dta", clear
order appl_id $stewards_id_vars hdp_id
sort $stewards_id_vars appl_id hdp_id	

	* Exclude records of non-study entities (CTN & "other") *;
	drop if mds_ctn_flag==1  /*n=40 dropped */
	drop if proj_ser_num=="" /*n=6 dropped*/
	sort appl_id
	merge m:1 appl_id using "$der/research_networks.dta"
	drop if _merge==2
	drop _merge res_net_override_flag
	drop if res_net==4 /*n=1481 deleted*/

sort appl_id hdp_id
/*by appl_id: gen xnum_rows_for_applid=_n
by appl_id: egen num_rows_for_applid=max(xnum_rows_for_applid)
drop xnum_rows_for_applid*/
merge m:m appl_id using "$temp/study_ids_formerge.dta" /*n=1481*/
save "$temp/studies_NDA_affiliation.dta", replace
	/* m:m merge is done because the hdp_id from using is attached to the xstudy_id, not the appl_id, and trying to use it as a merge var messes up the merge. The m:m merge command produces the desired result of appending the correct xstudy_id to the master data, though I'm not entirely sure how it chooses the correct hdp_id + studyid from using to match to master (but it does!) */

* Find IC for each study ID *;
/* temp override adm_ic for the 1 appl_id that is in MDS but not MySQL yet */
use "$temp/studies_NDA_affiliation.dta", clear
keep appl_id hdp_id xstudy_id adm_ic fund_ic 
replace adm_ic="NIDA" if appl_id=="10875930"
keep adm_ic xstudy_id
duplicates drop
tab adm_ic

* Find repository selection *;
use "$temp/studies_NDA_affiliation.dta", clear
keep appl_id hdp_id xstudy_id adm_ic repository_name 
/*duplicates list xstudy_id*/
keep if repository_name!=""
duplicates list xstudy_id
tab repository_name

* Check DAI-2 for repository selection *;
global dai "C:\Users\smccutchan\OneDrive - Research Triangle Institute\Documents\HEAL\DAI2\Derived"
use "$dai\dai2_clean.dta", clear
keep if heal_dai2_assessment_complete==2




/* ----- Query: 2024/07/25	----- */
/* Note: Request from Anthony and arbitrated by RJ and Maria: Pull a list of all HEAL-funded appl_IDs currently in the MySQL DB */
use "$der/xold/mysql_2024-07-18.dta", clear
drop if appl_id==""
drop if merge_awards_mds==2 /* Limit to what's in MYSQL; exclude awards that're only in MDS*/
drop if heal_funded=="N" /* Exclude appl_ids that aren't HEAL funded */
keep appl_id heal_funded proj_title proj_num_spl_ty_code rfa res_prg
replace heal_funded="?" if heal_funded==""
replace heal_funded="Yes" if heal_funded=="Y"
sort heal_funded appl_id
label var appl_id "Application ID"
label var heal_funded "[awards] Award was HEAL-funded"
label var proj_title "[reporter] Project Title"
label var proj_num_spl_ty_code "[reporter] Project Type Code"
label var rfa "[awards] Research Focus Area"
label var res_prg "[awards] Research Program"
export delimited using "$out/HEAL_MySQL_applids_2024-07-31.csv", quote replace




/* ----- Query: 2024/07/01	----- */
/* Note: Slack from KathyJ in #mysql-updates on 2024/06/28
Could someone with access to MySQL extract everything about all HEAL studies with PI Yong Chen for me? Title is "Modeling temporomandibular joint disorders pain: role of transient receptor potential ion channels". Looks like they got 7 different NIH awards. The engagement team might be able to clear up the study list for us. Thanks!
*/
use "$der/mysql_$today.dta", clear
foreach x of varlist pi pi_fst_nm pi_lst_nm {
	replace `x'=lower(`x')
	replace `x'=subinstr(`x', "`=char(10)'", "`=char(32)'", .) /* replace linebreaks inside cells with a space */
	replace `x'=strtrim(`x')
	replace `x'=stritrim(`x')
	replace `x'=ustrtrim(`x')
	split `x', p(";")
	}
gen xname_flag=0
forv i=1/7 {
	replace xname_flag=1 if pi_lst_nm`i'=="chen"
	/*replace xname_flag=1 if pi_lst_nm`i'=="yong"   no results */
	}
browse if xname_flag==1
gen name_flag=0
forv i=1/7 {
	replace name_flag=1 if pi`i'=="yong chen"
	}
keep if name_flag==1
forv i=1/7 {
	drop pi`i' pi_fst_nm`i' pi_lst_nm`i'
	}
drop name_flag xname_flag
save "$out/yongchen_$today.dta", replace
export excel using "$out/yongchen_$today", replace firstrow(var) keepcellfmt





/*
/* ----- Query: 2024/05/13	----- */
/* Note: Slack from KathyJ in #mysql-updates on 2024/05/13
I investigated the list of 14 appl_IDs above which are in the Studies board but I didn't find in the lookup table. Several seem to be legit HEAL studies based on Reporter data. For the ones below in particular, when you get a chance, it would be good to 1) check if they are in MySQL and 2) confirm whether they are or are not in the lookup table. If they are in MySQL and not in the lookup table, we can try to figure out why.
9673173  (5U24HD095254-02)
9769689  (5R01DE027454-02)
10593312  (3R24DA055306-02S1)
*/

use "$raw/reporter_$today.dta", clear
browse if inlist(appl_id,"9673173","9769689","10593312")


use "$raw/awards_$today.dta", clear
browse if inlist(appl_id,"9673173","9769689","10593312")

import excel using "$doc/Change Log.xlsx", sheet("Modifications") firstrow clear
browse if inlist(ApplID,"9673173","9769689","10593312")




/* ----- Query: 2024/05/28	----- */
/* Note: Pull record for consult prep */
use "$der/mysql_$today.dta", clear
keep if hdp_id=="HDP00014"
export delimited using "$out/reike.csv"




/* ----- Query: 2024/05/31	----- */
use "$out/study_lookup_table.dta", clear
rename study_hdp_id hdp_id
sort hdp_id
merge m:1 hdp_id using "$raw/progress_tracker_$today.dta", keepusing(archived)
drop if _merge==2
drop _merge
gen most_recent_appl_archived=0
keep if appl_id==study_most_recent_appl /*n=1313*/
replace most_recent_appl_archived=1 if archived=="archived"
export excel using "$out/most_recent_appls_by_archived_status", replace firstrow(var) keepcellfmt




/* ----- Check MySQL Updates: 2024/06/06	----- */
use "$raw/reporter_$today.dta", clear
order appl_id
drop if appl_id==""
merge 1:1 appl_id using "$raw/xold/reporter_2024-05-31.dta"
keep if _merge==1
save "$temp/new_reporter_rows_$today.dta", replace
