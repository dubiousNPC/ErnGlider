# Glider

OpenMW mod that adds a glider when you double-jump outside.

Add `00 Core` and one of `01 DwemerGlider` or `01 RacerGlider` to your data paths.

Add both `ErnGlider.omwaddon` and `ErnGlider.omwscripts`!

In your settings, enable these:

- [use-additional-anim-sources](https://openmw.readthedocs.io/en/stable/reference/modding/settings/game.html#use-additional-anim-sources)
- [smooth-animation-transitions](https://openmw.readthedocs.io/en/stable/reference/modding/settings/game.html#smooth-animation-transitions)

And don't enable this:
- [player-movement-ignores-animation](https://openmw.readthedocs.io/en/stable/reference/modding/settings/game.html#player-movement-ignores-animation)

## Using Your Glider

Gliders only work while outside. While in an unreadied stance (your weapon is sheathed and you don't have your spellcasting hands out), do a double jump while not holding forward or backward. This will activate your glider, which drains fatigue. Tap your jump button again to put the glider away.

## Shield Surfing

Surfing only works while outside. While in an unreadied stance (your weapon is sheathed and you don't have your spellcasting hands out), do a double jump while holding backward. Shield surfing damages your shield, but you move faster while heading down-slope. Tap your jump button again to put your shield away.

## Walkthrough

1. Talk to a friendly [Acrobat](https://en.uesp.net/wiki/Category:Morrowind-Acrobat) to get a basic glider.
2. Talk to a friendly [Savant](https://en.uesp.net/wiki/Category:Morrowind-Savant) when you have at least 40 Acrobatics to upgrade your glider.
3. Talk to a friendly [Savant](https://en.uesp.net/wiki/Category:Morrowind-Savant) when you have at least 80 Acrobatics to upgrade your glider again.

If you're using `Ben's Skyships (OpenMW)`, you can instead just talk to a glider expert.

<details>

<summary>Console Commands</summary>

You can enable the glider like this, too:

Basic glider: `setJournalIndex eg_glider 1`
Advanced glider: `setJournalIndex eg_glider 21`
Masterwork glider: `setJournalIndex eg_glider 31`

</details>


## Credits

### Sounds

- Wind 1 Loop by jasoneweber -- https://freesound.org/s/179110/ -- License: Attribution 3.0
- Breath In by mooncubedesign -- https://freesound.org/s/319247/ -- License: Creative Commons 0
- Gravel Road by seth-m -- https://freesound.org/people/seth-m/sounds/341069/ -- License: Creative Commons 0

### Meshes & Textures

- Gliders by Semaro, used with explicit permission.
- Textures derived from TES3: Morrowind.

## Animations

- openmw-animated-levitation -- https://gitlab.com/fallchildren/openmw-animated-levitation -- GPL
- glider by Dubious, used with explicit permission.

### Third-Party Code

- openmw-animated-levitation -- https://gitlab.com/fallchildren/openmw-animated-levitation -- GPL

## TODO

- Meshes
- Gliding animation.
- Extra boost when over lava?
- shield surf animation
- un-equip shield while surfing and then re-equip


/home/ern/tes3/mods/Fonts/AlternativeTrueTypeFonts/fonts/Pelagiad.ttf
/home/ern/tes3/mods/Fonts/AlternativeTrueTypeFonts/fonts/Pelagiad.ttf

magick -gravity center -background transparent -fill white -size 128x64 -font /home/ern/tes3/mods/Fonts/AlternativeTrueTypeFonts/fonts/Pelagiad.ttf caption:"kph" kph.png
