import React from "react";
import Link from "next/link";
import {
  ArrowLeft,
  ScanLine,
  ChefHat,
  ShoppingCart,
  Mic,
  Users,
  Star,
} from "lucide-react";

export default function GuidePage() {
  return (
    <div className="min-h-screen bg-white dark:bg-black text-gray-900 dark:text-gray-100 pb-24">
      {/* Header */}
      <div className="bg-emerald-600 text-white py-16 px-6">
        <div className="max-w-4xl mx-auto">
          <Link
            href="/"
            className="inline-flex items-center gap-2 text-emerald-100 hover:text-white mb-8 transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            Back to Home
          </Link>
          <h1 className="text-4xl md:text-5xl font-bold mb-4">
            ChefMindAI User Guide
          </h1>
          <p className="text-lg text-emerald-100 max-w-2xl">
            Everything you need to know to master your kitchen, from scanning
            ingredients to cooking hands-free.
          </p>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-6 mt-12 grid gap-16">
        {/* Section 1: Getting Started */}
        <section id="getting-started">
          <h2 className="text-2xl font-bold mb-6 flex items-center gap-3">
            <span className="w-8 h-8 rounded-full bg-emerald-100 dark:bg-emerald-900/40 text-emerald-600 flex items-center justify-center text-sm">
              1
            </span>
            Getting Started
          </h2>
          <div className="prose dark:prose-invert max-w-none text-gray-600 dark:text-gray-400">
            <p className="mb-4">
              Welcome to ChefMindAI! To get the most out of your experience:
            </p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>
                <strong>Create an Account:</strong> Sign up with email, Google,
                or Apple to sync your data across devices.
              </li>
              <li>
                <strong>Grant Permissions:</strong> Allow Camera access for the
                Vision Scanner and Microphone access for Voice Commands.
              </li>
              <li>
                <strong>Set Preferences:</strong> Go to Settings to set your
                dietary restrictions (e.g., Vegan, Gluten-Free) which will
                filter all AI-generated recipes.
              </li>
            </ul>
          </div>
        </section>

        {/* Section 2: Vision Scanner */}
        <section id="pantry">
          <h2 className="text-2xl font-bold mb-6 flex items-center gap-3 pt-6 border-t border-gray-100 dark:border-gray-800">
            <div className="p-2 bg-purple-100 dark:bg-purple-900/20 text-purple-600 rounded-lg">
              <ScanLine className="w-6 h-6" />
            </div>
            Vision Pantry Scanner
          </h2>
          <div className="prose dark:prose-invert max-w-none text-gray-600 dark:text-gray-400">
            <p className="mb-4">
              Populate your digital pantry instantly without typing.
            </p>
            <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-2">
              How to Scan
            </h3>
            <ol className="list-decimal pl-6 space-y-2 mb-6">
              <li>Tap the "Scan" button on the Pantry tab.</li>
              <li>
                Point your camera at a group of ingredients (e.g., on a table or
                open fridge shelf).
              </li>
              <li>Snap the photo and wait for the AI Analysis.</li>
              <li>
                Review the list: Uncheck any incorrect items and tap "Add to
                Pantry".
              </li>
            </ol>
            <div className="bg-gray-50 dark:bg-gray-900 p-4 rounded-xl border border-gray-100 dark:border-gray-800">
              <p className="font-semibold text-gray-900 dark:text-white mb-1">
                💡 Pro Tip
              </p>
              <p className="text-sm">
                Ensure good lighting and spread items out slightly so labels are
                visible. You can scan up to 10 items at once!
              </p>
            </div>
          </div>
        </section>

        {/* Section 3: AI Chef */}
        <section id="ai-chef">
          <h2 className="text-2xl font-bold mb-6 flex items-center gap-3 pt-6 border-t border-gray-100 dark:border-gray-800">
            <div className="p-2 bg-emerald-100 dark:bg-emerald-900/20 text-emerald-600 rounded-lg">
              <ChefHat className="w-6 h-6" />
            </div>
            AI Chef & Recipe Generation
          </h2>
          <div className="prose dark:prose-invert max-w-none text-gray-600 dark:text-gray-400">
            <p className="mb-4">
              Create unique recipes based strictly on what you have at home.
            </p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>
                <strong>Generate from Pantry:</strong> Tap the "AI Chef" button.
                Select specific ingredients you want to use, or let the AI pick
                from your entire pantry.
              </li>
              <li>
                <strong>Customize:</strong> Choose a meal type (Breakfast,
                Lunch, Dinner) and cuisine style before generating.
              </li>
              <li>
                <strong>Save to Vault:</strong> Love a result? Save it to "My
                Recipes" to keep it forever. Unsaved generated recipes disappear
                when you leave the screen.
              </li>
            </ul>
          </div>
        </section>

        {/* Section 4: Cooking Mode */}
        <section id="cooking-mode">
          <h2 className="text-2xl font-bold mb-6 flex items-center gap-3 pt-6 border-t border-gray-100 dark:border-gray-800">
            <div className="p-2 bg-orange-100 dark:bg-orange-900/20 text-orange-600 rounded-lg">
              <Mic className="w-6 h-6" />
            </div>
            Interactive Cooking Mode
          </h2>
          <div className="prose dark:prose-invert max-w-none text-gray-600 dark:text-gray-400">
            <p className="mb-4">
              Cook without touching your phone with messy hands.
            </p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>
                <strong>Start Cooking:</strong> Open any saved recipe and tap
                "Start Cooking".
              </li>
              <li>
                <strong>Voice Navigation:</strong> The app will read steps out
                loud. Say <em>"Next step"</em>, <em>"Repeat"</em>, or{" "}
                <em>"Go back"</em> to control the flow.
              </li>
              <li>
                <strong>Wake Lock:</strong> Your screen will stay on mainly
                during cooking mode so you don't have to keep unlocking it.
              </li>
            </ul>
          </div>
        </section>

        {/* Section 5: Shopping List */}
        <section id="shopping">
          <h2 className="text-2xl font-bold mb-6 flex items-center gap-3 pt-6 border-t border-gray-100 dark:border-gray-800">
            <div className="p-2 bg-blue-100 dark:bg-blue-900/20 text-blue-600 rounded-lg">
              <ShoppingCart className="w-6 h-6" />
            </div>
            Smart Shopping List
          </h2>
          <div className="prose dark:prose-invert max-w-none text-gray-600 dark:text-gray-400">
            <p className="mb-4">Never forget an ingredient.</p>
            <ul className="list-disc pl-6 space-y-2 mb-6">
              <li>
                <strong>One-Tap Add:</strong> When viewing a recipe, if you miss
                ingredients, tap "Add missing items to cart" to sync them
                instantly.
              </li>
              <li>
                <strong>Manual Add:</strong> Type items directly into the input
                field.
              </li>
              <li>
                <strong>Check It Off:</strong> Tap items to mark them as done.
                Use the "Clear Checked" button to tidy up your list after a
                shopping trip.
              </li>
            </ul>
          </div>
        </section>

        {/* Section 6: Household */}
        <section id="household">
          <h2 className="text-2xl font-bold mb-6 flex items-center gap-3 pt-6 border-t border-gray-100 dark:border-gray-800">
            <div className="p-2 bg-pink-100 dark:bg-pink-900/20 text-pink-600 rounded-lg">
              <Users className="w-6 h-6" />
            </div>
            Household Sharing
          </h2>
          <div className="prose dark:prose-invert max-w-none text-gray-600 dark:text-gray-400">
            <p className="mb-4">
              Manage your kitchen with family or roommates.
            </p>
            <p className="mb-4">
              Create a Household in settings and invite others via email. Once
              joined:
            </p>
            <ul className="list-disc pl-6 space-y-2 mb-4">
              <li>
                <strong>Shared Pantry:</strong> Everyone sees and updates the
                same inventory.
              </li>
              <li>
                <strong>Shared Shopping List:</strong> Add items to the list and
                your partner sees them instantly.
              </li>
              <li>
                <strong>Recipe Vault:</strong> You have a "Personal Vault" and a
                "Household Vault". Shared recipes are visible to everyone.
              </li>
            </ul>
          </div>
        </section>

        {/* Section 7: Premium */}
        <section id="premium">
          <h2 className="text-2xl font-bold mb-6 flex items-center gap-3 pt-6 border-t border-gray-100 dark:border-gray-800">
            <div className="p-2 bg-amber-100 dark:bg-amber-900/20 text-amber-600 rounded-lg">
              <Star className="w-6 h-6" />
            </div>
            ChefMindAI Premium
          </h2>
          <div className="prose dark:prose-invert max-w-none text-gray-600 dark:text-gray-400">
            <p className="mb-4">
              Unlock the full potential with our paid tiers (Sous Chef &
              Executive Chef).
            </p>
            <div className="grid md:grid-cols-2 gap-4">
              <div className="bg-gray-50 dark:bg-gray-900 p-6 rounded-2xl border border-gray-200 dark:border-gray-800">
                <h4 className="font-bold mb-2">Free Plan</h4>
                <ul className="text-sm space-y-1">
                  <li>• Scanning: 5 scans / day</li>
                  <li>• AI Recipes: 3 generations / day</li>
                  <li>• Voice Mode: Limited steps</li>
                  <li>• 1 Household Member</li>
                </ul>
              </div>
              <div className="bg-emerald-50 dark:bg-emerald-900/10 p-6 rounded-2xl border border-emerald-200 dark:border-emerald-800">
                <h4 className="font-bold mb-2 text-emerald-700 dark:text-emerald-400">
                  Premium Plans
                </h4>
                <ul className="text-sm space-y-1">
                  <li>• Unlimited Vision Scanning</li>
                  <li>• Unlimited AI Recipe Generation</li>
                  <li>• Full Voice Command access</li>
                  <li>• Multiple Household Members</li>
                  <li>• Priority Support</li>
                </ul>
              </div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
