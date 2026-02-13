-- Connect to database



-- PART I: SCHOOL ANALYSIS
-- TASK 1: View the schools and school details tables
SELECT * FROM schools;
SELECT * FROM school_details;

-- TASK 2: In each decade, how many schools were there that produced players? [Numeric Functions]
SELECT floor(yearID/10)*10 as decade, count(distinct schoolID) as num_schools from dbo.schools
group by  floor(yearID/10)
order by decade;

-- TASK 3: What are the names of the top 5 schools that produced the most players? [Joins]
SELECT TOP 5 sd.name_full,count(distinct s.playerID) as num_players 
from dbo.schools as s
LEFT JOIN dbo.school_details as sd 
on s.schoolID = sd.schoolID
group by sd.name_full
order by num_players desc;

-- TASK 4: For each decade, what were the names of the top 3 schools that produced the most players? [Window Functions]

WITH CTE AS (
SELECT floor(yearID/10)*10 as decade , sd.name_full, count(distinct s.playerID) as num_players
from dbo.schools as s
LEFT JOIN dbo.school_details as sd 
on s.schoolID = sd.schoolID
group by floor(yearID/10)*10, sd.name_full)


SELECT decade,name_full,num_players from (
SELECT *
,row_number() over(partition by decade order by num_players desc) as row_num FROM CTE) as t
where row_num <=3
order by decade desc;


-- PART II: SALARY ANALYSIS

-- TASK 1: View the salaries table
SELECT * FROM salaries;

-- TASK 2: Return the top 20% of teams in terms of average annual spending [Window Functions]
WITH CTE AS (
SELECT teamID,yearID,SUM(salary) as totalspend from dbo.salaries
group by teamID,yearID
),

   SP AS (SELECT teamID,avg(totalspend) as avg_spend,
NTILE(5) OVER(order by avg(totalspend) desc) as spend_per FROM CTE
group by teamID)

select teamID,avg_spend/1000000 as avg_spend_mil from SP
where spend_per = 1;


-- TASK 3: For each team, show the cumulative sum of spending over the years [Rolling Calculations]

WITH CTE AS (
SELECT teamID,yearID,SUM(salary) as total_spend from dbo.salaries
group by teamID,yearID
)
select teamID,yearID, 
ROUND(SUM(total_spend) OVER(partition by teamID order by yearID)/1000000,1) as cum_sum_millions from CTE
order by teamID,yearID;


-- TASK 4: Return the first year that each team's cumulative spending surpassed 1 billion [Min / Max Value Filtering]

WITH CTE AS (
SELECT teamID,yearID,SUM(salary) as total_spend from dbo.salaries
group by teamID,yearID
),

CS AS (select teamID,yearID, 
SUM(total_spend) OVER(partition by teamID order by yearID)as cum_sum_millions from CTE)

SELECT teamID,yearID,ROUND(cum_sum_millions/1000000000,2) as cum_sum_billions from 
(SELECT *,
ROW_NUMBER() OVER(partition by teamID order by yearID) as row_num from CS
where cum_sum_millions > 1000000000) as cst
where row_num = 1;


-- PART III: PLAYER CAREER ANALYSIS

-- TASK 1: View the players table and find the number of players in the table
SELECT * FROM players;
SELECT COUNT(*) FROM players;

-- TASK 2: For each player, calculate their age at their first (debut) game, their last game,
-- and their career length (all in years). Sort from longest career to shortest career. [Datetime Functions]
SELECT nameGiven,TRY_CAST(CONCAT(birthyear,'-',birthMonth,'-',birthDay) as DATE) as birthdate 
, debut,finalGame,DATEDIFF(year,TRY_CAST(CONCAT(birthyear,'-',birthMonth,'-',birthDay) as DATE),debut) as start_age
, DATEDIFF(year,TRY_CAST(CONCAT(birthyear,'-',birthMonth,'-',birthDay) as DATE),finalGame) as ending_age
,DATEDIFF(year,debut,finalGame) as career_length from dbo.players
order by career_length desc;


-- TASK 3: What team did each player play on for their starting and ending years? [Joins]

SELECT nameGiven
,s.yearID as starting_yr,s.teamID as starting_team,e.yearID as ending_yr,e.teamID as ending_team 
from dbo.players as p
INNER JOIN dbo.salaries as s on  p.playerID = s.playerID and YEAR(p.debut) = s.yearID
INNER JOIN dbo.salaries as e on  p.playerID = e.playerID and YEAR(p.FinalGame) = e.yearID;


-- TASK 4: How many players started and ended on the same team and also played for over a decade? [Basics]
SELECT nameGiven
,s.yearID as starting_yr,s.teamID as starting_team,e.yearID as ending_yr,e.teamID as ending_team 
from dbo.players as p
INNER JOIN dbo.salaries as s on  p.playerID = s.playerID and YEAR(p.debut) = s.yearID
INNER JOIN dbo.salaries as e on  p.playerID = e.playerID and YEAR(p.FinalGame) = e.yearID
where s.teamID = e.teamID and (e.yearID - s.yearID) > 10 ;



-- PART IV: PLAYER COMPARISON ANALYSIS

-- TASK 1: View the players table
SELECT * FROM players;

-- TASK 2: Which players have the same birthday? Hint: Look into GROUP_CONCAT / LISTAGG / STRING_AGG [String Functions]
WITH CTE AS (
SELECT TRY_CAST(CONCAT(birthYear,'-',birthMonth,'-',birthDay) as date) as birthdate,nameGiven
FROM players)

SELECT birthdate,STRING_AGG(nameGiven,', ') as _list FROM CTE
where year(birthdate) BETWEEN 1980 AND 1990
group by birthdate
order by birthdate;


-- TASK 3: Create a summary table that shows for each team, what percent of players bat right, left and both [Pivoting]
SELECT s.teamID ,
CAST(SUM(CASE WHEN p.bats = 'R' THEN 1 ELSE 0 end) *100  / COUNT(s.playerID) as decimal(5,2)) as bats_right,
CAST(SUM(CASE WHEN p.bats = 'L' THEN 1 ELSE 0 end) *100/COUNT(s.playerID)as decimal(5,2)) as bats_left,
CAST(SUM(CASE WHEN p.bats = 'B' THEN 1 ELSE 0 end) *100/COUNT(s.playerID)as decimal(5,2)) as bats_both from salaries as s
LEFT JOIN players as p on s.playerID = p.playerID
GROUP BY s.teamID;

-- TASK 4: How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference? [Window Functions]
WITH CTE AS (
SELECT floor(year(debut)/10)*10 as decade,avg(height) avg_h,avg(weight) as avg_w from players
group by floor(year(debut)/10)*10)

SELECT decade
, CAST(avg_h - LAG(avg_h) OVER(order by decade) as decimal(5,2)) as h_diff
, CAST(avg_w - LAG(avg_w) OVER(order by decade) as decimal(5,2)) as w_diff FROM CTE
where decade is not null
order by decade; 

