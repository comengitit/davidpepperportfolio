--vwProspectScore.sql
CREATE VIEW dbo.vwProspectScore
AS
SELECT tblInquiry.InquiryID,
	tblContactInterest.ContactID,
	DivisionCode,
	AreaCode,
	DateOfContact,

	-----------------------------------------------------------
	DateScore =
		Case
			WHEN  DateofContact > GetDate() - 8 THEN 40						--within past 1 week
			WHEN  DateofContact > GetDate() - 15 AND  DateofContact <= GetDate() - 8 THEN 25	--within past 2 weeks
			WHEN  DateofContact > GetDate() - 31 AND  DateofContact <= GetDate() - 15 THEN 15	--within past 1 month
			WHEN  DateofContact > GetDate() - 61 AND  DateofContact <= GetDate() - 31 THEN 10	--within past 2 months
			WHEN  DateofContact > GetDate() - 91 AND  DateofContact <= GetDate() - 61 THEN 5	--within past 3 months
			ELSE 0
		End,

	-----------------------------------------------------------
	RSVPScore =
		CASE
			WHEN RSVP <> 0 THEN 30
			ELSE 0
		END,
		
	-----------------------------------------------------------
	RequestScoreCS = 
		CASE 
			WHEN Request = 'Catalog' THEN 40
			WHEN Request = 'Schedule' THEN 40
			ELSE 0
		END,

	-----------------------------------------------------------
	RequestScoreAdv = 
		CASE 
			WHEN Request = 'Business Advisor Call' THEN 15
			WHEN Request = 'Education Advisor Call' THEN 15
			WHEN Request = 'Undergrad Advisor Call' THEN 15
			ELSE 0
		END,
		
	-----------------------------------------------------------
	CatOrSchedReq =
		CASE
			WHEN Request = 'Catalog' THEN 1
			WHEN Request = 'Schedule' THEN 1
			ELSE 0
		END,
		
	-----------------------------------------------------------
	AdvisorReqDivisionCode =
		CASE
			WHEN Request = 'Business Advisor Call' THEN 1
			WHEN Request = 'Education Advisor Call' THEN 3
			WHEN Request = 'Undergrad Advisor Call' THEN 7
			ELSE 0
		END
	
FROM tblInquiry LEFT JOIN tblContactInterest 
	ON tblInquiry.InquiryID = tblContactInterest.InquiryID
	
WHERE tblInquiry.InqOrAcq = 'I'			--Source is not acquisition
	AND Initiator = 'INQ'			--Inquiry initiated contact
	AND tblInquiry.DoNotMail = 0 		--Do not mail is not flagged
	AND tblInquiry.DoNotShare = 0 		--Do not share is not flagged
	AND tblInquiry.Applied = 0		--Inquirer has not applied
	AND DateOfContact > getdate() - 91	--3 month window on scored contacts







