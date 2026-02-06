import React from "react";
import Link from "next/link";
import Image from "next/image";

export default function Header() {
  return (
    <header className="border-b border-gray-100 dark:border-gray-800 bg-white/80 dark:bg-black/80 backdrop-blur-md sticky top-0 z-50">
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <Link
          href="/"
          className="flex items-center gap-2 font-bold text-xl text-emerald-600 dark:text-emerald-500"
        >
          <div className="relative w-12 h-12 rounded-full overflow-hidden shadow-sm">
            <Image
              src="/logo.png"
              alt="ChefMindAI Logo"
              fill
              className="object-cover rounded-full"
            />
          </div>
          <span>ChefMindAI</span>
        </Link>
        <nav className="flex items-center gap-6 text-sm font-medium text-gray-600 dark:text-gray-300">
          <Link
            href="/"
            className="hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
          >
            Home
          </Link>
          <Link
            href="/privacy-policy"
            className="hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
          >
            Privacy
          </Link>
          <Link
            href="/terms"
            className="hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
          >
            Terms
          </Link>
          <Link
            href="/guide"
            className="hover:text-emerald-600 dark:hover:text-emerald-400 transition-colors"
          >
            Guide
          </Link>
        </nav>
      </div>
    </header>
  );
}
