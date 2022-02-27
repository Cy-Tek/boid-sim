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

    pub fn mul(self: Self, other: Vec2) Vec2 {
        return .{
            .x = self.x * other.x,
            .y = self.y * other.y,
        };
    }

    pub fn div(self: Self, other: Vec2) Vec2 {
        return .{
            .x = self.x / other.x,
            .y = self.y / other.y,
        };
    }
};