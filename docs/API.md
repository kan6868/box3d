# BoxS3D API reference

`plugin.box3d` 0.2.0: 3D physics for Solar2D, based on [Box3D](https://github.com/erincatto/box3d). It is designed to
be used with [Solar3D](https://github.com/kan6868/solar3d/tree/main) (`plugin.s3d`) for rendering.

```lua
local box3d = require( "plugin.box3d" )
```

- [Conventions](#conventions)
- [World](#world)
- [Body](#body)
- [Shapes](#shapes)
- [Joints](#joints)
- [Events](#events)
- [Sensors](#sensors)
- [Queries](#queries)
- [Breakable joints](#breakable-joints)
- [Math helpers](#math-helpers)
- [Using with Solar3D](#using-with-solar3d)
- [Performance tips](#performance-tips)

## Conventions

| Topic | Convention |
| --- | --- |
| Units | Meters, kilograms, seconds. Forces in newtons (N), torques in N·m. |
| Axes | Right-handed, Y up, the same as Solar3D. |
| Angles | **Degrees**, as in Solar2D. Angular velocity is in degrees per second. |
| Rotations | Quaternions as 4 numbers `qx, qy, qz, qw`. Tables `{ qx, qy, qz, qw }` in options. |
| Euler angles | `angles = { rx, ry, rz }` in degrees, applied in Y·X·Z order (as Solar3D). |
| Vectors in options | Tables `{ x, y, z }`. |
| Density | Default 1000 kg/m³ (water): a 1 m³ box weighs 1000 kg. |
| Lifetime | Worlds, bodies, shapes and joints are Lua userdata. Destroying a world or body invalidates its children. Calling a method on a destroyed object raises an error, except `isValid()`. |

## World

### box3d.newWorld( [opts] )

Creates a physics world.

| Option | Default | Description |
| --- | --- | --- |
| `gravity` | `{ 0, -10, 0 }` | Gravity vector (m/s²). |
| `subSteps` | `4` | Solver sub-steps per `step()`. More is stiffer and slower. |
| `workers` | `1` | Worker threads. `n > 1` uses Box3D's built-in scheduler (creates `n − 1` threads). |
| `enableSleep` | `true` | Lets resting bodies sleep. |
| `enableContinuous` | `true` | Continuous collision against static bodies. |

```lua
local world = box3d.newWorld{ gravity = { 0, -9.8, 0 } }
```

### World methods

| Method | Returns | Description |
| --- | --- | --- |
| `world:step( dt [, subSteps] )` | | Advances the simulation. Use a fixed step such as `1/60`. |
| `world:newBody( opts )` | body | Creates a body. See [Body](#body). |
| `world:newRevoluteJoint( opts )` and other joint constructors | joint | See [Joints](#joints). |
| `world:rayCast( ... )`, `sphereCast`, `boxCast`, `castShape`, `overlapSphere`, `overlapBox`, `overlapShape`, `overlapAABB` | | See [Queries](#queries). |
| `world:explode{ position, radius, falloff, impulsePerArea = 1000 }` | | Pushes bodies away from `position`. |
| `world:getContactEvents()` | table | Contact events of the last step. See [Events](#events). |
| `world:getSensorEvents()` | table | Sensor events of the last step. See [Sensors](#sensors). |
| `world:getJointEvents()` | array | Joint force events of the last step. See [Breakable joints](#breakable-joints). |
| `world:getMoveEvents()` | array | Bodies that moved during the last step. See [Events](#events). |
| `world:getBodies()` | array | All live bodies. |
| `world:getAwakeBodyCount()` | number | Number of awake bodies. |
| `world:setGravity( x, y, z )` / `world:getGravity()` | `x, y, z` | Gravity. |
| `world:enableSleeping( on )` | | Turns sleeping on or off. |
| `world:destroy()` | | Destroys the world and everything in it. Also happens on garbage collection. |

## Body

### world:newBody( [opts] )

| Option | Default | Description |
| --- | --- | --- |
| `type` | `"dynamic"` | `"dynamic"`, `"static"` or `"kinematic"`. |
| `position` | `{ 0, 0, 0 }` | World position. |
| `rotation` | identity | Quaternion `{ qx, qy, qz, qw }`. |
| `angles` | | Euler angles `{ rx, ry, rz }` in degrees (instead of `rotation`). |
| `linearVelocity` | `{ 0, 0, 0 }` | m/s. |
| `angularVelocity` | `{ 0, 0, 0 }` | Degrees/s. |
| `linearDamping`, `angularDamping` | `0` | Velocity damping. |
| `gravityScale` | `1` | Multiplier on world gravity. |
| `bullet` | `false` | Continuous collision against dynamic bodies too (fast projectiles). |
| `enableSleep` | `true` | Allows this body to sleep. |
| `awake` | `true` | Initial awake state. |
| `lockRotation` | `false` | Prevents all rotation (character capsules). |

A body is a Lua userdata that accepts custom fields (`body.obj = mesh`, `body.tag = "enemy"`). Events and query
results return the same body object, so those fields are available there.

### Adding shapes

| Method | Description |
| --- | --- |
| `body:addBox( hx, hy, hz [, opts] )` | Box from half extents. |
| `body:addSphere( r [, opts] )` | Sphere. `opts.offset` is its center. |
| `body:addCapsule( x1, y1, z1, x2, y2, z2, r [, opts] )` | Capsule between two sphere centers. |
| `body:addCylinder( height, r [, sides = 16 [, opts]] )` | Cylinder along Y (convex hull). |
| `body:addHull( points [, opts] )` | Convex hull of `{ x1, y1, z1, ... }` or `{ { x, y, z }, ... }`. |
| `body:addMesh( vertices, indices [, opts] )` | Triangle mesh, 1-based indices. Best for static bodies. `opts.scale`. |

Each returns a [shape](#shapes).

### Body methods

| Method | Description |
| --- | --- |
| `getPosition()` | `x, y, z` |
| `getRotation()` | `qx, qy, qz, qw` |
| `getTransform()` | `x, y, z, qx, qy, qz, qw` (the arguments of Solar3D's `obj:setPose()`). |
| `setTransform( x, y, z [, qx, qy, qz, qw] )` | Teleports the body. |
| `getLinearVelocity()` / `setLinearVelocity( vx, vy, vz )` | m/s. |
| `getAngularVelocity()` / `setAngularVelocity( wx, wy, wz )` | Degrees/s. |
| `applyForce( fx, fy, fz [, px, py, pz] )` | Force at a world point, or at the center of mass. |
| `applyImpulse( ix, iy, iz [, px, py, pz] )` | Impulse at a world point, or at the center of mass. |
| `applyTorque( x, y, z )`, `applyAngularImpulse( x, y, z )` | |
| `getMass()` | kg. |
| `getType()` / `setType( type )` | `"dynamic"`, `"static"`, `"kinematic"`. |
| `isAwake()` / `setAwake( on )` | |
| `setBullet( on )` | |
| `setGravityScale( s )` | |
| `setDamping( linear [, angular] )` | |
| `setFixedRotation( on )` / `isFixedRotation()` | Locks rotation at runtime. |
| `getWorldPoint( lx, ly, lz )` / `getLocalPoint( x, y, z )` | Converts between body and world space. |
| `getShapes()` | Array of shapes. |
| `isValid()` | `false` after the body or its world is destroyed. |
| `destroy()` | Destroys the body, its shapes and its joints. |

## Shapes

Options shared by all `add*` methods:

| Option | Default | Description |
| --- | --- | --- |
| `density` | `1000` | kg/m³. |
| `friction` | `0.6` | |
| `restitution` | `0` | Bounciness, 0 to 1. |
| `rollingResistance` | `0` | |
| `offset` | `{ 0, 0, 0 }` | Position of the shape in the body. |
| `rotation` / `angles` | identity | Orientation of the shape in the body. |
| `sensor` | `false` | The shape detects overlaps but does not collide. See [Sensors](#sensors). |
| `sensorEvents` | `true` | This shape can be seen by sensors. |
| `contactEvents` | `true` | Reports `began` / `ended` contact events. |
| `hitEvents` | `false` | Reports `hit` events (impact speed and point). |
| `categoryBits` | all bits | The groups this shape belongs to. |
| `maskBits` | all bits | The groups this shape collides with. |
| `groupIndex` | `0` | Shapes with the same negative group never collide; the same positive group always collide. |

Two shapes collide when `(A.categoryBits & B.maskBits) ~= 0` and `(B.categoryBits & A.maskBits) ~= 0`.

> Unlike Box2D, a shape without `categoryBits` belongs to **every** category. Set `categoryBits` explicitly when you
> want to filter collisions or queries.

Shape methods: `setFriction( f )`, `getFriction()`, `setRestitution( r )`, `getRestitution()`, `setDensity( d )`,
`isSensor()`, `isValid()`, `destroy()`.

## Joints

All joints take:

| Option | Description |
| --- | --- |
| `bodyA`, `bodyB` | The two bodies (required). |
| `anchor` | Anchor point in world space. Default: the position of `bodyB`. |
| `collideConnected` | Lets the two bodies collide with each other. Default `false`. |
| `breakForce`, `breakTorque`, `breakable` | See [Breakable joints](#breakable-joints). |

The plugin computes each body's local frame from `anchor` and `axis`.

| Constructor | Specific options |
| --- | --- |
| `world:newRevoluteJoint( opts )` | `axis` (hinge axis); `enableLimit, lowerAngle, upperAngle` (degrees); `enableMotor, motorSpeed` (degrees/s), `maxMotorTorque`; `enableSpring, hertz, dampingRatio` |
| `world:newSphericalJoint( opts )` | `axis` (cone center); `enableConeLimit, coneAngle`; `enableTwistLimit, lowerTwistAngle, upperTwistAngle`; `enableSpring, hertz, dampingRatio` |
| `world:newPrismaticJoint( opts )` | `axis` (slide direction); `enableLimit, lowerTranslation, upperTranslation`; `enableMotor, motorSpeed` (m/s), `maxMotorForce`; spring options |
| `world:newWeldJoint( opts )` | `linearHertz, angularHertz, linearDampingRatio, angularDampingRatio` (0 = rigid) |
| `world:newDistanceJoint( opts )` | `anchorA, anchorB, length, enableSpring, hertz, dampingRatio, enableLimit, minLength, maxLength` |

### Joint methods

| Method | Description |
| --- | --- |
| `getType()` | `"revolute"`, `"spherical"`, `"prismatic"`, `"weld"`, `"distance"`. |
| `getBodies()` | `bodyA, bodyB` |
| `getAngle()` | Revolute angle in degrees. |
| `getTranslation()` | Prismatic translation in meters. |
| `enableMotor( on [, speed [, maxTorqueOrForce]] )` | Revolute and prismatic. |
| `setLimits( lower, upper )` | Revolute (degrees) and prismatic (meters). |
| `setLength( length )` | Distance joint. |
| `getConstraintForce()` / `getConstraintTorque()` | `x, y, z` of the last step. |
| `setBreakForce( n )` / `getBreakForce()` | |
| `setBreakTorque( n )` / `getBreakTorque()` | |
| `setBreakable( on )` | |
| `isValid()`, `destroy()` | |

```lua
-- a door hinged on the Y axis, limited to 0..110 degrees
local hinge = world:newRevoluteJoint{
    bodyA = wall, bodyB = door, anchor = { 1, 1, 0 }, axis = { 0, 1, 0 },
    enableLimit = true, lowerAngle = 0, upperAngle = 110,
}
```

## Events

Events describe the **last** `world:step()`. Read them after every step: they are replaced by the next step.

### world:getContactEvents()

Returns `{ began = {...}, ended = {...}, hit = {...} }`.

- Each `began` / `ended` entry has `bodyA, bodyB, shapeA, shapeB`.
- `hit` entries also have `x, y, z` (contact point), `nx, ny, nz` (normal) and `speed` (approach speed). Only shapes
  with `hitEvents = true` report hits.

```lua
for _, e in ipairs( world:getContactEvents().hit ) do
    if e.speed > 3 then audio.play( thud ) end
end
```

### world:getMoveEvents()

Returns an array of `{ body, x, y, z, qx, qy, qz, qw, sleep }` for the bodies that moved. This is the cheapest way to
sync many render objects.

```lua
for _, e in ipairs( world:getMoveEvents() ) do
    local obj = e.body.obj
    if obj then obj:setPose( e.x, e.y, e.z, e.qx, e.qy, e.qz, e.qw ) end
end
```

## Sensors

A shape with `sensor = true` does not collide. It reports shapes that enter or leave it.

```lua
local zone = world:newBody{ type = "static", position = { 0, 1, 0 } }
zone:addBox( 1.5, 1, 1.5, { sensor = true } )
zone.name = "goal"

-- after each world:step
local ev = world:getSensorEvents()
for _, e in ipairs( ev.began ) do print( e.visitorBody.tag, "entered", e.sensorBody.name ) end
for _, e in ipairs( ev.ended ) do print( "left", e.sensorBody and e.sensorBody.name ) end
```

`world:getSensorEvents()` returns `{ began = {...}, ended = {...} }`. Each entry is
`{ sensor, visitor, sensorBody, visitorBody }`.

- Both shapes must have sensor events enabled. `sensorEvents` is on by default for every shape. Set
  `sensorEvents = false` on shapes that sensors should ignore, which also saves work.
- Only convex shapes (box, sphere, capsule, hull) trigger sensors; meshes do not. Sensors do not detect other sensors
  or shapes on the same body.
- Destroying a body or shape inside a sensor produces an `ended` event, where `visitor` / `visitorBody` may be `nil`.

## Queries

| Method | Description |
| --- | --- |
| `world:rayCast( ox, oy, oz, tx, ty, tz [, opts] )` | Ray from origin `o` along translation `t`. |
| `world:sphereCast( ox, oy, oz, r, tx, ty, tz [, opts] )` | Sphere of radius `r` moved from `o` along `t`. |
| `world:boxCast( ox, oy, oz, hx, hy, hz, tx, ty, tz [, opts] )` | Box with half extents `h`. `opts.rotation` / `angles` rotate it. |
| `world:castShape{ points, radius, position, translation, ... }` | Convex hull of `points` (around `position`, up to 64 points), rounded by `radius`. |
| `world:overlapSphere( x, y, z, r [, opts] )` | Shapes touching the sphere (exact test). |
| `world:overlapBox( x, y, z, hx, hy, hz [, opts] )` | Shapes touching the box (`opts.rotation` / `angles`). |
| `world:overlapShape{ points, radius, position, ... }` | Shapes touching a convex hull. |
| `world:overlapAABB( minX, minY, minZ, maxX, maxY, maxZ [, opts] )` | Shapes whose bounding box touches this box. Fast but coarse. |

Common options:

| Option | Default | Description |
| --- | --- | --- |
| `mode` | `"closest"` | `"closest"`, `"all"` or `"any"`. |
| `categoryBits` | all bits | Groups of the query. |
| `maskBits` | all bits | Groups the query can hit. |
| `ignoreSensors` | `false` | Skip sensor shapes. |
| `bodies` | `false` | Overlaps only: return bodies instead of shapes, without duplicates. |

**Cast results**

- `closest` and `any` return one hit or `nil`.
- `all` returns an array of hits sorted by `fraction`, or `nil` when nothing is hit.
- A hit is `{ body, shape, x, y, z, nx, ny, nz, fraction, triangle }`. `triangle` (1-based) is set for meshes only.
- Shape casts also return `cx, cy, cz`: the position of the cast shape at impact (for example the sphere center).

**Overlap results**

- An array of `{ body, shape }`, one entry per shape, or an empty array.
- With `bodies = true`, an array of bodies.
- `mode = "any"` stops at the first shape.

A shape matches when `(shape.categoryBits & opts.maskBits) ~= 0` and `(shape.maskBits & opts.categoryBits) ~= 0`.

```lua
-- where does a ball dropped from above land?
local hit = world:sphereCast( x, 10, z, 0.5, 0, -20, 0 )
if hit then marker:moveTo( hit.cx, hit.cy, hit.cz ) end

-- enemies within 6 m
local enemies = world:overlapSphere( px, py, pz, 6, { maskBits = ENEMY, bodies = true } )

-- line of sight
local blocked = world:rayCast( ex, ey, ez, px - ex, py - ey, pz - ez, { mode = "any", maskBits = WALL } )
```

## Breakable joints

```lua
local j = world:newWeldJoint{ bodyA = a, bodyB = b, anchor = { 0, 1, 0 }, breakForce = 20000 }  -- N
j:setBreakTorque( 5000 )                                                                         -- N·m

-- after each world:step
for _, e in ipairs( world:getJointEvents() ) do
    if e.broken then print( "broke", e.force, e.torque ) end
end
```

Each event is `{ joint, bodyA, bodyB, force, torque, broken }`.

- When the joint force or torque exceeds its threshold, the joint is **destroyed right after the step**:
  `broken = true` and `joint:isValid()` becomes `false`.
- With `breakable = false` (at creation) or `joint:setBreakable( false )`, the joint only reports the event every
  step and stays intact.
- A joint without thresholds never reports events. `setBreakForce( nil )` removes the threshold. Setting a threshold
  at runtime wakes both bodies (sleeping bodies have no forces).
- Impact forces are much larger than resting forces. To tune a threshold, use `breakable = false` and print
  `e.force`.
- Destroying a body also destroys its joints.

## Math helpers

| Function | Returns |
| --- | --- |
| `box3d.quatFromEuler( rx, ry, rz )` | `qx, qy, qz, qw` from degrees (Y·X·Z order). |
| `box3d.quatFromAxisAngle( ax, ay, az, deg )` | `qx, qy, qz, qw` |
| `box3d.quatMul( ax, ay, az, aw, bx, by, bz, bw )` | `qx, qy, qz, qw` (a · b) |
| `box3d.rotate( qx, qy, qz, qw, vx, vy, vz )` | `x, y, z`: the vector rotated by the quaternion |

## Using with Solar3D

Solar3D and BoxS3D share the same axes, units and quaternion order, so a body maps directly to a Solar3D object:

```lua
local s3d = require( "plugin.s3d" )
local box3d = require( "plugin.box3d" )

local scene = s3d.newScene()
local world = box3d.newWorld()

local function crate( x, y, z )
    local body = world:newBody{ position = { x, y, z } }
    body:addBox( 0.5, 0.5, 0.5 )
    body.obj = s3d.newCube( scene, 1, { texture = "assets/crate.png" } )
    body.obj:setPose( body:getTransform() )
    return body
end

Runtime:addEventListener( "enterFrame", function()
    world:step( 1 / 60 )
    for _, e in ipairs( world:getMoveEvents() ) do
        if e.body.obj then e.body.obj:setPose( e.x, e.y, e.z, e.qx, e.qy, e.qz, e.qw ) end
    end
end )
```

Picking with the camera:

```lua
-- tap: find what is under the finger
local o, d = s3d.screenToRay( event.x, event.y )
local hit = world:rayCast( o[1], o[2], o[3], d[1] * 100, d[2] * 100, d[3] * 100 )
if hit then print( "tapped", hit.body.tag ) end
```

The demo's `phys3d.lua` wraps this pattern (body + mesh + sync) in a small helper you can copy.

## Performance tips

- Step with a fixed `dt` (1/60). Use an accumulator if the frame rate varies.
- Sync render objects with `world:getMoveEvents()` instead of reading every body.
- Prefer boxes, spheres and capsules. Use hulls for irregular dynamic objects and meshes only for static level geometry.
- Merge static geometry into a few large boxes or one static body with many shapes.
- Let bodies sleep (`enableSleep = true`).
- Set `sensorEvents = false`, `contactEvents = false` on shapes that do not need them.
- `workers > 1` enables multi-threading. On Android, test it on your target devices first.
