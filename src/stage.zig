const c = @import("./c.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;

const config = @import("./consts.zig");
const draw = @import("./draw.zig");
const utils = @import("./utils.zig");
const comp = @import("component.zig");

const Entity = @import("./entity.zig").Entity;
const App = @import("./app.zig").App;
const Level = @import("level.zig").Level;
const Vec2 = @import("vector.zig").Vec2;

pub const Stage = struct {
    const Self = @This();

    app: *App,
    arena: *std.heap.ArenaAllocator,
    rand: std.rand.Xoshiro256,

    boids: std.ArrayList(Entity),
    boid_tex: *c.SDL_Texture,

    pub fn init(app: *App) !Self {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));

        var arena = try std.heap.page_allocator.create(std.heap.ArenaAllocator);
        arena.* = std.heap.ArenaAllocator.init(std.heap.page_allocator);

        var stage = Stage{
            .app = app,
            .arena = arena,
            .rand = std.rand.DefaultPrng.init(seed),
            .boids = std.ArrayList(Entity).init(arena.allocator()),
            .boid_tex = try draw.loadTexture("gfx/ship.png", app.renderer),
        };

        try stage.initializeBoids(stage.arena.allocator());

        return stage;
    }

    pub fn deinit(self: *Self) void {
        for (self.boids.items) |*boid| {
            boid.deinit();
        }

        self.boids.deinit();
        self.arena.deinit();
        std.heap.page_allocator.destroy(self.arena);
    }

    pub fn level(self: *Self) Level {
        return .{
            .stage = @ptrCast(*anyopaque, self),
            .logicFn = logic,
            .drawFn = drawEntities,
        };
    }

    fn logic(self_ptr: *anyopaque) void {
        var self = utils.castTo(Self, self_ptr);

        for (self.boids.items) |*entity| {
            const boid = entity.getComponent(comp.Boid).?;

            const vel1 = self.rule1(boid, 0.0005);
            const vel2 = self.rule2(boid);
            const vel3 = self.rule3(boid);
            const bounds = Self.bound_position(boid);

            boid.vel = boid.vel.add(vel1)
                .add(vel2)
                .add(vel3)
                .add(bounds);
            
            Self.limit_velocity(boid);

            boid.pos = boid.pos.add(boid.vel);
        }
    }

    fn drawEntities(self_ptr: *anyopaque) void {
        var self = utils.castTo(Self, self_ptr);

        for (self.boids.items) |*boid| {
            const b = boid.getComponent(comp.Boid).?;
            const t = boid.getComponent(comp.Texture).?;

            const x = b.vel.x;
            const y = b.vel.y;

            const aim = 180 * std.math.atan2(f64, y, x) / std.math.pi;
            const dst = c.SDL_Rect{
                .x = @floatToInt(c_int, b.pos.x),
                .y = @floatToInt(c_int, b.pos.y),
                .w = b.dim.w,
                .h = b.dim.h,
            };

            draw.blitRot(dst, t.texture, aim, self.app.renderer);
        }
    }

    fn initializeBoids(self: *Self, allocator: Allocator) !void {
        const random = self.rand.random();

        var i: usize = 0;
        while (i < config.NumberOfBoids) : (i += 1) {
            var boid = Entity.init(allocator);

            _ = try boid.addComponent(comp.Texture, .{ .texture = self.boid_tex });

            _ = try boid.addComponent(comp.Boid, comp.Boid{
                .vel = .{
                    .x = random.float(f64) * 20 - 10,
                    .y = random.float(f64) * 20 - 10
                },
                .pos = .{
                    .x = config.ScreenWidth / 2,
                    .y = config.ScreenHeight / 2,
                },
                .dim = .{
                    .w = 24,
                    .h = 24,
                },
                .vision = 30.0,
            });

            try self.boids.append(boid);
        }
    }

    fn rule1(self: *Self, boid: *comp.Boid, strength: f64) Vec2 {
        var other: *comp.Boid = undefined;
        var center_pos = Vec2{ .x = 0, .y = 0 };

        for (self.boids.items) |*entity| {
            other = entity.getComponent(comp.Boid).?;
            
            if (boid != other) {
                center_pos = center_pos.add(other.pos); 
            }
        }

        center_pos = center_pos.divByConst(@intToFloat(f64, self.boids.items.len) - 1);

        return center_pos.sub(boid.pos).mulByConst(strength);
    }

    fn rule2(self: *Self, boid: *comp.Boid) Vec2 {
        var other: *comp.Boid = undefined;
        var result = Vec2{ .x = 0, .y = 0 };

        for (self.boids.items) |*entity| {
            other = entity.getComponent(comp.Boid).?;

            if (boid != other) {
                if (other.pos.sub(boid.pos).magnitude() < 24) {
                    result = result.sub(other.pos.sub(boid.pos)).mulByConst(0.25);
                }
            }
        }

        return result;
    }

    fn rule3(self: *Self, boid: *comp.Boid) Vec2 {
        var other: *comp.Boid = undefined;
        var result = Vec2{ .x = 0, .y = 0 };

        for (self.boids.items) |*entity| {
            other = entity.getComponent(comp.Boid).?;

            if (boid != other) {
                result = result.add(other.vel);
            }
        }

        result = result.divByConst(@intToFloat(f64, self.boids.items.len) - 1);

        return result.sub(boid.vel).divByConst(20);
    }

    fn limit_velocity(boid: *comp.Boid) void {
        const v_lim = 10;

        if (boid.vel.magnitude() > v_lim) {
            boid.vel = boid.vel.divByConst(boid.vel.magnitude()).mulByConst(v_lim);
        }
    }

    fn bound_position(boid: *comp.Boid) Vec2 {
        const buffer = 50;
        const x_min = buffer;
        const x_max = config.ScreenWidth - buffer - @intToFloat(f64, boid.dim.w);
        const y_min = buffer;
        const y_max = config.ScreenHeight - buffer - @intToFloat(f64, boid.dim.h);
        var result = Vec2{ .x = 0, .y = 0, };

        if (boid.pos.x < x_min) {
            result.x = 10;
        }
        if (boid.pos.x > x_max) {
            result.x = -10;
        }
        if (boid.pos.y < y_min) {
            result.y = 10;
        }
        if (boid.pos.y > y_max) {
            result.y = -10;
        }

        return result;
    }
};
