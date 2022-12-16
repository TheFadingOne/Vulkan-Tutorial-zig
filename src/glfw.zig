const std = @import("std");
const c = @import("c.zig");

pub fn init() void {
    _ = c.glfwInit();
}

pub fn createWindow(width: i32, height: i32, name: [*:0]const u8) ?*c.GLFWwindow {
    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);

    return c.glfwCreateWindow(@as(c_int, width), @as(c_int, height), name, null, null);
}
