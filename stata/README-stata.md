Most Stata code is organized into a program tree, where each program is meant to be run sequentially, beginning with HEAL_00_Master.do. There are a few Stata programs which are not part of the program tree. Programs in the tree include numbers in the file name, while those outside the tree do not include numbers in the file name.

Summary of what each Stata .do file in the program tree does:
- HEAL_00_Master : This is the master Stata program for MySQL data processing. It sets global macros before calling the other programs in the tree.
- HEAL_01_ImportMerge : This program imports the latest data from MySQL, merges it, and cleans it.
- HEAL_02_ResNetTable : This program generates and populates the res_net field in the research_networks table in MySQL.
- HEAL_03_StudyTable : This program creates the xstudy_id field and the study_lookup_table.
- HEAL_04_CTN : This program generates a crosswalk for Clinical Trials Network protocols and associated project numbers. It identifies application IDs that belong to project numbers identified by responsible SMEs as part of the Clinical Trials Network (CTN).
- HEAL_98_StudyMetrics : This program produces a report of HDE study metrics.
- HEAL_99_QC : This program creates a data quality control (QC) report.
- HEAL_valuelabels : This program applies Stata value labels to variables.

Other Stata programs
- HEAL_scratch.do : This program performs ad-hoc queries.
- HEAL_TableArchiving : This program manages MySQL tables prior to archiving. 
