import React from "react";
import Link from "next/link";

export default function Home() {
  return (
    <div className="flex flex-col min-h-screen">
      {/* Hero Section */}
      <section className="bg-gradient-to-b from-emerald-50 to-white pt-24 pb-20 px-6">
        <div className="max-w-4xl mx-auto text-center">
          <h1 className="text-5xl md:text-6xl font-extrabold text-gray-900 tracking-tight mb-6">
            Your AI Personal Chef <br className="hidden md:block" />
            <span className="text-emerald-600">in Your Pocket</span>
          </h1>
          <p className="text-xl text-gray-600 mb-10 max-w-2xl mx-auto">
            ChefMind AI helps you reduce food waste and cook delicious meals
            with what you have. Scan your pantry, generate recipes, and plan
            your week.
          </p>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
            {/* Placeholder buttons for App Store badges */}
            <button className="bg-black text-white px-8 py-3 rounded-full font-semibold hover:bg-gray-800 transition-colors flex items-center gap-2">
              App Store
            </button>
            <button className="bg-emerald-600 text-white px-8 py-3 rounded-full font-semibold hover:bg-emerald-700 transition-colors flex items-center gap-2">
              Google Play
            </button>
          </div>
        </div>
      </section>

      {/* Features Grid */}
      <section className="py-20 px-6">
        <div className="max-w-6xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-10">
          {/* Feature 1 */}
          <div className="p-6 rounded-2xl bg-gray-50 border border-gray-100">
            <div className="text-4xl mb-4">📸</div>
            <h3 className="text-xl font-bold mb-2">Vision Scanner</h3>
            <p className="text-gray-600">
              Instantly add ingredients to your digital pantry by simply taking
              a picture.
            </p>
          </div>
          {/* Feature 2 */}
          <div className="p-6 rounded-2xl bg-gray-50 border border-gray-100">
            <div className="text-4xl mb-4">✨</div>
            <h3 className="text-xl font-bold mb-2">AI Recipe Gen</h3>
            <p className="text-gray-600">
              Create unique, personalized recipes based exactly on what
              ingredients you have on hand.
            </p>
          </div>
          {/* Feature 3 */}
          <div className="p-6 rounded-2xl bg-gray-50 border border-gray-100">
            <div className="text-4xl mb-4">📅</div>
            <h3 className="text-xl font-bold mb-2">Meal Planning</h3>
            <p className="text-gray-600">
              Plan your week effortlessly and automatically generate smart
              shopping lists.
            </p>
          </div>
        </div>
      </section>

      {/* About Privacy */}
      <section className="bg-gray-900 text-white py-20 px-6">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-3xl font-bold mb-6">Built with Privacy First</h2>
          <p className="text-gray-400 mb-8 max-w-2xl mx-auto">
            We believe your dietary data is yours. We use local processing where
            possible and strict privacy standards for all AI interactions.
          </p>
          <Link
            href="/privacy-policy"
            className="text-emerald-400 hover:text-emerald-300 font-semibold underline"
          >
            Read our Privacy Policy
          </Link>
        </div>
      </section>
    </div>
  );
}
