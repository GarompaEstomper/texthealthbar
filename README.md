A heavy modification fork of target_healthbar by Nero: https://github.com/Neyami/Various-Plugins/tree/main/HEALTHBAR

# Sven Co-op Dynamic Boss Healthbar Script (game_textbar)

An ultra-optimized, event-driven AngelScript custom entity for **Sven Co-op** that renders a global boss healthbar using clean, centrally aligned HUD game_text. 

It eliminates massive server lag by moving away from constant high-frequency polling loops with sprites and replaces them with an efficient event-based system that only broadcasts data across the network when actual changes occur.

---

## ✨ Features

* **Global Screen Alignment:** Uses native `HUDTextParams` formatting with absolute or centered configurations, guaranteeing a perfectly aligned boss layout on every player's monitor regardless of aspect ratio or resolution.
* **Fully Customizable via Hammer/J.A.C.K.:** Mappers can now natively change the color (RGB), HUD channel, post-death delay, and screen coordinates directly within the entity keys.
* **Single Boss Bar Focus:** Stripped of old multi-bar overlapping logic to maintain a clean, readable UI focusing on one epic encounter at a time.
* **Ultra-Optimized Networking (Smart Refresh):** Instead of refreshing dozens of times per second, a lightweight 1.0-second background checker monitors data. It *only* broadcasts an actual update across the network if:
  1. The boss takes damage (health changes).
  2. A new player joins the server.
  3. A dead player respawns (catching HUD wipes instantly).
* **60-Character Dynamic UI:** Carefully tuned to a 60-character maximum length (`||||----`), optimizing screen width for 1080p+ widescreen monitors while staying perfectly safe from text-wrapping breaks on retro low-resolution screens (like 640x480).
* **Automatic Name Cascade with Failsafe:** Zero setup required for basic naming. The entity automatically loops through an optimized hierarchy to grab names (`Custom message override` ➔ `Player Network Profile name` ➔ `Sven Co-op Monster DisplayName` ➔ `func_breakable DisplayName`). If all are blank, it defaults directly to an epic **"Boss"** identifier instead of leaking ugly raw engine classnames.
* **Low-Health Edge-Case Protection:** Includes mathematical clamping protection. If a boss's health falls so low that calculations round down to 0 characters, the script forces a single visual tick (`|------`) to remain visible on the HUD. This keeps the execution loop alive and prevents the UI from prematurely disappearing while the boss is still fighting.
* **Dynamic Post-Death Expiration Protocol:** Completely fixes lingering text problems. When the boss dies, the script dynamically overrides its massive network-saving hold time with the mapper's exact `delay` duration, forcing the text channel to naturally expire and flush out of the engine's internal buffer perfectly.
* To make the bar respawnable, you must use trigger_createentity

---

## 🛠️ Level Editor Configuration (.FGD)

Add this point class block to your map editor's `.fgd` file to expose the custom entity to level designers:

```fgd
@PointClass base(EditorFlags) color(220 0 0) size(-8 -8 -8, 8 8 8) = game_textbar : "Text-Based Boss Healthbar (Ultra-Optimized)"
[
    targetname(target_source) : "Name" : "" : "The unique name of this healthbar entity so other map entities can trigger or target it."
    target(target_destination) : "Boss Targetname" : "" : "The targetname of the monster, player, or breakable object whose health you want to track."
    
    spawnflags(Flags) =
    [
        1 : "Start Inactive (Requires Trigger Use)" : 0
    ]

    message(string) : "Custom Boss Name Override" : "" : "Optional custom name text to show on the HUD. If left blank, it automatically searches for the target's Player Name or DisplayName. Falls back to 'Boss' if completely empty. [Default: Blank]"
    delay(string) : "Post-Death Delay Duration" : "0.0" : "How many seconds the empty healthbar stays on the players' screen after the boss dies before vanishing completely. [Default: 0.0]"
    
    color(string) : "HUD Bar Color (R G B)" : "255 0 0" : "The text color of the boss name and health matrix bar formatted as three space-separated integers between 0 and 255. [Default: 255 0 0]"
    x(string) : "Horizontal Position (X)" : "-1.0" : "Horizontal placement on screen. Use -1.0 for a clean, absolute screen centering alignment. [Default: -1.0]"
    y(string) : "Vertical Position (Y)" : "0.08" : "Vertical placement on screen, starting from top (0.0) down to bottom (1.0). Sits near the top edge. [Default: 0.08]"
    channel(choices) : "HUD Text Channel" : 1 =
    [
        1 : "Channel 1 (Default)"
        2 : "Channel 2"
        3 : "Channel 3"
        4 : "Channel 4"
    ]
]
