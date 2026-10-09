import { createElement } from 'lwc';
import LibraryMemberShell from 'c/libraryMemberShell';

jest.mock('@salesforce/apex/LibraryMemberController.getCurrentMemberContext', () => ({ default: jest.fn(() => Promise.resolve({})) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.getMyDashboard', () => ({ default: jest.fn(() => Promise.resolve({ activeLoans: 0, dueSoon: 0, overdueLoans: 0, activeReservations: 0, outstandingFine: 0, loans: [], reservations: [] })) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.searchCatalog', () => ({ default: jest.fn(() => Promise.resolve([])) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.getBookDetails', () => ({ default: jest.fn(() => Promise.resolve({})) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.getMyBorrowings', () => ({ default: jest.fn(() => Promise.resolve([])) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.renewMyLoan', () => ({ default: jest.fn(() => Promise.resolve()) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.getMyReservations', () => ({ default: jest.fn(() => Promise.resolve([])) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.reserveBook', () => ({ default: jest.fn(() => Promise.resolve()) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.cancelMyReservation', () => ({ default: jest.fn(() => Promise.resolve()) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.getMyFines', () => ({ default: jest.fn(() => Promise.resolve([])) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.getMyMembership', () => ({ default: jest.fn(() => Promise.resolve({})) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.getMyProfile', () => ({ default: jest.fn(() => Promise.resolve({})) }), { virtual: true });
jest.mock('@salesforce/apex/LibraryMemberController.updateMyProfile', () => ({ default: jest.fn(() => Promise.resolve()) }), { virtual: true });
jest.mock('lightning/platformShowToastEvent', () => ({ ShowToastEvent: class {} }), { virtual: true });

describe('libraryMemberShell state safety', () => {
    afterEach(() => {
        while (document.body.firstChild) document.body.removeChild(document.body.firstChild);
    });

    it('does not dereference member or plan data before Apex resolves', () => {
        const element = createElement('c-library-member-shell', { is: LibraryMemberShell });
        expect(element.member).toBeUndefined();
        expect(element.dashboard).toBeUndefined();
        expect(element.isHomeReady).toBe(false);
        expect(element.planName).toBe('');
        expect(element.hasPlan).toBe(false);
        document.body.appendChild(element);
        expect(element.error).toBeUndefined();
    });

    it('renders a safe missing-plan state without throwing', () => {
        const element = createElement('c-library-member-shell', { is: LibraryMemberShell });
        element.member = { First_Name__c: 'Khushi', Membership_End_Date__c: '2027-10-07' };
        element.dashboard = { activeLoans: 0, dueSoon: 0, overdueLoans: 0, activeReservations: 0, outstandingFine: 0, loans: [], reservations: [] };
        element.membership = { Status__c: 'Active' };
        document.body.appendChild(element);
        expect(element.isHomeReady).toBe(true);
        expect(element.hasPlan).toBe(false);
        expect(element.planName).toBe('');
    });
});
