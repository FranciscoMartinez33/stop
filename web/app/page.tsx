"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function Home() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [mode, setMode] = useState<"create" | "join">("create");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleCreate() {
    if (!name.trim()) return setError("Enter your name");
    setLoading(true);
    setError("");
    const res = await fetch("/api/games", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: name.trim() }),
    });
    const data = await res.json();
    if (!res.ok) { setError(data.error); setLoading(false); return; }
    localStorage.setItem(`stop_player_${data.code}`, data.playerId);
    router.push(`/game/${data.code}`);
  }

  async function handleJoin() {
    if (!name.trim()) return setError("Enter your name");
    if (!code.trim()) return setError("Enter the game code");
    const c = code.trim().toUpperCase();
    setLoading(true);
    setError("");
    const res = await fetch(`/api/games/${c}/join`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: name.trim() }),
    });
    const data = await res.json();
    if (!res.ok) { setError(data.error); setLoading(false); return; }
    localStorage.setItem(`stop_player_${c}`, data.playerId);
    router.push(`/game/${c}`);
  }

  return (
    <div style={{ display: "flex", alignItems: "center", justifyContent: "center", minHeight: "100vh", padding: "1rem" }}>
      <div className="card" style={{ width: "100%", maxWidth: 420 }}>
        <div className="title-stop" style={{ marginBottom: ".25rem" }}>STOP!</div>
        <div className="subtitle">Online Multiplayer · 2–8 Players</div>

        <div style={{ marginBottom: "1rem" }}>
          <label style={{ display: "block", marginBottom: ".4rem", color: "var(--text-muted)", fontSize: ".85rem" }}>
            YOUR NAME
          </label>
          <input
            className="input"
            placeholder="Enter your name"
            value={name}
            maxLength={20}
            onChange={e => setName(e.target.value)}
            onKeyDown={e => e.key === "Enter" && (mode === "create" ? handleCreate() : handleJoin())}
          />
        </div>

        <div style={{ display: "flex", gap: ".5rem", marginBottom: "1.5rem" }}>
          <button
            className={`btn ${mode === "create" ? "btn-red" : "btn-ghost"}`}
            style={{ flex: 1 }}
            onClick={() => setMode("create")}
          >
            Create Game
          </button>
          <button
            className={`btn ${mode === "join" ? "btn-red" : "btn-ghost"}`}
            style={{ flex: 1 }}
            onClick={() => setMode("join")}
          >
            Join Game
          </button>
        </div>

        {mode === "join" && (
          <div style={{ marginBottom: "1rem" }}>
            <label style={{ display: "block", marginBottom: ".4rem", color: "var(--text-muted)", fontSize: ".85rem" }}>
              GAME CODE
            </label>
            <input
              className="input"
              placeholder="e.g. XKBM"
              value={code}
              maxLength={4}
              onChange={e => setCode(e.target.value.toUpperCase())}
              onKeyDown={e => e.key === "Enter" && handleJoin()}
              style={{ textTransform: "uppercase", letterSpacing: "4px", fontSize: "1.3rem", textAlign: "center" }}
            />
          </div>
        )}

        {error && (
          <div style={{ color: "#ff8888", fontSize: ".9rem", marginBottom: ".75rem" }}>{error}</div>
        )}

        <button
          className="btn btn-red btn-big"
          disabled={loading}
          onClick={mode === "create" ? handleCreate : handleJoin}
        >
          {loading ? "…" : mode === "create" ? "Create Game" : "Join Game"}
        </button>

        <div style={{ marginTop: "1.5rem", color: "var(--text-muted)", fontSize: ".8rem", textAlign: "center" }}>
          Share the game code with friends — they join from this page.
        </div>
      </div>
    </div>
  );
}
