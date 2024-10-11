/* -------------------------------------------------------------------------------- */
/* Project: HEAL 																	*/
/* PI: Kira Bradford, Becky Boyles													*/
/* Program: HEAL_01_ImportMerge														*/
/* Programmer: Sabrina McCutchan (CDMS)												*/
/* Date Created: 2024/02/29															*/
/* Date Last Updated: 2024/09/03													*/
/* Description:	This program imports the latest data from MySQL for processing.		*/
/*		1. Import data																*/
/*		2. Prepare progress_tracker to merge										*/
/*		3. Merge data 																*/
/*		4. Clean merged data														*/
/*																					*/
/* Notes:  																			*/
/*		- This program creates a stage 1 study identifier, xstudy_id_stewards, based*/
/*		  on unique combinations of values for 3 fields: proj_ser_num subproj_id 	*/
/*		  proj_num_spl_sfx_code														*/
/*		- It creates a stage 2 (last stage) study identifier, xstudy_id, based on	*/
/*		  xstudy_id_stewards and hdp_ids											*/
/*		- Type 3 awards are always supplements. Supplements are always type 3 awards*/
/*		- Supplement awards related to each other are identified by the suffix in	*/
/*		  the project number (proj_num) field. Project numbers ending in S1 are		*/
/*		  related; ending in S2 are related; and so forth.							*/
/*		- The field subproj_id is often missing. When non-missing, it identifies	*/
/*		  separate studies under a consortia/DCC/other large award. 				*/
/*		- Both project_num and appl_id fields in MDS are populated with the CTN 	*/
/*		  protocol number if the HDP_ID is for a CTN protocol						*/
/*																					*/
/* Version changes																	*/
/*		- 2024/04/29 The reporter table may contain records for appl_ids not present*/
/*		  in the awards table. The Platform adds some records for studies that 		*/
/*		  aren't themselves HEAL-funded, but are related to HEAL-funded work 		*/
/*		  ("HEAL-adjacent studies"). Such records appear in NIH Reporter but they 	*/
/*		  don't appear in the HEAL-funded specific data sources used to populate 	*/
/*		  the awards table.															*/ 
/*		- 2024/05/15 Platform has performed QC on appl_id to fix format errors; the */
/*		  code block that fixed these errors has been archived at end of program, 	*/
/*		  in case it's ever needed again.											*/
/*		- 2024/05/28 This program originally native to the HEAL_Study program tree.	*/
/*		  It has now been split out because it is a necessary first step to all 	*/
/*		  processing. This program should be run before any other HEAL programs.	*/	
/*																					*/
/* -------------------------------------------------------------------------------- */



/* ----- 1. Import data ----- */
foreach dtaset in reporter_$today awards_$today progress_tracker_$today {
import delimited using "$raw/`dtaset'.csv", varnames(1) stringcols(_all) bindquote(strict) favorstrfixed clear
	foreach x of varlist * {
		replace `x'=subinstr(`x', "`=char(10)'", "`=char(32)'", .) /* replace linebreaks inside cells with a space */
		replace `x'=strtrim(`x')
		replace `x'=stritrim(`x')
		replace `x'=ustrtrim(`x')
		}
		
sort appl_id
save "$raw/`dtaset'.dta", replace
}



/* ----- 2. Prepare progress_tracker to merge ----- */

use "$raw/progress_tracker_$today.dta", clear /*n=1335*/
order appl_id 
drop if appl_id==""

* -- CTN Protocols -- *;

* Create new CTN variables*;
gen mds_ctn_flag=regexm(project_num,"^CTN") /*n=40*/
gen mds_ctn_number=project_num if mds_ctn_flag==1

* Remove CTN values from appl_id and project_num fields *;
replace project_num="" if mds_ctn_flag==1
replace appl_id="" if mds_ctn_flag==1


* -- Project numbers -- *;

* Split project_num into components needed for xstudy_id *;
foreach var in project_num {
	gen x`var'=`var'
	egen sieved`var'=sieve(`var') , char(-)
	gen num_dashes=length(strtrim(sieved`var'))
	}
replace xproject_num="" if num_dashes>1 /*n=6 changes made*/ 
	
	* Identify and flag bad values of project_num*;
	gen mds_flag_bad_projnum=1 if num_dashes>1 /*n=6 changes made*/
	gen mds_bad_projnum=project_num if num_dashes>1 /*n=6 changes made*/
	
	* If an underscore was inserted, remove it and everything that follows it *;
	foreach var of varlist xproject_num {
	   replace `var'=regexr(`var', "\_.*", "") 
	   } /*n=0 real changes as of 10/09  */

	/*browse project_num xproject_num if project_num!=xproject_num*/
	
gen proj_num_spl_ty_code=substr(xproject_num,1,1)
gen proj_num_spl_act_code=substr(xproject_num,2,3)
gen proj_ser_num=substr(xproject_num,5,8)
	split xproject_num, p(-)
	drop xproject_num1
	rename xproject_num2 proj_nm_spl_supp_yr
gen proj_num_spl_sfx_code=substr(proj_nm_spl_supp_yr,3,.)
foreach var in proj_num_spl_ty_code proj_num_spl_act_code proj_ser_num proj_nm_spl_supp_yr proj_num_spl_sfx_code {
	rename `var' mds_`var'
	}
	
* Count number of hdp_ids for a given appl_id *;
sort appl_id hdp_id
by appl_id: egen num_hdp_by_appl=count(hdp_id)
replace num_hdp_by_appl=0 if num_hdp_by_appl==.
replace num_hdp_by_appl=. if appl_id==""
	/*Note: 2024-10-09: there are only 8 appl_ids that have >1 HDP_ID associated, and the max number of HDP_IDs associated is 3. This excludes CTN records where appl_id==.*/

* Save prepped data *;
drop sievedproject_num num_dashes xproject_num
save "$temp/progress_tracker_$today.dta", replace

	


/* ----- 3. Merge data ----- */
* Merge awards reporter *;
use "$raw/reporter_$today.dta", clear /*n=1665*/
drop if appl_id==""
merge 1:1 appl_id using "$raw/awards_$today.dta" /*n=1665*/
drop if appl_id==""
rename _merge merge_reporter_awards
label define awrep 1 "In reporter only" 2 "In awards only" 3 "In both tables"
label values merge_reporter_awards awrep
save "$temp/nihtables_$today.dta", replace /*n=1665*/

* Merge MDS data (via progress_tracker) *;
use "$temp/nihtables_$today.dta", clear
merge 1:m appl_id using "$temp/progress_tracker_$today.dta" 
rename _merge merge_awards_mds
label var merge_awards_mds "Merge of MySQL and MDS"
label define sqlmds 1 "In MySQL only" 2 "In MDS only" 3 "In both databases"
label values merge_awards_mds sqlmds
save "$temp/dataset_$today.dta", replace /*n=1719*/




/* ----- 4. Clean merged data ----- */
use "$temp/dataset_$today.dta", clear 

* Update values of variables used for identifiers *;
foreach var in proj_ser_num proj_num_spl_sfx_code {
	replace `var'=mds_`var' if strtrim(`var')==""
	}
	/* Note: subproj_id is not available in the MDS data */ /*n=2 and n=0 real changes made*/
	
	replace proj_ser_num=mds_proj_ser_num if strtrim(proj_ser_num)==""

* Flag supplement awards *;
gen xsupp_flag=substr(proj_num,-2,1)
gen supplement_flag=1 if xsupp_flag=="S"
tab supplement_flag /*n=525*/
drop xsupp_flag	

* Dates *;
destring fisc_yr, replace
foreach var in bgt_end proj_end_date {
gen x`var'=substr(`var',1,10)
gen `var'_date=date(x`var',"YMD")
format `var'_date %td
drop x`var'
order `var'_date,after(`var')
label var `var'_date "Stata date format"
}

* Entity type *;
gen entity_type="Study"
replace entity_type="CTN" if mds_ctn_flag==1
replace entity_type="Other" if mds_flag_bad_projnum==1

save "$der/mysql_$today.dta", replace /*n=1719*/	
	

	
	
	





/* 
/* ----- X. Archived code ----- */
* Fix appl_id format - code temporarily needed until Platform performs QC on this field *; 
	foreach var in appl_id {
		gen x`var'=`var'
		egen sieved`var'=sieve(`var') , keep(alphabetic space other)
		}
	tab sievedappl_id /*note: only non-numeric characters are dashes*/

	foreach var of varlist appl_id {
	   replace `var'=regexr(`var', "\-.*", "") /* dash and everything that follows it */
	   }

	replace appl_id="" if appl_id=="0"
	/* Note: there are n=5 records where no appl_id is recorded in either the appl_id or nih_reporter_link variables. For these 5, there is a non-missing project number, but it has been modified from source by Platform */
	drop if appl_id==""
	
* Extract project number components *;
		* Remove lowercase letters (these were inserted by Platform) *;
	foreach var of varlist project_num {
	   replace `var'=regexr(`var', "[a-z]", "") 
	   } /*n=0 real changes*/
	   
	   
	   
	   
	   
	   
	   

order appl_id $stewards_id_vars hdp_id
sort $stewards_id_vars appl_id hdp_id	
	
* Exclude problem rows (missing serial numbers) *;
drop if proj_ser_num=="" /*n=11 dropped*/
	/*
	* Num of unique serial numbers: n=824 using only MySQL data, n=837 if supplemented with MDS data *;
	keep proj_ser_num
	sort proj_ser_num
	duplicates drop 
	*/

* Generate study identifier *;
/* Note: this must be done in 2 stages because missing values among the $stewards_id_vars group should still be assigned a number (subproj_id is often missing), but missing values of hdp_id should *not* be assigned a number */
	* Stage 1 *;
	egen xstudy_id_stewards=group($stewards_id_vars), missing
	
	* Stage 2 *;
	egen study_id=group(xstudy_id_stewards hdp_id)
	label var study_id "Unique Study ID (created by Stewards)"
	order study_id xstudy_id_stewards

* Non-missing subproject number by serial number *;
gen xhas_subproj_num=1 if subproj_id!="" /*n=57*/
bysort proj_ser_num: egen has_subproj_num_by_sernum=max(xhas_subproj_num)
drop xhas_subproj_num


save "$temp/mysql_$today.dta", replace /*n=1622*/




* Count # of appl_ids for each xstudy_id_stewards *;
use "$temp/mysql_$today.dta", clear
keep xstudy_id_stewards appl_id
sort xstudy_id_stewards appl_id
duplicates drop
by xstudy_id_stewards: egen num_appl_by_xstudyidstewards=count(appl_id)
keep xstudy_id_stewards num_appl_by_xstudyidstewards
duplicates drop
save "$temp/sis_count.dta", replace

* Count # of hdp_ids for each xstudy_id_stewards *;
use "$temp/mysql_$today.dta", clear
keep xstudy_id_stewards hdp_id
sort xstudy_id_stewards hdp_id
duplicates drop /*n=1488*/
by xstudy_id_stewards: egen num_hdp_by_xstudyidstewards=count(hdp_id)
keep xstudy_id_stewards num_hdp_by_xstudyidstewards
duplicates drop /*n=1216*/
save "$temp/hdpid_count.dta", replace

use "$temp/mysql_$today.dta", clear
sort xstudy_id_stewards
merge m:1 xstudy_id_stewards using "$temp/sis_count.dta"
drop _merge
merge m:1 xstudy_id_stewards using "$temp/hdpid_count.dta"
drop _merge
order $id_gen_vars
save "$der/mysql_$today.dta", replace /*n=1622*/

