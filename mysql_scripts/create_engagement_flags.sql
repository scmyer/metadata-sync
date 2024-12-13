
/* Define the table */
CREATE TABLE `healstudies`.`engagement_flags` (
`appl_id` VARCHAR(8) NOT NULL PRIMARY KEY,
`do_not_engage` TINYINT(1),
`checklist_exempt_all` TINYINT(1)
);


/* Load a local data file into the table */
LOAD DATA LOCAL
INFILE 'C:/Users/smccutchan/OneDrive - Research Triangle Institute/Documents/HEAL/MySQL/Derived/engagement_flags.csv'
INTO TABLE `healstudies`.`engagement_flags`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;