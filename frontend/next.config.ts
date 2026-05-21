import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async rewrites() {
    const api =
      process.env.INTERNAL_API_URL?.replace(/\/$/, "") ??
      process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, "") ??
      "http://localhost:3000";
    return [
      {
        source: "/api/:path*",
        destination: `${api}/:path*`,
      },
    ];
  },
};

export default nextConfig;
