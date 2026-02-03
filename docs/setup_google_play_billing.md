# Setting Up Google Play Billing & RevenueCat for ChefMind AI

This guide covers the steps to enable In-App Purchases (IAP) for the Android version of ChefMind AI using RevenueCat and the Google Play Console.

## Prerequisites

- **Google Play Developer Account** (Active and Validated).
- **RevenueCat Account** (You likely already have this for iOS).
- **App Bundle (.aab)**: You will need to build this to upload to the Internal Testing track.

---

## Step 1: Prepare the Google Play Console

1.  **Create App**: Log in to [Google Play Console](https://play.google.com/console) and create a new app.
    - **App Name**: ChefMind AI
    - **Language**: Default (English)
    - **App Type**: App
    - **Free/Paid**: Free (The app itself is free, subscriptions are IAP).

2.  **Upload Internal Testing Build**:
    - Go to **Testing > Internal testing**.
    - Click **Create new release**.
    - **Build the App Bundle**:
      Run the following command in your terminal:
      ```bash
      flutter build appbundle
      ```
    - Upload the generated file (`build/app/outputs/bundle/release/app-release.aab`) to the Play Console.
    - **Note**: You will need to sign the app. If you haven't generated a keystore yet, you'll need to do so (see specific Android signing guides). For internal testing, you can sometimes let Google generate a key, but a consistent keystore is better.

3.  **Add Testers**:
    - In the **Internal testing** tab, look for the **Testers** tab.
    - Create an email list (including your own Google email).
    - **Copy the "Join on the web" link** and open it on your Android device to "Join the beta".

---

## Step 2: Configure RevenueCat & Google Cloud

To let RevenueCat verify purchases, it needs access to your Google Play data via a Service Account.

1.  **Link Google Play Project**:
    - In Play Console, go to **Setup > API access**.
    - Click **Create a new Google Cloud Project** (or link an existing one).

2.  **Create Service Account Key**:
    - Click the "View in Google Cloud Platform" link.
    - Go to **IAM & Admin > Service Accounts**.
    - Click **Create Service Account**.
      - Name: `revenuecat-access`.
    - **Role**: Assign the role **Pub/Sub Admin** (for real-time notifications) and **Monitoring Viewer**.
      - _Actually, for simple IAP validation, the role "Google Play Android Developer" is needed, but that is assigned in Play Console._
    - Click **Done**.
    - Click the three dots on the new account > **Manage keys** > **Add Key** > **Create new key** > **JSON**.
    - **Save this file!** You will need it.

3.  **Grant Access in Play Console**:
    - Back in Play Console **API access**, verify the Service Account is listed.
    - Click **Grant Access** (or "Manage Play Console permissions").
    - **Permissions**:
      - Go to **Account permissions**.
      - Check **View app information** and **View financial data** (required for validation).
      - Go to **App permissions** -> Add "ChefMind AI".
    - Click **Invite User** or **Save**.

4.  **Configure RevenueCat**:
    - Go to your application in RevenueCat dashboard.
    - Navigate to **Project Settings > Apps > Android**.
    - Package Name: `ai.chefmindai.app` (Confirm this in `android/app/build.gradle`).
    - **Service Account Credentials JSON**: Upload the JSON file you downloaded in step 2.2.
    - **Shared Secret**: Generally not needed for Google Play (unlike iOS), but follow RevenueCat prompts if asked.

---

## Step 3: Create Products in Google Play

1.  **Monetization Setup**:
    - In Play Console, go to **Monetization > Products > Subscriptions**.
    - You may need to set up a Merchant Account first if you haven't (requires bank details).

2.  **Create Subscriptions**:
    Create subscription products that match your business model.
    - **Product ID**: e.g., `sous_chef_monthly`
    - **Name**: Sous Chef Monthly
    - **Base Plan**: Auto-renewing, Monthly, Price (e.g. $4.99).
    - **Product ID**: e.g., `executive_chef_monthly`
    - **Name**: Executive Chef Monthly
    - **Base Plan**: Auto-renewing, Monthly, Price (e.g. $9.99).

3.  **Link to RevenueCat Offerings**:
    - Go to RevenueCat Dashboard > **Offerings**.
    - Select your **Default Offering** (e.g., "default").
    - Click on the **Packages** (e.g., "Monthly").
    - **Attach Product**: Select "Play Store" and enter the Product ID you just created (e.g., `sous_chef_monthly`).
    - Repeat for other tiers/packages.
    - **CRITICAL**: Ensure you map them to the correct **Entitlements** in RevenueCat:
      - `sous_chef_monthly` -> grants `sous_chef` entitlement.
      - `executive_chef_monthly` -> grants `executive_chef` entitlement.
        _(Note: Our app code looks for `sous_chef` and `executive_chef` entitlements exactly)._

---

## Step 4: Verification

1.  **Update Config (Optional)**:
    - In `lib/core/config/store_config.dart`, update `googleApiKey` with the **RevenueCat Public API Key** for Android (found in RevenueCat Project Settings > API Keys).

    _Current Config:_

    ```dart
    static const googleApiKey = 'test_fawmSfbCLdpmnRclGVlzsCXOKpF';
    ```

    If this is the correct key from RevenueCat, you are good.

2.  **Test on Device**:
    - Uninstall any debug version of the app.
    - Download the app **via the Internal Testing link** (Google Play Store) on your device.
    - _Note: Sideloading the AAB/APK often fails for IAP testing. It must be downloaded from the Store to recognize your user as a "Tester"._
    - Go to settings -> Upgrade.
    - You should see the Google Play purchase sheet appear with "Test Card".

## Troubleshooting

- **"Authentication is required. You need to sign into your Google Account."**: Ensure the device has a Google account logged in that is on the Tester list.
- **"Item not found"**:
  - Check if the Product ID in RevenueCat exactly matches Google Play.
  - Check if the App Bundle is actually "Active" in the Internal Testing track.
  - Wait 1-2 hours. Google Play updates can be slow.
- **No Purchase Sheet**: Check Logcat (`flutter run`). If permissions are missing, it will say so (though we added `BILLING` permission).
