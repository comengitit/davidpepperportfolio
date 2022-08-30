--this view is the INITIAL SITE selection that is used by dbo.vewActiveSNextCRByYYYYMM_I_Count 
--order by clause only needs to be used for testing
--added as part of CRRI Database Project 212: Bucket CRs Phase 2 - Split Sites -DP 5/20/2008

CREATE VIEW dbo.vewActiveSNextCRByYYYYMM_I
AS

select 
	CRRI=p.strcrriprotid,
	s.tblsitepk,
	PI = c.strfirstname + ' ' + c.strlastname,
	--pStatus = p.intstatus,
	--sStatus = s.intstatus
	sNextCR = 
		(
		select 
			case len(month(sr.dtmduedate))
				when 1 then
					convert(varchar(4),year(sr.dtmduedate))+'0'+convert(varchar(2),month(sr.dtmduedate))
				else 
					convert(varchar(4),year(sr.dtmduedate))+convert(varchar(2),month(sr.dtmduedate))
			end
		),
	c.strlastname,
	c.strfirstname,
	CRRIYear=
		(
		case
			when ISNUMERIC(substring(strcrriprotid,3,2)) = 1 then --1
				(
				case
					when convert(int,substring(strcrriprotid,3,2)) > 59 then convert(int,'19' + substring(strcrriprotid,3,2))
					else convert(int,'20' + substring(strcrriprotid,3,2))
				end 
				)
			else -1
		end
		),
	CRRIMonth=
		(
		case
			when ISNUMERIC(substring(strcrriprotid,1,2)) = 1 then --1
				substring(strcrriprotid,1,2)
			else -1
		end
		)
from 
	tblprotocol p
		left join tblsite s
			on s.tblprotocolfk = p.tblprotocolpk
			left join tblsitereview sr 
				on sr.tblsitefk = s.tblsitepk
				left join tblcontact c
					on c.tblcontactpk = dbo.udfgetinvkey(s.tblsitepk)
where 0=0
	and p.intstatus = 2
	and s.intstatus = 2
	and sr.intactiontaken = 0
	and sr.tblsitefk = s.tblsitepk
	and sr.intdatetype = 3 --initial
	and sr.dtmreviewdate is null --aka event date
/*
order by
	sNextCR,
	--crri sometimes has non numeric values, but is a packed field
	(
	case
		when ISNUMERIC(substring(strcrriprotid,3,2)) = 1 then --1
			(
			case
				when convert(int,substring(strcrriprotid,3,2)) > 59 then convert(int,'19' + substring(strcrriprotid,3,2))
				else convert(int,'20' + substring(strcrriprotid,3,2))
			end 
			)
		else -1
	end
	),
	c.strlastname,
	c.strfirstname,
	s.tblsitepk
*/