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

        for (self.boids.items) |*boid| {
            const bounds = boid.getComponent(comp.Bounds).?;
            const velocity = boid.getComponent(comp.Velocity).?;

            bounds.x += velocity.dx;
            bounds.y += velocity.dy;

            if (bounds.x + 32 < 0 or bounds.x + 32 > config.ScreenWidth) {
                velocity.dx = -velocity.dx;
            }
            if (bounds.y + 32 < 0 or bounds.y + 32 > config.ScreenHeight) {
                velocity.dy = -velocity.dy;
            }
        }
    }

    fn drawEntities(self_ptr: *anyopaque) void {
        var self = utils.castTo(Self, self_ptr);

        for (self.boids.items) |*boid| {
            const bounds = boid.getComponent(comp.Bounds).?;
            const velocity = boid.getComponent(comp.Velocity).?;
            const texture = boid.getComponent(comp.Texture).?;

            const dx = @intToFloat(f64, velocity.dx);
            const dy = @intToFloat(f64, velocity.dy);

            const aim = 180 * std.math.atan2(f64, dy, dx) / std.math.pi;
            draw.blitRot(bounds.*, texture.texture, aim, self.app.renderer);
        }
    }

    fn initializeBoids(self: *Self, allocator: Allocator) !void {
        const random = self.rand.random();

        var i: usize = 0;
        while (i < config.NumberOfBoids) : (i += 1) {
            var boid = Entity.init(allocator);

            _ = try boid.addComponent(comp.Texture, .{ .texture = self.boid_tex });
            _ = try boid.addComponent(comp.Bounds, .{
                .x = config.ScreenWidth / 2,
                .y = config.ScreenHeight / 2,
                .w = 32,
                .h = 32,
            });
            _ = try boid.addComponent(comp.Velocity, .{
                .dx = random.intRangeAtMost(i32, -10, 10),
                .dy = random.intRangeAtMost(i32, -10, 10),
            });

            try self.boids.append(boid);
        }
    }
};
