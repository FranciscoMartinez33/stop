import { NextRequest, NextResponse } from "next/server";
import { getGame } from "@/lib/redis";

export async function GET(
  _req: NextRequest,
  { params }: { params: { code: string } }
) {
  const state = await getGame(params.code.toUpperCase());
  if (!state) return NextResponse.json({ error: "Game not found" }, { status: 404 });
  return NextResponse.json(state);
}
