if OBJECT_ID(N'Proc_QueryUPOPMerchantTransReport', N'P') is not null
begin
	drop procedure Proc_QueryUPOPMerchantTransReport;
end
go

create procedure Proc_QueryUPOPMerchantTransReport
	@StartDate datetime = '2011-01-01',
	@PeriodUnit nchar(4) = N'周',
	@EndDate datetime = '2011-09-30'
as
begin

--1. Check input
if (@StartDate is null or ISNULL(@PeriodUnit, N'') = N'' or (@PeriodUnit = N'自定义' and @EndDate is null))
begin
	raiserror(N'Input params cannot be empty in Proc_QueryUPOPMerchantTransReport', 16, 1);
end

--2. Prepare StartDate and EndDate
declare @CurrStartDate datetime;
declare @CurrEndDate datetime;

if(@PeriodUnit = N'周')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(week, 1, @StartDate);
end
else if(@PeriodUnit = N'月')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(MONTH, 1, @StartDate);
end
else if(@PeriodUnit = N'季度')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 1, @StartDate);
end
else if(@PeriodUnit = N'半年')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(QUARTER, 2, @StartDate);
end
else if(@PeriodUnit = N'年')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DATEADD(YEAR, 1, @StartDate);
end
else if(@PeriodUnit = N'自定义')
begin
    set @CurrStartDate = @StartDate;
    set @CurrEndDate = DateAdd(day,1,@EndDate);
end

--3. Get UPOP GateNo
select 
	GateNo 
into
	#GateNo
from 
	dbo.DimGate 
where 
	DimGate.GateNo in ('8604','8607');
	
--4. Get Payment Data
With PeriodTrans as
(
	select
		GateNo,
		MerchantNo,
		SucceedTransAmount
	from
		FactDailyTrans
	where
		DailyTransDate >= @CurrStartDate
		and
		DailyTransDate < @CurrEndDate
)
select
	Upop.MerchantName,
	Upop.MerchantNo,
	convert(decimal, SUM(isnull(Trans.SucceedTransAmount,0)))/100 as SumAmount,
	Convert(decimal, SUM(case when
			GateNo.GateNo is not null 
		then 
			Trans.SucceedTransAmount 
		else 
			0 
		end))/100 as UPOPAmount
from
	dbo.Table_UPOPMerchants Upop
	left join
	PeriodTrans Trans
	on
		Upop.MerchantNo = Trans.MerchantNo
	left join
	#GateNo GateNo
	on
		Trans.GateNo = GateNo.GateNo
group by
	Upop.MerchantName,
	Upop.MerchantNo
order by
	Upop.MerchantName,
	Upop.MerchantNo;
	
--5. Clean temp tables
drop table #GateNo;

end 