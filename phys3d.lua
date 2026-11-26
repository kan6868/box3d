-- phys3d: bridges plugin.s3d (rendering) with plugin.box3d (physics).
--   local phys3d = require( "phys3d" )
--   local env = phys3d.new{ s3d = s3d, box3d = box3d, scene = post.scene }
--   local obj, body = env:box( 0.5, 0.5, 0.5, { position = { 0, 3, 0 } } )
--   Runtime:addEventListener( "enterFrame", function() env:update() end )
--
-- Each body keeps its shape at body.obj; env:update() steps the world at a fixed 1/60 s step and only updates
-- the shapes of bodies that moved (Box3D move event). Sleeping bodies are dimmed so the sleep mechanism is visible.

local M = {}
M.__index = M

local STEP = 1 / 60
local SLEEP_DIM = 0.55

function M.new( opts )
    local self = setmetatable( {}, M )
    self.s3d, self.b3, self.scene = opts.s3d, opts.box3d, opts.scene
    self.world = self.b3.newWorld{ gravity = opts.gravity or { 0, -10, 0 }, subSteps = opts.subSteps or 4 }
    self.bodies = {}
    self.acc = 0
    self.lastTime = nil
    self.paused = false
    self.stepCount = 0
    self.showSleep = opts.showSleep ~= false
    self.stepListeners = {}
    return self
end

-- fn() runs after every physics step (several per frame at low fps): read per-step events here
-- (getSensorEvents, getJointEvents, getContactEvents) so none are missed
function M:onStep( fn ) self.stepListeners[#self.stepListeners + 1] = fn end

local function afterStep( self )
    self.stepCount = self.stepCount + 1
    self:sync()
    for i = 1, #self.stepListeners do self.stepListeners[i]() end
end

-- shape color: color = { r, g, b }; remembered so it can be dimmed when asleep
local function paint( obj, c, dim )
    local k = dim and SLEEP_DIM or 1
    obj:setFillColor( c[1] * k, c[2] * k, c[3] * k, c[4] or 1 )
end

-- attach an existing shape to a body
function M:link( obj, body, color )
    body.obj = obj
    body.color = color or { 1, 1, 1 }
    obj.body = body
    paint( obj, body.color, false )
    obj:setPose( body:getTransform() )
    self.bodies[#self.bodies + 1] = body
    return obj, body
end

local function look( opts )
    opts = opts or {}
    return opts.texture or "assets/white.png", opts.color or { 0.85, 0.85, 0.85 }
end

local function shadowOn( self, obj, o ) if not ( o and o.castShadow == false ) then obj:castShadow( true ) end end

-- bodyOpts: newBody parameters (type, position, rotation/angles, ...); shapeOpts: density, friction, restitution...
-- lookOpts: { texture, color, castShadow = false }
function M:box( hx, hy, hz, bodyOpts, shapeOpts, lookOpts )
    local tex, color = look( lookOpts )
    local obj = self.s3d.newCube( self.scene, 1, { texture = tex } )
    obj:scaleTo( 2 * hx, 2 * hy, 2 * hz )
    local body = self.world:newBody( bodyOpts or {} )
    body:addBox( hx, hy, hz, shapeOpts )
    shadowOn( self, obj, lookOpts )
    return self:link( obj, body, color )
end

function M:sphere( r, bodyOpts, shapeOpts, lookOpts )
    local tex, color = look( lookOpts )
    local obj = self.s3d.newSphere( self.scene, r, 20, 14, { texture = tex } )
    local body = self.world:newBody( bodyOpts or {} )
    body:addSphere( r, shapeOpts )
    shadowOn( self, obj, lookOpts )
    return self:link( obj, body, color )
end

-- capsule along local Y axis: halfLen = half the segment between the two hemisphere centers
function M:capsule( r, halfLen, bodyOpts, shapeOpts, lookOpts )
    local tex, color = look( lookOpts )
    local obj = self.s3d.newCapsule( self.scene, r, 2 * halfLen, 16, 5, { texture = tex } )
    local body = self.world:newBody( bodyOpts or {} )
    body:addCapsule( 0, -halfLen, 0, 0, halfLen, 0, r, shapeOpts )
    shadowOn( self, obj, lookOpts )
    return self:link( obj, body, color )
end

function M:cylinder( height, r, bodyOpts, shapeOpts, lookOpts )
    local tex, color = look( lookOpts )
    local obj = self.s3d.newCylinder( self.scene, r, height, 20, { texture = tex } )
    local body = self.world:newBody( bodyOpts or {} )
    body:addCylinder( height, r, 20, shapeOpts )
    shadowOn( self, obj, lookOpts )
    return self:link( obj, body, color )
end

-- static ground: top surface at y = 0
function M:ground( half, shapeOpts )
    half = half or 20
    display.setDefault( "textureWrapX", "repeat" )
    display.setDefault( "textureWrapY", "repeat" )
    local obj = self.s3d.newPlane( self.scene, 2 * half, 2 * half, { texture = "assets/checker.png", uvRepeat = half / 2 } )
    display.setDefault( "textureWrapX", "clampToEdge" )
    display.setDefault( "textureWrapY", "clampToEdge" )
    local body = self.world:newBody{ type = "static", position = { 0, -1, 0 } }
    body:addBox( half, 1, half, shapeOpts )
    body.obj = obj
    self.groundBody = body
    return obj, body
end

-- throw a ball from the camera along the ray through the screen touch point
function M:shoot( sx, sy, speed, r )
    local o, d = self.s3d.screenToRay( sx, sy )
    r, speed = r or 0.3, speed or 25
    local _, body = self:sphere( r, { position = { o[1] + d[1], o[2] + d[2], o[3] + d[3] },
        linearVelocity = { d[1] * speed, d[2] * speed, d[3] * speed }, bullet = speed > 40 },
        { density = 2000, restitution = 0.2 }, { color = { 0.95, 0.4, 0.3 } } )
    return body
end

-- run the world in real time with a fixed step, at most 4 steps per frame
function M:update( now )
    now = now or system.getTimer()
    local dt = self.lastTime and ( now - self.lastTime ) / 1000 or STEP
    self.lastTime = now
    if self.paused then return 0 end
    self.acc = math.min( self.acc + dt, 4 * STEP )
    local n = 0
    while self.acc >= STEP do
        self.world:step( STEP )
        self.acc = self.acc - STEP
        n = n + 1
        afterStep( self )
    end
    return n
end

function M:stepOnce()
    self.world:step( STEP )
    afterStep( self )
end

function M:sync()
    local dim = self.showSleep
    for _, e in ipairs( self.world:getMoveEvents() ) do
        local b = e.body
        local obj = b and b.obj
        if obj and obj.setPose then
            obj:setPose( e.x, e.y, e.z, e.qx, e.qy, e.qz, e.qw )
            if dim then
                if e.sleep then
                    paint( obj, b.color, true ); b.dimmed = true
                elseif b.dimmed then
                    paint( obj, b.color, false ); b.dimmed = false
                end
            end
        end
    end
end

-- update the shapes of all bodies (after manually setting transforms)
function M:syncAll()
    for _, b in ipairs( self.bodies ) do
        if b:isValid() and b.obj then b.obj:setPose( b:getTransform() ) end
    end
end

function M:remove( body )
    if body.obj and body.obj.removeSelf then body.obj:removeSelf() end
    body.obj = nil
    body:destroy()
end

function M:destroy()
    self.world:destroy()
    self.bodies = {}
    self.stepListeners = {}
end

return M