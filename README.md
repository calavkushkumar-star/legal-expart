# Legal Expart — Android (Flutter)

A Hindi/English legal services app starter with customer registration/login, admin login, service request submission, an admin request queue, and a custom navy/gold legal emblem.

## Services
- GST Registration
- MSME / Udyam
- FSSAI Food License
- Digital Signature
- Trademark Registration
- Legal Consultation

## Run locally
1. Install Flutter stable and Android Studio / Android SDK.
2. Create a Firebase project and register an Android app with package ID `com.legalexpart.app`.
3. Enable Firebase Authentication > Email/Password and create a Cloud Firestore database.
4. Add Firebase Android configuration: download `google-services.json` into `android/app/`, configure the Google Services Gradle plugin using the current FlutterFire Android setup guide, and ensure native Firebase setup is complete.
5. From this directory run:
   ```bash
   flutter pub get
   flutter run
   ```

## Admin setup
New registrations are customer accounts only. Assign the first admin role securely through a trusted Firebase Admin SDK environment or Cloud Function by setting `users/{uid}.role` to `admin`. Never allow the public app to grant itself admin access.

## Security / launch checklist
- Publish `firestore.rules` to Firestore.
- Configure password reset and email verification.
- Add a privacy policy, terms, support contact, and legal-service disclaimers.
- Review fees (sample prices only) and local legal requirements before launch.
- Do not store sensitive legal documents until Storage rules, consent, retention and access controls are implemented.
- Never commit service-account private keys or secrets to GitHub.

This is a starter project; it has not been built into a signed APK or connected to a real Firebase project yet.
