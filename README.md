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
