public with sharing class BoostPortalClaimsController {

    private static Set<Id> getCurrentAccountIds() {

        User u = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (u.ContactId == null) {
            throw new AuraHandledException('User is not associated with a contact.');
        }

        Contact c = [
            SELECT AccountId
            FROM Contact
            WHERE Id = :u.ContactId
            LIMIT 1
        ];

        Set<Id> accountIds = new Set<Id>();

        if (c.AccountId != null) {
            accountIds.add(c.AccountId);
        }

        for (AccountContactRelation acr : [
            SELECT AccountId
            FROM AccountContactRelation
            WHERE ContactId = :u.ContactId
              AND IsActive = true
        ]) {
            accountIds.add(acr.AccountId);
        }

        if (accountIds.isEmpty()) {
            throw new AuraHandledException('User is not related to any accounts.');
        }

        return accountIds;
    }

    @AuraEnabled(cacheable=true)
    public static List<Boost__c> getClaims() {

        Set<Id> accountIds = getCurrentAccountIds();

        return [
            SELECT Id,
                   Claim_Number__c,
                   BoostAccountName__c,
                   Patient_Full_Name__c,
                   DOS_Start__c,
                   Billed_Charges__c,
                   Member_Status__c,
                   Claim_Type__c
            FROM Boost__c
            WHERE ARN_Account__r.Community_Account__c IN :accountIds
            ORDER BY DOS_Start__c DESC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static BillDetailWrapper getBillDetail(Id billId) {

        if (billId == null) {
            throw new AuraHandledException('Bill Id is required.');
        }

        Set<Id> accountIds = getCurrentAccountIds();

        Boost__c bill = [
            SELECT Id,
                   Claim_Number__c,
                   BoostAccountName__c,
                   Patient_Full_Name__c,
                   DOS_Start__c,
                   DOS_End__c,
                   Total_Units__c,
                   Uploaded__c,
                   Billed_Charges__c,
                   Total_Charges__c,
                   Member_Status__c,
                   Claim_Type__c,
                   Denial_Reason__c,
                   ARN_Account__r.Community_Account__c
            FROM Boost__c
            WHERE Id = :billId
              AND ARN_Account__r.Community_Account__c IN :accountIds
            LIMIT 1
        ];

        List<CheckPaymentInfo> paymentList = new List<CheckPaymentInfo>();

        for (Check_Payment__c cp : [
            SELECT Id,
                   Name,
                   Amount_Paid__c,
                   Check_Date__c,
                   Payor__c,
                   Provider_Clinic__c,
                   ARN_Check_To_Member__c,
                   ARN_Check_To_Member__r.Name,
                   ARN_Check_To_Member__r.ARN_Total_Check_Amount__c
            FROM Check_Payment__c
            WHERE Bill__c = :bill.Id
            ORDER BY Check_Date__c DESC
        ]) {
            CheckPaymentInfo info = new CheckPaymentInfo();
            info.id = cp.Id;
            info.name = cp.Name;
            info.amountPaid = cp.Amount_Paid__c;
            info.checkDate = cp.Check_Date__c;
            info.arnCheckToMemberId = cp.ARN_Check_To_Member__c;
            info.arnCheckNumber = cp.ARN_Check_To_Member__r != null
                ? cp.ARN_Check_To_Member__r.Name
                : null;
            info.totalCheckAmount = cp.ARN_Check_To_Member__r != null
                ? cp.ARN_Check_To_Member__r.ARN_Total_Check_Amount__c
                : null;
            info.payor = cp.Payor__c;
            info.providerClinic = cp.Provider_Clinic__c;
            paymentList.add(info);
        }

        List<CaseInfo> caseList = new List<CaseInfo>();

        for (Case c : [
            SELECT Id,
                   CaseNumber,
                   Subject,
                   CreatedDate,
                   Status,
                   AccountId
            FROM Case
            WHERE Bill__c = :bill.Id
              AND AccountId IN :accountIds
            ORDER BY CreatedDate DESC
        ]) {
            CaseInfo info = new CaseInfo();
            info.caseId = c.Id;
            info.caseNumber = c.CaseNumber;
            info.subject = c.Subject;
            info.createdDate = c.CreatedDate;
            info.status = c.Status;
            caseList.add(info);
        }

        List<MemberNoteInfo> memberNoteList = new List<MemberNoteInfo>();

        for (Boost_Member_Note__c note : [
            SELECT Id,
                   Name,
                   Note_Text__c,
                   Note_Type__c,
                   Source__c,
                   CreatedDate,
                   Related_Case__c,
                   Related_Case__r.CaseNumber
            FROM Boost_Member_Note__c
            WHERE Boost__c = :bill.Id
            ORDER BY CreatedDate DESC
        ]) {
            MemberNoteInfo info = new MemberNoteInfo();
            info.id = note.Id;
            info.name = note.Name;
            info.noteText = note.Note_Text__c;
            info.noteType = note.Note_Type__c;
            info.source = note.Source__c;
            info.createdDate = note.CreatedDate;
            info.relatedCaseId = note.Related_Case__c;
            info.relatedCaseNumber = note.Related_Case__r != null
                ? note.Related_Case__r.CaseNumber
                : null;
            memberNoteList.add(info);
        }

        BillDetailWrapper wrapper = new BillDetailWrapper();
        wrapper.bill = bill;
        wrapper.checkPayments = paymentList;
        wrapper.cases = caseList;
        wrapper.memberNotes = memberNoteList;

        return wrapper;
    }

    public class BillDetailWrapper {
        @AuraEnabled public Boost__c bill;
        @AuraEnabled public List<CheckPaymentInfo> checkPayments;
        @AuraEnabled public List<CaseInfo> cases;
        @AuraEnabled public List<MemberNoteInfo> memberNotes;
    }

    public class CheckPaymentInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal amountPaid;
        @AuraEnabled public Date checkDate;
        @AuraEnabled public String arnCheckNumber;
        @AuraEnabled public Id arnCheckToMemberId;
        @AuraEnabled public Decimal totalCheckAmount;
        @AuraEnabled public String payor;
        @AuraEnabled public String providerClinic;
    }

    public class CaseInfo {
        @AuraEnabled public Id caseId;
        @AuraEnabled public String caseNumber;
        @AuraEnabled public String subject;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String status;
    }

    public class MemberNoteInfo {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String noteText;
        @AuraEnabled public String noteType;
        @AuraEnabled public String source;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Id relatedCaseId;
        @AuraEnabled public String relatedCaseNumber;
    }
}