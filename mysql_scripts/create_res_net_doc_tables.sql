/* Define the table */
/*
CREATE TABLE `healstudies`.`res_net_ref_table` (
`goal` VARCHAR(22) NOT NULL,
`res_prg` VARCHAR(135) NOT NULL,
`res_net` VARCHAR(19),
`dcc` VARCHAR(19),
`rfa` VARCHAR(73)
);

CREATE TABLE `healstudies`.`res_net_override` (
`appl_id` VARCHAR(8) NOT NULL,
`res_net` VARCHAR(19)
);

*/


/* Empty the table contents */
TRUNCATE TABLE `res_net_ref_table`;
TRUNCATE TABLE `res_net_override`;


/* Load a local data file into the table */
LOAD DATA LOCAL
INFILE 'C:/Users/smccutchan/OneDrive - Research Triangle Institute/Documents/HEAL/MySQL/Documentation/res_net_ref_table.csv'
INTO TABLE res_net_ref_table
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;


LOAD DATA LOCAL
INFILE 'C:/Users/smccutchan/OneDrive - Research Triangle Institute/Documents/HEAL/MySQL/Documentation/res_net_value_overrides.csv'
INTO TABLE res_net_override
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;