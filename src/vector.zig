const std = @import("std");

pub const Vec2 = struct {
    const Self = @This();

    x: f64,
    y: f64,

    pub fn add(self: Self, other: Vec2) Vec2 {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
        };
    }

    pub fn sub(self: Self, other: Vec2) Vec2 {
        return .{
            .x = self.x - other.x,
            .y = self.y - other.y,
        };
    }

    pub fn mul(self: Self, other: Vec2) Vec2 {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
        };
    }

    pub fn mulByConst(self: Self, num: f64) Vec2 {
        return .{
            .x = self.x * num,
            .y = self.y * num,
        };
    }

    pub fn div(self: Self, other: Vec2) Vec2 {
        return .{
            .x = self.x / other.x,
            .y = self.y / other.y,
        };
    }

    pub fn divByConst(self: Self, num: f64) Vec2 {
        return .{
            .x = self.x / num,
            .y = self.y / num,
        };
    }

    pub fn magnitude(self: Self) f64 {
        return @sqrt(std.math.pow(f64, self.x, 2) + std.math.pow(f64, self.y, 2));
    }
};