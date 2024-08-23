---------------------------------------------------------------------------------------------------------------
------------------------------------------ Step 1 : Database Creation -----------------------------------------
---------------------------------------------------------------------------------------------------------------
create database PlacementProject
use PlacementProject

select * from MachineData


---------------------------------------------------------------------------------------------------------------
-------------------------------------------- Step 2 : Data Cleaning -------------------------------------------
---------------------------------------------------------------------------------------------------------------
-- 1. Check data type of each column
select COLUMN_NAME, DATA_TYPE
from INFORMATION_SCHEMA.COLUMNS
where TABLE_NAME = 'MachineData'

-- 2. Rename the column request_fixed_date to request_fixed_time

-- 3. Check the null values present in the table
declare @tableName nvarchar(20) = 'MachineData';
declare @sql nvarchar(max) = '';

select @sql = @sql + 
	'select ''' + column_name + ''' as column_name, ' +
		'COUNT(*) as null_counts, ' + 
		'ROUND(CAST(COUNT(*) AS FLOAT) / (SELECT COUNT(*) FROM ' + QUOTENAME(@tableName) + ') * 100, 2) AS null_perc ' +
		'from ' + quotename(@tableName) + 
		' where ' + quotename(COLUMN_NAME) + ' is null union all ' 
	from INFORMATION_SCHEMA.COLUMNS
	where TABLE_NAME = @tableName;

set @sql = left(@sql, LEN(@sql) - 10);

exec sp_executesql @sql;

-- 4. As we required below columns for analysis 
	  -- machine_number, age_of_machine, breakdown_id, request_created_time, request_fixed_time, machine_status,	
	  -- quotation_amount, amount_in_breakdown_request, machine_id, maintenance_status
	-- so we remove null values from these columns
delete from MachineData
where breakdown_id is null or request_fixed_time is null or quotation_amount is null or 
      amount_in_breakdown_request is null;

-- 5. Validate machine status column
select distinct machine_status
from MachineData
	
	-- It has 4 values - (IN_MAINTENANCE, NULL, OPERATIONS, #REF!)
	-- This #REF! is something inconsistent so, we check how many are they
		select *
		from MachineData
		where machine_status = '#REF!'
		
		-- only one row is there so i will delete it
			delete from MachineData
			where machine_status = '#REF!'

	-- As we saw earlier that machine_status column contains 36k null values i.e 20 %
	-- So, we either we delete it or we make it as unknown status
		update MachineData
		set machine_status = 'UNKNOWN'
		where machine_status is null
	
	
-- 6. Validate maintenance status column
select distinct maintenance_status
from MachineData
	
	-- It displays 8 values - (PENDING, PENDING, ON_THE_WAY, ACCEPTED, INCOMPLETE, REJECTED, COMPLETED, DONE, REJECED).
	-- Here the spelling of the value REJECED is wrong so we replace the name REJECED to REJECTED.
		update MachineData
		set maintenance_status = (
			case when maintenance_status = 'REJECED' then 'REJECTED' end
			)
		where maintenance_status = 'REJECED'


---------------------------------------------------------------------------------------------------------------
----------------------------------------- Step 3 : Feature Engineering ----------------------------------------
---------------------------------------------------------------------------------------------------------------
-- 1. Add column total_downtime
alter table machinedata
add total_downtime int;

/*alter table machineData
drop column total_downtime
*/
update MachineData
set total_downtime =  (
	case
		when request_created_time <= request_fixed_time
			then
				DATEDIFF(MINUTE,
					DATEADD(MINUTE, CAST(LEFT(request_created_time,CHARINDEX(':', request_created_time)-1) as float),0) +
						DATEADD(SECOND, CAST(RIGHT(request_created_time, CHARINDEX(':',request_created_time)+1) as float), 0),
					DATEADD(MINUTE, CAST(LEFT(request_fixed_time,CHARINDEX(':', request_fixed_time)-1) as float),0) +
						DATEADD(SECOND, CAST(RIGHT(request_fixed_time, CHARINDEX(':',request_fixed_time)+1) as float), 0)
				)
		else 0
	end 
)


---------------------------------------------------------------------------------------------------------------
-------------------------------------------- Step 4 : Data Analysis -------------------------------------------
---------------------------------------------------------------------------------------------------------------	
-- 1. Analyze the Machines by their age and calculates the average number of breakdowns for each age group 
	  -- to see if older machines tend to break down more often.
select age_of_machine, AVG(res.total_breakdown_machines) avg_breakdown_machines
from (
	select age_of_machine, COUNT(distinct breakdown_id) total_breakdown_machines
	from MachineData
	group by age_of_machine
) res
group by age_of_machine
order by age_of_machine;

	-- After the analysis, the machines those are over 2 years of age lead to have more breakdowns.
	-- Suggestion 
		-- 1. We can more focus on the machines who are 2+ years old and we do preventive maintenance more frequently.
		-- 2. We will do continuous monitoring of that particular machines to catch the issues before it lead to breakdown.
		-- 3. We can also go for machine replacement if we often required maintenance. 
			  -- So, this will increases the maintenance cost so its better to replace it.


-- 2. Identify the top 5 breakdown-prone machines and their associated downtime.

with mch_downtime as (
	select machine_number, 
		SUM(total_downtime) total_downtime, 
		AVG(total_downtime) avg_downtime,
		COUNT(distinct breakdown_id) breakdown_count		 
	from MachineData
	group by machine_number
),
machine_breakdown_rank as (
	select *, DENSE_RANK() over(order by breakdown_count desc) rnk
	from mch_downtime
) 
select machine_number, breakdown_count, total_downtime, avg_downtime,
	CONCAT(
		total_downtime / 1440 , ' days ',
		FORMAT((total_downtime % 1440) / 60, '00'), ' hours ', 
		FORMAT((total_downtime % 60), '00'), ' minutes ', 
		'00', ' seconds'
	) machine_downtime
from machine_breakdown_rank
where rnk <= 5
order by breakdown_count desc

	-- Here, the machine UPL_275 has highest breakdown_count 137 but it has a lower downtime as compare to machine UPL_491
		-- and UPL_1755.
	-- Suggestions -
		-- 1. For machine UPL_491 & UPL_1755, We need to identify the factors which impacts on thier downtime. 
			  -- Which helps us to target the specific issue and with the help of this we can improve our maintenance practice.


-- 3. find the pattern of the cost impact of breakdowns by machine state.
select machine_status, COUNT(distinct breakdown_id) total_breakdown_machines,
	CONCAT(ROUND(SUM(quotation_amount ) / 1000000, 2), ' Millions') total_quotation_amt, 
	CONCAT(ROUND(SUM(amount_in_breakdown_request) / 1000000, 2), ' Millions') total_amt_req_in_breakdown_period
from MachineData
group by machine_status
order by total_breakdown_machines desc

	-- The machines those status is operations have highest breakdown count and the total cost required is also highest.
	-- Suggestions -
		-- We need to prioritize maintenance for machines in the operations state which helps to reduce breakdown and cost as well.

-- 4. Identify the impact of machine location on breakdown frequency.
select state, COUNT(distinct breakdown_id) total_breakdown_machines,
	case 
		when COUNT( breakdown_id) < 10000 then 'Low Impact'
		when COUNT( breakdown_id) between 10000 and 20000 then 'Medium Impact'
		when COUNT( breakdown_id) > 20000 then 'High Impact'
	end impacts
from MachineData
group by state
order by total_breakdown_machines desc;

	-- Haryana, Punjab, Rajasthan have the highest number of breakdowns 
	-- Gujarat, Madhya pradesh, Maharashtra, Andhra pradesh have the medium number of breakdowns
	-- Telangana, Karnataka, Andaman and Nicobar Islands, Jammu and Kashmir, Assam, Uttar Pradesh have the lowest number of breakdowns
	-- Suggestions - 
		-- 1. High impact states should be prioritized for detailed analysis to understand the issue. 
			  -- We need to analyse different factors like machine usage, maintenance quality then different environmental factors.
		-- 2. Medium impact states needs attention to reduce the number of breakdowns. Frequent maintenance and monitoring is required.
		-- 3. For low impact states regular monitoring is required to ensure that the situation remain stable.


-- 5. compares the breakdown frequency of machines that underwent preventive maintenance against those that didn't, 
	-- to assess the impact of maintenance on machine reliability.
with maintenance_category as (
	select machine_number, breakdown_id, 
		   case 
				when maintenance_status in ('COMPLETED','DONE') then 'Maintenance Completed'
				when maintenance_status in ('ON_THE_WAY', 'ACCEPTED') then 'Maintenance Ongoing'
				else 'No Maintenance'
		   end maintenance_status_group
	from MachineData
	
),
machine_summary as(
	select maintenance_status_group, COUNT(distinct machine_number) machine_count, COUNT(distinct breakdown_id) total_breakdown
	from maintenance_category
	group by maintenance_status_group
)
select *
from machine_summary
order by total_breakdown desc;

	-- Total breakdown count is more for the machines whose maintenance status is completed.
	-- For Maintenance ongoing  and No Maintenance status both has less number of breakdowns 
		-- as compared to Maintenance Completed.
	-- Suggestions - 
		-- 1. As we can see the highest breakdowns are for maintenance complete status. 
			  -- We need to find the factors which affects the highest breakdowns such as - age of machine, maintenance frequency.
		-- 2. No maintenance category are those machines which are less critical or it doesn't required frequent maintenance.
			  -- But we need to identify the risk which may cause more breakdowns in future due to the lack of preventive maintenance.
		-- 3. So, the machines under Maintenance Ongoing states that the ongoing maintenance helps them from breakdowns.
