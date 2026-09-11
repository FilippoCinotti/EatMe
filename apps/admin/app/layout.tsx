import type { Metadata } from 'next';
import './style.css';
export const metadata: Metadata = { title: 'EatMe · Content review', robots: { index: false, follow: false } };
export default function Layout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="it"><body>{children}</body></html>;
}
