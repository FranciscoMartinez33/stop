# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Stop** is a 3D word board game (similar to Scattergories) built in Godot 4.6.
- Rendering: Forward Plus (via D3D12 on Windows)
- Physics: Jolt Physics engine
- Language: GDScript (`.gd`)

### Architecture

Everything is created procedurally at runtime from a single script — there are no child nodes in the scene file.

```
scenes/main.tscn          ← root Node3D with game_board.gd attached
scripts/game_board.gd     ← spawns camera, lights, board, and all buttons in _ready()
```

**Board layout (world units):**
- Board disc radius: 5.2
- Letter button ring radius: 4.0
- Center display platform radius: 1.55

**Button interaction flow:**
`StaticBody3D.input_event` → `_pick(letter)` → updates `_center_lbl` text and button color via `_mats` dictionary.

**Letters:** A–Y excluding W, X, Z (23 letters) + `?` wildcard = 24 buttons.  
Wildcard randomly picks one of the 23 real letters and displays it in the center.

## Running the Project

Open the project in the Godot 4.6 editor by launching Godot and importing `project.godot`, or from the command line:

```
godot --path . --editor          # Open in editor
godot --path .                   # Run the project headlessly
```

There is no build step — Godot interprets GDScript at runtime.

## Project Configuration

Key settings in `project.godot` (prefer editing via the Godot editor UI):
- Physics engine: Jolt (set under `[physics]` → `3d/physics_engine`)
- Renderer: Forward Plus / D3D12

## GDScript Conventions

- Scripts attach to nodes via `extends <NodeType>` at the top
- Autoloads (singletons) are registered in Project Settings → Autoload
- Signals are the preferred decoupling mechanism between nodes
- The `.godot/` directory is generated cache — never edit manually, already gitignored
