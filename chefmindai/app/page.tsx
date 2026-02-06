"use client";

import React from "react";
import Link from "next/link";
import Image from "next/image";
import QRCode from "react-qr-code";
import { motion } from "framer-motion";
import {
  ArrowRight,
  ChefHat,
  ScanLine,
  Calendar,
  Smartphone,
  Sparkles,
  ShoppingCart,
} from "lucide-react";

export default function Home() {
  const oneLinkUrl = "https://onelink.to/853e9h";

  return (
    <div className="flex flex-col min-h-screen bg-white dark:bg-black text-gray-900 dark:text-gray-100 overflow-hidden">
      {/* Hero Section */}
      <section className="relative pt-32 pb-20 px-6 lg:px-12 max-w-7xl mx-auto w-full">
        {/* Decorative Gradients */}
        <div className="absolute top-0 right-0 -z-10 w-[600px] h-[600px] bg-emerald-500/10 rounded-full blur-[120px]" />
        <div className="absolute bottom-0 left-0 -z-10 w-[500px] h-[500px] bg-teal-500/10 rounded-full blur-[100px]" />

        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Text Content */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="flex flex-col items-start text-left"
          >
            <div className="inline-flex items-center gap-2 px-3 py-1 bg-emerald-100 dark:bg-emerald-900/30 text-emerald-800 dark:text-emerald-300 rounded-full text-sm font-semibold mb-6">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
              </span>
              v1.0 is Live
            </div>

            <h1 className="text-5xl md:text-7xl font-bold tracking-tight mb-6 leading-tight">
              Your Kitchen, <br />
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-emerald-600 to-teal-500">
                Reimagined.
              </span>
            </h1>
            <p className="text-xl text-gray-600 dark:text-gray-400 mb-8 max-w-lg leading-relaxed">
              Stop wondering "what's for dinner?". Scan your pantry, generate AI
              recipes instantly, and plan your week with ChefMindAI.
            </p>

            <div className="flex flex-wrap gap-4 items-center">
              <Link
                href={oneLinkUrl}
                className="group flex items-center gap-3 bg-emerald-600 hover:bg-emerald-700 text-white px-8 py-3.5 rounded-full font-semibold transition-all shadow-lg hover:shadow-emerald-500/30"
              >
                <Smartphone className="w-5 h-5" />
                <span>Get the App</span>
                <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
              </Link>
            </div>

            {/* QR Code (Mobile Only Helper) */}
            <div className="mt-8 hidden lg:flex items-center gap-4 bg-gray-50 dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-4 rounded-xl">
              <div className="bg-white p-2 rounded-lg">
                <QRCode
                  value={oneLinkUrl}
                  size={64}
                  style={{ height: "auto", maxWidth: "100%", width: "100%" }}
                />
              </div>
              <div className="text-sm text-gray-500 dark:text-gray-400">
                <p className="font-semibold text-gray-900 dark:text-white">
                  Scan to Install
                </p>
                <p>Available on iOS & Android</p>
              </div>
            </div>
          </motion.div>

          {/* Hero Visual (Mockup Placeholder) */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.8, delay: 0.2 }}
            className="relative lg:h-[600px] flex items-center justify-center"
          >
            <div className="relative w-[300px] h-[600px] bg-gray-100 dark:bg-gray-800 border-[8px] border-gray-900 dark:border-gray-700 rounded-[3rem] shadow-2xl overflow-hidden">
              {/* Simulated Screen */}
              <div className="absolute inset-0 bg-white dark:bg-gray-900 flex flex-col">
                {/* Top Bar */}
                <div className="h-24 bg-gradient-to-b from-emerald-500/20 to-transparent p-6 flex justify-between items-center">
                  <div className="w-8 h-8 rounded-full bg-emerald-100 dark:bg-emerald-900" />
                  <div className="w-20 h-4 rounded-full bg-gray-200 dark:bg-gray-700" />
                </div>
                {/* Content Area */}
                <div className="p-6 space-y-4">
                  <div className="h-40 rounded-2xl bg-gray-100 dark:bg-gray-800 animate-pulse" />
                  <div className="flex gap-2">
                    <div className="h-24 w-1/2 rounded-2xl bg-emerald-50 dark:bg-emerald-900/20" />
                    <div className="h-24 w-1/2 rounded-2xl bg-teal-50 dark:bg-teal-900/20" />
                  </div>
                  <div className="space-y-2 pt-4">
                    <div className="h-4 w-3/4 rounded bg-gray-200 dark:bg-gray-700" />
                    <div className="h-4 w-1/2 rounded bg-gray-100 dark:bg-gray-800" />
                  </div>
                </div>
                {/* Floating Action Button */}
                <div className="absolute bottom-8 right-6 w-14 h-14 bg-emerald-600 rounded-full shadow-lg flex items-center justify-center text-white">
                  <ChefHat className="w-7 h-7" />
                </div>
              </div>
            </div>
            {/* Floating Elements */}
            <motion.div
              animate={{ y: [0, -10, 0] }}
              transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
              className="absolute top-20 right-10 bg-white dark:bg-gray-800 p-4 rounded-xl shadow-xl border border-gray-100 dark:border-gray-700"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 bg-orange-100 dark:bg-orange-900/30 text-orange-600 rounded-lg">
                  <ScanLine size={20} />
                </div>
                <div>
                  <p className="text-xs text-gray-500 font-medium">Scan</p>
                  <p className="font-bold text-sm">Pantry Items</p>
                </div>
              </div>
            </motion.div>

            {/* Floating Elements - Label 2 (Generate) */}
            <motion.div
              animate={{ y: [0, 10, 0] }} // Opposite float direction
              transition={{
                duration: 4.5, // Slightly different duration
                repeat: Infinity,
                ease: "easeInOut",
                delay: 0.5,
              }}
              className="absolute top-40 -left-6 bg-white dark:bg-gray-800 p-4 rounded-xl shadow-xl border border-gray-100 dark:border-gray-700 z-10"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 rounded-lg">
                  <Sparkles size={20} />
                </div>
                <div>
                  <p className="text-xs text-gray-500 font-medium">Generate</p>
                  <p className="font-bold text-sm">Unique Recipes</p>
                </div>
              </div>
            </motion.div>

            {/* Floating Elements - Label 3 (Shopping) */}
            <motion.div
              animate={{ y: [0, -8, 0] }}
              transition={{
                duration: 5,
                repeat: Infinity,
                ease: "easeInOut",
                delay: 1.2,
              }}
              className="absolute bottom-32 -right-8 bg-white dark:bg-gray-800 p-4 rounded-xl shadow-xl border border-gray-100 dark:border-gray-700 z-10"
            >
              <div className="flex items-center gap-3">
                <div className="p-2 bg-blue-100 dark:bg-blue-900/30 text-blue-600 rounded-lg">
                  <ShoppingCart size={20} />
                </div>
                <div>
                  <p className="text-xs text-gray-500 font-medium">Smart</p>
                  <p className="font-bold text-sm">Shopping List</p>
                </div>
              </div>
            </motion.div>
          </motion.div>
        </div>
      </section>

      {/* Bento Grid Features */}
      <section className="py-24 px-6 bg-gray-50 dark:bg-gray-900/50">
        <div className="max-w-6xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl font-bold mb-4">Master Your Meals</h2>
            <p className="text-gray-500 max-w-2xl mx-auto">
              ChefMindAI combines powerful computer vision with advanced
              generative AI to solve your daily cooking challenges.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Feature 1 - Scanner */}
            <div className="md:col-span-2 p-8 rounded-3xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 hover:border-emerald-500/30 transition-colors shadow-sm">
              <div className="w-12 h-12 bg-purple-100 dark:bg-purple-900/20 text-purple-600 rounded-2xl flex items-center justify-center mb-6">
                <ScanLine className="w-6 h-6" />
              </div>
              <h3 className="text-2xl font-bold mb-3">Vision Pantry Scanner</h3>
              <p className="text-gray-500 dark:text-gray-400 mb-6 max-w-md">
                Don't type. Just snap. Our advanced scanner recognizes thousands
                of ingredients instantly, populating your digital pantry in
                seconds.
              </p>
            </div>

            {/* Feature 2 - AI Chef */}
            <div className="p-8 rounded-3xl bg-gradient-to-br from-emerald-600 to-teal-700 text-white shadow-lg">
              <ChefHat className="w-10 h-10 mb-6 opacity-90" />
              <h3 className="text-2xl font-bold mb-3">AI Chef</h3>
              <p className="text-emerald-50 opacity-90">
                Generate unique recipes based ONLY on what you have. No more
                grocery runs.
              </p>
            </div>

            {/* Feature 3 - Planning */}
            <div className="p-8 rounded-3xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 hover:border-emerald-500/30 transition-colors shadow-sm">
              <div className="w-12 h-12 bg-blue-100 dark:bg-blue-900/20 text-blue-600 rounded-2xl flex items-center justify-center mb-6">
                <Calendar className="w-6 h-6" />
              </div>
              <h3 className="text-xl font-bold mb-3">Smart Planning</h3>
              <p className="text-gray-500 dark:text-gray-400">
                Drag and drop recipes into your weekly calendar. We track
                nutrition automatically.
              </p>
            </div>

            {/* Feature 4 - Shopping */}
            <div className="md:col-span-2 p-8 rounded-3xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 hover:border-emerald-500/30 transition-colors shadow-sm flex items-center justify-between">
              <div>
                <h3 className="text-2xl font-bold mb-2">
                  Automated Shopping Lists
                </h3>
                <p className="text-gray-500 dark:text-gray-400">
                  Missing an ingredient? It's added to your list automatically.
                </p>
              </div>
              <div className="hidden sm:block text-6xl">🛒</div>
            </div>
          </div>
        </div>
      </section>

      {/* Download CTA */}
      <section className="py-24 px-6">
        <div className="max-w-4xl mx-auto bg-black dark:bg-emerald-950 rounded-[3rem] p-12 text-center text-white relative overflow-hidden">
          <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_top_right,_var(--tw-gradient-stops))] from-emerald-500/20 to-transparent" />

          <h2 className="text-4xl lg:text-5xl font-bold mb-6 relative z-10">
            Start Cooking Smarter.
          </h2>
          <p className="text-lg text-gray-400 mb-10 max-w-xl mx-auto relative z-10">
            Join thousands of home cooks saving time and reducing waste with
            ChefMindAI.
          </p>

          <div className="inline-block bg-white p-4 rounded-2xl relative z-10">
            <QRCode value={oneLinkUrl} size={120} />
            <p className="text-black text-xs font-bold mt-2 uppercase tracking-wide">
              Scan to Download
            </p>
          </div>
        </div>
      </section>
    </div>
  );
}
