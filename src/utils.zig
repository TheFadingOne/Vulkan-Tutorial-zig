const std = @import("std");
const allocator = std.heap.c_allocator;
const stderr = std.io.getStdErr().writer();

const c = @import("c.zig");

const constants = @import("constants.zig");

const QueueFamilyIndeces = struct {
    const Self = @This();

    graphicsFamily: ?u32 = null,

    pub fn isComplete(self: *Self) bool {
        return self.graphicsFamily != null;
    }
};

pub fn findQueueFamilies(device: c.VkPhysicalDevice) !QueueFamilyIndeces {
    var indices = QueueFamilyIndeces{};

    var queueFamilyCount: u32 = 0;
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, null);

    const Vec = std.ArrayList(c.VkQueueFamilyProperties);
    var queueFamilies = Vec.init(allocator);
    try queueFamilies.resize(queueFamilyCount);
    c.vkGetPhysicalDeviceQueueFamilyProperties(device, &queueFamilyCount, queueFamilies.items.ptr);

    var i: u32 = 0;
    for (queueFamilies.items) |queueFamily| {
        if (queueFamily.queueFlags & c.VK_QUEUE_GRAPHICS_BIT != 0) {
            indices.graphicsFamily = i;
            break;
        }

        i += 1;
    }

    return indices;
}

pub fn isDeviceSuitable(device: c.VkPhysicalDevice) !bool {
    var indices = try findQueueFamilies(device);

    return indices.isComplete();
}

pub fn createDebugUtilsMessengerEXT(
    instance: c.VkInstance,
    pCreateInfo: ?*c.VkDebugUtilsMessengerCreateInfoEXT,
    pAllocator: ?*const c.VkAllocationCallbacks,
    pDebugMessenger: ?*c.VkDebugUtilsMessengerEXT,
) c.VkResult {
    const func = @ptrCast(
        c.PFN_vkCreateDebugUtilsMessengerEXT,
        c.vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT"),
    );

    if (func != null) {
        return func.?(instance, pCreateInfo, pAllocator, pDebugMessenger);
    } else {
        return c.VK_ERROR_EXTENSION_NOT_PRESENT;
    }
}

pub fn destroyDebugUtilsMessengerEXT(
    instance: c.VkInstance,
    debugMessenger: c.VkDebugUtilsMessengerEXT,
    pAllocator: ?*const c.VkAllocationCallbacks,
) void {
    const func = @ptrCast(
        c.PFN_vkDestroyDebugUtilsMessengerEXT,
        c.vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT"),
    );

    if (func != null) {
        func.?(instance, debugMessenger, pAllocator);
    }
}

pub fn checkValidationLayerSupport() !void {
    var layerCount: u32 = 0;
    _ = c.vkEnumerateInstanceLayerProperties(&layerCount, null);

    const Vec = std.ArrayList(c.VkLayerProperties);
    var availableLayers = Vec.init(allocator);
    try availableLayers.resize(layerCount);
    defer availableLayers.deinit();

    _ = c.vkEnumerateInstanceLayerProperties(&layerCount, availableLayers.items.ptr);

    for (constants.validationLayers) |layerName| {
        for (availableLayers.allocatedSlice()) |layerProperties| {
            const layerNameSlice = std.mem.span(layerName);
            if (std.mem.startsWith(u8, &layerProperties.layerName, layerNameSlice)) {
                // validation layer supported, check next one
                break;
            }
        } else {
            return error.InsufficientValidationLayerSupport;
        }
    }
}

// returns ArrayList that mus be deinitialized
pub fn getRequiredExtensions() !std.ArrayList([*c]const u8) {
    var glfwExtensionCount: u32 = 0;
    const glfwExtensions = c.glfwGetRequiredInstanceExtensions(&glfwExtensionCount);

    var extensions = std.ArrayList([*c]const u8).init(allocator);
    errdefer extensions.deinit();

    try extensions.appendSlice(glfwExtensions[0..glfwExtensionCount]);

    if (constants.enableValidationLayers) {
        try extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    }

    return extensions;
}

pub fn populateDebugMessengerCreateInfo(createInfo: *c.VkDebugUtilsMessengerCreateInfoEXT) void {
    createInfo.* = std.mem.zeroInit(c.VkDebugUtilsMessengerCreateInfoEXT, .{
        .sType = c.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
        .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
        .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
            c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
        .pfnUserCallback = debugCallback,
    });
}

pub export fn debugCallback(
    messageSeverity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    messageType: c.VkDebugUtilsMessageTypeFlagBitsEXT,
    pCallbackData: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
    pUserData: ?*anyopaque,
) callconv(.C) c.VkBool32 {
    _ = messageSeverity;
    _ = messageType;
    _ = pUserData;

    stderr.print("validation layer: {s}\n", .{pCallbackData.?.pMessage}) catch {};

    return c.VK_FALSE;
}
