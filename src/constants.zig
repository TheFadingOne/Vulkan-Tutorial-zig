const std = @import("std");

pub const width = 800;
pub const height = 600;

pub const validationLayers = [_][*:0]const u8{
    "VK_LAYER_KHRONOS_validation",
};

pub const enableValidationLayers = std.debug.runtime_safety;
