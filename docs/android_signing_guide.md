# Android App Signing Guide

Since I have already configured your `build.gradle` to use `key.properties`, you just need to generate the key and create that file.

## Step 1: Generate the Upload Keystore

Run the following command in your terminal.
**Important**:

- Keep the password safe.
- Answer "yes" to "Is CN=... correct?".

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

_Note: This creates the file `upload-keystore.jks` in your User Home directory (`~/`). This is safer than keeping it inside the project folder._

## Step 2: Create `key.properties`

1.  Create a file named `key.properties` in the `android/` directory:
    `chefmind_ai/android/key.properties`
2.  Paste the following content into it (replace `YOUR_PASSWORD` with the password you set):

```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/Users/rawad/upload-keystore.jks
```

_Note: Ensure `storeFile` points to the correct location where you generated the `.jks` file._

## Step 3: Build the App Bundle

Now you can build the signed release bundle:

```bash
flutter build appbundle
```

The output file will be at:
`build/app/outputs/bundle/release/app-release.aab`

Upload this file to the **Google Play Console > Internal Testing**.
