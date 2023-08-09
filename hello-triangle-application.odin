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

VALIDATION_LAYERS := [?]cstring{"VK_LAYER_KHRONOS_validation"};



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
    glfw.DestroyWindow(window);
    glfw.Terminate();
}

createInstance :: proc(using ctx: ^Context)
{
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
    createInfo.enabledLayerCount = 0;
    createInfo.ppEnabledLayerNames = &VALIDATION_LAYERS[0];

    glfwExtensions := glfw.GetRequiredInstanceExtensions();

    createInfo.enabledExtensionCount = cast(u32)len(glfwExtensions);
    createInfo.ppEnabledExtensionNames = raw_data(glfwExtensions);
    
	if vk.CreateInstance(&createInfo, nil, &instance) != .SUCCESS
	{
		fmt.eprintf("ERROR: Failed to create instance\n");
		return;
	}
	
	fmt.println("Instance Created");
}