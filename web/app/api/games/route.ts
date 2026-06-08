import { NextRequest, NextResponse } from "next/server";
import { newGame } from "@/lib/game";
import { saveGame } from "@/lib/redis";
import { getGame } from "@/lib/redis";

function genCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXY";
  return Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join("");
}

export async function POST(req: NextRequest) {
  const { name } = await req.json();
  if (!name?.trim()) return NextResponse.json({ error: "Name required" }, { status: 400 });

  const playerId = crypto.randomUUID();
  let code = genCode();
  // avoid collision (best-effort)
  for (let i = 0; i < 5; i++) {
    const existing = await getGame(code);
    if (!existing) break;
    code = genCode();
  }

  const state = newGame(playerId, name.trim().slice(0, 20));
  state.code = code;
  await saveGame(state);

  return NextResponse.json({ code, playerId });
}
