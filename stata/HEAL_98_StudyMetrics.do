/* -------------------------------------------------------------------------------- */
/* Project: HEAL 																	*/
/* PI: Kira Bradford																*/
/* Program: HEAL_98_StudyMetrics													*/
/* Programmer: Sabrina McCutchan (CDMS)												*/
/* Date Created: 2024/06/23															*/
/* Date Last Updated: 2024/10/09													*/
/* Description:	This program produces a report of HDE study metrics.				*/				
/*		1. Number of NIH awards in MySQL											*/
/*		2. Number of entities tracked 												*/
/*		3. Number of live HDP_IDs													*/
/*		X. Create dataset for study metrics 										*/
/*		4. Number of entities registered 											*/
/*		5. Number of entities selected a repo  										*/
/*		6. Number of entities submitted SLMD										*/
/*		7. Number of entities submitted VLMD										*/
/*		8. Number of entities begun data deposit									*/
/*		9. Crosscheck PM repo and deposit lists										*/
/*																					*/
/* Notes:  																			*/
/*		- In June 2024, a "6-Month Report" was generated to measure Get the Data	*/
/*		  (GtD) progress. This contained metrics which resemble but predate the		*/
/*		  formally agreed-upon study metrics. Thus, this program supersedes the 	*/
/*		  previous program HEAL_6Mo_Report.do; the latter has been archived.		*/
/*																					*/
/* Version changes																	*/
/*		- v2 - current version														*/
/*		- v1 - HEAL_6Mo_Report.do, now archived. June 2024. 						*/	
/*																					*/
/* -------------------------------------------------------------------------------- */


clear



/* ----- 1. Number of HEAL Studies ----- */
asdoc, text(--------------1. Number of HEAL Studies--------------) fs(14), save($qc/StudyMetrics_$today.doc) replace
asdoc, text(Estimated by the number of active records on the Platform.) save($qc/StudyMetrics_$today.doc) append label

use "$der/mysql_$today.dta", clear
drop if merge_awards_mds==1
drop if archived=="archived"
keep hdp_id archived entity_type
gen HEAL_studies=_n
asdoc sum HEAL_studies, statistics(max) save($qc/StudyMetrics_$today.doc) append label
asdoc, text( ) fs(14), save($qc/StudyMetrics_$today.doc) append

asdoc, text(These active records on Platform may be one of three entity types: a study, a CTN protocol, or an 'other' entity.) save($qc/StudyMetrics_$today.doc) append label
asdoc tab entity_type, title(HEAL Studies by entity_type) save($qc/StudyMetrics_$today.doc) append label



/* ----- 2. Number of studies not sharing data ----- */
asdoc, text(--------------2. Number of studies not sharing data--------------) fs(14), save($qc/StudyMetrics_$today.doc) append label
asdoc, text(Estimated by the number of studies on the Platform with Data Availability status flagged as Not Available.) save($qc/StudyMetrics_$today.doc) append label

asdoc, text(Note: There's no column in the progress_tracker table that indicates data availability. Kathy slacked Brienna asking which field in the Platform MDS shows 'Data Availability'. Stephen and Hina must update the script that pulls data from MDS and creates the progress_tracker table to add this field to the pull.) save($qc/StudyMetrics_$today.doc) append label

use "$temp/progress_tracker_$today.dta", clear
drop if archived=="archived"

asdoc, text( ) fs(12), save($qc/StudyMetrics_$today.doc) append 



/* ----- 3. Number of studies with VLMD on Platform ----- */
asdoc, text(--------------3. Number of studies with VLMD on Platform--------------) fs(14), save($qc/StudyMetrics_$today.doc) append label
asdoc, text(Estimated by the number of active MDS records where variable_level_metadata.data_dictionaries is non-missing.) save($qc/StudyMetrics_$today.doc) append label
asdoc, text(Note: Need to check provenance of the vlmd_metadata var in the progress_tracker table. Is this raw data exported from Platform MDS or is it a field derived by Stephen's script?) save($qc/StudyMetrics_$today.doc) append label

use "$temp/progress_tracker_$today.dta", clear
drop if archived=="archived"
/* note: drop studies fitting number 2 condition, producing but not sharing data */
gen vlmd_available=""
label var vlmd_available "VLMD available on Platform?"
replace vlmd_available="no" if vlmd_metadata=="[]"
replace vlmd_available="yes" if vlmd_metadata!="[]" 
asdoc tab vlmd_available, save($qc/StudyMetrics_$today.doc) append label



/* ----- 4. Number of studies with VLMD available in HSS ----- */
asdoc, text(--------------4. Number of studies with VLMD available in HSS--------------) fs(14), save($qc/StudyMetrics_$today.doc) append label
asdoc, text(Estimated by the number of items in the Stewards 'Data Dictionary Tracker' board for which 'in HSS' = Yes.) save($qc/StudyMetrics_$today.doc) append label

*  Read in monday.com spreadsheet export tabs *;
* Note: Some manual reformatting of the Data Dictionary Tracker board export file was done to make it more machine readable. The separate table sections of the original export were all on one tab; these were manually moved to distinct tabs, and the tabs were name as defined in the following global macro. *;
global tabs engagement_in_progress dd_file_in_hand no_vlmd_expected
foreach tab in $tabs {
	import excel using "C:\Users\smccutchan\OneDrive - Research Triangle Institute\Documents\HEAL\monday_boards\Data_Dictionary_Tracker_1728247808.xlsx", sheet("`tab'") /*firstrow case(lower)*/ allstring clear
	drop if _n == 1 
	foreach x of varlist * {
		replace `x'=subinstr(`x', "`=char(10)'", "`=char(32)'", .) /* replace linebreaks inside cells with a space */
		replace `x'=strtrim(`x')
		replace `x'=stritrim(`x')
		replace `x'=ustrtrim(`x')
		label var `x' `"`=`x'[1]'"'
		}
	missings dropvars * , force /* drop columns with no data */
	missings dropobs * , force /* drop rows with no data */
	gen source_tab="`tab'"
	/*gen xrowID=_n*/
	save "$temp/`tab'.dta", replace
	/*descsave using "$raw/`src'/`tab'.dta", list(,) idstr(`tab') saving("$temp/`src'/varlist_`tab'.dta", replace) */
	}
	
clear
foreach tab in $tabs {
	append using "$temp/`tab'.dta"
	}
drop if A=="Name"
gen vlmd_in_hss=0
replace vlmd_in_hss=1 if T=="Yes"
label var vlmd_in_hss "VLMD in HSS"
do "$prog/HEAL_valuelabels"
/*label define yesno 0 "No" 1 "Yes"*/
label values vlmd_in_hss yesno
save "$temp/monday_data.dta", replace


* Add section to report *;
use "$temp/monday_data.dta", clear
keep if vlmd_in_hss==1
asdoc sum vlmd_in_hss, statistics(N) save($qc/StudyMetrics_$today.doc) append label
asdoc, text( ) fs(12), save($qc/StudyMetrics_$today.doc) append 



/* ----- 5. Number of studies who've submitted CDE usage----- */
asdoc, text(--------------5. Number of studies who've submitted CDE usage--------------) fs(14), save($qc/StudyMetrics_$today.doc) append label
asdoc, text(Estimated by the number of active MDS records where 'Variable_level_metadata.common_data_elements' is non-missing) save($qc/StudyMetrics_$today.doc) append label
asdoc, text(Note: This data point won't exist until Platform implements the CDE picker feature) save($qc/StudyMetrics_$today.doc) append label
asdoc, text( ) fs(12), save($qc/StudyMetrics_$today.doc) append 



/* ----- 6. Number of studies registered ----- */
asdoc, text(--------------6. Number of studies registered--------------) fs(14), save($qc/StudyMetrics_$today.doc) append label

use "$temp/progress_tracker_$today.dta", clear
drop if archived=="archived"
/* note: drop studies fitting number 2 condition, producing but not sharing data */
gen registered=.
replace registered=0 if is_registered=="not registered"
replace registered=1 if is_registered=="is registered"
label var registered "Registered on Platform"
do "$prog/HEAL_valuelabels"
/*label define yesno 0 "No" 1 "Yes"*/
label values registered yesno
asdoc tab registered, miss save($qc/StudyMetrics_$today.doc) append label



/* ----- 7. Number of studies submitted SLMD ----- */
asdoc, text(--------------7. Number of studies submitted SLMD--------------) fs(14), save($qc/StudyMetrics_$today.doc) append label
asdoc, text(SLMD is considered submitted if the CEDAR form completion rate is >=50%.) save($qc/StudyMetrics_$today.doc) append label

use "$temp/progress_tracker_$today.dta", clear
drop if archived=="archived"
/* note: drop studies fitting number 2 condition, producing but not sharing data */
destring overall_percent_complete, replace
gen slmd=0
replace slmd=1 if overall_percent_complete>=50 & overall_percent_complete!=.
label var slmd "SLMD Submitted"
label values slmd yesno
asdoc tab slmd, miss save($qc/StudyMetrics_$today.doc) append label



/* ----- 8. Number of studies selected repo ----- */
asdoc, text(--------------8. Number of studies selected repo--------------) fs(14), save($qc/StudyMetrics_$today.doc) append label
asdoc, text( .) save($qc/StudyMetrics_$today.doc) append label

use "$temp/progress_tracker_$today.dta", clear
drop if archived=="archived"
/* note: drop studies fitting number 2 condition, producing but not sharing data */
gen has_repo=.
replace has_repo=0 if strtrim(repository_name)==""
replace has_repo=1 if strtrim(repository_name)!=""
label var has_repo "Repository selected, on Platform"
label values has_repo yesno
asdoc tab has_repo, miss save($qc/StudyMetrics_$today.doc) append label




/* ----- 9. Number of studies with data linked on Platform ----- */
asdoc, text(--------------9. Number of studies with data linked on Platform--------------) fs(14), save($qc/StudyMetrics_$today.doc) append label
asdoc, text( .) save($qc/StudyMetrics_$today.doc) append label

use "$temp/progress_tracker_$today.dta", clear
drop if archived=="archived"
/* note: drop studies fitting number 2 condition, producing but not sharing data */
gen has_deposit=0 
replace has_deposit=1 if strtrim(repository_study_id)!=""
replace has_deposit=0 if repository_study_id=="0"
label var has_deposit "Data deposited"
label values has_deposit yesno
asdoc tab has_deposit, miss save($qc/StudyMetrics_$today.doc) append label










