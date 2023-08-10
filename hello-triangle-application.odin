package main

import "core:os"
import "core:fmt"

import "vendor:glfw"
import vk "vendor:vulkan"

WIDTH : i32 = 800
HEIGHT : i32 = 600

Context :: struct
{
    window: glfw.WindowHandle,
    instance : vk.Instance,
}

call_back : vk.ProcDebugUtilsMessengerCallbackEXT

VALIDATION_LAYERS := [?]cstring{"VK_LAYER_KHRONOS_validation"};

DEVICE_EXTENSIONS := [?]cstring{
	"VK_KHR_swapchain",
};

run :: proc()
{
    using ctx: Context;

    initWindow(&ctx);

    initVulkan(&ctx);
    mainLoop(&ctx);
    cleanup(&ctx);
}

initWindow :: proc(using ctx: ^Context)
{
    glfw.Init();
    
    glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API);
    glfw.WindowHint(glfw.RESIZABLE, 0);
    
	window = glfw.CreateWindow(WIDTH, HEIGHT, "Vulkan", nil, nil);
	glfw.SetWindowUserPointer(window, ctx);
}

initVulkan :: proc(using ctx: ^Context) 
{
    context.user_ptr = &instance;
	get_proc_address :: proc(p: rawptr, name: cstring) 
	{
		(cast(^rawptr)p)^ = glfw.GetInstanceProcAddress((^vk.Instance)(context.user_ptr)^, name);
	}
    vk.load_proc_addresses(get_proc_address);
    createInstance(ctx);
    get_suitable_device(ctx);
    vk.load_proc_addresses(get_proc_address);
}

mainLoop :: proc(using ctx: ^Context) 
{
    for (!glfw.WindowShouldClose(window)) 
    {
        glfw.PollEvents();
    }
}

cleanup :: proc(using ctx: ^Context) 
{
    vk.DestroyInstance(instance, nil);
    glfw.DestroyWindow(window);
    glfw.Terminate();
}

createInstance :: proc(using ctx: ^Context)
{
    enableValidationLayers := false
    when ODIN_DEBUG
    {
        if !checkValidationLayerSupport()
        {
            fmt.eprintf("ERROR: validation layer %q not available\n", name);
			os.exit(1);
        }

        enableValidationLayers = true
    }

    appInfo : vk.ApplicationInfo;
    appInfo.sType = .APPLICATION_INFO;
    appInfo.pNext = nil;
    appInfo.pApplicationName = "Hello Triangle";
    appInfo.applicationVersion = vk.MAKE_VERSION(0, 0, 1);
    appInfo.pEngineName = "No Engine";
    appInfo.engineVersion = vk.MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = vk.API_VERSION_1_0;

    createInfo : vk.InstanceCreateInfo;
    createInfo.sType = .INSTANCE_CREATE_INFO;
    createInfo.pNext = nil;
    createInfo.pApplicationInfo = &appInfo;

    if(enableValidationLayers)
    {
        createInfo.ppEnabledLayerNames = &VALIDATION_LAYERS[0];
		createInfo.enabledLayerCount = len(VALIDATION_LAYERS);
    }
    else
    {
        createInfo.enabledLayerCount = 0;
    }

    extensions := getRequiredExtensions(enableValidationLayers)

    // createInfo.flags = distinct bit_set [vk.InstanceCreateFlag.ENUMERATE_PORTABILITY_KHR]
    createInfo.enabledExtensionCount = cast(u32)len(extensions);
    createInfo.ppEnabledExtensionNames = raw_data(extensions);
    
	if vk.CreateInstance(&createInfo, nil, &instance) != .SUCCESS
	{
		fmt.eprintf("ERROR: Failed to create instance\n");
		return;
	}
	
	fmt.println("Instance Created");
}

get_suitable_device :: proc(using ctx: ^Context)
{
    device_count: u32;
	
	vk.EnumeratePhysicalDevices(instance, &device_count, nil);
	if device_count == 0
	{
		fmt.eprintf("ERROR: Failed to find GPUs with Vulkan support\n");
		os.exit(1);
	}

	devices := make([]vk.PhysicalDevice, device_count);
	vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(devices));

    for dev in devices
    {
        if !check_device_extension_support(dev)
        {
            fmt.eprintf("ERROR: Device Doesn't Support Extentions\n");
        }
    }
}

check_device_extension_support :: proc(physical_device: vk.PhysicalDevice) -> bool
{
	ext_count: u32;
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &ext_count, nil);
	
	available_extensions := make([]vk.ExtensionProperties, ext_count);
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &ext_count, raw_data(available_extensions));
	
	for ext in DEVICE_EXTENSIONS
	{
		found: b32;
		for available in &available_extensions
		{
			if cstring(&available.extensionName[0]) == ext
			{
				found = true;
				break;
			}
		}
		if !found do return false;
	}
	return true;
}

checkValidationLayerSupport :: proc() -> bool
{
    layer_count: u32;
    vk.EnumerateInstanceLayerProperties(&layer_count, nil);
    layers := make([]vk.LayerProperties, layer_count);
    vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(layers));
    
    outer: for name in VALIDATION_LAYERS
    {
        for layer in &layers
        {
            if name == cstring(&layer.layerName[0]) do continue outer;
        }

        return false
    }

    return true;
}

getRequiredExtensions :: proc(enableValidationLayers : bool) -> [dynamic]cstring
{
    glfwExtensions := glfw.GetRequiredInstanceExtensions();

    extensions : [dynamic]cstring
    for i := 0; i <  len(glfwExtensions); i += 1
    {
        append(&extensions, glfwExtensions[i])
    }

    append(&extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)

    if (enableValidationLayers) 
    {
        append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
    }

    return extensions;
}