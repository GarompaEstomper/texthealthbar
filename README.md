A heavy modification fork of target_healthbar by Nero: https://github.com/Neyami/Various-Plugins/tree/main/HEALTHBAR

# Sven Co-op Dynamic Boss Healthbar Script (game_textbar)

An ultra-optimized, event-driven AngelScript custom entity for **Sven Co-op** that renders a global boss healthbar using clean, centrally aligned HUD game_text. 

It eliminates massive server lag by moving away from constant high-frequency polling loops with sprites and replaces them with an efficient event-based system that only broadcasts data across the network when actual changes occur.

---

## ✨ Features

* **Global Screen Alignment:** Uses native `HUDTextParams` formatting with absolute or centered configurations, guaranteeing a perfectly aligned boss layout on every player's monitor regardless of aspect ratio or resolution.
* **Dual-Target Arcade Layout:** Supports tracking up to 2 boss targets simultaneously on a single HUD channel, cleanly separating them into a stacked visual layout.
* **Dynamic Layout Rearrangement:** When tracking multiple bosses, a boss's bar will completely vanish the moment they die. The interface automatically rearranges itself to display the surviving boss cleanly without leaving any ugly empty rows or dead spacing.
* **Fully Customizable via Hammer/J.A.C.K.:** Mappers can natively configure the primary color, secondary effect color, text effects, entry fade-in/exit fade-out speeds, typewriter delays, HUD channel, post-death delay, and screen coordinates directly within the entity keys.
* **Native GoldSrc Text Effects:** Fully exposes engine text behavior. Mappers can choose between clean fades, retro credits flickering, or an atmospheric typewriter style scan-out.
* **First-Frame Effect Optimization:** Visual text effects and scan-outs run strictly on the very first frame the bar initializes. Active gameplay damage ticks automatically drop transitions to ensure live health reductions update smoothly and instantly without constantly flashing or re-typing letters.
* **Ultra-Optimized Networking (Smart Refresh):** Instead of refreshing dozens of times per second, a lightweight background checker monitors data. It *only* broadcasts an actual update across the network if:
  1. Any tracked boss takes damage (health changes).
  2. A new player joins the server.
  3. A dead player respawns (catching HUD wipes instantly).
* **60-Character Dynamic UI:** Carefully tuned to a 60-character maximum length (`||||----`), optimizing screen width for 1080p+ widescreen monitors while staying perfectly safe from text-wrapping breaks on retro low-resolution screens (like 640x480).
* **Automatic Name Cascade with Failsafe:** Zero setup required for basic naming. The entity automatically loops through an optimized hierarchy to grab names (`Custom message override` ➔ `Player Network Profile name` ➔ `Sven Co-op Monster DisplayName` ➔ `func_breakable DisplayName`). If all are blank, it defaults directly to an epic **"Boss"** identifier instead of leaking ugly raw engine classnames. Multiple custom names can be bound via semicolons (e.g., `Boss 1;Boss 2`).
* **Low-Health Edge-Case Protection:** Includes mathematical clamping protection. If an active boss's health falls so low that calculations round down to 0 characters, the script forces a single visual tick (`|------`) to remain visible on the HUD. This keeps the execution loop alive and prevents the UI from prematurely disappearing while the boss is still fighting.
* **Dynamic Post-Death Expiration Protocol:** Completely fixes lingering text problems. When all bosses die, the script dynamically overrides its massive network-saving hold time with the mapper's exact `delay` duration, forcing the text channel to naturally expire and flush out of the engine's internal buffer perfectly.
* To make the bar respawnable, you must use `trigger_createentity`.

---

## 🛠️ Level Editor Configuration (.FGD)

Add this point class block to your map editor's `.fgd` file to expose the custom entity to level designers:

```fgd
@PointClass base(EditorFlags) color(220 0 0) size(-8 -8 -8, 8 8 8) = game_textbar : "Text-Based Boss Healthbar (Ultra-Optimized)"
[
    targetname(target_source) : "Name" : "" : "The unique name of this healthbar entity so other map entities can trigger or target it."
    target(target_destination) : "Boss Targetname" : "" : "The targetname of the monster, player, or breakable object whose health you want to track. Supports up to 2 targets separated by a semicolon (e.g., boss1;boss2)."
    
    spawnflags(Flags) =
    [
        1 : "Start Inactive (Requires Trigger Use)" : 0
    ]

    message(string) : "Custom Boss Name Override" : "" : "Optional custom name text to show on the HUD. Separate with a semicolon for two names: Name1;Name2. If left blank, it automatically searches for the target's Player Name or DisplayName. [Default: Blank]"
    delay(string) : "Post-Death Delay Duration" : "0.0" : "How many seconds the empty healthbars stay on the players' screen after ALL tracked targets die before vanishing completely. [Default: 0.0]"
    
    color(string) : "HUD Bar Color 1 (R G B)" : "255 0 0" : "The text color of the boss name and primary health matrix bar formatted as three space-separated integers between 0 and 255. [Default: 255 0 0]"
    color2(string) : "HUD Bar Color 2 (R G B)" : "100 100 200" : "The secondary color used as an alternate flash color (Effect 1) or typewriter background shadow color (Effect 2) formatted as three space-separated integers between 0 and 255. [Default: 100 100 200]"
    
    effect(choices) : "HUD Text Effect" : 0 =
    [
        0 : "Fade In / Fade Out (Default)"
        1 : "Credits / Flicker / Flashing"
        2 : "Scan Out (Typewriter style)"
    ]
    
    fadein(string) : "Fade-In Speed / Character Time" : "0.02" : "Duration of the entry fade-in, or delay per character transition speed. [Default: 0.02]"
    fadeout(string) : "Fade-Out Speed" : "0.02" : "Duration of the exit fade-out text speed. [Default: 0.02]"
    fxtime(string) : "Scan Out Typewriter Delay" : "1.0" : "Typewriter delay modifier speed when utilizing the Scan Out effect. [Default: 1.0]"

    x(string) : "Horizontal Position (X)" : "-1.0" : "Horizontal placement on screen. Use -1.0 for a clean, absolute screen centering alignment. [Default: -1.0]"
    y(string) : "Vertical Position (Y)" : "0.05" : "Vertical placement on screen, starting from top (0.0) down to bottom (1.0). Default 0.05 provides clean lift position. [Default: 0.05]"
    channel(choices) : "HUD Text Channel" : 1 =
    [
        1 : "Channel 1 (Default)"
        2 : "Channel 2"
        3 : "Channel 3"
        4 : "Channel 4"
    ]
]
