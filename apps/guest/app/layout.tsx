import type { Metadata } from "next";
import "./style.css";

export const metadata: Metadata = {
  title: "EatMe · Dinner RSVP",
  description: "Private dinner RSVP and food preference form.",
  robots: { index: false, follow: false, nocache: true },
};

export default function Layout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
