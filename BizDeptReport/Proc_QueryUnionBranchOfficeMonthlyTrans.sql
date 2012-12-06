--[Modified] at 2012-07-13 by 王红燕  Description:Add Financial Dept Configuration Data
if OBJECT_ID(N'Proc_QueryUnionBranchOfficeMonthlyTrans',N'P') is not null
begin
	drop procedure Proc_QueryUnionBranchOfficeMonthlyTrans;
end
go

Create Procedure Proc_QueryUnionBranchOfficeMonthlyTrans
	@StartDate datetime = '2011-03-14',
	@PeriodUnit nChar(3) = N'月',
	@BranchOfficeName nChar(16) = N'中国银联股份有限公司内蒙古分公司'
as 
begin

--1. Check Input
if (@StartDate is null or ISNULL(@PeriodUnit,N'') = N'' or ISNULL(@BranchOfficeName,N'') = N'')
begin
	raiserror(N'Input params cannot be empty in Proc_QueryUnionBranchOfficeMonthlyTrans',16,1);
end


--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;
declare @ThisYearStartDate datetime;
declare @ThisYearEndDate datetime;

if(@PeriodUnit = N'月')
begin
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(MONTH,1,@CurrStartDate);
end
else if(@PeriodUnit = N'季度')
begin
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,1,@CurrStartDate);
end
else if(@PeriodUnit = N'半年')
begin
	set @CurrStartDate = left(CONVERT(char,@StartDate,120),7) + '-01';
	set @CurrEndDate = DATEADD(QUARTER,2,@CurrStartDate);
end

set @ThisYearStartDate = CONVERT(char(4),YEAR(@CurrStartDate)) + '-01-01';
set @ThisYearEndDate = @CurrEndDate;


--3. Get ThisYear Data
select
	MerchantNo,
	TransAmount,
	CPDate as TransDate 
into
	#OraTransSum
from
	Table_OraTransSum
where
	CPDate >= @ThisYearStartDate
	and
	CPDate < @ThisYearEndDate;
	
select 
	MerchantNo,
	SucceedTransAmount as TransAmount,
	DailyTransDate as TransDate
into
	#FactDailyTrans
from
	FactDailyTrans
where
	DailyTransDate >= @ThisYearStartDate
	and
	DailyTransDate < @ThisYearEndDate;
	
select 
	EmallTransSum.MerchantNo,
	EmallTransSum.SucceedTransAmount as TransAmount,
	EmallTransSum.TransDate
into 
	#EmallTransSum
from	
	Table_EmallTransSum EmallTransSum
	inner join
	Table_BranchOfficeNameRule BranchOfficeNameRule
	on
		EmallTransSum.BranchOffice = BranchOfficeNameRule.UnnormalBranchOfficeName
where 
	EmallTransSum.TransDate >= @ThisYearStartDate
	and
	EmallTransSum.TransDate < @ThisYearEndDate
	and
	BranchOfficeNameRule.UnionPaySpec = @BranchOfficeName;
	
	
--4. Union all data
select
	MerchantNo,
	TransAmount,
	TransDate
into 
	#AllMerTrans	
from
	#OraTransSum	
union all
select 
	MerchantNo,
	TransAmount,
	TransDate
from
	#FactDailyTrans;	


--5. Get AllMerTransWithBo
With MerBranchOffice as
(
	select
		SalesDeptConfig.MerchantNo
	from
		Table_SalesDeptConfiguration SalesDeptConfig
	where
		SalesDeptConfig.BranchOffice = @BranchOfficeName
	union
	select
		Finance.MerchantNo
	from
		Table_FinancialDeptConfiguration Finance
	where
		Finance.BranchOffice = @BranchOfficeName
)
select
	AllMerTrans.MerchantNo,
	AllMerTrans.TransAmount,
	AllMerTrans.TransDate
into
	#AllMerTransWithBo
from
	#AllMerTrans AllMerTrans
	inner join
	MerBranchOffice
	on
		AllMerTrans.MerchantNo = MerBranchOffice.MerchantNo
union all
select
	MerchantNo,
	TransAmount,
	TransDate
from
	#EmallTransSum;


--6.1 Create temp time period tableCREATE TABLE #TimePeriod(	PeriodStart datetime NOT NULL PRIMARY KEY, 	PeriodEnd datetime NOT NULL); --6.2 Fill #TimePeriodDECLARE @PeriodStart datetime; DECLARE @PeriodEnd datetime;SET @PeriodStart = @ThisYearStartDate;SET @PeriodEnd = 	CASE @PeriodUnit       WHEN N'月' THEN DATEADD(month, 1, @PeriodStart)       WHEN N'季度' THEN DATEADD(QUARTER, 1, @PeriodStart)       WHEN N'半年' THEN DATEADD(QUARTER, 2, @PeriodStart)       ELSE DATEADD(day,1,@ThisYearEndDate)     END;       WHILE (@PeriodEnd <= @ThisYearEndDate) BEGIN		INSERT INTO #TimePeriod	(		PeriodStart, 		PeriodEnd	)	VALUES 	(		@PeriodStart,		@PeriodEnd	);	SET @PeriodStart = @PeriodEnd;	SET @PeriodEnd = 		CASE @PeriodUnit 		  WHEN N'月' THEN DATEADD(month, 1, @PeriodStart) 		  WHEN N'季度' THEN DATEADD(QUARTER, 1, @PeriodStart) 		  WHEN N'半年' THEN DATEADD(QUARTER, 2, @PeriodStart) 		  ELSE DATEADD(day,1,@ThisYearEndDate) 		END;END--7. Get Resultselect	Left(CONVERT(char,TimePeriod.PeriodStart,120),7) as PeriodStart,	CONVERT(decimal,SUM(ISNULL(AllMerTransWithBo.TransAmount,0)))/1000000 as SumTransAmountfrom	#TimePeriod TimePeriod	left join	#AllMerTransWithBo AllMerTransWithBo	on		AllMerTransWithBo.TransDate >= TimePeriod.PeriodStart		and		AllMerTransWithBo.TransDate < TimePeriod.PeriodEndgroup by	TimePeriod.PeriodStartorder by	TimePeriod.PeriodStart;		--8. drop temp tabledrop table #OraTransSum;drop table #FactDailyTrans;drop table #EmallTransSum;drop table #AllMerTrans;drop table #AllMerTransWithBo;drop table #TimePeriod;end