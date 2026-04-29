import { LightningElement, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getBillDetail from '@salesforce/apex/BoostPortalClaimsController.getBillDetail';
import { getRecordId, goToPage, navigate } from 'c/portalNavigator';
import { PORTAL_PAGES } from 'c/portalPages';

export default class BoostPortalBillDetail extends NavigationMixin(LightningElement) {
    recordId;
    bill;
    checkPayments = [];
    cases = [];
    memberNotes = [];
    isLoading = true;

    caseColumns = [
        {
            label: 'Case Number',
            fieldName: 'caseNumber',
            type: 'button',
            typeAttributes: {
                label: { fieldName: 'caseNumber' },
                name: 'open_case',
                variant: 'base'
            }
        },
        { label: 'Subject', fieldName: 'subject', type: 'text' },
        { label: 'Opened', fieldName: 'createdDate', type: 'date' },
        { label: 'Status', fieldName: 'status', type: 'text' }
    ];

    @wire(CurrentPageReference)
    setPageRef(pageRef) {
        this.recordId = getRecordId(pageRef);
    }

    @wire(getBillDetail, { billId: '$recordId' })
    wiredBill({ data, error }) {
        if (data) {
            this.bill = data.bill;
            this.checkPayments = data.checkPayments || [];
            this.cases = data.cases || [];
            this.memberNotes = (data.memberNotes || []).map(note => {
                const isCaseAdvice =
                    note.relatedCaseId &&
                    note.relatedCaseNumber &&
                    note.noteText &&
                    note.noteText.toLowerCase().startsWith('see case');

                return {
                    ...note,
                    isCaseAdvice,
                    notePrefix: isCaseAdvice ? 'See case ' : '',
                    noteSuffix: isCaseAdvice ? ' and advice' : ''
                };
            });
        } else if (error) {
            console.error('Bill detail error:', error);
            this.bill = null;
            this.checkPayments = [];
            this.cases = [];
            this.memberNotes = [];
        }

        this.isLoading = false;
    }

    get hasCheckPayments() {
        return this.checkPayments && this.checkPayments.length > 0;
    }

    get hasCases() {
        return this.cases && this.cases.length > 0;
    }

    get hasMemberNotes() {
        return this.memberNotes && this.memberNotes.length > 0;
    }

    handleArnCheckToMemberClick(event) {
        const recordId = event.currentTarget.dataset.recordId;

        if (!recordId) {
            return;
        }

        navigate(this, PORTAL_PAGES.PAYMENT_DETAIL, recordId);
    }

    handleCaseRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'open_case' && row.caseId) {
            navigate(this, PORTAL_PAGES.CASE_DETAIL, row.caseId);
        }
    }

    handleMemberNoteCaseClick(event) {
        const recordId = event.currentTarget.dataset.recordId;

        if (!recordId) {
            return;
        }

        navigate(this, PORTAL_PAGES.CASE_DETAIL, recordId);
    }

    navigateBack() {
        goToPage(this, PORTAL_PAGES.BILLS);
    }
}