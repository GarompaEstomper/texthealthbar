A heavy modification fork of target_healthbar by Nero https://github.com/Neyami/Various-Plugins/tree/main/HEALTHBAR

This works just like the original, except:
- Sprites have been removed and replaced by more text. The bar is now made out of text. This is because i didn't find a way to make it a single centered sprite. I could not set the center of the sprite to be aligned with the center of the screen, that is probably why the original script used 2 sprites that started from the center of the screen, because the start or end point of the sprite can be set, just not the center...
- The boss name text now has a line break and adds the health bar below like this: |||||||||||||
- The change to full text means we can get rid of the whole per-player cycle. Cycling the entire script through all players to refresh it created a lot of lag. But now the text is made global, so we dont have to cycle
- Making it global means that we can get rid of PVS mode, again removing any per player loop
- And making it a text means we can give it a longer holdtime than the refresh time, because it uses always text channel 1 and replaces itself, it cannot overflow and compensates this way any flashing due to high ping
- And of course, the elephant in the room. I changed the refresh and holdtimes from 0.0025 or something insane like that, which would result in thousands of cycles per player, creating MASSIVE lag ingame. Now its just 1 second, that is every server frame or 2.


WHAT CANNOT BE DONE:
I wanted to have a super long holdtime, so the bar is refreshed only when an event occurs like the enemy taking damage, a player respawning or joining the game (in the last 2 cases the channels are cleared by the engine for the client so the bar disappears if you respawn or join while the bar was triggered before you joined).
But, it seems there is no way to check for players joining or respawning that I know of. I'm still a noob at scripting. And because it can't check for that, having a long holdtime is useless.
