# Setup & Configuration Guide

## Prerequisites

- Salesforce org with API 68.0+
- Agentforce enabled
- Data Cloud enabled
- SFDX CLI installed

## Installation Steps

### 1. Deploy Source to Org

```bash
sf project deploy start --target-org library-org
```

Verify deployment succeeded with zero failures.

### 2. Data Cloud Configuration

#### Enable Calculated Insights

1. Go to **Data Cloud** > **Calculated Insights**
2. Create the following insights from data sources:

| Name                                     | Source           | Schedule      |
| ---------------------------------------- | ---------------- | ------------- |
| Library_Copy_Availability__cio           | Book_Copy__c     | Every 6 hours |
| Library_Member_Loan_Activity__cio        | Borrow_Record__c | Every 6 hours |
| Library_Member_Reservation_Activity__cio | Reservation__c   | Every 6 hours |
| Library_Member_Fine_Activity__cio        | Fine__c          | Every 6 hours |
| Library_Book_Popularity__cio             | Borrow_Record__c | Every 6 hours |
| Library_Reservation_Demand__cio          | Reservation__c   | Every 6 hours |

#### Verify Readiness

Run in Apex:

```apex
LibraryDataCloudReadinessService.StatusDTO status = LibraryDataCloudReadinessService.getStatus();
System.debug('Ready: ' + status.ready);
System.debug('Status: ' + status.status);
```

### 3. Payment Gateway Setup

1. Go to **Setup** > **Custom Metadata Types** > **Payment_Gateway_Config**
2. Create a default record:
   - **Provider_Name**: Stripe (or your provider)
   - **Enabled**: true
   - **Checkout_Named_Credential**: Library_Metadata
   - **Default_Currency**: USD

### 4. Email Configuration

1. Go to **Setup** > **Email** > **Email Relay**
2. Configure SMTP for notification delivery
3. Verify sending email address is registered

### 5. Experience Cloud Site Setup

1. Go to **Setup** > **Digital Experiences** > **All Sites**
2. Activate the **Library** site
3. Configure member access:
   - Authentication: Enable self-registration
   - Profile: Standard Community User

### 6. Member Portal Access

1. Go to site URL: `/s/library` (on your community URL)
2. Test registration flow
3. Test member login

### 7. Agentforce Agent Configuration

1. Open **Agentforce** > **Agents**
2. Verify 4 agents are active:
   - Library_Member_Agentforce
   - Library_Librarian_Agentforce_Refresh
   - Library_Member_Assistant
   - Library_Librarian_Assistant_V2_5
3. Test agent responses with sample queries

### 8. Permissions Setup

Assign permission sets to users:

```bash
sf org assign permset --perm-set-name "Library_Librarian" \
  --target-username library-org
sf org assign permset --perm-set-name "Library_Member" \
  --target-username library-org
```

## Configuration Checklist

- [ ] Source deployed successfully
- [ ] Data Cloud insights created
- [ ] Data Cloud readiness verified
- [ ] Payment gateway configured
- [ ] Email relay configured
- [ ] Experience Cloud site activated
- [ ] Agentforce agents tested
- [ ] Permission sets assigned
- [ ] Member portal accessible
- [ ] Librarian workspace accessible

## Post-Deployment Tasks

### Add Library Settings

1. Go to **Library Settings** tab in workspace
2. Configure:
   - Library Name
   - Contact Email
   - Default Loan Duration (14 days)
   - Fine per Day ($0.50)
   - Borrow Limit (5 copies)
   - Reservation Limit (3 items)

### Import Initial Data

1. Create book categories
2. Create membership plans
3. Import book catalog (if available)
4. Add authors and book details

### User Onboarding

1. Create librarian users and assign Library_Librarian permission set
2. Create test member accounts
3. Train librarians on workspace
4. Communicate portal access to members

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues.

## Support

Contact the Library System Admin team for setup assistance.
