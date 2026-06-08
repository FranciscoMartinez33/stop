"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useParams, useRouter } from "next/navigation";
import type { GameState } from "@/lib/game";

const LETTERS = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","Y","?"];
const TURN_T = 15;

function usePlayerId(code: string) {
  return typeof window !== "undefined" ? localStorage.getItem(`stop_player_${code}`) ?? "" : "";
}

export default function GamePage() {
  const { code } = useParams<{ code: string }>();
  const router = useRouter();
  const [game, setGame] = useState<GameState | null>(null);
  const [error, setError] = useState("");
  const [toast, setToast] = useState<{ msg: string; ok: boolean } | null>(null);
  const [wordInput, setWordInput] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [maxPen, setMaxPen] = useState(3);
  const [timeLeft, setTimeLeft] = useState(TURN_T);
  const playerId = usePlayerId(code);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const timeoutSentRef = useRef(false);

  const showToast = useCallback((msg: string, ok = true) => {
    setToast({ msg, ok });
    setTimeout(() => setToast(null), 3000);
  }, []);

  const fetchGame = useCallback(async () => {
    try {
      const res = await fetch(`/api/games/${code}`);
      if (res.status === 404) { setError("Game not found"); return; }
      const data: GameState = await res.json();
      setGame(data);
      if (data.phase === "PLAYING") {
        const elapsed = (Date.now() - data.turnStartedAt) / 1000;
        const remaining = Math.max(0, TURN_T - elapsed);
        setTimeLeft(remaining);
        timeoutSentRef.current = false;
      }
    } catch { /* network error */ }
  }, [code]);

  useEffect(() => {
    if (!playerId) { router.push("/"); return; }
    fetchGame();
    pollRef.current = setInterval(fetchGame, 2000);
    return () => { if (pollRef.current) clearInterval(pollRef.current); };
  }, [fetchGame, playerId, router]);

  // Client-side countdown
  useEffect(() => {
    if (timerRef.current) clearInterval(timerRef.current);
    if (game?.phase !== "PLAYING") return;
    timerRef.current = setInterval(() => {
      setTimeLeft(prev => {
        const next = Math.max(0, prev - 0.1);
        return next;
      });
    }, 100);
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
  }, [game?.phase, game?.turnStartedAt]);

  // Send timeout when timer hits 0
  useEffect(() => {
    if (game?.phase !== "PLAYING") return;
    if (timeLeft > 0) return;
    if (timeoutSentRef.current) return;
    timeoutSentRef.current = true;
    fetch(`/api/games/${code}/move`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ playerId, timeout: true }),
    }).then(() => fetchGame());
  }, [timeLeft, game?.phase, code, playerId, fetchGame]);

  async function post(path: string, body: object) {
    setSubmitting(true);
    try {
      const res = await fetch(`/api/games/${code}${path}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const data = await res.json();
      if (!res.ok) { showToast(data.error, false); return false; }
      await fetchGame();
      return true;
    } finally {
      setSubmitting(false);
    }
  }

  async function handleStart(mode: "CLASSIC" | "WORLD_CUP") {
    await post("/start", { playerId, mode, maxPenalties: maxPen });
  }

  async function handlePickCard(idx: 0 | 1) {
    await post("/card", { playerId, idx });
  }

  async function handleSubmitWord(e: React.FormEvent) {
    e.preventDefault();
    const w = wordInput.trim();
    if (!w) return;
    setWordInput("");
    const ok = await post("/move", { playerId, word: w });
    if (ok) showToast("✓ " + w.toUpperCase());
  }

  async function handleWrong() {
    await post("/move", { playerId, word: "", timeout: false });
  }

  if (error) return (
    <Center>
      <div className="card" style={{ textAlign: "center" }}>
        <div style={{ color: "#ff8888", fontSize: "1.2rem", marginBottom: "1rem" }}>{error}</div>
        <button className="btn btn-red" onClick={() => router.push("/")}>Back to Home</button>
      </div>
    </Center>
  );

  if (!game) return <Center><div style={{ color: "var(--text-muted)" }}>Connecting…</div></Center>;

  const isMine = (idx: number) => game.players[idx]?.id === playerId;
  const curIsMe = isMine(game.curPlayer);
  const isHost = game.hostId === playerId;

  return (
    <div style={{ maxWidth: 900, margin: "0 auto", padding: "1rem" }}>
      {toast && <div className={`toast ${toast.ok ? "toast-ok" : "toast-err"}`}>{toast.msg}</div>}

      {/* Header */}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "1rem" }}>
        <div className="title-stop" style={{ fontSize: "1.8rem" }}>STOP!</div>
        <div style={{ background: "var(--gray-mid)", border: "1px solid var(--gray-border)", borderRadius: 8, padding: ".4rem 1rem" }}>
          <span style={{ color: "var(--text-muted)", fontSize: ".75rem" }}>GAME CODE</span>
          <div style={{ fontWeight: 900, fontSize: "1.4rem", letterSpacing: 4 }}>{code}</div>
        </div>
      </div>

      {/* LOBBY */}
      {game.phase === "LOBBY" && (
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem", alignItems: "start" }}>
          <div className="card">
            <div style={{ fontWeight: 700, marginBottom: "1rem", color: "var(--text-muted)", fontSize: ".85rem" }}>PLAYERS ({game.players.length}/8)</div>
            {game.players.map((p, i) => (
              <div key={p.id} style={{ display: "flex", alignItems: "center", gap: ".5rem", marginBottom: ".5rem" }}>
                <div style={{ width: 8, height: 8, borderRadius: "50%", background: i === 0 ? "var(--yellow)" : "var(--green)" }} />
                <span style={{ fontWeight: p.id === playerId ? 700 : 400 }}>
                  {p.name} {i === 0 ? "(host)" : ""} {p.id === playerId ? "← you" : ""}
                </span>
              </div>
            ))}
            <div style={{ marginTop: "1rem", color: "var(--text-muted)", fontSize: ".8rem" }}>
              Share code <strong>{code}</strong> to invite players
            </div>
          </div>

          <div className="card">
            {isHost ? (
              <>
                <div style={{ fontWeight: 700, marginBottom: ".5rem" }}>Choose Game Mode</div>
                <div style={{ color: "var(--text-muted)", fontSize: ".85rem", marginBottom: "1.5rem" }}>
                  At least 2 players needed to start
                </div>
                <button
                  className="btn btn-red btn-big"
                  style={{ marginBottom: ".75rem" }}
                  disabled={game.players.length < 2 || submitting}
                  onClick={() => handleStart("CLASSIC")}
                >
                  CLASSIC
                </button>
                <button
                  className="btn btn-green btn-big"
                  disabled={game.players.length < 2 || submitting}
                  onClick={() => handleStart("WORLD_CUP")}
                >
                  ⚽ WORLD CUP 2026
                </button>
                <div style={{ marginTop: "1rem" }}>
                  <label style={{ color: "var(--text-muted)", fontSize: ".8rem" }}>PENALTIES TO LOSE</label>
                  <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginTop: ".5rem" }}>
                    <button className="btn btn-ghost" onClick={() => setMaxPen(p => Math.max(1, p - 1))}>−</button>
                    <span style={{ fontWeight: 700, fontSize: "1.3rem", color: "#ff8888" }}>{maxPen}</span>
                    <button className="btn btn-ghost" onClick={() => setMaxPen(p => Math.min(10, p + 1))}>+</button>
                  </div>
                </div>
              </>
            ) : (
              <div style={{ textAlign: "center", paddingTop: "2rem", color: "var(--text-muted)" }}>
                <div style={{ fontSize: "1.5rem", marginBottom: ".5rem" }}>⏳</div>
                Waiting for host to start the game…
              </div>
            )}
          </div>
        </div>
      )}

      {/* CARD SELECTION */}
      {game.phase === "CARD_SELECT" && game.cardOptions && (
        <div>
          {game.lastMove && (
            <LastMoveBar move={game.lastMove} players={game.players} maxPen={game.maxPenalties} penalties={game.penalties} />
          )}
          <div style={{ textAlign: "center", marginBottom: "1rem", color: "var(--text-muted)" }}>
            {curIsMe
              ? "Pick a topic card for this round:"
              : `Waiting for ${game.players[game.curPlayer]?.name} to pick a topic…`}
          </div>
          <div style={{ display: "flex", gap: "1rem", justifyContent: "center" }}>
            {game.cardOptions.map((topic, i) => (
              <button
                key={i}
                onClick={() => curIsMe && !submitting && handlePickCard(i as 0 | 1)}
                disabled={!curIsMe || submitting}
                style={{
                  flex: 1,
                  maxWidth: 280,
                  padding: "2.5rem 1.5rem",
                  background: curIsMe ? "var(--red-dark)" : "var(--gray-mid)",
                  border: `2px solid ${curIsMe ? "var(--red-border)" : "var(--gray-border)"}`,
                  borderRadius: 14,
                  color: "var(--white)",
                  fontSize: "1.1rem",
                  fontWeight: 700,
                  cursor: curIsMe ? "pointer" : "default",
                  transition: "background .15s",
                  textAlign: "center",
                  lineHeight: 1.3,
                }}
                onMouseEnter={e => { if (curIsMe) (e.currentTarget as HTMLButtonElement).style.background = "var(--red)"; }}
                onMouseLeave={e => { if (curIsMe) (e.currentTarget as HTMLButtonElement).style.background = "var(--red-dark)"; }}
              >
                {topic}
              </button>
            ))}
          </div>
          <Scoreboard game={game} playerId={playerId} />
        </div>
      )}

      {/* PLAYING */}
      {game.phase === "PLAYING" && (
        <div style={{ display: "grid", gridTemplateColumns: "1fr 260px", gap: "1rem" }}>
          <div>
            {/* Status bar */}
            <div className="card" style={{ marginBottom: "1rem", padding: "1rem" }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: ".5rem" }}>
                <div>
                  <span style={{ color: "var(--text-muted)", fontSize: ".85rem" }}>TOPIC: </span>
                  <strong style={{ color: "var(--yellow)" }}>{game.topic}</strong>
                </div>
                <div style={{ color: "var(--text-muted)", fontSize: ".85rem" }}>
                  {LETTERS.filter(l => l !== "?" && !game.blocked.includes(l)).length} letters left
                </div>
              </div>
              {/* Timer */}
              <div className="timer-track">
                <div
                  className="timer-fill"
                  style={{
                    width: `${(timeLeft / TURN_T) * 100}%`,
                    background: timeLeft > 8 ? "var(--green)" : timeLeft > 4 ? "var(--yellow)" : "var(--red)",
                  }}
                />
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", marginTop: ".3rem", fontSize: ".8rem", color: "var(--text-muted)" }}>
                <span>{curIsMe ? "⏱ Your turn!" : `${game.players[game.curPlayer]?.name}'s turn`}</span>
                <span style={{ color: timeLeft < 5 ? "#ff8888" : "inherit" }}>{Math.ceil(timeLeft)}s</span>
              </div>
            </div>

            {/* Last move banner */}
            {game.lastMove && (
              <LastMoveBar move={game.lastMove} players={game.players} maxPen={game.maxPenalties} penalties={game.penalties} />
            )}

            {/* Letter board */}
            <div className="card" style={{ marginBottom: "1rem" }}>
              <div className="board-grid">
                {LETTERS.map(l => {
                  const blocked = game.blocked.includes(l);
                  const isWild = l === "?";
                  const usedLast = game.lastMove?.usedLetter === l;
                  return (
                    <div
                      key={l}
                      className={`letter-btn ${isWild ? "wildcard" : ""} ${blocked ? "blocked" : ""} ${usedLast && !blocked ? "used-last" : ""}`}
                      style={{
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "center",
                        padding: ".5rem",
                      }}
                    >
                      {l}
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Word input (current player only) */}
            {curIsMe && (
              <form className="card" onSubmit={handleSubmitWord} style={{ padding: "1rem" }}>
                <div style={{ fontSize: ".85rem", color: "var(--text-muted)", marginBottom: ".5rem" }}>
                  Type a word for: <strong style={{ color: "var(--yellow)" }}>{game.topic}</strong>
                </div>
                <div style={{ display: "flex", gap: ".5rem" }}>
                  <input
                    className="input"
                    placeholder="Your word…"
                    value={wordInput}
                    onChange={e => setWordInput(e.target.value)}
                    autoFocus
                    autoComplete="off"
                    style={{ flex: 1 }}
                  />
                  <button className="btn btn-red" type="submit" disabled={submitting || !wordInput.trim()}>
                    Submit
                  </button>
                </div>
                <button
                  type="button"
                  className="btn btn-ghost"
                  style={{ width: "100%", marginTop: ".5rem" }}
                  onClick={handleWrong}
                  disabled={submitting}
                >
                  ⚠ Wrong Word / Pass
                </button>
              </form>
            )}

            {!curIsMe && (
              <div className="card" style={{ textAlign: "center", padding: "1.5rem", color: "var(--text-muted)" }}>
                Waiting for <strong style={{ color: "var(--white)" }}>{game.players[game.curPlayer]?.name}</strong> to play…
              </div>
            )}
          </div>

          {/* Sidebar: Scoreboard */}
          <div>
            <Scoreboard game={game} playerId={playerId} />
          </div>
        </div>
      )}

      {/* GAME OVER */}
      {game.phase === "GAME_OVER" && (
        <Center>
          <div className="card" style={{ width: "100%", maxWidth: 480, textAlign: "center" }}>
            <div style={{ fontSize: "2.5rem", fontWeight: 900, color: "var(--red)", marginBottom: ".25rem" }}>
              GAME OVER
            </div>
            <div style={{ color: "var(--text-muted)", marginBottom: "1.5rem" }}>Final Scoreboard</div>
            <table className="score-table" style={{ marginBottom: "1.5rem" }}>
              <thead>
                <tr>
                  <th style={{ textAlign: "left", color: "var(--text-muted)", fontWeight: 400, paddingBottom: ".5rem" }}>Player</th>
                  <th style={{ color: "var(--text-muted)", fontWeight: 400 }}>Penalties</th>
                </tr>
              </thead>
              <tbody>
                {game.players.map((p, i) => {
                  const pen = game.penalties[i] ?? 0;
                  const out = pen >= game.maxPenalties;
                  return (
                    <tr key={p.id} style={{ color: out ? "#ff4444" : "var(--white)" }}>
                      <td style={{ textAlign: "left" }}>
                        {p.name} {p.id === playerId ? "(you)" : ""}
                      </td>
                      <td style={{ textAlign: "center" }}>
                        {Array.from({ length: game.maxPenalties }, (_, d) => d < pen ? "●" : "○").join(" ")}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
            <button className="btn btn-red btn-big" onClick={() => router.push("/")}>
              ↩ New Game
            </button>
          </div>
        </Center>
      )}
    </div>
  );
}

function Scoreboard({ game, playerId }: { game: GameState; playerId: string }) {
  return (
    <div className="card" style={{ marginTop: "1rem" }}>
      <div style={{ color: "var(--text-muted)", fontSize: ".8rem", marginBottom: ".5rem" }}>SCOREBOARD</div>
      <table className="score-table">
        <tbody>
          {game.players.map((p, i) => {
            const pen = game.penalties[i] ?? 0;
            const isCur = i === game.curPlayer && game.phase === "PLAYING";
            const isMe = p.id === playerId;
            return (
              <tr key={p.id} className={isCur ? "active-row" : ""}>
                <td style={{ textAlign: "left" }}>
                  {isCur ? "▶ " : "   "}{p.name}{isMe ? " (you)" : ""}
                </td>
                <td style={{ textAlign: "right", color: "#ff8888" }}>
                  {pen > 0 ? Array.from({ length: game.maxPenalties }, (_, d) => d < pen ? "●" : "○").join("") : ""}
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}

function LastMoveBar({ move, players, maxPen, penalties }: {
  move: NonNullable<GameState["lastMove"]>;
  players: GameState["players"];
  maxPen: number;
  penalties: number[];
}) {
  const color = move.result === "correct" ? "var(--green)" : "#ff4444";
  const icon = move.result === "correct" ? "✓" : "✗";
  return (
    <div style={{
      background: move.result === "correct" ? "#0a2e0a" : "#2e0a0a",
      border: `1px solid ${color}`,
      borderRadius: 8,
      padding: ".6rem 1rem",
      marginBottom: "1rem",
      display: "flex",
      alignItems: "center",
      gap: ".75rem",
      fontSize: ".9rem",
    }}>
      <span style={{ color, fontWeight: 700, fontSize: "1.2rem" }}>{icon}</span>
      <span>
        <strong>{move.playerName}</strong>{" "}
        {move.result === "correct"
          ? <>played <strong style={{ color: "var(--yellow)" }}>{move.word}</strong> → <strong>{move.usedLetter}</strong> blocked</>
          : move.result === "timeout"
          ? "ran out of time"
          : <>submitted <strong style={{ color: "#ff8888" }}>{move.word || "invalid word"}</strong></>
        }
        {move.result !== "correct" && (
          <span style={{ color: "#ff8888" }}>
            {" "}({penalties[move.playerIdx]}/{maxPen} penalties)
          </span>
        )}
      </span>
    </div>
  );
}

function Center({ children }: { children: React.ReactNode }) {
  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "80vh" }}>
      {children}
    </div>
  );
}
