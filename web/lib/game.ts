import { hasWord } from "./words";

export const LETTERS = [
  "A","B","C","D","E","F","G","H","I","J","K","L",
  "M","N","O","P","Q","R","S","T","U","V","Y","?"
] as const;

export const REAL_LETTERS = LETTERS.filter(l => l !== "?");
export const TURN_T = 15; // seconds

export type Phase = "LOBBY" | "CARD_SELECT" | "PLAYING" | "GAME_OVER";
export type GameMode = "CLASSIC" | "WORLD_CUP";

export interface Player {
  id: string;
  name: string;
}

export interface LastMove {
  playerIdx: number;
  playerName: string;
  word: string;
  result: "correct" | "wrong" | "timeout";
  usedLetter: string;
}

export interface GameState {
  code: string;
  phase: Phase;
  mode: GameMode | null;
  maxPenalties: number;
  players: Player[];
  hostId: string;
  curPlayer: number;
  penalties: number[];
  topic: string;
  blocked: string[];
  deckSeq: number[];
  deckPos: number;
  turnStartedAt: number;
  cardOptions: [string, string] | null;
  lastMove: LastMove | null;
  createdAt: number;
}

export const CLASSIC_DECK: [string, string][] = [
  ["RED THINGS",       "SUPERPOWERS"],
  ["ANIMALS",          "SPORTS"],
  ["COUNTRIES",        "FOODS"],
  ["MOVIES",           "JOBS"],
  ["FRUITS",           "COLORS"],
  ["FAMOUS PEOPLE",    "VEHICLES"],
  ["KITCHEN ITEMS",    "MUSIC GENRES"],
  ["BEACH THINGS",     "TV SHOWS"],
  ["SCHOOL SUBJECTS",  "CLOTHING"],
  ["CAPITAL CITIES",   "DRINKS"],
  ["THINGS THAT FLY",  "BOARD GAMES"],
  ["FAMOUS BRANDS",    "FAIRY TALE CHARS"],
  ["PARK THINGS",      "WATER SPORTS"],
  ["HOLIDAYS",         "BODY PARTS"],
  ["PLANTS",           "DANCE STYLES"],
  ["GLOWING THINGS",   "MYTHICAL CREATURES"],
  ["COLD THINGS",      "CARTOON CHARACTERS"],
  ["MAP THINGS",       "INSTRUMENTS"],
  ["SWEET FOODS",      "OLYMPIC SPORTS"],
  ["SPACE THINGS",     "PROFESSIONS"],
];

export const WC_DECK: [string, string][] = [
  ["WC26 TEAMS",        "PLAYERS AWARDED IN WC"],
  ["CHAMPIONS COUNTRIES", "COUNTRIES NEVER WON WC"],
  ["WC26 CITIES",       "COUNTRIES NEVER PLAYED WC"],
  ["PLAYERS CHAMPIONS", "WC26 COUNTRIES NOT QUALIFIED"],
  ["WC MASCOTS",        "WC BALLS"],
  ["WC TOP SCORERS",    "WC26 MANAGERS"],
  ["WC HOSTS",          "PLAYERS IN WC26"],
  ["WC26 TEAMS",        "WC26 STADIUMS"],
  ["COUNTRIES NEVER WON WC", "PLAYERS CHAMPIONS"],
  ["PLAYERS IN WC26",   "WC MASCOTS"],
];

function shuffle<T>(arr: T[]): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function drawCard(state: GameState): [string, string] {
  const deck = state.mode === "WORLD_CUP" ? WC_DECK : CLASSIC_DECK;
  if (state.deckPos >= state.deckSeq.length) {
    state.deckSeq = shuffle(Array.from({ length: deck.length }, (_, i) => i));
    state.deckPos = 0;
  }
  const card = deck[state.deckSeq[state.deckPos]];
  state.deckPos++;
  return card;
}

export function newGame(hostId: string, hostName: string): GameState {
  return {
    code: "",
    phase: "LOBBY",
    mode: null,
    maxPenalties: 3,
    players: [{ id: hostId, name: hostName }],
    hostId,
    curPlayer: 0,
    penalties: [0],
    topic: "",
    blocked: [],
    deckSeq: [],
    deckPos: 0,
    turnStartedAt: 0,
    cardOptions: null,
    lastMove: null,
    createdAt: Date.now(),
  };
}

export function joinGame(
  state: GameState,
  playerId: string,
  name: string
): GameState | string {
  if (state.phase !== "LOBBY") return "Game already started";
  if (state.players.length >= 8) return "Game is full";
  if (state.players.some(p => p.id === playerId)) return "Already joined";
  const s = clone(state);
  s.players.push({ id: playerId, name });
  s.penalties.push(0);
  return s;
}

export function startGame(
  state: GameState,
  playerId: string,
  mode: GameMode,
  maxPenalties: number
): GameState | string {
  if (state.hostId !== playerId) return "Only the host can start";
  if (state.players.length < 2) return "Need at least 2 players";
  if (state.phase !== "LOBBY") return "Game already started";
  const s = clone(state);
  s.mode = mode;
  s.maxPenalties = maxPenalties;
  s.curPlayer = 0;
  s.penalties = new Array(s.players.length).fill(0);
  const deck = mode === "WORLD_CUP" ? WC_DECK : CLASSIC_DECK;
  s.deckSeq = shuffle(Array.from({ length: deck.length }, (_, i) => i));
  s.deckPos = 0;
  s.cardOptions = drawCard(s);
  s.phase = "CARD_SELECT";
  return s;
}

export function pickCard(
  state: GameState,
  playerId: string,
  idx: 0 | 1
): GameState | string {
  if (state.phase !== "CARD_SELECT") return "Not in card selection";
  if (state.players[state.curPlayer].id !== playerId)
    return "Not your turn to pick";
  if (!state.cardOptions) return "No card options";
  const s = clone(state);
  s.topic = s.cardOptions[idx];
  s.cardOptions = null;
  s.blocked = [];
  s.lastMove = null;
  s.turnStartedAt = Date.now();
  s.phase = "PLAYING";
  return s;
}

export function applyMove(
  state: GameState,
  playerId: string,
  word: string,
  isTimeout: boolean
): GameState | string {
  if (state.phase !== "PLAYING") return "Not in playing phase";
  const curP = state.players[state.curPlayer];
  if (!isTimeout && curP.id !== playerId) return "Not your turn";
  if (isTimeout) {
    const elapsed = (Date.now() - state.turnStartedAt) / 1000;
    if (elapsed < TURN_T) return "Timer has not expired yet";
  }

  const s = clone(state);

  let result: "correct" | "wrong" | "timeout" = isTimeout ? "timeout" : "wrong";
  let usedLetter = "";

  if (!isTimeout) {
    const normalized = normalizeWord(word);
    const firstChar = normalized.charAt(0);
    const letter = firstChar.toUpperCase();

    if ((REAL_LETTERS as readonly string[]).includes(letter)) {
      if (hasWord(s.topic, word)) {
        // determine which letter gets blocked
        if (!s.blocked.includes(letter)) {
          usedLetter = letter;
          result = "correct";
        } else if (!s.blocked.includes("?")) {
          // use wildcard: block a random free letter
          const free = REAL_LETTERS.filter(l => !s.blocked.includes(l));
          if (free.length === 0) {
            // board full – reset and give the player another chance same turn
            s.blocked = [];
            s.lastMove = {
              playerIdx: s.curPlayer,
              playerName: curP.name,
              word: word.toUpperCase(),
              result: "correct",
              usedLetter: "BOARD FULL",
            };
            s.turnStartedAt = Date.now();
            return s;
          }
          usedLetter = free[Math.floor(Math.random() * free.length)];
          s.blocked.push("?");
          result = "correct";
        }
        // else: wildcard also blocked → wrong (stays as "wrong")
      }
    }
  }

  s.lastMove = {
    playerIdx: s.curPlayer,
    playerName: curP.name,
    word: isTimeout ? "(time's up)" : word.toUpperCase(),
    result,
    usedLetter,
  };

  if (result === "correct") {
    s.blocked.push(usedLetter);
    s.curPlayer = (s.curPlayer + 1) % s.players.length;
    s.turnStartedAt = Date.now();
    // phase stays PLAYING
  } else {
    // wrong or timeout
    const loserIdx = s.curPlayer;
    s.penalties[loserIdx]++;
    s.blocked = [];
    s.curPlayer = (loserIdx + 1) % s.players.length;

    if (s.penalties[loserIdx] >= s.maxPenalties) {
      s.phase = "GAME_OVER";
    } else {
      s.cardOptions = drawCard(s);
      s.phase = "CARD_SELECT";
    }
  }

  return s;
}

function normalizeWord(word: string): string {
  const MAP: Record<string, string> = {
    "À":"A","Á":"A","Â":"A","Ã":"A","Ä":"A","Å":"A",
    "à":"A","á":"A","â":"A","ã":"A","ä":"A","å":"A",
    "È":"E","É":"E","Ê":"E","Ë":"E",
    "è":"E","é":"E","ê":"E","ë":"E",
    "Ì":"I","Í":"I","Î":"I","Ï":"I",
    "ì":"I","í":"I","î":"I","ï":"I",
    "Ò":"O","Ó":"O","Ô":"O","Õ":"O","Ö":"O",
    "ò":"O","ó":"O","ô":"O","õ":"O","ö":"O",
    "Ù":"U","Ú":"U","Û":"U","Ü":"U",
    "ù":"U","ú":"U","û":"U","ü":"U",
    "Ñ":"N","ñ":"N","Ç":"C","ç":"C",
    "Ý":"Y","ý":"Y","Š":"S","š":"S","Ś":"S","ś":"S",
    "Ž":"Z","ž":"Z","Ź":"Z","ź":"Z","Ř":"R","ř":"R",
    "Č":"C","č":"C","Ć":"C","ć":"C","Ě":"E","ě":"E",
    "Ď":"D","ď":"D","Ľ":"L","ľ":"L","Ń":"N","ń":"N",
    "İ":"I","ı":"I",
  };
  return word.toUpperCase().split("").map(ch => MAP[ch] ?? ch).join("");
}

function clone<T>(obj: T): T {
  return JSON.parse(JSON.stringify(obj));
}
