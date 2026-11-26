# Box3D

**3D physics for [Solar3D](https://github.com/kan6868/solar3d/tree/main) on Solar2D.**

Solar3D (`plugin.s3d`) draws the 3D world: meshes, models, lights, shadows, cameras. Box3D (`plugin.box3d`) makes
that world move: rigid bodies, collisions, joints, sensors, raycasts. Together they fill in the 3D feature set that
Solar2D does not have out of the box.

Box3D is a native plugin written in C on top of [Box3D](https://github.com/erincatto/box3d) by Erin Catto (the
author of Box2D). It uses only Solar2D's public plugin API, so it runs on a stock Solar2D engine.

- **Version:** 0.2.0 (Box3D commit `e48b902`, 2026-11-22)
- **Platforms:** Android and Windows (Win32 Simulator)
- **API reference:** [docs/API.md](docs/API.md)

## Features

- Rigid bodies: dynamic, static and kinematic, with sleeping, continuous collision (bullets), damping, gravity scale
  and rotation lock.
- Shapes: box, sphere, capsule, cylinder, convex hull and triangle mesh, with friction, restitution, density,
  collision filtering and offsets.
- Joints: revolute, spherical, prismatic, weld and distance, with limits, motors, springs and breakable joints.
- Events: contact (began / ended / hit), sensor (began / ended), body move and joint break events.
- Queries: ray cast, sphere / box / convex shape cast, and sphere / box / shape / AABB overlap, all with filters.
- Explosions, deterministic simulation, optional multi-threading.
- Solar2D conventions: **angles in degrees**, Y up, right-handed, the same axes as Solar3D.

## Platforms

| Platform | Architectures | Package |
| --- | --- | --- |
| Android | arm64-v8a, armeabi-v7a, x86_64 | `plugins/plugin.box3d-android.tgz` |
| Windows Simulator | Win32 (x86) | `plugins/plugin.box3d-win32.tgz` |

iOS, macOS and other platforms are not supported yet.

## Installation

Box3D is distributed as a self-hosted Solar2D plugin.

1. Copy the packages into your local plugin storage. Solar2D looks in `%APPDATA%\Solar2DPlugins` on Windows:

   ```
   %APPDATA%\Solar2DPlugins\com.s3d\plugin.box3d\win32-sim\data.tgz   <- plugins/plugin.box3d-win32.tgz
   %APPDATA%\Solar2DPlugins\com.s3d\plugin.box3d\android\data.tgz     <- plugins/plugin.box3d-android.tgz
   ```

2. Add the plugin to `build.settings`, next to Solar3D:

   ```lua
   settings =
   {
       plugins =
       {
           ["plugin.box3d"] = { publisherId = "com.solartools", 
              supportedPlatforms = {
                  ["win32-sim"] = {
                      url = "https://github.com/kan6868/box3d/releases/download/v0.2.0/plugin.box3d-win32.tgz"
                  },
                  ["android"] = {
                      url = "https://github.com/kan6868/box3d/releases/download/v0.2.0/plugin.box3d-android.tgz"
                  }
              } 
        },
       },
   }
   ```

   Use the `publisherId` that matches the Solar3D build you installed.

3. For quick testing in the Windows Simulator, you can also put `plugin.box3d.dll` and `plugin.s3d.dll` next to
   `main.lua`. The demo's `main.lua` shows how to load them from the project folder.

## Quick start

A box falling onto the ground, drawn with Solar3D:

```lua
local s3d = require( "plugin.s3d" )
local box3d = require( "plugin.box3d" )

local scene = s3d.newScene()
local world = box3d.newWorld{ gravity = { 0, -10, 0 } }

-- ground: a static box 40 x 2 x 40 whose top is at y = 0
local ground = world:newBody{ type = "static", position = { 0, -1, 0 } }
ground:addBox( 20, 1, 20 )                                   -- half extents

-- a 1 m crate dropped from 3 m, turned 30 degrees around Y
local body = world:newBody{ position = { 0, 3, 0 }, angles = { 0, 30, 0 } }
body:addBox( 0.5, 0.5, 0.5, { friction = 0.6, restitution = 0.1 } )
local crate = s3d.newCube( scene, 1, { texture = "assets/crate.png" } )

Runtime:addEventListener( "enterFrame", function()
    world:step( 1 / 60 )
    crate:setPose( body:getTransform() )                     -- x, y, z, qx, qy, qz, qw
end )
```

`body:getTransform()` returns the position and the rotation quaternion in the order `obj:setPose()` expects, so
syncing a Solar3D object with its body is one line. For many bodies, `world:getMoveEvents()` returns only the bodies
that moved during the last step.

Units are meters, kilograms and seconds. The default density is 1000 kg/m³ (water), so a 1 m³ box weighs one tonne.

## Demo

This repository is also a runnable Solar2D project with 18 scenes based on the classic Box3D samples. Open the
folder in the Solar2D Simulator.

| Scenes | What they show |
| --- | --- |
| Box Stack, Pyramid, Jenga, Dominoes | Stacking and stability |
| Bridge, Ball and Chain, Ragdoll Pile | Revolute and spherical joints with limits |
| Restitution, Inclined Plane | Bounce and friction |
| Convex Pile, Explosion, Bullet vs Stack | Convex hulls, explosions, continuous collision |
| Spinner, Elevator | Motors and kinematic bodies |
| Sensors, Queries, Breakable | Sensor events, casts and overlaps, breakable joints |
| Tests | Runs the 29 automated tests on the device and shows the results |

Controls: drag to orbit the camera, use the mouse wheel or the + / − buttons to zoom, use the arrow keys, WASD or
the on-screen pad to move, and tap the scene to throw a ball.

| File | Purpose |
| --- | --- |
| `main.lua` | UI and main loop |
| `scenes.lua` | The demo scenes |
| `phys3d.lua` | Small helper that links Solar3D objects to Box3D bodies |
| `camera3d.lua` | Orbit camera |
| `box3d_tests.lua` | Automated tests |

## Documentation

The full API is in **[docs/API.md](docs/API.md)**. It covers the world, bodies, shapes, joints, sensors, queries,
breakable joints and math helpers.

## Credits and license

- [Box3D](https://github.com/erincatto/box3d) by Erin Catto, MIT License.
- [Solar3D](https://github.com/kan6868/solar3d/tree/main) for 3D rendering.
- [Solar2D](https://solar2d.com).
