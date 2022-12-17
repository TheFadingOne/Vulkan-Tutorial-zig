const std = @import("std");
const allocator = std.heap.c_allocator;
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const c = @import("c.zig");

const constants = @import("constants.zig");

const utils = @import("utils.zig");

const App = struct {
    const Self = @This();

    window: ?*c.GLFWwindow = null,

    vkInstance: c.VkInstance = null,
    vkPhysicalDevice: c.VkPhysicalDevice = null,
    vkDevice: c.VkDevice = null,
    vkGraphicsQueue: c.VkQueue = null,

    debugMessenger: c.VkDebugUtilsMessengerEXT = null,

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

        self.window = c.glfwCreateWindow(@as(c_int, constants.width), @as(c_int, constants.height), "Vulkan", null, null);
    }

    fn initVulkan(self: *Self) !void {
        try self.createInstance();
        try self.setupDebugMessenger();
        try self.pickPhysicalDevice();
        try self.createLogicalDevice();
    }

    fn createInstance(self: *Self) !void {
        if (constants.enableValidationLayers) {
            try utils.checkValidationLayerSupport();
        }

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
        var glfwExtensions = try utils.getRequiredExtensions();
        defer glfwExtensions.deinit();

        // get supported Vulkan extensions
        var vkExtensionCount: u32 = 0;
        _ = c.vkEnumerateInstanceExtensionProperties(null, &vkExtensionCount, null);

        const Vec = std.ArrayList(c.VkExtensionProperties);
        var vkExtensions = Vec.init(allocator);
        try vkExtensions.resize(vkExtensionCount);
        defer vkExtensions.deinit();

        _ = c.vkEnumerateInstanceExtensionProperties(null, &vkExtensionCount, vkExtensions.items.ptr);

        try stdout.print("available extensions:\n", .{});
        for (vkExtensions.items) |extension| {
            // extract actual string slice to avoid printing garbage beyond '\0'
            const maxNameLen = c.VK_MAX_EXTENSION_NAME_SIZE;
            const nameLen = std.mem.len(@ptrCast([*:0]const u8, extension.extensionName[0..maxNameLen]));
            const name = extension.extensionName[0..nameLen];

            try stdout.print("\t{s}\n", .{name});
        }

        // create Create Info struct
        var createInfo = std.mem.zeroInit(c.VkInstanceCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &appInfo,
            .enabledExtensionCount = @intCast(u32, glfwExtensions.items.len),
            .ppEnabledExtensionNames = glfwExtensions.items.ptr,
        });

        var debugCreateInfo: c.VkDebugUtilsMessengerCreateInfoEXT = undefined;
        if (constants.enableValidationLayers) {
            createInfo.enabledLayerCount = constants.validationLayers.len;
            createInfo.ppEnabledLayerNames = &constants.validationLayers;

            utils.populateDebugMessengerCreateInfo(&debugCreateInfo);
            createInfo.pNext = &debugCreateInfo;
        }

        // create Vulkan instance
        if (c.vkCreateInstance(&createInfo, null, &self.vkInstance) != c.VK_SUCCESS) {
            return error.VulkanError;
        }
    }

    fn setupDebugMessenger(self: *Self) !void {
        if (!constants.enableValidationLayers) {
            return;
        }

        var createInfo: c.VkDebugUtilsMessengerCreateInfoEXT = undefined;
        utils.populateDebugMessengerCreateInfo(&createInfo);

        if (utils.createDebugUtilsMessengerEXT(self.vkInstance, &createInfo, null, &self.debugMessenger) != c.VK_SUCCESS) {
            return error.VulkanError;
        }
    }

    fn pickPhysicalDevice(self: *Self) !void {
        var deviceCount: u32 = 0;
        _ = c.vkEnumeratePhysicalDevices(self.vkInstance, &deviceCount, null);

        if (deviceCount == 0) {
            return error.VulkanNoGPUFound;
        }

        const Vec = std.ArrayList(c.VkPhysicalDevice);
        var devices = Vec.init(allocator);
        defer devices.deinit();
        try devices.resize(deviceCount);

        _ = c.vkEnumeratePhysicalDevices(self.vkInstance, &deviceCount, devices.items.ptr);

        for (devices.items) |device| {
            if (try utils.isDeviceSuitable(device)) {
                self.vkPhysicalDevice = device;
                break;
            }
        }

        if (self.vkPhysicalDevice == null) {
            return error.VulkanNoSuitableGPUFound;
        }
    }

    fn createLogicalDevice(self: *Self) !void {
        const indices = try utils.findQueueFamilies(self.vkPhysicalDevice);

        const queuePriority: f32 = 1.0;
        const queueCreateInfo = std.mem.zeroInit(c.VkDeviceQueueCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = indices.graphicsFamily.?,
            .queueCount = 1,
            .pQueuePriorities = &queuePriority,
        });

        const deviceFeatures = std.mem.zeroes(c.VkPhysicalDeviceFeatures);

        var createInfo = std.mem.zeroInit(c.VkDeviceCreateInfo, .{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .pQueueCreateInfos = &queueCreateInfo,
            .queueCreateInfoCount = 1,
            .pEnabledFeatures = &deviceFeatures,
        });

        if (constants.enableValidationLayers) {
            createInfo.enabledLayerCount = @intCast(u32, constants.validationLayers.len);
            createInfo.ppEnabledLayerNames = &constants.validationLayers;
        }

        if (c.vkCreateDevice(self.vkPhysicalDevice, &createInfo, null, &self.vkDevice) != c.VK_SUCCESS) {
            return error.VulkanUnableToCreateLogicalDevice;
        }

        c.vkGetDeviceQueue(self.vkDevice, indices.graphicsFamily.?, 0, &self.vkGraphicsQueue);
    }

    fn mainLoop(self: *Self) !void {
        while (c.glfwWindowShouldClose(self.window) == c.GLFW_FALSE) {
            c.glfwPollEvents();
        }
    }

    fn cleanup(self: *Self) void {
        c.vkDestroyDevice(self.vkDevice, null);
        if (constants.enableValidationLayers) {
            utils.destroyDebugUtilsMessengerEXT(self.vkInstance, self.debugMessenger, null);
        }
        _ = c.vkDestroyInstance(self.vkInstance, null);

        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();
    }
};

pub fn main() !u8 {
    var app: App = .{};

    app.run() catch |err| {
        try stdout.print("error: {s}\n", .{@errorName(err)});
        return 1;
    };

    return 0;
}
