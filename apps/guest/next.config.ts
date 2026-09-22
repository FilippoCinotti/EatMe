import type { NextConfig } from "next";

const api = process.env.NEXT_PUBLIC_API_URL ?? "http://127.0.0.1:8000/api/v1";
const connectOrigin = new URL(api).origin;

const config: NextConfig = {
  poweredByHeader: false,
  output: "standalone",
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "Cache-Control", value: "private, no-store, max-age=0" },
          { key: "X-Robots-Tag", value: "noindex, nofollow, noarchive" },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "no-referrer" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), geolocation=(), payment=()" },
          {
            key: "Content-Security-Policy",
            value:
              "default-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'; " +
              "object-src 'none'; img-src 'self' data:; font-src 'self'; " +
              "style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; " +
              `connect-src 'self' ${connectOrigin}`,
          },
          ...(process.env.ENABLE_HSTS === "true"
            ? [{ key: "Strict-Transport-Security", value: "max-age=31536000; includeSubDomains" }]
            : []),
        ],
      },
    ];
  },
};

export default config;
