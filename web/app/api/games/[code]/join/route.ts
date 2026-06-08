import { NextRequest, NextResponse } from "next/server";
import { joinGame } from "@/lib/game";
import { getGame, saveGame } from "@/lib/redis";

export async function POST(
  req: NextRequest,
  { params }: { params: { code: string } }
) {
  const { name } = await req.json();
  if (!name?.trim()) return NextResponse.json({ error: "Name required" }, { status: 400 });

  const state = await getGame(params.code.toUpperCase());
  if (!state) return NextResponse.json({ error: "Game not found" }, { status: 404 });

  const playerId = crypto.randomUUID();
  const result = joinGame(state, playerId, name.trim().slice(0, 20));
  if (typeof result === "string") return NextResponse.json({ error: result }, { status: 400 });

  await saveGame(result);
  return NextResponse.json({ playerId });
}
