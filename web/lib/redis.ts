import { Redis } from "@upstash/redis";
import type { GameState } from "./game";

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

const TTL = 60 * 60 * 4; // 4 hours

export async function getGame(code: string): Promise<GameState | null> {
  return redis.get<GameState>(`game:${code}`);
}

export async function saveGame(state: GameState): Promise<void> {
  await redis.set(`game:${state.code}`, state, { ex: TTL });
}

export async function deleteGame(code: string): Promise<void> {
  await redis.del(`game:${code}`);
}
