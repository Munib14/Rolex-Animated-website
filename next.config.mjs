/**
 * `next dev` and `next build` both write to the same output directory by
 * default, so running a build while the dev server is up leaves it serving a
 * broken mix of development and production artifacts. Giving each its own
 * directory means the two can safely run side by side.
 *
 * `next dev` runs with NODE_ENV=development; `next build` and `next start`
 * both run with NODE_ENV=production, so start still reads what build wrote.
 */
const distDir = process.env.NODE_ENV === "development" ? ".next-dev" : ".next";

/** @type {import('next').NextConfig} */
const nextConfig = {
  distDir,
  reactStrictMode: true,
  poweredByHeader: false,
  async headers() {
    return [
      {
        // Videos are immutable build assets: cache hard so re-visits and
        // back/forward navigation never re-download or stall the scrub.
        source: "/videos/:path*",
        headers: [
          { key: "Cache-Control", value: "public, max-age=31536000, immutable" },
        ],
      },
    ];
  },
};

export default nextConfig;
