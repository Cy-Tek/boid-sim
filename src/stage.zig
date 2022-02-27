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

        for (self.boids.items) |*entity| {
            const boid = entity.getComponent(comp.Boid).?;

            boid.pos.x += boid.vel.x;
            boid.pos.y += boid.vel.y;

            if (boid.pos.x < 0 or boid.pos.x + @intToFloat(f64, boid.dim.w) > config.ScreenWidth) {
                boid.vel.x = -boid.vel.x;
            }
            if (boid.pos.y < 0 or boid.pos.y + @intToFloat(f64, boid.dim.h) > config.ScreenHeight) {
                boid.vel.y = -boid.vel.y;
            }
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

    // fn rule1(self: *Self, boid: *comp.Boid) void {
    //     var other: comp.Boid = undefined;

    //     for (self.boids.items) |*entity| {
    //         other = entity.getComponent(comp.Boid).?;
            
    //         if (boid != other) {
    //             boid.vel
    //         }
    //     }        
    // }
};
