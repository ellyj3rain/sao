| Document | Publishing readiness |
|---|---|
| Updated | 2026-08-28 |
| Author | ellyj3rain |
| Repository | `PUBLISHING.md` |
| Status | Blocked on the operator; mechanics otherwise known. |

# What publishing needs

Read from the game's own `Workshop/ModTemplate` and
`media/WorkshopTags.txt` rather than from memory, against B42.20.

## The layout Steam expects

```
  Zomboid/Workshop/<Name>/
      workshop.txt
      preview.png
      Contents/mods/<mod id>/
          mod.info
          media/...
```

Note the nesting: the mod tree does not sit at the top. What this
repository calls `mod/` becomes `Contents/mods/SurvivorAwareness/`.

## workshop.txt

```
  version=1
  title=<name>
  description=<one line per description= key, repeated>
  tags=<from media/WorkshopTags.txt, semicolon-separated>
  visibility=public
```

`description=` repeats per line, including a bare `description=` for a
blank line. Valid tags for this mod, from the shipped list: **Build
42**, **Framework**, **Realistic**, **WIP**. There is no "NPC" tag.

## What is missing

```
  preview.png   MISSING   the Steam thumbnail; without it an upload cannot complete
  workshop.txt  MISSING   the metadata above
```

`icon.png` and `poster.png` exist ([B51] - generated, checked by
Border 73, declared placeholder: anyone may prefer their own drawing).
Border 19 refuses a `poster=` or `icon=` in `mod.info` naming a file
that does not exist, so art can land in any order.

## Why nothing here is staged

Publishing is the operator's call. The mod's own `mod.info` still says
*PRE-ALPHA: playable, but unproven - no feature here has live-play
verification yet*, and that remains true: the border gate and the
offline harnesses establish that the code does what it says offline,
and none of it is a play receipt. This file exists so that when the
call is made, the mechanics are already known and nobody has to
rediscover the layout.
