import React from "react";
import Link from "next/link";

export default function Header() {
  return (
    <header className="border-b border-gray-100 bg-white/80 backdrop-blur-md sticky top-0 z-50">
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <Link
          href="/"
          className="flex items-center gap-2 font-bold text-xl text-emerald-600"
        >
          <span>👨‍🍳 ChefMind AI</span>
        </Link>
        <nav className="flex items-center gap-6 text-sm font-medium text-gray-600">
          <Link href="/" className="hover:text-emerald-600 transition-colors">
            Home
          </Link>
          <Link
            href="/privacy-policy"
            className="hover:text-emerald-600 transition-colors"
          >
            Privacy
          </Link>
          <Link
            href="/terms"
            className="hover:text-emerald-600 transition-colors"
          >
            Terms
          </Link>
        </nav>
      </div>
    </header>
  );
}
