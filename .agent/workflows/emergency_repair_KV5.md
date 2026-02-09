---
description: Emergency repair workflow for structure KV5UNpUfnGaHWR0gKyjYWQjMFIz1
---
This workflow attempts to recover the functionality of the structure `KV5UNpUfnGaHWR0gKyjYWQjMFIz1` which migrated from Google Play to Stripe but is currently broken (subscription expired, potentially missing data).

The goal is to "cleanly recreate" the structure by:
1.  Fixing the subscription status and expiration date.
2.  Scanning all `users` associated with this structure.
3.  Recreating missing `children` documents in `structures/KV5UNpUfnGaHWR0gKyjYWQjMFIz1/children/` based on parent user records.
4.  Ensuring basic integrity of the structure.

## Prerequisites
- Authenticated with Google Cloud (`gcloud auth login` or application default credentials) to obtain access token.
- Node.js (v18+) installed.

## Steps

1.  **Generate Access Token**:
    Run `gcloud auth print-access-token` to get a valid token for Firestore REST API operations.

2.  **Execute Recovery Script**:
    Run the recovery script `tools/recover_structure_KV5.js` with the token.
    ```bash
    export FIRESTORE_TOKEN=$(gcloud auth print-access-token)
    node tools/recover_structure_KV5.js
    ```

## Script Logic (tools/recover_structure_KV5.js)
The script performs the following actions:
-   **Fetch Structure**: Retrieves `structures/KV5UNpUfnGaHWR0gKyjYWQjMFIz1`.
-   **Update Subscription**: Patches the structure to set `subscriptionStatus: 'active'`, `subscriptionPlatform: 'stripe'`, and `subscriptionExpiresAt` to a future date (e.g., 2027-01-01).
-   **Fetch Associated Users**: Queries `users` collection where `structureId == 'KV5UNpUfnGaHWR0gKyjYWQjMFIz1'`.
-   **Reconstruct Children**:
    -   Iterates through each user.
    -   If the user has `children` IDs, checks if corresponding documents exist in `structures/KV5UNpUfnGaHWR0gKyjYWQjMFIz1/children/`.
    -   If a child document is missing, it creates a new document using the `childName` and `childId` from the user record.
-   **Log Results**: Outputs a summary of fixed items.

## Verification
After running the script:
1.  Ask the user (Alice) to log out and log back in.
2.  Verify she can see her dashboard and children.
3.  Verify subscription status is active in the app.
