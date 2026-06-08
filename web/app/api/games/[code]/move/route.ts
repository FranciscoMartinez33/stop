import { NextRequest, NextResponse } from "next/server";
import { applyMove } from "@/lib/game";
import { getGame, saveGame } from "@/lib/redis";

export async function POST(
  req: NextRequest,
  { params }: { params: { code: string } }
) {
  const { playerId, word, timeout } = await req.json();

  const state = await getGame(params.code.toUpperCase());
  if (!state) return NextResponse.json({ error: "Game not found" }, { status: 404 });

  const result = applyMove(state, playerId, word ?? "", !!timeout);
  if (typeof result === "string") return NextResponse.json({ error: result }, { status: 400 });

  await saveGame(result);
  return NextResponse.json({ ok: true });
}
