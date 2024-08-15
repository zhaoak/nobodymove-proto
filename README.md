# NOBODY MOVE

Prototype for a Love2D platformer/shooter game about heavily armed (and legged) spiders, written in Lua

## How to run

First, you'll need to install the Love2D game engine. See the [Love2D wiki page on getting started](https://www.love2d.org/wiki/Getting_Started) for more details.

Once Love2D is installed, clone this repository to a location of your choice.

Running the game will require different steps based on which operating system you're on; the "getting started" page linked above has detailed instructions for Mac, Windows, and Linux.

Note that there's no `.love` file yet, as the game isn't ready to be packaged and distributed; instead you should pass the `love` executable to the local folder containing this repository's files.

## Userdata format

Box2D (the physics engine we're using) lets you store arbitrary data in physics objects for use in handling game logic.

We're storing a table in it, with the following format:

```
{
name (string): The name of the entity. May be displayed to the player.
type (string): What sort of object it is. Used in determining how the object handles collisions with other objects.
               Must be one of the following values:
                - "terrain"    : static, unmoving part of the map environment. Does not have team string.
                - "prop"       : part of the map environment that moves or is otherwise dynamic.
                - "npc"        : an enemy, friendly, or neutral non-player character
                - "player"     : a player.
                - "projectile" : something someone shot, probably from a gun.
uid (number) : A unique ID given to each object of a given type.
team (string): Who the object is allied with, relative to the player. Must be one of: "friendly", "enemy", "neutral".
health (num) : How much health this entity has. Not applicable for terrain or projectiles.
proj_properties (table) : the properties of a fired projectile (damage, etc). Only present for "projectile" type
}
```

Copyright (c) 2024 Allie Zhao & Spider Forrest
