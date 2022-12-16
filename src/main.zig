const std = @import("std");
const c = @import("c.zig");
const allocator = std.heap.c_allocator;
const stdout = std.io.getStdOut().writer();

const width = 800;
const height = 600;

const App = struct {
    const Self = @This();

    window: ?*c.GLFWwindow = null,
    vkInstance: c.VkInstance = null,

    pub fn run(self: *Self) !void {
        try self.initWindow();
        try self.initVulkan();
        defer self.cleanup();

        try self.mainLoop();
    }

    fn initWindow(self: *Self) !void {
        if (c.glfwInit() != c.GLFW_TRUE) {
            return error.GLFWError;
        }

        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        c.glfwWindowHint(c.GLFW_RESIZABLE, c.GLFW_FALSE);

        self.window = c.glfwCreateWindow(@as(c_int, width), @as(c_int, height), "Vulkan", null, null);
    }

    fn initVulkan(self: *Self) !void {
        // create Application Info
        const appInfo = std.mem.zeroInit(c.VkApplicationInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "Triangle",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_API_VERSION_1_0,
        });

        // get required GLFW extensions
        var glfwExtensionCount: u32 = 0;
        const glfwExtensions = c.glfwGetRequiredInstanceExtensions(&glfwExtensionCount);

        // get supported Vulkan extensions
        var vkExtensionCount: u32 = 0;
        _ = c.vkEnumerateInstanceExtensionProperties(null, &vkExtensionCount, null);

        const Vec = std.ArrayList(c.VkExtensionProperties);

        var vkExtensions = try Vec.initCapacity(allocator, vkExtensionCount);
        defer vkExtensions.deinit();
        _ = c.vkEnumerateInstanceExtensionProperties(null, &vkExtensionCount, vkExtensions.allocatedSlice().ptr);

        try stdout.print("available extensions:\n", .{});

        for (vkExtensions.allocatedSlice()) |extension| {
            try stdout.print("\t{s}\n", .{extension.extensionName});
        }

        // create Create Info struct
        const createInfo = std.mem.zeroInit(c.VkInstanceCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &appInfo,
            .enabledExtensionCount = glfwExtensionCount,
            .ppEnabledExtensionNames = glfwExtensions,
            .enabledLayerCount = 0,
        });

        // create Vulkan instance
        if (c.vkCreateInstance(&createInfo, null, &self.vkInstance) != c.VK_SUCCESS) {
            return error.VulkanError;
        }
    }

    fn mainLoop(self: *Self) !void {
        while (c.glfwWindowShouldClose(self.window) == c.GLFW_FALSE) {
            c.glfwPollEvents();
        }
    }

    fn cleanup(self: *Self) void {
        _ = c.vkDestroyInstance(self.vkInstance, null);

        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();
    }
};

pub fn main() !u8 {
    var app: App = .{};

    app.run() catch |err| {
        std.log.info("{s}", .{@errorName(err)});
        return 1;
    };

    return 0;
}
