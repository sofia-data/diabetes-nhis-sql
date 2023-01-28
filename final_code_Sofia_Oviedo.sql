-- tables creation
-- dataset imported using Table Data Import Wizard 

-- demographics table creation
CREATE TABLE `demographics` (
  `NHISPID` bigint NOT NULL,
  `AGE` int NOT NULL,
  `MARST` int NOT NULL,
  `RACENEW` int NOT NULL,
  `HISPYN` int NOT NULL,
  `USBORN` int NOT NULL,
  `EMPSTAT` int NOT NULL,
  `EARNINGS` int NOT NULL,
  `BMICALC` int NOT NULL,
  `sex1` text NOT NULL,
  `classwk21` text NOT NULL,
  PRIMARY KEY (`NHISPID`)
);

-- access_care table creation
CREATE TABLE `access_care` (
  `NHISP_ID` bigint NOT NULL,
  `GLUCCHEK1YR` int NOT NULL,
  `CHECKUP` int NOT NULL,
  `CARE10X` int NOT NULL,
  `SAWEYEDR` int NOT NULL,
  `SAWFOOT` int NOT NULL,
  `USUALPL` int NOT NULL,
  `DELAYTRANS` int NOT NULL,
  `HINOTCOVE` int NOT NULL,
  `CARE_ID` int NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`CARE_ID`),
  KEY `NHISPID_idx` (`NHISP_ID`),
  CONSTRAINT `NHISP_ID` FOREIGN KEY (`NHISP_ID`) REFERENCES `demographics` (`NHISPID`)
);

-- fin_hardship table creation
CREATE TABLE `fin_hardship` (
  `NHISPID` bigint NOT NULL,
  `POORYN` int NOT NULL,
  `GOTWELF` int NOT NULL,
  `YBARCARE` int NOT NULL,
  `WORMEDBILL` int NOT NULL,
  `YDELAYMEDYR` int NOT NULL,
  `YSKIPMEDYR` int NOT NULL,
  `HIUNABLEPAY` int NOT NULL,
  `FIND_ID` int NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`FIND_ID`),
  KEY `NHIS_PID_idx` (`NHISPID`),
  CONSTRAINT `NHIS_PID` FOREIGN KEY (`NHISPID`) REFERENCES `demographics` (`NHISPID`)
);

-- conditions table creation
CREATE TABLE `conditions` (
  `NHISPID` bigint NOT NULL,
  `CHEARTDIEV` int NOT NULL,
  `CHOLHIGHEV` int NOT NULL,
  `DIABETICEV` int NOT NULL,
  `HEARTCONEV` int NOT NULL,
  `HYPERTENYR` int NOT NULL,
  `STROKEV` int NOT NULL,
  `cond_id` int NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`cond_id`),
  KEY `NHISPID_idx` (`NHISPID`),
  CONSTRAINT `NHISPID` FOREIGN KEY (`NHISPID`) REFERENCES `demographics` (`NHISPID`)
);


-- analytical questions

-- 1) Average age of people with diabetes who could and could not afford needed care 
CREATE VIEW final.age_diab_afford_care_vw AS 
(
SELECT ROUND(AVG(d.age), 2) as average_age,
CASE 
	WHEN f.ybarcare = 1 THEN 'No'
    WHEN f.ybarcare = 2 THEN 'Yes'
END AS could_not_afford_care
FROM final.demographics AS d
INNER JOIN final.fin_hardship AS f
ON d.nhispid = f.nhispid
WHERE f.ybarcare = 1 or f.ybarcare = 2
GROUP BY f.ybarcare
);
-- those who needed but could not afford care younger (57.94) than those who could afford needed care (64.23)
SELECT * FROM final.age_diab_afford_care_vw;

-- 2) average BMI for each employment type
CREATE VIEW final.bmi_emp_vw AS 
(
SELECT ROUND(AVG(bmicalc), 2) AS average_bmi, classwk21 AS employment_type
FROM final.demographics
GROUP BY classwk21
HAVING classwk21 != "Unknown"
);
-- government employees have highest BMI, working without pay have lowest BMI
SELECT * FROM final.bmi_emp_vw;

-- 3) to assess access to care: % who had a fasting blood glucose test the past 12 months, had a checkup in the past 12 months, 
-- saw an eye doctor the past 12 months by delaytrans, saw a foot doctor the past 12 months 
CREATE VIEW final.access_care_guidelines_vw AS
(
SELECT ROUND(COUNT(DISTINCT(NHISP_ID)) * 100.00 / (SELECT COUNT(DISTINCT(NHISP_ID)) FROM final.access_care), 2) AS percent_meeting_care_guidelines,
CASE 
	WHEN delaytrans = 1 THEN 'No'
    WHEN delaytrans = 2 THEN 'Yes'
END AS delay_care_due_to_trans
FROM final.access_care
WHERE glucchek1yr = 2 AND saweyedr = 2 AND sawfoot = 2
GROUP BY delaytrans
);
-- 15.78% of those who did not delay care because of lack of transportation met guidelines
-- 1.28% of those who DID delay care because of lack of transportation actually met guidelines
SELECT * FROM final.access_care_guidelines_vw;


-- 4) percent of those with and without insurance coverage that have a usual place for medical care
CREATE VIEW final.insurance_place_care_vw AS
(
SELECT ROUND(COUNT(DISTINCT(nhisp_id)) * 100.00 / (SELECT COUNT(DISTINCT(nhisp_id)) FROM final.access_care), 2) AS percent_having_usual_place_for_care,
CASE 
	WHEN hinotcove = 1 THEN 'Has coverage'
    WHEN hinotcove = 2 THEN 'Does not have coverage'
    WHEN hinotcove = 9 THEN 'Unknown'
END AS insurance_coverage
FROM final.access_care 
WHERE usualpl = 2 -- among those who do have a usual source of medical care
GROUP BY hinotcove
);
-- 91.18% percent of those who have insurance coverage have a usual place for medidcal care 
-- 3.44% of those who do not have insurance coverage have a usual place for medical care
-- 0.15% of those with unknown insurance coverage have a usual place for medical care 
SELECT * FROM final.insurance_place_care_vw;


-- 5) average bmi of those with diabetes by level of worry about paying medical bills and comorbidity score
CREATE VIEW final.bmi_comorb_bills_vw AS
(
SELECT ROUND(AVG(d.bmicalc), 2) AS average_bmi,
CASE
	WHEN hypertenyr = 2 AND heartconev = 2 THEN 2
    WHEN heartconev = 2 OR hypertenyr = 2 THEN 1
    WHEN heartconev != 2 OR hypertenyr != 2 THEN 0
END AS comorb_score,
-- hypertenyr = hypertension, hearconev = heart condition
-- 0 if have neither comorbidity, 1 if has one comorbidity, 2 if both comorbidities
CASE 
	WHEN wormedbill = 1 THEN 'Very worried'
    WHEN wormedbill = 2 THEN 'Somewhat worried'
    WHEN wormedbill = 3 then 'Not worried at all'
    WHEN wormedbill IN (7,8,9) THEN 'Unknown'
END AS worried_about_paying_med_bills
FROM final.conditions as c
INNER JOIN final.demographics as d
ON c.nhispid = d.nhispid
INNER JOIN final.fin_hardship as f
ON d.nhispid = f.nhispid
GROUP BY comorb_score, worried_about_paying_med_bills
HAVING worried_about_paying_med_bills != 'Unknown'
ORDER BY comorb_score 
);
-- highest comorbidity score = highest BMI and highest level of worry about paying medical bills and vice versa
SELECT * FROM final.bmi_comorb_bills_vw;



-- question 4 
-- just want to see what percent of people have a usual place of care (usualpl = 2)
SELECT ROUND(COUNT(DISTINCT(nhisp_id)) * 100.00 / (SELECT COUNT(DISTINCT(nhisp_id)) FROM final.access_care), 2) AS percent_having_usual_place_of_care
FROM final.access_care 
WHERE usualpl = 2;
-- 94.78% of people in this dataset have a usual place of care