# SourceMod Plugins

## Game Stats

Provides the command `sm_gamestats` which will print to the console the list of players (bot or human) and their scores (kills and deaths).
This can later be parsed by scripts. This plugin requires a password, which must be stored in `plugins/game-stats.pass`.

Usage: `sm_gamestats <password>`

## No Bomb Points

In CS:S, the player will get 3 extra score points if the bomb is defused or explodes. This plugin removes that.

Usage: `sm_nobombpoints <1|0>` (1 enables this plugin (default), 0 disables it)

## Team Money

This plugin will provide you a way of seeing your fellow teammates current money during freezetime. This is useful for coordinating purchases.

Usage: `sm_teammoney <1|0>` (1 enables this plugin (default), 0 disables it)
