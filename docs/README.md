# `pkmn-rse` scripts

Lua scripts designed for use with the [`mgba`](https://github.com/mgba-emu/mgba) emulator.

## Project structure

`docs/`
- Contains various (unsorted) documentation for R/S/E data incl. a memory map

## Setup

As of October 2022 mGBA has yet to release an official `0.10.x` build with Lua scripting available.
As such, to use any of these scripts one must [compile the project manually](https://github.com/mgba-emu/mgba#compiling).

## Scripts

Read the documentation for each script in the dedicated subsection:
- [Party & wild mon info](#battle-info)

### Battle Info

Upon enabling the script, will place 4 buffers into the scripting window:
1. Info for the pokemon in slot 1 (active mon). It will be named after the mon's nickname
2. Raw info for all party pokemon & wild mon, formatted in pokemon showdown's expected syntax
3. Information about the current wild pokemon. Outside of battle, it will be the last encountered mon.
4. Damage calculations for each move in the party vs the opposing mon

Example output, script #1:
```
> Bud     Lv.5 21/21    |
  2 in party            | * Buddy (Mudkip) Lv. 5  -  Relaxed  (PV: 881cbb6a)
  WINGULL Lv.3 0/15     |            21/21      Sp.Atk    11
  Battle Calculator     |    Attack     12      Sp.Def    10
                        |    Defense    11      Speed      9
                        |
                        | IV  -  HP Ice, 23 power           | EV
                        |    HP  ATK  DEF  SpD  SpA  SPD    |    HP  ATK  DEF  SpD  SpA  SPD
                        |    21    6   10    1   21   27    |     0    1    0    0    0    0
                        |
```

### Todo

- [ ] Finish loop to update battle-info every emu frame

Unsorted list of next steps:
- [ ] Test cases
- [ ] write-mon module
- [ ] Networking example script

