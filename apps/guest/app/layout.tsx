import type { Metadata, Viewport } from "next";
import localFont from "next/font/local";
import "./style.css";

// The app's own typefaces (see docs/product/visual-design.md), self-hosted so
// the guest page needs no third-party font request. Licenses: app/fonts/.
const display = localFont({
  src: "./fonts/EatMeDisplay-Bold.ttf",
  weight: "700",
  variable: "--font-display",
  display: "swap",
  fallback: ["Georgia", "Times New Roman", "serif"],
});
const sans = localFont({
  src: [
    { path: "./fonts/EatMeSans-Regular.ttf", weight: "400" },
    { path: "./fonts/EatMeSans-Bold.ttf", weight: "700" },
  ],
  variable: "--font-sans",
  display: "swap",
  fallback: ["ui-sans-serif", "system-ui", "-apple-system", "Segoe UI", "sans-serif"],
});

export const metadata: Metadata = {
  title: "EatMe+ · Dinner RSVP",
  description: "Private dinner RSVP and food preference form.",
  robots: { index: false, follow: false, nocache: true },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f8f9f5" },
    { media: "(prefers-color-scheme: dark)", color: "#101413" },
  ],
};

export default function Layout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html className={`${display.variable} ${sans.variable}`} lang="en">
      <body>{children}</body>
    </html>
  );
}
