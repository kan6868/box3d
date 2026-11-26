-- Demo scenes, following popular Box3D samples (samples/sample_*.cpp).
-- Each scene: build( env, ctx ) -> { camera = { yaw, pitch, dist, target }, update = function( dt ) end }
--   env: phys3d (env.world is the plugin.box3d world)
--   ctx.button( label, fn ): add a scene-specific button · ctx.info( text ): description line · ctx.box3d: plugin
local S = {}

local CRATE = { texture = "assets/crate.png", color = { 1, 1, 1 } }
local function col( r, g, b ) return { color = { r, g, b } } end
local PALETTE = { { 0.9, 0.35, 0.3 }, { 0.3, 0.65, 0.9 }, { 0.95, 0.8, 0.3 }, { 0.45, 0.8, 0.45 }, { 0.75, 0.5, 0.9 }, { 0.95, 0.6, 0.3 } }
local function pal( i ) return col( unpack( PALETTE[( i - 1 ) % #PALETTE + 1] ) ) end

local function add( name, info, build ) S[#S + 1] = { name = name, info = info, build = build } end

---------------------------------------------------------------------------------------------
add( "Box Stack", "Stacking / Box Stack: 15 boxes stacked straight up. Tap the scene to throw a ball.", function( env )
    env:ground( 20 )
    for i = 1, 15 do
        env:box( 0.5, 0.5, 0.5, { position = { 0, 0.5 + ( i - 1 ) * 1.0, 0 } }, { rollingResistance = 0.1 }, CRATE )
    end
    return { camera = { 35, 15, 22, { 0, 6, 0 } } }
end )

add( "Pyramid", "Stacking / Large Pyramid (scaled down): 12-tier pyramid, 78 boxes.", function( env )
    env:ground( 20 )
    local base = 12
    for row = 0, base - 1 do
        local n = base - row
        for i = 0, n - 1 do
            env:box( 0.5, 0.5, 0.5, { position = { ( i - ( n - 1 ) / 2 ) * 1.05, 0.5 + row, 0 } }, nil, CRATE )
        end
    end
    return { camera = { 25, 18, 24, { 0, 5, 0 } } }
end )

add( "Jenga", "Stacking / Jenga Stack: 14 tiers, 3 bars per tier rotated 90°. Throw a ball to pull out bars.", function( env )
    env:ground( 20 )
    local hx, hy, hz, gap = 1.5, 0.3, 0.5, 0.02
    for layer = 0, 13 do
        local y = hy + layer * ( 2 * hy + 0.005 )
        for k = -1, 1 do
            local off = k * ( 2 * hz + gap )
            if layer % 2 == 0 then
                env:box( hx, hy, hz, { position = { 0, y, off } }, { friction = 0.6 }, CRATE )
            else
                env:box( hz, hy, hx, { position = { off, y, 0 } }, { friction = 0.6 }, CRATE )
            end
        end
    end
    return { camera = { 40, 20, 18, { 0, 4, 0 } } }
end )

add( "Dominoes", "Stacking / Dominoes: 40 tiles arranged in an arc, automatically pushes the first one after 1 second.", function( env, ctx )
    env:ground( 25 )
    local first
    local n, radius = 40, 9
    for i = 0, n - 1 do
        local a = math.pi * 1.4 * i / ( n - 1 ) - math.pi * 0.2
        local x, z = radius * math.cos( a ), radius * math.sin( a ) - 4
        -- thin axis (local X) lies along the arc tangent: rotate around Y by 90° - a
        local _, b = env:box( 0.08, 0.6, 0.3, { position = { x, 0.6, z }, angles = { 0, 90 - math.deg( a ), 0 } },
            { friction = 0.6 }, pal( i + 1 ) )
        first = first or b
    end
    local t = 0
    local pushed = false
    local function push()
        -- local X = (sin a, 0, -cos a), opposite the next tile: push along -X, near the top of the tile
        local qx, qy, qz, qw = first:getRotation()
        local nx, _, nz = ctx.box3d.rotate( qx, qy, qz, qw, 1, 0, 0 )
        local x, y, z = first:getPosition()
        first:applyImpulse( -nx * 60, 0, -nz * 60, x, y + 0.45, z )
    end
    ctx.button( "Push", push )
    return {
        camera = { 0, 40, 26, { 0, 0, 0 } },
        update = function( dt )
            t = t + dt
            if not pushed and t > 1 then pushed = true; push() end
        end,
    }
end )

add( "Bridge", "Joints / Bridge: 24 planks connected by revolute joints between two pillars.", function( env, ctx )
    env:ground( 25 )
    local n, w, y = 24, 0.5, 4
    local x0 = -n * w / 2
    local _, left = env:box( 0.3, y / 2, 1.2, { type = "static", position = { x0 - 0.3, y / 2, 0 } }, nil, col( 0.5, 0.5, 0.55 ) )
    local _, right = env:box( 0.3, y / 2, 1.2, { type = "static", position = { -x0 + 0.3, y / 2, 0 } }, nil, col( 0.5, 0.5, 0.55 ) )
    local prev = left
    for i = 0, n - 1 do
        local _, plank = env:box( w / 2 - 0.01, 0.08, 1, { position = { x0 + w * ( i + 0.5 ), y - 0.08, 0 } }, { density = 500 }, CRATE )
        env.world:newRevoluteJoint{ bodyA = prev, bodyB = plank, anchor = { x0 + w * i, y - 0.08, 0 }, axis = { 0, 0, 1 } }
        prev = plank
    end
    env.world:newRevoluteJoint{ bodyA = prev, bodyB = right, anchor = { -x0, y - 0.08, 0 }, axis = { 0, 0, 1 } }
    local function drop()
        for k = 1, 6 do
            local x = ( math.random() - 0.5 ) * n * w * 0.7
            if k % 2 == 0 then
                env:sphere( 0.35, { position = { x, y + 3 + k, ( math.random() - 0.5 ) } }, nil, pal( k ) )
            else
                env:box( 0.35, 0.35, 0.35, { position = { x, y + 3 + k, ( math.random() - 0.5 ) } }, nil, pal( k ) )
            end
        end
    end
    drop()
    ctx.button( "Drop", drop )
    return { camera = { 20, 20, 18, { 0, 3, 0 } } }
end )

add( "Ball and Chain", "Joints / Ball and Chain: 20-link chain of capsule segments (spherical joints) pulling a heavy ball.", function( env )
    env:ground( 25 )
    local top, n, seg = 12, 20, 0.5
    local _, anchor = env:box( 0.3, 0.3, 0.3, { type = "static", position = { 0, top, 0 } }, nil, col( 0.5, 0.5, 0.55 ) )
    local prev = anchor
    for i = 1, n do
        local x = ( i - 0.5 ) * seg
        local _, link = env:capsule( 0.08, seg / 2 - 0.1, { position = { x, top, 0 }, angles = { 0, 0, 90 } },
            { density = 2000 }, col( 0.75, 0.75, 0.8 ) )
        env.world:newSphericalJoint{ bodyA = prev, bodyB = link, anchor = { ( i - 1 ) * seg, top, 0 } }
        prev = link
    end
    local r = 1.0
    local _, ball = env:sphere( r, { position = { n * seg + r, top, 0 } }, { density = 3000 }, col( 0.3, 0.3, 0.35 ) )
    env.world:newSphericalJoint{ bodyA = prev, bodyB = ball, anchor = { n * seg, top, 0 } }
    -- a few boxes for the ball to sweep through
    for i = 1, 8 do env:box( 0.5, 0.5, 0.5, { position = { -3 + i * 0.9, 0.5, ( i % 2 ) * 1.2 - 0.6 } }, nil, CRATE ) end
    return { camera = { 15, 15, 26, { 2, 6, 0 } } }
end )

-- simple ragdoll: 11 parts, spherical joints with cone limits at neck/shoulders/hips, revolute at elbows/knees
local ragdollGroup = 0
local function ragdoll( env, x, y, z, tint )
    ragdollGroup = ragdollGroup - 1
    local f = { groupIndex = ragdollGroup, friction = 0.6 } -- parts of the same ragdoll don't collide
    local c = { color = tint }
    local function cap( r, h, px, py, pz ) local _, b = env:capsule( r, h, { position = { x + px, y + py, z + pz } }, f, c ); return b end
    local function bx( hx, hy, hz, px, py, pz ) local _, b = env:box( hx, hy, hz, { position = { x + px, y + py, z + pz } }, f, c ); return b end
    local pelvis = bx( 0.16, 0.1, 0.1, 0, 1.0, 0 )
    local torso = bx( 0.18, 0.22, 0.11, 0, 1.36, 0 )
    local _, head = env:sphere( 0.12, { position = { x, y + 1.72, z } }, f, col( 0.95, 0.8, 0.65 ) )
    local thighL, thighR = cap( 0.065, 0.16, -0.09, 0.7, 0 ), cap( 0.065, 0.16, 0.09, 0.7, 0 )
    local shinL, shinR = cap( 0.055, 0.16, -0.09, 0.26, 0 ), cap( 0.055, 0.16, 0.09, 0.26, 0 )
    local armL, armR = cap( 0.05, 0.13, -0.26, 1.4, 0 ), cap( 0.05, 0.13, 0.26, 1.4, 0 )
    local foreL, foreR = cap( 0.045, 0.12, -0.26, 1.06, 0 ), cap( 0.045, 0.12, 0.26, 1.06, 0 )
    local w = env.world
    local function ball( a, b, px, py, axis, cone )
        w:newSphericalJoint{ bodyA = a, bodyB = b, anchor = { x + px, y + py, z }, axis = axis,
            enableConeLimit = true, coneAngle = cone, enableTwistLimit = true, lowerTwistAngle = -25, upperTwistAngle = 25 }
    end
    local function hinge( a, b, px, py, lo, hi )
        w:newRevoluteJoint{ bodyA = a, bodyB = b, anchor = { x + px, y + py, z }, axis = { 1, 0, 0 },
            enableLimit = true, lowerAngle = lo, upperAngle = hi }
    end
    ball( pelvis, torso, 0, 1.12, { 0, 1, 0 }, 25 )
    ball( torso, head, 0, 1.6, { 0, 1, 0 }, 35 )
    ball( pelvis, thighL, -0.09, 0.92, { 0, -1, 0 }, 50 )
    ball( pelvis, thighR, 0.09, 0.92, { 0, -1, 0 }, 50 )
    hinge( thighL, shinL, -0.09, 0.48, 0, 140 )
    hinge( thighR, shinR, 0.09, 0.48, 0, 140 )
    ball( torso, armL, -0.26, 1.56, { 0, -1, 0 }, 85 )
    ball( torso, armR, 0.26, 1.56, { 0, -1, 0 }, 85 )
    hinge( armL, foreL, -0.26, 1.24, -140, 0 )
    hinge( armR, foreR, 0.26, 1.24, -140, 0 )
    return pelvis
end

add( "Ragdoll Pile", "Ragdoll / Pile: 8 ragdolls (11 parts, joint limits) falling onto steps.", function( env )
    env:ground( 25 )
    for i = 0, 5 do
        env:box( 3, 0.25 * ( i + 1 ), 0.6, { type = "static", position = { 0, 0.25 * ( i + 1 ), -i * 1.2 } }, nil, col( 0.6, 0.6, 0.65 ) )
    end
    for i = 1, 8 do
        ragdoll( env, ( ( i - 1 ) % 4 - 1.5 ) * 1.2, 2.5 + math.floor( ( i - 1 ) / 4 ) * 2.2, -5 + ( i % 2 ), PALETTE[( i - 1 ) % #PALETTE + 1] )
    end
    return { camera = { 60, 18, 14, { 0, 1.5, -3 } } }
end )

add( "Restitution", "Restitution: 6 balls with restitution 0, 0.2 … 1.0 dropped from the same height.", function( env )
    env:ground( 20, { restitution = 0 } )
    for i = 0, 5 do
        env:sphere( 0.4, { position = { ( i - 2.5 ) * 1.4, 6, 0 } }, { restitution = i / 5 }, pal( i + 1 ) )
    end
    return { camera = { 0, 12, 16, { 0, 3, 0 } } }
end )

add( "Inclined Plane", "Shapes / Inclined Plane: 25° slope, 5 boxes with friction 0 … 0.8 (tan 25° ≈ 0.47).", function( env )
    env:ground( 25 )
    local b3 = env.b3
    local qx, qy, qz, qw = b3.quatFromEuler( 0, 0, -25 )
    local _, ramp = env:box( 8, 0.25, 4, { type = "static", position = { 0, 3.5, 0 }, rotation = { qx, qy, qz, qw } }, { friction = 1 }, col( 0.55, 0.55, 0.6 ) )
    local nx, ny = b3.rotate( qx, qy, qz, qw, 0, 1, 0 )
    local tx, ty = b3.rotate( qx, qy, qz, qw, 1, 0, 0 )
    for i = 0, 4 do
        local z = ( i - 2 ) * 1.5
        local px, py = -5 * tx + 0.8 * nx, 3.5 - 5 * ty + 0.8 * ny
        env:box( 0.5, 0.5, 0.5, { position = { px, py, z }, rotation = { qx, qy, qz, qw } }, { friction = i * 0.2 }, pal( i + 1 ) )
    end
    return { camera = { 20, 15, 22, { 0, 2, 0 } } }
end )

add( "Convex Pile", "Benchmark / Convex Pile (scaled down): 80 boxes, spheres, cylinders, capsules falling into a bin.", function( env )
    env:ground( 25 )
    local wall = col( 0.55, 0.55, 0.6 )
    env:box( 4, 1.5, 0.2, { type = "static", position = { 0, 1.5, 4 } }, nil, wall )
    env:box( 4, 1.5, 0.2, { type = "static", position = { 0, 1.5, -4 } }, nil, wall )
    env:box( 0.2, 1.5, 4, { type = "static", position = { 4, 1.5, 0 } }, nil, wall )
    env:box( 0.2, 1.5, 4, { type = "static", position = { -4, 1.5, 0 } }, nil, wall )
    local k = 0
    for layer = 0, 4 do
        for i = 0, 3 do
            for j = 0, 3 do
                k = k + 1
                local p = { ( i - 1.5 ) * 1.6 + ( math.random() - 0.5 ) * 0.3, 4 + layer * 1.6, ( j - 1.5 ) * 1.6 + ( math.random() - 0.5 ) * 0.3 }
                local o = { position = p, angles = { math.random( 360 ), math.random( 360 ), math.random( 360 ) } }
                local kind = k % 4
                if kind == 0 then env:box( 0.35, 0.25, 0.45, o, nil, pal( k ) )
                elseif kind == 1 then env:sphere( 0.4, o, nil, pal( k ) )
                elseif kind == 2 then env:cylinder( 0.6, 0.35, o, nil, pal( k ) )
                else env:capsule( 0.25, 0.3, o, nil, pal( k ) ) end
            end
        end
    end
    return { camera = { 30, 35, 20, { 0, 1, 0 } } }
end )

add( "Explosion", "Benchmark / Explosion: ring of 48 boxes, press \"Explode\" to push them out from the center.", function( env, ctx )
    env:ground( 25 )
    for ring = 1, 3 do
        local n = 8 * ring
        for i = 0, n - 1 do
            local a = 2 * math.pi * i / n
            env:box( 0.4, 0.4, 0.4, { position = { 2 * ring * math.cos( a ), 0.4, 2 * ring * math.sin( a ) }, angles = { 0, -math.deg( a ), 0 } }, nil, CRATE )
        end
    end
    local function boom() env.world:explode{ position = { 0, 0, 0 }, radius = 8, falloff = 4, impulsePerArea = 3000 } end
    ctx.button( "Explode", boom )
    return { camera = { 30, 40, 22, { 0, 0, 0 } } }
end )

add( "Bullet vs Stack", "Continuous / Bullet vs Stack: fire a 120 m/s bullet into a box stack (continuous collision).", function( env, ctx )
    env:ground( 25 )
    for row = 0, 7 do
        for i = 0, 3 do
            env:box( 0.4, 0.4, 0.4, { position = { 3, 0.4 + row * 0.8, ( i - 1.5 ) * 0.82 } }, nil, CRATE )
        end
    end
    local function fire()
        env:sphere( 0.15, { position = { -12, 2.5 + math.random() * 2, ( math.random() - 0.5 ) * 2 }, linearVelocity = { 120, 0, 0 }, bullet = true },
            { density = 8000 }, col( 0.25, 0.25, 0.3 ) )
    end
    ctx.button( "Fire", fire )
    return { camera = { 70, 12, 18, { 0, 2.5, 0 } } }
end )

add( "Spinner", "Benchmark / Spinner (scaled down): motorized paddle (revolute) stirring 120 balls in a bin.", function( env, ctx )
    env:ground( 25 )
    local wall = col( 0.55, 0.55, 0.6 )
    env:box( 5, 2, 0.2, { type = "static", position = { 0, 2, 5 } }, nil, wall )
    env:box( 5, 2, 0.2, { type = "static", position = { 0, 2, -5 } }, nil, wall )
    env:box( 0.2, 2, 5, { type = "static", position = { 5, 2, 0 } }, nil, wall )
    env:box( 0.2, 2, 5, { type = "static", position = { -5, 2, 0 } }, nil, wall )
    local _, paddle = env:box( 4.6, 0.6, 0.15, { position = { 0, 0.7, 0 } }, { density = 2000 }, col( 0.9, 0.35, 0.3 ) )
    local joint = env.world:newRevoluteJoint{ bodyA = env.groundBody, bodyB = paddle, anchor = { 0, 0.7, 0 }, axis = { 0, 1, 0 },
        enableMotor = true, motorSpeed = 120, maxMotorTorque = 1e6 }
    for i = 1, 120 do
        env:sphere( 0.3, { position = { ( math.random() - 0.5 ) * 8, 2 + math.floor( ( i - 1 ) / 30 ) * 0.8, ( math.random() - 0.5 ) * 8 } }, nil, pal( i ) )
    end
    local on = true
    ctx.button( "Motor", function() on = not on; joint:enableMotor( on, 120 ) end )
    return { camera = { 25, 45, 20, { 0, 0, 0 } } }
end )

add( "Elevator", "Joints / Prismatic + Bodies / Kinematic: motorized elevator and a kinematic conveyor.", function( env, ctx )
    env:ground( 25 )
    local _, lift = env:box( 1.5, 0.15, 1.5, { position = { -4, 0.3, 0 } }, { density = 500 }, col( 0.3, 0.65, 0.9 ) )
    local j = env.world:newPrismaticJoint{ bodyA = env.groundBody, bodyB = lift, anchor = { -4, 0.3, 0 }, axis = { 0, 1, 0 },
        enableLimit = true, lowerTranslation = 0, upperTranslation = 5, enableMotor = true, motorSpeed = 1.5, maxMotorForce = 1e6 }
    for i = 0, 2 do env:box( 0.4, 0.4, 0.4, { position = { -4 + ( i - 1 ) * 0.9, 0.9, 0 } }, nil, CRATE ) end
    local _, platform = env:box( 1.5, 0.15, 1.5, { type = "kinematic", position = { 3, 2, 0 } }, nil, col( 0.95, 0.8, 0.3 ) )
    env:box( 0.4, 0.4, 0.4, { position = { 3, 2.6, 0 } }, nil, CRATE )
    local t, up = 0, true
    ctx.button( "Up/Down", function() up = not up; j:enableMotor( true, up and 1.5 or -1.5 ) end )
    return {
        camera = { 20, 15, 18, { 0, 2, 0 } },
        update = function( dt )
            t = t + dt
            -- kinematic body: set velocity, Box3D automatically pushes objects standing on it
            platform:setLinearVelocity( 2.5 * math.cos( t * 0.8 ), 0, 0 )
            local tr = j:getTranslation()
            if up and tr > 4.95 then up = false; j:enableMotor( true, -1.5 )
            elseif not up and tr < 0.05 then up = true; j:enableMotor( true, 1.5 ) end
        end,
    }
end )

add( "Sensors", "Sensor shapes (plugin.box3d 0.2): three trigger zones count the balls inside them (world:getSensorEvents). Balls pass through sensors and take the zone's color.", function( env, ctx )
    if not env.world.getSensorEvents then ctx.status( "Needs plugin.box3d 0.2" ); return {} end
    env:ground( 20 )
    local s3d = env.s3d
    local ZC = { { 0.95, 0.35, 0.3 }, { 0.3, 0.6, 0.95 }, { 0.4, 0.85, 0.4 } }
    local NAMES = { "Red", "Blue", "Green" }
    local zones = {}
    for i = 1, 3 do
        local x = ( i - 2 ) * 4.5
        local body = env.world:newBody{ type = "static", position = { x, 1, 0 } }
        body:addBox( 1.5, 1, 1.5, { sensor = true } ) -- 3 x 2 x 3 m trigger volume
        local pad = s3d.newCube( env.scene, 1, { texture = "assets/white.png" } )
        pad:scaleTo( 3, 0.04, 3 ); pad:moveTo( x, 0.02, 0 )
        body.zone = { pad = pad, color = ZC[i], inside = 0, total = 0, name = NAMES[i] }
        zones[i] = body.zone
    end
    local function paintPad( z )
        local k = 0.45 + 0.55 * math.min( 1, z.inside / 4 )
        z.pad:setFillColor( z.color[1] * k, z.color[2] * k, z.color[3] * k )
    end
    for _, z in ipairs( zones ) do paintPad( z ) end

    local WHITE = { 0.9, 0.9, 0.9 }
    env:onStep( function()
        local ev = env.world:getSensorEvents()
        for _, e in ipairs( ev.began ) do
            local z, b = e.sensorBody and e.sensorBody.zone, e.visitorBody
            if z then
                z.inside, z.total = z.inside + 1, z.total + 1
                paintPad( z )
                if b and b.obj then b.color = z.color; b.obj:setFillColor( unpack( z.color ) ) end
            end
        end
        for _, e in ipairs( ev.ended ) do
            local z, b = e.sensorBody and e.sensorBody.zone, e.visitorBody -- visitorBody is nil when the ball was removed
            if z then
                z.inside = math.max( 0, z.inside - 1 )
                paintPad( z )
                if b and b.obj and b.obj.setFillColor then b.color = WHITE; b.obj:setFillColor( unpack( WHITE ) ) end
            end
        end
    end )

    local balls, t, rain = {}, 0, true
    local function spawn()
        local _, b = env:sphere( 0.3, { position = { ( math.random() - 0.5 ) * 15, 8, ( math.random() - 0.5 ) * 3 } },
            { restitution = 0.3 }, { color = WHITE } )
        balls[#balls + 1] = b
        if #balls > 50 then env:remove( table.remove( balls, 1 ) ) end
    end
    ctx.button( "Rain", function() rain = not rain end )
    return {
        camera = { 0, 30, 20, { 0, 1, 0 } },
        update = function( dt )
            t = t + dt
            if rain and t > 0.35 then t = 0; spawn() end
            local parts = {}
            for i, z in ipairs( zones ) do parts[i] = string.format( "%s: %d inside, %d entered", z.name, z.inside, z.total ) end
            ctx.status( table.concat( parts, " · " ) )
        end,
    }
end )

add( "Queries", "Queries (plugin.box3d 0.2): the laser ray cast lists every hit (mode \"all\"), the ghost ball is a sphere cast showing where a ball dropped from above would stop, the ring is an overlap test.", function( env, ctx )
    if not env.world.sphereCast then ctx.status( "Needs plugin.box3d 0.2" ); return {} end
    env:ground( 20 )
    local s3d = env.s3d
    local BLUE, ORANGE = { 0.3, 0.6, 0.95 }, { 0.95, 0.6, 0.25 }
    for i = 1, 36 do
        local a, r = i * 2.4, 2 + ( i % 9 ) * 0.8
        local x, z = r * math.cos( a ), r * math.sin( a )
        if i % 2 == 0 then
            env:box( 0.4, 0.4 + ( i % 3 ) * 0.3, 0.4, { position = { x, 0.4 + ( i % 3 ) * 0.3, z } }, { categoryBits = 2 }, { color = BLUE } )
        else
            env:sphere( 0.45, { position = { x, 0.45, z } }, { categoryBits = 4 }, { color = ORANGE } )
        end
    end
    -- markers (drawing only, no bodies)
    local function marker( r, c )
        local m = s3d.newSphere( env.scene, r, 12, 8, { texture = "assets/white.png" } )
        m:setFillColor( unpack( c ) ); m.isVisible = false
        return m
    end
    local hits = {}
    for i = 1, 16 do hits[i] = marker( 0.12, { 1, 0.95, 0.2 } ) end
    local beam = s3d.newCube( env.scene, 1, { texture = "assets/white.png" } )
    beam:setFillColor( 1, 0.2, 0.2 )
    local ghost = marker( 0.4, { 0.5, 1, 0.6 } )
    local ring = s3d.newCylinder( env.scene, 1.5, 0.03, 32, { texture = "assets/white.png" } )
    ring:setFillColor( 0.95, 0.95, 0.4 )

    local FILTERS = { { "all", nil }, { "boxes", 2 }, { "spheres", 4 } }
    local filter, modeAll = 1, true
    ctx.button( "Filter", function() filter = filter % #FILTERS + 1 end )
    ctx.button( "Closest/All", function() modeAll = not modeAll end )

    local lit = {} -- bodies highlighted by the ring last frame
    local t = 0
    local Y, LEN = 0.5, 11
    return {
        camera = { 20, 50, 22, { 0, 0, 0 } },
        update = function( dt )
            t = t + dt
            local w = env.world
            local opts = { mode = modeAll and "all" or "closest", maskBits = FILTERS[filter][2] }
            -- laser: horizontal ray from the center, turning slowly
            local a = t * 0.4
            local dx, dz = math.cos( a ) * LEN, math.sin( a ) * LEN
            beam:scaleTo( LEN, 0.03, 0.03 ); beam:moveTo( dx / 2, Y, dz / 2 ); beam:rotateTo( 0, -math.deg( a ), 0 )
            local res = w:rayCast( 0, Y, 0, dx, 0, dz, opts )
            if res and not modeAll then res = { res } end
            res = res or {}
            for i, m in ipairs( hits ) do
                local h = res[i]
                m.isVisible = h ~= nil
                if h then m:moveTo( h.x, h.y, h.z ) end
            end
            -- sphere cast straight down from a point circling at 8 m
            local px, pz = 5 * math.cos( -t * 0.3 ), 5 * math.sin( -t * 0.3 )
            local sc = w:sphereCast( px, 8, pz, 0.4, 0, -10, 0, { maskBits = FILTERS[filter][2] } )
            ghost.isVisible = sc ~= nil
            if sc then ghost:moveTo( sc.cx, sc.cy, sc.cz ) end
            -- overlap: bodies touching a 1.5 m sphere sliding back and forth
            local ox = 6 * math.sin( t * 0.5 )
            ring:moveTo( ox, 0.03, -1 )
            for b in pairs( lit ) do if b:isValid() and b.obj then b.obj:setFillColor( unpack( b.color ) ) end end
            lit = {}
            local inside = w:overlapSphere( ox, 0.5, -1, 1.5, { bodies = true, maskBits = FILTERS[filter][2] } )
            local n = 0
            for _, b in ipairs( inside ) do
                if b.obj and b ~= env.groundBody then lit[b] = true; n = n + 1; b.obj:setFillColor( 1, 1, 1 ) end
            end
            ctx.status( string.format( "Filter: %s · ray mode: %s · ray hits: %d · bodies in ring: %d",
                FILTERS[filter][1], opts.mode, #res, n ) )
        end,
    }
end )

add( "Breakable", "Breakable joints (plugin.box3d 0.2): a wall of crates glued with weld joints (breakForce). Tap to throw balls; joints that take too much force break (world:getJointEvents).", function( env, ctx )
    if not env.world.getJointEvents then ctx.status( "Needs plugin.box3d 0.2" ); return {} end
    env:ground( 20 )
    local H, Wd, h = 6, 7, 0.4
    local grid, joints = {}, {}
    local strength = 20000 -- N: holds the wall up, a thrown ball breaks it
    for r = 1, H do
        grid[r] = {}
        for c = 1, Wd do
            local x, y = ( c - ( Wd + 1 ) / 2 ) * 2 * h, h + ( r - 1 ) * 2 * h
            local _, b = env:box( h, h, h, { position = { x, y, 0 } }, { density = 300 }, CRATE )
            grid[r][c] = b
            if c > 1 then
                joints[#joints + 1] = env.world:newWeldJoint{ bodyA = grid[r][c - 1], bodyB = b, anchor = { x - h, y, 0 }, breakForce = strength }
            end
            if r > 1 then
                joints[#joints + 1] = env.world:newWeldJoint{ bodyA = grid[r - 1][c], bodyB = b, anchor = { x, y - h, 0 }, breakForce = strength }
            end
        end
    end
    local broken = 0
    env:onStep( function()
        for _, e in ipairs( env.world:getJointEvents() ) do
            if e.broken then
                broken = broken + 1
                -- tint the two crates that came apart
                for _, b in ipairs{ e.bodyA, e.bodyB } do
                    if b and b.obj then b.color = { 1, 0.75, 0.6 }; b.obj:setFillColor( 1, 0.75, 0.6 ) end
                end
            end
        end
    end )
    ctx.button( "Strength", function()
        strength = strength == 20000 and 40000 or 20000
        for _, j in ipairs( joints ) do if j:isValid() then j:setBreakForce( strength ) end end
    end )
    ctx.button( "Explode", function() env.world:explode{ position = { 0, 1, 1 }, radius = 4, impulsePerArea = 6000 } end )
    return {
        camera = { 0, 12, 14, { 0, 2.4, 0 } },
        update = function()
            ctx.status( string.format( "Break force %d N · joints broken: %d / %d", strength, broken, #joints ) )
        end,
    }
end )

add( "Tests", "29 automated tests of plugin.box3d (box3d_tests.lua): free fall, joints, raycast, events...", function( env, ctx )
    local results = {}
    local ok, failed = 0, 0
    local tests = require( "box3d_tests" )
    ok, failed = tests.run( ctx.box3d, function( line ) results[#results + 1] = line; print( line ) end )
    ctx.report( results, failed == 0 )
    return { camera = { 30, 22, 14, { 0, 1, 0 } }, noPhysics = true }
end )

return S
