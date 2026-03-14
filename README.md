# Glider

OpenMW mod that adds a glider when you double-jump outside.

## Installing

Add `00 Core` and one of `01 DwemerGlider` or `01 RacerGlider` to your data paths.

Add both `ErnGlider.omwaddon` and `ErnGlider.omwscripts`!

In your settings, enable these:

- [use-additional-anim-sources](https://openmw.readthedocs.io/en/stable/reference/modding/settings/game.html#use-additional-anim-sources)
- [smooth-animation-transitions](https://openmw.readthedocs.io/en/stable/reference/modding/settings/game.html#smooth-animation-transitions)

And don't enable this:
- [player-movement-ignores-animation](https://openmw.readthedocs.io/en/stable/reference/modding/settings/game.html#player-movement-ignores-animation)

Consider turning this off:
- [shield sheathing](https://openmw.readthedocs.io/en/stable/reference/modding/settings/game.html#shield-sheathing)

## Using Your Glider

Gliders only work while outside. While in an unreadied stance (your weapon is sheathed and you don't have your spellcasting hands out), do a double jump while not holding forward or backward. This will activate your glider, which drains fatigue. Tap your jump button again to put the glider away.

### Glider Quest Walkthrough

1. Talk to a friendly [Acrobat](https://en.uesp.net/wiki/Category:Morrowind-Acrobat) to get a basic glider.
2. Talk to a friendly [Savant](https://en.uesp.net/wiki/Category:Morrowind-Savant) when you have at least 40 Acrobatics to upgrade your glider.
3. Talk to a friendly [Savant](https://en.uesp.net/wiki/Category:Morrowind-Savant) when you have at least 80 Acrobatics to upgrade your glider again.

If you're using `Ben's Skyships (OpenMW)`, you can instead just talk to a glider expert.

If you're on Vvardenfell, you can just talk to Louis Beauchamp.

<details>

<summary>Console Commands</summary>

You can enable the glider like this, too:

Basic glider: `setJournalIndex eg_glider 1`
Advanced glider: `setJournalIndex eg_glider 21`
Masterwork glider: `setJournalIndex eg_glider 31`

</details>

## Shield Surfing

While in an unreadied stance (your weapon is sheathed and you don't have your spellcasting hands out), do a double jump while holding backward. Shield surfing damages your shield, but you move faster while heading down-slope. Tap your jump button again to put your shield away.


## Credits

### Sounds

- Wind 1 Loop by jasoneweber -- https://freesound.org/s/179110/ -- License: Attribution 3.0
- Breath In by mooncubedesign -- https://freesound.org/s/319247/ -- License: Creative Commons 0
- Gravel Road by seth-m -- https://freesound.org/people/seth-m/sounds/341069/ -- License: Creative Commons 0
- Landing On The Ground [2] by SoundDesignForYou -- https://freesound.org/people/SoundDesignForYou/sounds/646660/ -- License: Creative Commons 0
- up draft with more wind.wav by SahJop, used with explicit permission.

### Meshes & Textures

- Dwemer Glider by Semaro, used with explicit permission.
- Racer Glider by Dubious, used with explicit permission.
- Textures by Wareya, used with explicit permission.
- Dust cloud by Kronbits -- https://kronbits.itch.io/particle-pack -- License: Creative Commons 0

## Animations

- openmw-animated-levitation -- https://gitlab.com/fallchildren/openmw-animated-levitation -- License: GPL
- Racer Glider animation by Dubious, used with explicit permission.
- Shield Surfing animation by Dubious, used with explicit permission.

### Third-Party Code

- openmw-animated-levitation -- https://gitlab.com/fallchildren/openmw-animated-levitation -- License: GPL
- PCP-OpenMW by Qlonever -- https://github.com/Qlonever/PCP-OpenMW) -- License: MIT

## TODO

- Meshes
- Gliding animation.
- Extra boost when over lava?
- shield surf animation
- un-equip shield while surfing and then re-equip?
