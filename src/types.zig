pub const StepType = enum {
    authentication,
    curl,
    unknown,
};

pub const Step = union(StepType) {
    authentication: AuthenticationStep,
    curl: CurlStep,
    unknown: void,
};

pub const Command = struct {
    command: []const u8,
    steps: []Step,
};

pub const CurlStep = struct {
    command: []const u8,
};

pub const AuthenticationStep = struct {};
