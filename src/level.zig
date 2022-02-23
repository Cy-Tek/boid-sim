pub const Level = struct {
    stage: *anyopaque,

    logicFn: fn (*anyopaque) void,
    drawFn: fn (*anyopaque) void,

    pub fn logic(level: *const Level) void {
        level.logicFn(level.stage);
    }

    pub fn draw(level: *const Level) void {
        level.drawFn(level.stage);
    }
};
