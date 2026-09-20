import type { Metadata } from 'next';
import './style.css';

export const metadata: Metadata = {
  title: {default: 'EatMe+', template: '%s · EatMe+'},
  description: 'Your recipes, your fridge, your diet — one thoughtful decision.',
};

export default function Layout({children}: Readonly<{children: React.ReactNode}>) {
  return <html lang="en"><body>{children}</body></html>;
}
