import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

const WRITE_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  if (!pathname.startsWith("/api/books")) {
    return NextResponse.next();
  }

  if (WRITE_METHODS.has(request.method)) {
    return NextResponse.json(
      { error: "Method not allowed." },
      { status: 405 },
    );
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/api/books", "/api/books/:path*"],
};
