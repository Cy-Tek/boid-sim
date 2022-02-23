pub fn castTo(comptime T: type, ptr: *anyopaque) *T {
    return @ptrCast(*T, @alignCast(@alignOf(T), ptr));
}

pub fn typeId(comptime _: type) usize {
    // bit must be var so that the compiler does not optimize this away
    const static = struct { var bit: u1 = undefined; };
    return @ptrToInt(&static.bit);
}