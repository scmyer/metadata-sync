
/* Define the table */
CREATE TABLE `healstudies`.`pi_emails` (
`appl_id` VARCHAR(8) NOT NULL,
`pi_email` VARCHAR(119)
);

/* Load a local data file into the table */
LOAD DATA LOCAL
INFILE 'C:/Users/smccutchan/OneDrive - Research Triangle Institute/Documents/HEAL/MySQL/Raw/Derived/pi_emails_fy24.csv'
INTO TABLE `healstudies`.`pi_emails`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;