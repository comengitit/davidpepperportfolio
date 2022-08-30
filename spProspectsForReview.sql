CREATE PROCEDURE dbo.spProspectsForReview 

AS

/* Declare local variables */
DECLARE
	@InquiryID		Integer,
	@InquiryID_Old		Integer,
	@ContactID		Integer,
	@DivisionCode		Integer,
	@DivisionCodeOK		Integer,	--flag for if at least 1 contact interest record is within the user's zone
	@DivisionCodeConcat	varchar(140),	--concatenated division codes
	@AreaCode		varchar(4),
	@AreaCodeConcat		varchar(140),	--concatenated area codes 
	@DateOfContact		Datetime,
	@DateOfContactMax	Datetime,	--most recent contact date made by a student to spsbe
	@DateScore		Integer,
	@DateScoreST		Integer,	--subtotal of date component of propsect score
	@RSVPScore		Integer,
	@RSVPScoreST		Integer,	--subtotal of rsvp component of prospect score
	@RequestScoreCS		Integer,	--catalog/schedule request score component
	@RequestScoreAdv	Integer,	--advisor request score component
	@RequestScoreST		Integer,	--subtotal of special request component of prospect score
	@AdvisorReqDivisionCode	Integer,	--division code of advisor request
	@AdvisorReqUsersDiv	Integer,	--advisor request was made w/in same div(s) as user
	@EventAttend		Integer,	--an event was attended in last 30 days
	@CatOrSchedReq		Integer,	--a catalog and/or schedule was requested
	@CountContact		Integer,	--count of tblcontactInterest records for this inquiry
	@CountAR		Integer,	--count of related advisor review records for this inquiry
	@HotCT			Integer,	--count of hot ratings from tblAdvisorReview
	@WarmCT			Integer,	--count of warm ratings from tblAdvisorReview
	@ColdCT			Integer,	--count of cold ratings from tblAdvisorReview
	@ARRatingConcat		varchar(30),	--concatenated ratings from tblAdvisorReview
	@TotalScore		Integer


/* Create #ProspectRating temp table to store aggregate prospect data */
CREATE TABLE #ProspectRating 
	(
	InquiryID Integer,
	DivisionCodeOK Integer,
	DivisionCodeConcat varchar(140),
	AreaCodeConcat varchar(140),
	DateOfContactMax Datetime,
	DateScoreST Integer,
	RSVPScoreST Integer,
	RequestScoreST Integer,
	AdvisorReqUsersDiv Integer,
	EventAttend Integer,
	CatOrSchedReq Integer,
	CountContact Integer,
	CountAR Integer,
	ARRatingConcat varchar(30),
	TotalScore Integer
	)


/* Select from vwProspectScore and cursor through recs */
DECLARE curInsertProspectRating CURSOR FOR 

SELECT InquiryID, 
	ContactID, 
	DivisionCode, 
	AreaCode, 
	DateOfContact, 
	DateScore, 
	RSVPScore, 
	RequestScoreCS, 
	RequestScoreAdv, 
	CatOrSchedReq, 
	AdvisorReqDivisionCode
FROM vwProspectScore
ORDER BY InquiryID--, DateOfContact


-- Open the cursor --
OPEN curInsertProspectRating 

	-- Start fetching from the cursor --
	FETCH NEXT FROM curInsertProspectRating
	INTO @InquiryID,
		@ContactID,
		@DivisionCode,
		@AreaCode,
		@DateOfContact,
		@DateScore,
		@RSVPScore,
		@RequestScoreCS,
		@RequestScoreAdv,
		@CatOrSchedReq,
		@AdvisorReqDivisionCode


	SET @InquiryID_Old = @InquiryID

	/* set all variables to some baseline values that would be ok if they are not updated to something else before they are used in an expression */
	SET @DivisionCodeOK = 0
	SET @DivisionCodeConcat = ''
	SET @AreaCodeConcat = ''
	SET @DateOfContactMax = '1900-01-01 01:01:01.000'
	SET @DateScoreST = 0
	SET @RSVPScoreST = 0
	SET @RequestScoreST = 0
	SET @AdvisorReqUsersDiv = 0
	SET @EventAttend = 0
	SET @CatOrSchedReq = 0
	SET @CountContact = 0
	SET @CountAR = 0
	SET @HotCT = 0
	SET @WarmCT = 0
	SET @ColdCT = 0
	SET @ARRatingConcat = ''
	SET @TotalScore = 0
	
	-- Begin the loop --
	WHILE @@FETCH_STATUS = 0
	BEGIN 
		/* Aggregate values to temp table which is only storing 1 record per InquiryID */
		IF @InquiryID = @InquiryID_Old
			BEGIN 
				
				SET @InquiryID_Old = @InquiryID
				
				/* flag inquiries that are viewable by the suser_sname (ie >=1 tblContactInterest record has matching div) */
				IF @DivisionCode IN 
						(
							SELECT p.DivisionCode
							FROM tblUserProfileDivision d
								INNER JOIN tblDivisionProfile p
									ON p.DivID = d.DivID
							WHERE d.LoginName = User_Name()
						)
					BEGIN
						SET @DivisionCodeOK = 1		
					END
				
				/* also concatenate a list of divisions that have been inquired into */
				IF @DivisionCode IS NOT NULL
					BEGIN
						SET @DivisionCodeConcat = 
							(
							SELECT DivisionText =
								CASE 
									WHEN DivisionText = 'Business' THEN 'BUS'
									WHEN DivisionText = 'Liberal Arts' THEN 'Lib'
									WHEN DivisionText = 'Education' THEN 'EDU'
									WHEN DivisionText = 'Graduate' THEN 'GRAD'
									WHEN DivisionText = 'Evergreen - Homewood' THEN 'EvH'
									WHEN DivisionText = 'Evergreen - Montgomery County' THEN 'EvM'
									WHEN DivisionText = 'Undergraduate' THEN 'UG'
									WHEN DivisionText = 'General (Non-Credit)' THEN 'GEN'
									WHEN DivisionText = 'Public Safety Leadership' THEN 'PSL'
									ELSE DivisionText
								END
							FROM trnDivision 
							WHERE DivisionCode = @DivisionCode
							) + ' (' + Convert(varchar(8),@DateOfContact,1) + ')' + char(13) + char(10) + @DivisionCodeConcat
					END

				/* Add to the Subtotal scores, the total score, and update InquiryID_Old */
				IF @AreaCode IS NOT NULL
					BEGIN
						SET @AreaCodeConcat = @AreaCode + ' (' + Convert(varchar(8),@DateOfContact,1) + ')' + char(13) + char(10) + @AreaCodeConcat	
					END
				
				/* Add to the Subtotal scores, the total score, and update InquiryID_Old */
				IF @DateOfContact > @DateOfContactMax
					BEGIN
						SET @DateOfContactMax = @DateOfContact	
					END
				
				/* Add to the Subtotal scores, the total score, and update InquiryID_Old */	
				SET @DateScoreST = @DateScoreST + @DateScore
				SET @RSVPScoreST = @RSVPScoreST + @RSVPScore
				SET @RequestScoreST = @RequestScoreST + @RequestScoreCS

				/* Count request score in ST only if the user's divid matches the division of the advisor request */
				/* And set flag for advisor review requested in users division */
				IF @AdvisorReqDivisionCode <> 0
					BEGIN
						IF @AdvisorReqDivisionCode IN 
								(
									SELECT p.DivisionCode
									FROM tblUserProfileDivision d
										INNER JOIN tblDivisionProfile p
											ON p.DivID = d.DivID
									WHERE d.LoginName = User_Name()
								)
							BEGIN
								SET @RequestScoreST = @RequestScoreST + @RequestScoreAdv
								SET @AdvisorReqUsersDiv = 1
							END
					END

				SET @CountContact = @CountContact + 1               
				
				SET @TotalScore = @TotalScore + @DateScoreST		
				SET @TotalScore = @TotalScore + @RSVPScoreST
				SET @TotalScore = @TotalScore + @RequestScoreST
				
				/*
				Print ''
				--Print 'I=I_O'
				----Print 'InquiryID ' + Convert(varchar(10), @InquiryID)
				Print 'InquiryID_Old ' + Convert(varchar(10), @InquiryID_Old)
				--Print 'RSVPScore ' + Convert(varchar(10), @RSVPScore)
				--Print 'CountContact ' + Convert(varchar(10), @CountContact)
				--Print 'CountAR ' + Convert(varchar(10), @CountAR)
				--Print 'TotalScore ' + Convert(varchar(10), @TotalScore)
				Print '@DivCode/@DivCodeOK ' + convert(varchar(1), @DivisionCode) + '/' + convert(varchar(1), @DivisionCodeOK)
				*/
			END
		
		/* Inquiry ID is not equal to Inquiry ID old */
		ELSE 
			BEGIN
				/* Update CT AR for each matching rec */
				SET @CountAR = (SELECT Count(*) FROM tblAdvisorReview WHERE tblAdvisorReview.InquiryID = @InquiryID_OLD)

				IF @CountAR <> 0
					BEGIN
						SET @HotCT = (SELECT Count(Rating) FROM tblAdvisorReview WHERE tblAdvisorReview.InquiryID = @InquiryID_OLD AND Rating = 'HOT')
						SET @WarmCT = (SELECT Count(Rating) FROM tblAdvisorReview WHERE tblAdvisorReview.InquiryID = @InquiryID_OLD AND Rating = 'WARM')
						SET @ColdCT = (SELECT Count(Rating) FROM tblAdvisorReview WHERE tblAdvisorReview.InquiryID = @InquiryID_OLD AND Rating = 'COLD')
		
						/* Update Counts of AR Ratings for each matching rec */
						IF @HotCT <> 0
							BEGIN
								IF @WarmCT <> 0
									BEGIN
										IF @ColdCT <> 0	-- a,b,c
											BEGIN
												SET @ARRatingConcat = 'HOT(x' + Convert(varchar(2),@HotCT) + ')' + char(13) + char(10) + 'WARM(x' + Convert(varchar(2),@WarmCT) + ')' + char(13) + char(10) + 'COLD(x' + Convert(varchar(2),@ColdCT) + ')'
											END
										ELSE -- a,b
											BEGIN
												SET @ARRatingConcat = 'HOT(x' + Convert(varchar(2),@HotCT) + ')' + char(13) + char(10) + 'WARM(x' + Convert(varchar(2),@WarmCT) + ')'
											END	
									END
								ELSE
									BEGIN
										IF @ColdCT <> 0	-- a,c
											BEGIN
												SET @ARRatingConcat = 'HOT(x' + Convert(varchar(2),@HotCT) + ')' + 'COLD(x' + Convert(varchar(2),@ColdCT) + ')'	
											END
										ELSE -- a
											BEGIN
												SET @ARRatingConcat = 'HOT(x' + Convert(varchar(2),@HotCT) + ')'
											END
									END
							END
						ELSE
							BEGIN
								IF @WarmCT <> 0
									BEGIN
										IF @ColdCT <> 0	-- b,c
											BEGIN
												SET @ARRatingConcat = 'WARM(x' + Convert(varchar(2),@WarmCT) + ')' + char(13) + char(10) + 'COLD(x' + Convert(varchar(2),@ColdCT) + ')'
											END
										ELSE -- b
											BEGIN
												SET @ARRatingConcat = 'WARM(x' + Convert(varchar(2),@WarmCT) + ')'
											END
									END
								ELSE
									BEGIN
										IF @ColdCT <> 0	-- c
											BEGIN
												SET @ARRatingConcat = 'COLD(x' + Convert(varchar(2),@ColdCT) + ')'
											END
										ELSE --
											BEGIN
												SET @ARRatingConcat = ''
											END
									END
							END
					END

				SET @EventAttend = 
					(
					SELECT count(tblEvent.EventID)
					FROM tblInquiry
						INNER JOIN tblContactInterest
							ON tblContactInterest.InquiryID = tblInquiry.InquiryID
						INNER JOIN tblEvent
							ON tblEvent.EventID = tblContactInterest.EventID
					WHERE tblInquiry.InquiryID = @InquiryID_OLD
						AND tblContactInterest.ContactMode = 'Event'
						AND tblContactInterest.Attend = '1'
						AND tblEvent.EventType = 'Open House'
						AND tblEvent.DateEnd >= getdate() - 30
					)

				IF @EventAttend <> 0
					BEGIN
						SET @EventAttend = 1
					END

				/* Store aggregate rec in #ProspectRating */
				INSERT #ProspectRating 
					(
					InquiryID, 
					DivisionCodeOK,
					DivisionCodeConcat,
					AreaCodeConcat,
					DateOfContactMax,
					DateScoreST,
					RSVPScoreST, 
					RequestScoreST,
					AdvisorReqUsersDiv,
					EventAttend,
					CatOrSchedReq, 
					CountContact,
					CountAR,
					ARRatingConcat,
					TotalScore
					)
				VALUES 
					(
					@InquiryID_OLD,
					@DivisionCodeOK,
					@DivisionCodeConcat,
					@AreaCodeConcat,
					@DateOfContactMax,
					@DateScoreST,
					@RSVPScoreST,
					@RequestScoreST,
					@AdvisorReqUsersDiv,
					@EventAttend,
					@CatOrSchedReq,
					@CountContact,
					@CountAR,
					@ARRatingConcat,
					@TotalScore
					)

				/*
				Print ''
				--Print 'I<>I_O'
				Print 'InquiryID ' + Convert(varchar(10), @InquiryID)
				----Print 'InquiryID_Old ' + Convert(varchar(10), @InquiryID_Old)
				--Print 'RSVPScore ' + Convert(varchar(10), @RSVPScore)
				--Print 'CountContact ' + Convert(varchar(10), @CountContact)
				--Print 'TotalScore ' + Convert(varchar(10), @TotalScore)
				Print '@DivCode/@DivCodeOK ' + convert(varchar(1), @DivisionCode) + '/' + convert(varchar(1), @DivisionCodeOK)
				*/

				/* reset all variables to some baseline values that would be ok if they are not updated to something else before they are used in an expression */
				SET @DivisionCodeOK = 0
				SET @DivisionCodeConcat = ''
				SET @AreaCodeConcat = ''
				SET @DateOfContactMax = '1900-01-01 01:01:01.000'
				SET @DateScoreST = 0
				SET @RSVPScoreST = 0
				SET @RequestScoreST = 0
				SET @AdvisorReqUsersDiv = 0
				SET @EventAttend = 0
				SET @CatOrSchedReq = 0
				SET @CountContact = 1
				SET @CountAR = 0
				SET @HotCT = 0
				SET @WarmCT = 0
				SET @ColdCT = 0
				SET @ARRatingConcat = ''
				SET @TotalScore = 0
				
				SET @InquiryID_Old = @InquiryID
				
				/* flag inquiries that are viewable by the suser_sname (ie >=1 tblContactInterest record has matching div) */
				IF @DivisionCode IN 
						(
							SELECT p.DivisionCode
							FROM tblUserProfileDivision d
								INNER JOIN tblDivisionProfile p
									ON p.DivID = d.DivID
							WHERE d.LoginName = User_Name()
						)
					BEGIN
						SET @DivisionCodeOK = 1		
					END
				
				/* also concatenate a list of divisions that have been inquired into */
				IF @DivisionCode IS NOT NULL
					BEGIN
						SET @DivisionCodeConcat = 
							(
							SELECT DivisionText =
								CASE 
									WHEN DivisionText = 'Business' THEN 'BUS'
									WHEN DivisionText = 'Liberal Arts' THEN 'Lib'
									WHEN DivisionText = 'Education' THEN 'EDU'
									WHEN DivisionText = 'Graduate' THEN 'GRAD'
									WHEN DivisionText = 'Evergreen - Homewood' THEN 'EvH'
									WHEN DivisionText = 'Evergreen - Montgomery County' THEN 'EvM'
									WHEN DivisionText = 'Undergraduate' THEN 'UG'
									WHEN DivisionText = 'General (Non-Credit)' THEN 'GEN'
									WHEN DivisionText = 'Public Safety Leadership' THEN 'PSL'
									ELSE DivisionText
								END
							FROM trnDivision 
							WHERE DivisionCode = @DivisionCode
							) + ' (' + Convert(varchar(8),@DateOfContact,1) + ')' + char(13) + char(10) + @DivisionCodeConcat
					END

				/* Add to the Subtotal scores, the total score, and update InquiryID_Old */
				IF @AreaCode IS NOT NULL
					BEGIN
						SET @AreaCodeConcat = @AreaCode + ' (' + Convert(varchar(8),@DateOfContact,1) + ')' + char(13) + char(10) + @AreaCodeConcat	
					END
				
				/* Add to the Subtotal scores, the total score, and update InquiryID_Old */
				IF @DateOfContact > @DateOfContactMax
					BEGIN
						SET @DateOfContactMax = @DateOfContact	
					END
				
				/* Add to the Subtotal scores, the total score, and update InquiryID_Old */	
				SET @DateScoreST = @DateScoreST + @DateScore
				SET @RSVPScoreST = @RSVPScoreST + @RSVPScore
				SET @RequestScoreST = @RequestScoreST + @RequestScoreCS

				/* Count request score in ST only if the user's divid matches the division of the advisor request */
				/* And set flag for advisor review requested in users division */
				IF @AdvisorReqDivisionCode <> 0
					BEGIN
						IF @AdvisorReqDivisionCode IN 
								(
									SELECT p.DivisionCode
									FROM tblUserProfileDivision d
										INNER JOIN tblDivisionProfile p
											ON p.DivID = d.DivID
									WHERE d.LoginName = User_Name()
								)
							BEGIN
								SET @RequestScoreST = @RequestScoreST + @RequestScoreAdv
								SET @AdvisorReqUsersDiv = 1
							END
					END

				SET @CountContact = @CountContact + 1               
				
				SET @TotalScore = @TotalScore + @DateScoreST		
				SET @TotalScore = @TotalScore + @RSVPScoreST
				SET @TotalScore = @TotalScore + @RequestScoreST
				
			END
		
		-- Fetch the next cursor variable		
		FETCH NEXT FROM curInsertProspectRating
		INTO @InquiryID,
			@ContactID,
			@DivisionCode,
			@AreaCode,
			@DateOfContact,
			@DateScore,
			@RSVPScore,
			@RequestScoreCS,
			@RequestScoreAdv,
			@CatOrSchedReq,
			@AdvisorReqDivisionCode
	END

-- Close The Cursor --
CLOSE curInsertProspectRating
DEALLOCATE curInsertProspectRating

/* Update CT AR for each matching rec */
SET @CountAR = (SELECT Count(*) FROM tblAdvisorReview WHERE tblAdvisorReview.InquiryID = @InquiryID_OLD)

IF @CountAR <> 0
	BEGIN
		SET @HotCT = (SELECT Count(Rating) FROM tblAdvisorReview WHERE tblAdvisorReview.InquiryID = @InquiryID_OLD AND Rating = 'HOT')
		SET @WarmCT = (SELECT Count(Rating) FROM tblAdvisorReview WHERE tblAdvisorReview.InquiryID = @InquiryID_OLD AND Rating = 'WARM')
		SET @ColdCT = (SELECT Count(Rating) FROM tblAdvisorReview WHERE tblAdvisorReview.InquiryID = @InquiryID_OLD AND Rating = 'COLD')

		/* Update Counts of AR Ratings for each matching rec */
		IF @HotCT <> 0
			BEGIN
				IF @WarmCT <> 0
					BEGIN
						IF @ColdCT <> 0	-- a,b,c
							BEGIN
								SET @ARRatingConcat = 'HOT(x' + Convert(varchar(2),@HotCT) + ')' + char(13) + char(10) + 'WARM(x' + Convert(varchar(2),@WarmCT) + ')' + char(13) + char(10) + 'COLD(x' + Convert(varchar(2),@ColdCT) + ')'
							END
						ELSE -- a,b
							BEGIN
								SET @ARRatingConcat = 'HOT(x' + Convert(varchar(2),@HotCT) + ')' + char(13) + char(10) + 'WARM(x' + Convert(varchar(2),@WarmCT) + ')'
							END	
					END
				ELSE
					BEGIN
						IF @ColdCT <> 0	-- a,c
							BEGIN
								SET @ARRatingConcat = 'HOT(x' + Convert(varchar(2),@HotCT) + ')' + 'COLD(x' + Convert(varchar(2),@ColdCT) + ')'	
							END
						ELSE -- a
							BEGIN
								SET @ARRatingConcat = 'HOT(x' + Convert(varchar(2),@HotCT) + ')'
							END
					END
			END
		ELSE
			BEGIN
				IF @WarmCT <> 0
					BEGIN
						IF @ColdCT <> 0	-- b,c
							BEGIN
								SET @ARRatingConcat = 'WARM(x' + Convert(varchar(2),@WarmCT) + ')' + char(13) + char(10) + 'COLD(x' + Convert(varchar(2),@ColdCT) + ')'
							END
						ELSE -- b
							BEGIN
								SET @ARRatingConcat = 'WARM(x' + Convert(varchar(2),@WarmCT) + ')'
							END
					END
				ELSE
					BEGIN
						IF @ColdCT <> 0	-- c
							BEGIN
								SET @ARRatingConcat = 'COLD(x' + Convert(varchar(2),@ColdCT) + ')'
							END
						ELSE --
							BEGIN
								SET @ARRatingConcat = ''
							END
					END
			END
	END

SET @EventAttend = 
	(
	SELECT count(tblEvent.EventID)
	FROM tblInquiry
		INNER JOIN tblContactInterest
			ON tblContactInterest.InquiryID = tblInquiry.InquiryID
		INNER JOIN tblEvent
			ON tblEvent.EventID = tblContactInterest.EventID
	WHERE tblInquiry.InquiryID = @InquiryID_OLD
		AND tblContactInterest.ContactMode = 'Event'
		AND tblContactInterest.Attend = '1'
		AND tblEvent.EventType = 'Open House'
		AND tblEvent.DateEnd >= getdate() - 30
	)

IF @EventAttend <> 0
	BEGIN
		SET @EventAttend = 1
	END

/* Store aggregate rec in #ProspectRating */
INSERT #ProspectRating 
	(
	InquiryID, 
	DivisionCodeOK,
	DivisionCodeConcat,
	AreaCodeConcat,
	DateOfContactMax,
	DateScoreST,
	RSVPScoreST, 
	RequestScoreST,
	AdvisorReqUsersDiv,
	EventAttend,
	CatOrSchedReq,
	CountContact,
	CountAR,
	ARRatingConcat,
	TotalScore
	)
VALUES 
	(
	@InquiryID_OLD,
	@DivisionCodeOK,
	@DivisionCodeConcat,
	@AreaCodeConcat,
	@DateOfContactMax,
	@DateScoreST,
	@RSVPScoreST,
	@RequestScoreST,
	@AdvisorReqUsersDiv,
	@EventAttend,
	@CatOrSchedReq,
	@CountContact,
	@CountAR,
	@ARRatingConcat,
	@TotalScore
	)


/* Select records from #ProspectRating and make case statement to create rating */
--/*
SELECT  
	(
	CASE
		WHEN TotalScore >= 65 THEN 'HOT'
		WHEN TotalScore >= 35 AND TotalScore < 65 THEN 'WARM'
		WHEN TotalScore > 0 AND TotalScore < 35 THEN 'COLD'
		WHEN TotalScore = 0 THEN ''
	END
	) AS Rating,
	tblInquiry.InquiryID, 
	tblInquiry.FirstName, 
	tblInquiry.LastName, 
	tblInquiry.Address1,
	tblInquiry.City,
	tblInquiry.State,
	Left(tblInquiry.PostalCode,5) as Zip,
	tblInquiry.PhoneDaytime,
	tblInquiry.PhoneEvening,
	tblInquiry.EmailAddress,
	#ProspectRating.DivisionCodeConcat,
	#ProspectRating.AreaCodeConcat,
	#ProspectRating.DateOfContactMax,
	#ProspectRating.AdvisorReqUsersDiv,
	#ProspectRating.EventAttend,	
	#ProspectRating.CatOrSchedReq,
	#ProspectRating.CountContact, 
	#ProspectRating.CountAR,
	#ProspectRating.ARRatingConcat,
	#ProspectRating.DateScoreST,
	#ProspectRating.RSVPScoreST, 
	#ProspectRating.RequestScoreST, 
	#ProspectRating.TotalScore
FROM #ProspectRating
	INNER JOIN tblInquiry 
		ON tblInquiry.InquiryID = #ProspectRating.InquiryID
WHERE #ProspectRating.DivisionCodeOK = 1
ORDER BY TotalScore DESC, DateOfContactMax DESC, LastName
--*/


/* Drop #ProspectRating */
DROP TABLE #ProspectRating
GO
