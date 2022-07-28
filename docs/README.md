# `pkmn-rse` scripts

Lua scripts designed for use with the [`mgba`](https://github.com/mgba-emu/mgba) emulator.

## Project structure

`docs/`
- Contains various (unsorted) documentation for R/S/E data incl. a memory map

`src/`
- Source code
- Functions compatible across all versions

`src/{r,s,e}/`
- Functions specific to one version

## Setup

As of July 2022 mGBA has yet to release an official `0.10.x` build with Lua scripting available.
As such, to use any of these scripts one must [compile the project manually](https://github.com/mgba-emu/mgba#compiling).

