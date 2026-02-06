import React from "react";

export default function PrivacyPolicy() {
  return (
    <div className="max-w-4xl mx-auto px-6 py-12">
      <h1 className="text-3xl font-bold mb-6">Privacy Policy</h1>
      <p className="text-gray-600 mb-8">Last updated: February 05, 2026</p>

      <section className="mb-8">
        <p className="mb-4">
          ChefMindAI ("we," "our," or "us") respects your privacy. This Privacy
          Policy describes succinctly how we collect, use, and share your
          personal information when you use our mobile application ("App") or
          website.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-4">
          1. Information We Collect
        </h2>

        <h3 className="font-semibold mt-4 mb-2">Permissions We Request</h3>
        <p className="mb-4">
          To provide the core features of ChefMindAI, we request the following
          permissions on your device:
        </p>
        <ul className="list-disc pl-6 mb-4 space-y-2">
          <li>
            <strong>Camera (`android.permission.CAMERA`):</strong> Used for the{" "}
            <strong>Vision Scanner</strong> feature to identify ingredients and
            for taking photos of cooked meals for your private vault. We do not
            store raw camera feeds; images are processed locally or momentarily
            sent to secure AI servers for recognition.
          </li>
          <li>
            <strong>Microphone (`android.permission.RECORD_AUDIO`):</strong>{" "}
            Used for <strong>Voice Commands</strong> in Cooking Mode and for
            dictating notes. Microphone access is active only when you
            explicitly trigger listening mode. Audio is not permanently stored.
          </li>
        </ul>

        <h3 className="font-semibold mt-4 mb-2">Personal Data</h3>
        <p className="mb-4">
          We may collect personal information that you voluntarily provide to
          us, such as your name, email address (for account creation), and
          dietary preferences.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-4">
          2. How We Use Your Information
        </h2>
        <p className="mb-4">We use the information we collect to:</p>
        <ul className="list-disc pl-6 mb-4 space-y-2">
          <li>Provide, maintain, and improve our Service.</li>
          <li>
            Personalize your experience (e.g., recipe recommendations based on
            your pantry).
          </li>
          <li>
            Process AI generation requests (e.g., creating recipes from
            ingredients).
          </li>
          <li>
            Communicate with you regarding updates, support, or security alerts.
          </li>
        </ul>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-4">
          3. Data Sharing and Disclosure
        </h2>
        <p className="mb-4">
          We do not sell your personal data to third parties. We may share data
          with trusted third-party service providers (e.g., AI providers like
          OpenAI/Google Gemini, cloud hosting, analytics) solely to operate the
          Service. These providers are obligated to protect your data.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-4">4. Data Security</h2>
        <p className="mb-4">
          We implement appropriate technical and organizational measures to
          protect your personal information against unauthorized access,
          alteration, disclosure, or destruction. However, no method of
          transmission over the Internet is 100% secure.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-4">
          5. Data Retention & Deletion
        </h2>
        <p className="mb-4">
          We retain your personalized data (recipes, pantry items) as long as
          your account is active.
        </p>
        <h3 className="font-semibold mt-4 mb-2">Account Deletion</h3>
        <p className="mb-4">
          You have the right to request the deletion of your account and all
          associated data at any time. To do so, you can:
        </p>
        <ul className="list-disc pl-6 mb-4 space-y-2">
          <li>
            Use the <strong>"Delete Account"</strong> option within the App
            settings.
          </li>
          <li>
            Email us at{" "}
            <a
              href="mailto:support@chefmind.ai"
              className="text-emerald-600 hover:underline"
            >
              support@chefmind.ai
            </a>{" "}
            with the subject line "Account Deletion Request". We will process
            your request within 30 days.
          </li>
        </ul>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-4">6. Children's Privacy</h2>
        <p className="mb-4">
          Our Service is not intended for use by children under the age of 13.
          We do not knowingly collect personal information from children under
          13.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-4">
          7. Changes to This Policy
        </h2>
        <p className="mb-4">
          We may update our Privacy Policy from time to time. We will notify you
          of any changes by posting the new Privacy Policy on this page and
          updating the "Last updated" date.
        </p>
      </section>

      <section className="mb-8">
        <h2 className="text-xl font-semibold mb-4">8. Contact Us</h2>
        <p className="mb-4">
          If you have any questions about this Privacy Policy, please contact us
          at support@chefmind.ai.
        </p>
      </section>
    </div>
  );
}
