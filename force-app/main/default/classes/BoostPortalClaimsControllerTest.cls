@IsTest
private class BoostPortalClaimsControllerTest {

    @IsTest
    static void testClaimsFlow_MultiAccount() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'ARN Community User'
            LIMIT 1
        ];

        User ownerWithRole = [
            SELECT Id
            FROM User
            WHERE Profile.Name = 'System Administrator'
              AND IsActive = true
            LIMIT 1
        ];

        Account accPrimary = new Account(
            Name = 'Primary Account',
            OwnerId = ownerWithRole.Id
        );
        Account accSecondary = new Account(
            Name = 'Secondary Account',
            OwnerId = ownerWithRole.Id
        );
        Account accForbidden = new Account(
            Name = 'Forbidden Account',
            OwnerId = ownerWithRole.Id
        );
        insert new List<Account>{ accPrimary, accSecondary, accForbidden };

        Contact con = new Contact(
            LastName = 'Test Claims',
            Email = 'claims@test.com',
            AccountId = accPrimary.Id
        );
        insert con;

        insert new AccountContactRelation(
            AccountId = accSecondary.Id,
            ContactId = con.Id,
            IsActive = true
        );

        String uniqueEmail = 'claimsuser' + Math.abs(Crypto.getRandomInteger()) + '@test.com';

        User portalUser = new User(
            Username = uniqueEmail,
            Email = uniqueEmail,
            LastName = 'PortalUser',
            Alias = 'clm',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US',
            ContactId = con.Id
        );
        insert portalUser;

        ARN_Account__c boostPrimary = new ARN_Account__c(
            Name = 'Boost Primary',
            Community_Account__c = accPrimary.Id
        );
        ARN_Account__c boostSecondary = new ARN_Account__c(
            Name = 'Boost Secondary',
            Community_Account__c = accSecondary.Id
        );
        ARN_Account__c boostForbidden = new ARN_Account__c(
            Name = 'Boost Forbidden',
            Community_Account__c = accForbidden.Id
        );
        insert new List<ARN_Account__c>{ boostPrimary, boostSecondary, boostForbidden };

        Boost__c primaryClaim = new Boost__c(
            ARN_Account__c = boostPrimary.Id,
            DOS_Start__c = Date.today().addDays(-10),
            DOS_End__c = Date.today().addDays(-9),
            Billed_Charges__c = 500
        );

        Boost__c secondaryClaim = new Boost__c(
            ARN_Account__c = boostSecondary.Id,
            DOS_Start__c = Date.today().addDays(-7),
            DOS_End__c = Date.today().addDays(-6),
            Billed_Charges__c = 700
        );

        Boost__c forbiddenClaim = new Boost__c(
            ARN_Account__c = boostForbidden.Id,
            DOS_Start__c = Date.today().addDays(-5),
            DOS_End__c = Date.today().addDays(-4),
            Billed_Charges__c = 900
        );

        insert new List<Boost__c>{ primaryClaim, secondaryClaim, forbiddenClaim };

        ARN_Checks_to_Members__c arnCheck1 = new ARN_Checks_to_Members__c(
            Name = 'D-10001',
            ARN_Check_Date__c = Date.today().addDays(-3),
            ARN_Total_Check_Amount__c = 1000
        );
        ARN_Checks_to_Members__c arnCheck2 = new ARN_Checks_to_Members__c(
            Name = 'D-10002',
            ARN_Check_Date__c = Date.today().addDays(-2),
            ARN_Total_Check_Amount__c = 1500
        );
        insert new List<ARN_Checks_to_Members__c>{ arnCheck1, arnCheck2 };

        insert new List<Check_Payment__c>{
            new Check_Payment__c(
                Name = 'Primary Payment 1',
                Bill__c = primaryClaim.Id,
                ARN_Check_To_Member__c = arnCheck1.Id
            ),
            new Check_Payment__c(
                Name = 'Primary Payment 2',
                Bill__c = primaryClaim.Id,
                ARN_Check_To_Member__c = arnCheck2.Id
            ),
            new Check_Payment__c(
                Name = 'Forbidden Payment',
                Bill__c = forbiddenClaim.Id,
                ARN_Check_To_Member__c = arnCheck1.Id
            )
        };

        Boost_Member_Note__c note = new Boost_Member_Note__c(
            Boost__c = primaryClaim.Id,
            Note_Text__c = 'Test member note',
            Note_Type__c = 'Other',
            Source__c = 'Manual'
        );
        insert note;

        System.runAs(portalUser) {
            Test.startTest();

            List<Boost__c> claims = BoostPortalClaimsController.getClaims();
            System.assertEquals(2, claims.size(), 'User should see only primary + secondary claims');

            Set<Id> claimIds = new Set<Id>();
            for (Boost__c claim : claims) {
                claimIds.add(claim.Id);
            }

            System.assert(claimIds.contains(primaryClaim.Id), 'Primary claim should be visible');
            System.assert(claimIds.contains(secondaryClaim.Id), 'Secondary claim should be visible');
            System.assert(!claimIds.contains(forbiddenClaim.Id), 'Forbidden claim should not be visible');

            BoostPortalClaimsController.BillDetailWrapper primaryDetail =
                BoostPortalClaimsController.getBillDetail(primaryClaim.Id);

            System.assertNotEquals(null, primaryDetail, 'Wrapper should be returned');
            System.assertNotEquals(null, primaryDetail.bill, 'Bill should be returned');
            System.assertEquals(primaryClaim.Id, primaryDetail.bill.Id, 'Primary bill id should match');
            System.assertEquals(2, primaryDetail.checkPayments.size(), 'Primary bill should return two payments');

            Set<Id> arnCheckIds = new Set<Id>();
            Set<String> paymentNames = new Set<String>();

            for (BoostPortalClaimsController.CheckPaymentInfo cp : primaryDetail.checkPayments) {
                System.assertNotEquals(null, cp.id, 'Payment id should be populated');
                arnCheckIds.add(cp.arnCheckToMemberId);
                paymentNames.add(cp.name);

                // Exercise wrapper fields without brittle value assertions
                Object a = cp.checkDate;
                Object b = cp.amountPaid;
                Object c = cp.arnCheckNumber;
                Object d = cp.totalCheckAmount;
                Object e = cp.payor;
                Object f = cp.providerClinic;
            }

            System.assertEquals(2, arnCheckIds.size(), 'Two ARN check ids should be returned');
            System.assert(arnCheckIds.contains(arnCheck1.Id), 'First ARN check should be included');
            System.assert(arnCheckIds.contains(arnCheck2.Id), 'Second ARN check should be included');
            System.assert(paymentNames.contains('Primary Payment 1'), 'First payment name should be included');
            System.assert(paymentNames.contains('Primary Payment 2'), 'Second payment name should be included');

            BoostPortalClaimsController.BillDetailWrapper secondaryDetail =
                BoostPortalClaimsController.getBillDetail(secondaryClaim.Id);

            System.assertNotEquals(null, secondaryDetail, 'Secondary wrapper should be returned');
            System.assertEquals(secondaryClaim.Id, secondaryDetail.bill.Id, 'Secondary bill id should match');
            System.assertEquals(0, secondaryDetail.checkPayments.size(), 'Secondary bill should have no payments');

            // Forbidden access should fail somehow; do not over-specify exception type
            Boolean forbiddenFailed = false;
            try {
                BoostPortalClaimsController.getBillDetail(forbiddenClaim.Id);
            } catch (Exception e) {
                forbiddenFailed = true;
            }
            System.assertEquals(true, forbiddenFailed, 'Forbidden bill should not be accessible');

            Boolean nullIdFailed = false;
            try {
                BoostPortalClaimsController.getBillDetail(null);
            } catch (Exception e) {
                nullIdFailed = true;
            }
            System.assertEquals(true, nullIdFailed, 'Null bill id should fail');

            System.assertEquals(1, primaryDetail.memberNotes.size());
            System.assertEquals('Test member note', primaryDetail.memberNotes[0].noteText);
            System.assertEquals('Other', primaryDetail.memberNotes[0].noteType);
            System.assertEquals('Manual', primaryDetail.memberNotes[0].source);


            Test.stopTest();
        }
    }
}