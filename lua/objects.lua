local math = require('math')
local util = require('util')
local vector = require('vector')
local roots = require('roots')

function xor(a, b)
    return (a and not b) or (b and not a)
end

-- ---------------------------------------------------------------
Object = util.class()
function Object:init()
end

-- ---------------------------------------------------------------
Circle = util.class(Object)
function Circle:init(pos, rad)
    Object.init(self)
	self.pos = pos
	self.rad = rad
    self.radsq = rad*rad
end

function Circle:circle_line_poly(p0, p1)
    local dp = vector.vsubv(p1, p0)
    local dc = vector.vsubv(p0, self.pos)

    local a = vector.vlensq(dp)
    local b = 2 * vector.vdotv(dp, dc)
    local c = vector.vlensq(dc) - self.radsq
    return {c, b, a}
end

function Circle:intersection(seg)
    local p0, p1 = seg.p0, seg.p1
    local diff = vector.vsubv(p1, p0)
    local poly = self:circle_line_poly(p0, p1)
    local root = roots.quadratic(poly)

    if not root then
        return nil, nil
    end

    if root[1] < 0 or root[1] > 1 then
        if root[2] < 0 or root[2] > 1 then
            return nil, nil
        end
        return self, root[2]
    end
    return self, root[1]
end

function Circle:crosses(seg)
    local p0, p1 = seg.p0, seg.p1
    local dr0 = vector.vlensq(vector.vsubv(p0, self.pos))
    local dr1 = vector.vlensq(vector.vsubv(p1, self.pos))
    return (dr0 < self.radsq and dr1 > self.radsq) or (dr0 > self.radsq and dr1 < self.radsq)
end

function Circle:normal(seg)
    local dr0 = vector.vsubv(seg.p0, self.pos)
    local dr1 = vector.vsubv(seg.p1, self.pos)
    local norm = vector.vnorm(dr1)

    if vector.vlensq(dr0) <= vector.vlensq(dr1) then
        return vector.vneg(norm)
    end
    return norm
end

function Circle:translate(vec)
    return Circle(vector.vaddv(self.pos, vec), self.rad)
end

function Circle:scale(s)
    return Circle(self.pos, self.rad * s)
end

function Circle:rotate(theta)
    return Circle(self.pos, self.rad)
end

-- ----------------------------------------------------------------
MaskedCircle = util.class(Circle)
function MaskedCircle:init(pos, rad, func)
    Circle.init(self, pos, rad)
    self.func = func
end

function MaskedCircle:intersection(seg)
    local obj, time = Circle.intersection(self, seg)
    if not obj then
        return nil, nil
    end

    local x = seg.p0[1] + (seg.p1[1] - seg.p0[1]) * time
    local y = seg.p0[2] + (seg.p1[2] - seg.p0[2]) * time
    local c = self.pos
    local theta = math.atan2(c[2] - y, c[1] - x) + math.pi

    if self.func(theta) then
        return obj, time
    end
    return nil, nil
end

function circle_nholes(nholes, eps, offset)
    return function(theta)
        local r = nholes * theta / (2 * math.pi)
        return math.abs(r - math.floor(r + 0.5)) > eps
    end
end

function circle_single_angle(angle, eps)
end

-- ----------------------------------------------------------------
Segment = util.class(Object)
function Segment:init(p0, p1)
    self.p0 = p0
    self.p1 = p1
end

function Segment:intersection(seg)
    -- returns the length along seg1 when the intersection occurs (0, 1)
    local s0, e0 = self.p0, self.p1
    local s1, e1 = seg.p0, seg.p1

    local d0 = vector.vsubv(e0, s0)
    local d1 = vector.vsubv(e1, s1)
    local cross = vector.vcrossv(d0, d1)

    --if cross < 1e-15 then
    --    return self, 0
    --end

    local t = vector.vcrossv(vector.vsubv(s1, s0), d0) / cross
    local p = -vector.vcrossv(vector.vsubv(s0, s1), d1) / cross

    if 0 <= t and t <= 1 and 0 <= p and p <= 1 then
        return self, t
    end
    return nil, nil
end

function Segment:center()
    return vector.vmuls(vector.vaddv(self.p0, self.p1), 0.5)
end

function Segment:crosses(seg)
    local o, t = self:intersection(seg)
    return not o == nil
end

function Segment:normal(seg)
    local point = seg.p1
    local center = self:center()
    local newp0 = vector.vaddv(center, vector.rot90(vector.vsubv(self.p0, center)))
    local newp1 = vector.vaddv(center, vector.rot90(vector.vsubv(self.p1, center)))
    local out = vector.vnorm(vector.vsubv(newp1, newp0))

    local diff = vector.vsubv(seg.p1, seg.p0)
    if vector.vdotv(diff, out) > 0 then
        return out
    else
        return vector.vneg(out)
    end
end

function Segment:length()
    return vector.vlen(vector.vsubv(self.p1, self.p0))
end

function Segment:translate(vec)
    return Segment(vector.vaddv(self.p0, vec), vector.vaddv(self.p1, vec))
end

function Segment:rotate(theta, center)
    local center = center or self:center()
    return Segment(
        vector.vaddv(center, vector.rotate(vector.vsubv(self.p0, center), theta)),
        vector.vaddv(center, vector.rotate(vector.vsubv(self.p1, center), theta))
    )
end

function Segment:scale(s)
    assert(s > 0 and s < 1)
    return Segment(
        vector.lerp(self.p0, self.p1, 0.5 - s/2),
        vector.lerp(self.p0, self.p1, 0.5 + s/2)
    )
end

-- ---------------------------------------------------------------
Box = util.class(Object)
function Box:init(...)
    local args = {...}
    local ll, lu, uu, ul = nil, nil, nil, nil

    if #args == 0 then
        ll = {0, 0}
        uu = {1, 1}
    elseif #args == 1 then
        ll = {0, 0}
        uu = args[1]
    elseif #args == 2 then
        ll = args[1]
        uu = args[2]
    elseif #args == 4 then
        ll = args[1]
        lu = args[2]
        uu = args[3]
        ul = args[4]
    else
        return
    end

    self.ll = {ll[1], ll[2]}
    self.uu = {uu[1], uu[2]}

    if not lu then
        self.ul = {uu[1], ll[2]}
        self.lu = {ll[1], uu[2]}
    else
        self.ul = {ul[1], ul[2]}
        self.lu = {lu[1], lu[2]}
    end

    self.segments = {
        Segment(self.ll, self.lu),
        Segment(self.lu, self.uu),
        Segment(self.uu, self.ul),
        Segment(self.ul, self.ll)
    }
end

function Box:center()
    return {
        (self.ll[1] + self.ul[1] + self.uu[1] + self.lu[1])/4,
        (self.ll[2] + self.ul[2] + self.uu[2] + self.lu[2])/4
    }
end

function Box:intersection(seg)
    local min_time = 1e100
    local min_seg = nil

    for i = 1, 4 do
        local line = self.segments[i]
        local o, t = line:intersection(seg)
        if t and t < min_time and t >= 0 then
            min_time = t
            min_seg = o
        end
    end

    if min_seg then
        return min_seg, min_time
    end
    return nil, nil
end

function Box:crosses(seg)
    local bx0, bx1 = self.ll[1], self.uu[1]
    local by0, by1 = self.ll[2], self.uu[2]
    local p0, p1 = seg.p0, seg.p1

    local inx0 = (p0[1] > bx0 and p0[1] < bx1)
    local inx1 = (p1[1] > bx0 and p1[1] < bx1)
    local iny0 = (p0[2] > by0 and p0[2] < by1)
    local iny1 = (p1[2] > by0 and p1[2] < by1)

    return xor(inx0, inx1) and xor(iny0, iny1)
end

function Box:contains(pt)
    -- FIXME this is wrong
    local bx0, bx1 = self.ll[1], self.uu[1]
    local by0, by1 = self.ll[2], self.uu[2]

    local inx = (pt[1] > bx0 and pt[1] < bx1)
    local iny = (pt[2] > by0 and pt[2] < by1)
    return inx and iny
end

function Box:translate(vec)
    return Box(
        self.segments[1]:translate(vec).p0, self.segments[2]:translate(vec).p0,
        self.segments[3]:translate(vec).p0, self.segments[4]:translate(vec).p0
    )
end

function Box:rotate(theta)
    local c = self:center()
    return Box(
        self.segments[1]:rotate(theta, c).p0, self.segments[2]:rotate(theta, c).p0,
        self.segments[3]:rotate(theta, c).p0, self.segments[4]:rotate(theta, c).p0
    )
end

function Box:scale(s)
    local c = self:center()
    return Box(
        self.segments[1]:scale(s).p0, self.segments[2]:scale(s).p0,
        self.segments[3]:scale(s).p0, self.segments[4]:scale(s).p0
    )
end

-- -------------------------------------------------------------
PointParticle = util.class(Object)
function PointParticle:init(pos, vel, acc)
    self.pos = pos or {0, 0}
    self.vel = vel or {0, 0}
    self.acc = acc or {0, 0}
end

-- -------------------------------------------------------------
ParticleGroup = util.class()
function ParticleGroup:init() end
function ParticleGroup:index(i) return nil end
function ParticleGroup:count() return 0 end

-- -------------------------------------------------------------
SingleParticle = util.class(ParticleGroup)
function SingleParticle:init(pos, vel, acc) self.particle = PointParticle(pos, vel, acc) end
function SingleParticle:index(i) return i == 1 and self.particle or nil end
function SingleParticle:count() return 1 end

-- -------------------------------------------------------------


return {
    circle_masks = {
        circle_nholes = circle_nholes
    },
    Box = Box,
    Circle = Circle,
    MaskedCircle = MaskedCircle,
    Segment = Segment,
    PointParticle = PointParticle
}
