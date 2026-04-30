import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getClaims from '@salesforce/apex/BoostPortalClaimsController.getClaims';
import { navigate } from 'c/portalNavigator';
import { PORTAL_PAGES } from 'c/portalPages';

export default class BoostPortalClaims extends NavigationMixin(LightningElement) {
    allClaims = [];
    claims = [];
    paginatedClaims = [];
    isLoading = true;

    selectedClinic = 'ALL';
    selectedStatus = 'ALL';
    selectedClaimType = 'ALL';
    dosStart = null;
    dosEnd = null;

    pageSize = 50;
    pageNumber = 1;
    totalPages = 1;

    columns = [
        {
            label: 'Claim Number',
            fieldName: 'Claim_Number__c',
            type: 'button',
            typeAttributes: {
                label: { fieldName: 'Claim_Number__c' },
                variant: 'base',
                name: 'view_claim'
            }
        },
        { label: 'Boost Account', fieldName: 'BoostAccountName__c', type: 'text' },
        { label: 'Patient Full Name', fieldName: 'Patient_Full_Name__c', type: 'text' },
        { label: 'DOS Start', fieldName: 'DOS_Start__c', type: 'date-local' },
        { label: 'Billed Charges', fieldName: 'Billed_Charges__c', type: 'currency' },
        { label: 'Member Status', fieldName: 'Member_Status__c', type: 'text' },
        { label: 'Claim Type', fieldName: 'Claim_Type__c', type: 'text' }
    ];

    @wire(getClaims)
    wiredClaims({ data, error }) {
        this.isLoading = false;

        if (data) {
            this.allClaims = data;
            this.applyFilters();
        } else if (error) {
            console.error('Error loading claims:', error);
        }
    }

    get clinicOptions() {
        const clinics = [...new Set(
            this.allClaims
                .map(claim => claim.BoostAccountName__c)
                .filter(Boolean)
        )].sort();

        return [
            { label: 'All Clinics', value: 'ALL' },
            ...clinics.map(clinic => ({
                label: clinic,
                value: clinic
            }))
        ];
    }

    get statusOptions() {
        return [
            { label: 'All Statuses', value: 'ALL' },
            { label: 'Payment Being Processed (ARN)', value: 'PAYMENT_BEING_PROCESSED' },
            { label: 'Paid', value: 'PAID' },
            { label: 'Denied', value: 'DENIED' },
            { label: 'Pending/Processing', value: 'PENDING_PROCESSING' },
            { label: 'Information Requested/Needed', value: 'INFO_REQUESTED' },
            { label: 'Special Attention Needed', value: 'SPECIAL_ATTENTION' }
        ];
    }

    get claimTypeOptions() {
        const claimTypes = [...new Set(
            this.allClaims
                .map(claim => claim.Claim_Type__c)
                .filter(Boolean)
        )].sort();

        return [
            { label: 'All Claim Types', value: 'ALL' },
            ...claimTypes.map(type => ({
                label: type,
                value: type
            }))
        ];
    }

    get selectedStatusLabel() {
        const selected = this.statusOptions.find(
            option => option.value === this.selectedStatus
        );

        return selected ? selected.label : this.selectedStatus;
    }

    handleClinicChange(event) {
        this.selectedClinic = event.detail.value;
        this.pageNumber = 1;
        this.applyFilters();
    }

    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.pageNumber = 1;
        this.applyFilters();
    }

    handleClaimTypeChange(event) {
        this.selectedClaimType = event.detail.value;
        this.pageNumber = 1;
        this.applyFilters();
    }

    handleDosStartChange(event) {
        this.dosStart = event.detail.value;
        this.pageNumber = 1;
        this.applyFilters();
    }

    handleDosEndChange(event) {
        this.dosEnd = event.detail.value;
        this.pageNumber = 1;
        this.applyFilters();
    }

    applyFilters() {
        let filteredClaims = [...this.allClaims];

        if (this.selectedClinic !== 'ALL') {
            filteredClaims = filteredClaims.filter(
                claim => claim.BoostAccountName__c === this.selectedClinic
            );
        }

        filteredClaims = this.filterByStatus(filteredClaims);

        if (this.selectedClaimType !== 'ALL') {
            filteredClaims = filteredClaims.filter(
                claim => claim.Claim_Type__c === this.selectedClaimType
            );
        }

        if (this.dosStart) {
            filteredClaims = filteredClaims.filter(
                claim => claim.DOS_Start__c && claim.DOS_Start__c >= this.dosStart
            );
        }

        if (this.dosEnd) {
            filteredClaims = filteredClaims.filter(
                claim => claim.DOS_Start__c && claim.DOS_Start__c <= this.dosEnd
            );
        }

        this.claims = filteredClaims;
        this.totalPages = Math.max(1, Math.ceil(this.claims.length / this.pageSize));
        this.updatePagination();
    }

    filterByStatus(claims) {
        if (this.selectedStatus === 'ALL') {
            return claims;
        }

        const statusGroups = {
            PAYMENT_BEING_PROCESSED: [
                'Payment Being Processed by ARN'
            ],
            PAID: [
                'Paid',
                'Paid Combined With Other Claim',
                'Partial Payment'
            ],
            DENIED: [
                'Denied',
                'Denial Received and Being Processed',
                'UR DENIAL APPEAL SENT TO DIFS',
                'Appealing Denial',
                'PPO Reductions Being Disputed'
            ],
            PENDING_PROCESSING: [
                'Submitted to Payer',
                'Waiting For Payer Response',
                'Preparing For Payer',
                'Processing at Payer',
                'Being Reconsidered',
                'Bill Resubmitted',
                'Rejected at Clearinghouse'
            ],
            INFO_REQUESTED: [
                'Information Requested/Needed',
                'Utilization Review',
                'See Note'
            ],
            SPECIAL_ATTENTION: [
                'Special Attention Needed',
                'Under Investigation',
                'In Litigation',
                'Overpayment Request'
            ]
        };

        const allowedStatuses = statusGroups[this.selectedStatus] || [];

        return claims.filter(claim =>
            allowedStatuses.includes(claim.Member_Status__c)
        );
    }

    updatePagination() {
        const start = (this.pageNumber - 1) * this.pageSize;
        const end = start + this.pageSize;
        this.paginatedClaims = this.claims.slice(start, end);
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber++;
            this.updatePagination();
        }
    }

    handlePrevious() {
        if (this.pageNumber > 1) {
            this.pageNumber--;
            this.updatePagination();
        }
    }

    handleRowAction(event) {
        const { name } = event.detail.action;
        const row = event.detail.row;

        if (name === 'view_claim') {
            navigate(this, PORTAL_PAGES.BILL_DETAIL, row.Id);
        }
    }

    removeFilter(event) {
        const filterName = event.currentTarget.dataset.filter;

        if (filterName === 'clinic') {
            this.selectedClinic = 'ALL';
        }

        if (filterName === 'status') {
            this.selectedStatus = 'ALL';
        }

        if (filterName === 'claimType') {
            this.selectedClaimType = 'ALL';
        }

        if (filterName === 'dosStart') {
            this.dosStart = null;
        }

        if (filterName === 'dosEnd') {
            this.dosEnd = null;
        }

        this.pageNumber = 1;
        this.applyFilters();
    }

    clearFilters() {
        this.selectedClinic = 'ALL';
        this.selectedStatus = 'ALL';
        this.selectedClaimType = 'ALL';
        this.dosStart = null;
        this.dosEnd = null;

        this.pageNumber = 1;
        this.applyFilters();
    }

    get activeFilters() {
        const filters = [];

        if (this.selectedClinic !== 'ALL') {
            filters.push({
                name: 'clinic',
                label: `Clinic: ${this.selectedClinic}`
            });
        }

        if (this.selectedStatus !== 'ALL') {
            filters.push({
                name: 'status',
                label: `Status: ${this.selectedStatusLabel}`
            });
        }

        if (this.selectedClaimType !== 'ALL') {
            filters.push({
                name: 'claimType',
                label: `Claim Type: ${this.selectedClaimType}`
            });
        }

        if (this.dosStart) {
            filters.push({
                name: 'dosStart',
                label: `DOS From: ${this.dosStart}`
            });
        }

        if (this.dosEnd) {
            filters.push({
                name: 'dosEnd',
                label: `DOS To: ${this.dosEnd}`
            });
        }

        return filters;
    }

    get hasActiveFilters() {
        return this.activeFilters.length > 0;
    }

    get disablePrevious() {
        return this.pageNumber === 1;
    }

    get disableNext() {
        return this.pageNumber === this.totalPages;
    }

    get pageInfo() {
        return `Page ${this.pageNumber} of ${this.totalPages}`;
    }

    get recordRangeInfo() {
        if (!this.claims.length) {
            return 'Showing 0 bills';
        }

        const start = (this.pageNumber - 1) * this.pageSize + 1;
        const end = Math.min(this.pageNumber * this.pageSize, this.claims.length);

        return `Showing ${start}-${end} of ${this.claims.length} bills`;
    }

    get hasClaims() {
        return this.claims.length > 0;
    }
}