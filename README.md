A heavy modification fork of target_healthbar by Nero https://github.com/Neyami/Various-Plugins/tree/main/HEALTHBAR

# Sven Co-op Dynamic Boss Healthbar Script

An ultra-optimized, event-driven AngelScript custom entity for **Sven Co-op** that renders a global boss healthbar using clean, centrally aligned HUD text parameters. 

This script completely replaces old, unoptimized sprite-based variations. It eliminates massive server lag by moving away from constant high-frequency polling loops and replaces them with an efficient event-based system that only broadcasts data across the network when actual changes occur.

---

## ✨ Features

* **Global & Central Alignment:** Uses native `HUDTextParams` centering (`x = -1.0`), guaranteeing a perfectly centered boss layout on every player's monitor regardless of aspect ratio or resolution.
* **Single Boss Bar Focus:** Stripped of old multi-bar overlapping logic to maintain a clean, readable UI focusing on one epic encounter at a time.
* **Ultra-Optimized Networking (Smart Refresh):** Instead of refreshing dozens of times per second, a lightweight 1.0-second background checker monitors data. It *only* broadcasts an actual update across the network if:
  1. The boss takes damage (health changes).
  2. A new player joins the server.
  3. A dead player respawns (catching HUD wipes instantly).
* **60-Character Dynamic UI:** Carefully tuned to a 60-character maximum length (`||||----`), optimizing screen width for 1080p+ widescreen monitors while staying perfectly safe from text-wrapping breaks on retro low-resolution screens (like 640x480).
* **"Clear Message" Safety Protocol:** Includes a failsafe handler. The second a boss dies, is removed, or the entity is killed by the map, a 0-second blank message is fired to immediately wipe the text channel off everyone's monitors so it never freezes in place.

---

CHANGELOG (what changed from the original version):

Architectural Changes
    - Reduced Maximum Bars (2 ➔ 1): Changed MAX_HEALTH_BARS to 1. The script now strictly handles a single boss health bar at a time globally.
    
    - Shifted from Polling to Smart Event-Driven System: The original script completely reconstructed strings and hammered the network 40 times per second per player. This version uses a lightweight 1.0-second background checker that only triggers a full HUD draw/network broadcast when a true map state change happens (Damage, Connect, or Respawn).
    
    - Removed Visual PVS Logic: Stripped out the SPAWNFLAG_HEALTHBAR_PVS_ONLY flag and its expensive inPVS() visibility checking loops. The health bar is now completely global and works perfectly regardless of player positions.

Code Cleanup & Variable Removals
    - Removed Dual-Bar Spacing Logic: Completely removed the m_flOffset variable, the unused ShouldDrawText() helper function, and the GetHealthbarOffset() function.
    
    - Cleaned Up KeyValue Inputs: Removed the unused offset configuration block from the map data interpreter (KeyValue), cleaning up unnecessary parameters.
    
    - Array Adjustments: Rewrote all tracking indexes from dual-index tracking [0] & [1] down to a single index [0].

Optimization & Feature Additions
    - Expanded Bar Length (50 ➔ 60): Adjusted m_iMaxCharacters to 60 for a wider, cleaner bar visual. This length fits perfectly across standard resolutions down to 640x480 without text-wrapping or clipping.
    
    - Added Smart Memory Checkers: Introduced m_iLastBarValue and m_flLastRefreshTime to remember the state of the last update. If the boss takes zero damage, the server completely skips rebuilding strings and wasting bandwidth.
    
    - Added Join & Respawn Interceptor: Added a high-speed player tracking function GetPlayerCounts() alongside m_iLastConnectedCount and m_iLastAliveCount. If a new player enters the server or a dead player respawns, the script catches it instantly on the next 1-second interval and forces a screen redraw.
    - Implemented Long Hold-Time Strategy: Pushed the default holdTime and m_flFailsafeInterval up to a massive 60 seconds, reducing normal background network chatter to an absolute crawl.
    - Added "Clear Message" Death Safety Protocol: Added the ClearBossHUD() function. When a boss dies (or when the entity is removed by the map), the script sends a zero-second blank message to completely wipe text channel 1 off everyone's screens instantly, preventing the long 60-second bar from freezing on screen.
    - Language Standardization: Fully translated all comments, layout descriptions, and error notifications from Spanish back into English.
