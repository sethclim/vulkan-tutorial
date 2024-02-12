package main

import "core:fmt"
import "core:os"

import "vendor:glfw"
import vk "vendor:vulkan"


WIDTH: i32 = 800
HEIGHT: i32 = 600

Context :: struct {
	window:                 glfw.WindowHandle,
	instance:               vk.Instance,
	device:                 vk.Device,
	physicalDevice:         vk.PhysicalDevice,
	swap_chain:             Swapchain,
	graphicsQueue:          vk.Queue,
	presentQueue:           vk.Queue,
	debugMessenger:         vk.DebugUtilsMessengerEXT,
	enableValidationLayers: bool,
	surface:                vk.SurfaceKHR,
	render_pass:            vk.RenderPass,
	pipeline_layout:        vk.PipelineLayout,
	graphicsPipeline:       vk.Pipeline,
}

QueueFamilyIndices :: struct {
	graphicsFamily:    u32,
	graphicsFamilySet: bool,
	presentFamily:     u32,
	presentFamilySet:  bool,
}

Swapchain :: struct {
	handle:       vk.SwapchainKHR,
	images:       []vk.Image,
	image_views:  []vk.ImageView,
	format:       vk.SurfaceFormatKHR,
	extent:       vk.Extent2D,
	present_mode: vk.PresentModeKHR,
	image_count:  u32,
	support:      SwapChainSupportDetails,
	framebuffers: []vk.Framebuffer,
}


SwapChainSupportDetails :: struct {
	capabilities:  vk.SurfaceCapabilitiesKHR,
	formats:       []vk.SurfaceFormatKHR,
	present_modes: []vk.PresentModeKHR,
}

call_back: vk.ProcDebugUtilsMessengerCallbackEXT

VALIDATION_LAYERS := [?]cstring{"VK_LAYER_KHRONOS_validation"}
DEVICE_EXTENSIONS := [?]cstring{"VK_KHR_swapchain"}

run :: proc() {
	using ctx: Context

	initWindow(&ctx)
	initVulkan(&ctx)
	mainLoop(&ctx)
	cleanup(&ctx)
}

initWindow :: proc(using ctx: ^Context) {
	glfw.Init()

	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	glfw.WindowHint(glfw.RESIZABLE, 0)

	window = glfw.CreateWindow(WIDTH, HEIGHT, "Vulkan", nil, nil)
	glfw.SetWindowUserPointer(window, ctx)
}

initVulkan :: proc(using ctx: ^Context) {
	context.user_ptr = &instance
	get_proc_address :: proc(p: rawptr, name: cstring) {
		(cast(^rawptr)p)^ = glfw.GetInstanceProcAddress((^vk.Instance)(context.user_ptr)^, name)
	}

	when ODIN_DEBUG 
	{
		enableValidationLayers = true
	}

	vk.load_proc_addresses(get_proc_address)
	createInstance(ctx)
	// get_suitable_device(ctx);
	setupDebugMessenger(ctx)
	createSurface(ctx)
	vk.load_proc_addresses(get_proc_address)
	pickPhysicalDevice(ctx)
	createLogicalDevice(ctx)
	create_swap_chain(ctx)
	create_image_views(ctx)
	createRenderPass(ctx)
	createGraphicsPipeline(ctx)
}


createSurface :: proc(using ctx: ^Context) {
	if glfw.CreateWindowSurface(instance, window, nil, &surface) != .SUCCESS {
		fmt.eprintf("failed to find GPUs with Vulkan support!")
		os.exit(1)
	}
}

pickPhysicalDevice :: proc(using ctx: ^Context) {
	deviceCount: u32 = 0
	vk.EnumeratePhysicalDevices(instance, &deviceCount, nil)

	if (deviceCount == 0) {
		fmt.eprintf("failed to find GPUs with Vulkan support!")
		os.exit(1)
	}

	devices := make([]vk.PhysicalDevice, deviceCount)
	vk.EnumeratePhysicalDevices(instance, &deviceCount, raw_data(devices))

	for device in devices {
		if (isDeviceSuitable(ctx, device)) {
			physicalDevice = device
			break
		}
	}

	if (physicalDevice == nil) {
		fmt.eprintf("failed to find a suitable GPU!")
		os.exit(1)
	}
}

createLogicalDevice :: proc(ctx: ^Context) {
	indices := findQueueFamilies(ctx, ctx.physicalDevice)

	uniqueQueueFamilies: [dynamic]u32

	if (indices.graphicsFamilySet) {
		append(&uniqueQueueFamilies, indices.graphicsFamily)
	}

	if (indices.presentFamilySet && indices.presentFamily != uniqueQueueFamilies[0]) {
		append(&uniqueQueueFamilies, indices.presentFamily)
	}

	queueCreateInfos := make([]vk.DeviceQueueCreateInfo, len(uniqueQueueFamilies))

	queuePriority: f32 = 1.0
	for queueFamily, i in uniqueQueueFamilies {
		queueCreateInfo: vk.DeviceQueueCreateInfo
		queueCreateInfo.sType = vk.StructureType.DEVICE_QUEUE_CREATE_INFO
		queueCreateInfo.queueFamilyIndex = queueFamily
		queueCreateInfo.queueCount = 1
		queueCreateInfo.pQueuePriorities = &queuePriority

		queueCreateInfos[i] = queueCreateInfo
	}

	deviceFeatures: vk.PhysicalDeviceFeatures

	device_create_info: vk.DeviceCreateInfo
	device_create_info.sType = .DEVICE_CREATE_INFO
	device_create_info.enabledExtensionCount = u32(len(DEVICE_EXTENSIONS))
	device_create_info.ppEnabledExtensionNames = &DEVICE_EXTENSIONS[0]
	device_create_info.pQueueCreateInfos = raw_data(queueCreateInfos)
	device_create_info.queueCreateInfoCount = u32(len(queueCreateInfos))
	device_create_info.pEnabledFeatures = &deviceFeatures

	if (ctx.enableValidationLayers) {
		device_create_info.enabledLayerCount = len(VALIDATION_LAYERS)
		device_create_info.ppEnabledLayerNames = raw_data(&VALIDATION_LAYERS)
	} else {
		device_create_info.enabledLayerCount = 0
	}

	res := vk.CreateDevice(ctx.physicalDevice, &device_create_info, nil, &ctx.device)

	if res != .SUCCESS {
		fmt.eprintf("ERROR: failed to create logical device!\n", res)
		os.exit(1)
	}

	vk.GetDeviceQueue(ctx.device, indices.graphicsFamily, 0, &ctx.graphicsQueue)
	vk.GetDeviceQueue(ctx.device, indices.presentFamily, 0, &ctx.presentQueue)
}


mainLoop :: proc(using ctx: ^Context) {
	for (!glfw.WindowShouldClose(window)) {
		glfw.PollEvents()
	}
}

cleanup :: proc(using ctx: ^Context) {
	vk.DestroyPipeline(ctx.device, graphicsPipeline, nil)
	vk.DestroyPipelineLayout(ctx.device, ctx.pipeline_layout, nil)
	vk.DestroyRenderPass(ctx.device, ctx.render_pass, nil)
	for view in swap_chain.image_views {
		vk.DestroyImageView(device, view, nil)
	}
	vk.DestroySwapchainKHR(device, swap_chain.handle, nil)
	if (enableValidationLayers) {
		DestroyDebugUtilsMessengerEXT(instance, debugMessenger, nil)
	}
	vk.DestroyDevice(device, nil)
	vk.DestroySurfaceKHR(instance, surface, nil)
	vk.DestroyInstance(instance, nil)
	glfw.DestroyWindow(window)
	glfw.Terminate()
}

createInstance :: proc(using ctx: ^Context) {
	if enableValidationLayers && !checkValidationLayerSupport() {
		//could add in printing layer name 
		fmt.eprintf("ERROR: validation layer %q not available\n")
		os.exit(1)
	}

	appInfo: vk.ApplicationInfo
	appInfo.sType = .APPLICATION_INFO
	appInfo.pNext = nil
	appInfo.pApplicationName = "Hello Triangle"
	appInfo.applicationVersion = vk.MAKE_VERSION(0, 0, 1)
	appInfo.pEngineName = "No Engine"
	appInfo.engineVersion = vk.MAKE_VERSION(1, 0, 0)
	appInfo.apiVersion = vk.API_VERSION_1_0

	createInfo: vk.InstanceCreateInfo
	createInfo.sType = .INSTANCE_CREATE_INFO
	createInfo.pNext = nil
	createInfo.pApplicationInfo = &appInfo

	debugCreateInfo: vk.DebugUtilsMessengerCreateInfoEXT
	if (enableValidationLayers) {
		populateDebugMessengerCreateInfo(&debugCreateInfo)
		createInfo.ppEnabledLayerNames = &VALIDATION_LAYERS[0]
		createInfo.enabledLayerCount = len(VALIDATION_LAYERS)
		createInfo.pNext = &debugCreateInfo
	} else {
		createInfo.enabledLayerCount = 0
	}

	extensions := getRequiredExtensions(enableValidationLayers)

	// createInfo.flags = distinct bit_set [vk.InstanceCreateFlag.ENUMERATE_PORTABILITY_KHR]
	createInfo.enabledExtensionCount = cast(u32)len(extensions)
	createInfo.ppEnabledExtensionNames = raw_data(extensions)


	res := vk.CreateInstance(&createInfo, nil, &instance)

	if res != .SUCCESS {
		fmt.eprintf("ERROR: Failed to create instance", res)
		return
	}

	fmt.println("Instance Created")
}

get_suitable_device :: proc(using ctx: ^Context) {
	device_count: u32

	vk.EnumeratePhysicalDevices(instance, &device_count, nil)
	if device_count == 0 {
		fmt.eprintf("ERROR: Failed to find GPUs with Vulkan support\n")
		os.exit(1)
	}

	devices := make([]vk.PhysicalDevice, device_count)
	vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(devices))

	// for dev in devices
	// {
	//     if !check_device_extension_support(dev)
	//     {
	//         fmt.eprintf("ERROR: Device Doesn't Support Extentions\n");
	//     }
	// }
}


checkValidationLayerSupport :: proc() -> bool {
	layer_count: u32
	vk.EnumerateInstanceLayerProperties(&layer_count, nil)
	layers := make([]vk.LayerProperties, layer_count)
	vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(layers))

	outer: for name in VALIDATION_LAYERS {
		for layer in &layers {
			if name == cstring(&layer.layerName[0]) do continue outer
		}

		return false
	}

	return true
}

getRequiredExtensions :: proc(enableValidationLayers: bool) -> [dynamic]cstring {
	glfwExtensions := glfw.GetRequiredInstanceExtensions()

	extensions: [dynamic]cstring
	for i := 0; i < len(glfwExtensions); i += 1 {
		append(&extensions, glfwExtensions[i])
	}

	// append(&extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)

	if (enableValidationLayers) {
		append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
	}

	return extensions
}

debugCallback :: proc(
	messageSeverity: vk.DebugUtilsMessageSeverityFlagEXT,
	messageType: vk.DebugUtilsMessageTypeFlagsEXT,
	pCallbackData: vk.DebugUtilsMessengerCallbackDataEXT,
	pUserData: rawptr,
) -> b32 {
	fmt.eprintln("VULKAN ERROR!!!! :  %q ", pCallbackData.pMessage)
	// was vk.False
	return false
}

populateDebugMessengerCreateInfo :: proc(createInfo: ^vk.DebugUtilsMessengerCreateInfoEXT) {
	createInfo.sType = vk.StructureType.DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
	createInfo.messageSeverity =  {
		vk.DebugUtilsMessageSeverityFlagEXT.VERBOSE,
		vk.DebugUtilsMessageSeverityFlagEXT.WARNING,
		vk.DebugUtilsMessageSeverityFlagEXT.ERROR,
	}
	createInfo.messageType =  {
		vk.DebugUtilsMessageTypeFlagEXT.GENERAL,
		vk.DebugUtilsMessageTypeFlagEXT.GENERAL,
		vk.DebugUtilsMessageTypeFlagEXT.PERFORMANCE,
	}
	createInfo.pfnUserCallback = vk.ProcDebugUtilsMessengerCallbackEXT(debugCallback)
	createInfo.pUserData = nil // Optional
}

setupDebugMessenger :: proc(using ctx: ^Context) {
	if (!enableValidationLayers) {return}

	debugCreateInfo: vk.DebugUtilsMessengerCreateInfoEXT
	populateDebugMessengerCreateInfo(&debugCreateInfo)

	if (CreateDebugUtilsMessengerEXT(instance, &debugCreateInfo, nil, &ctx.debugMessenger) !=
		   vk.Result.SUCCESS) {
		fmt.eprintf("Failed to set up debug messenger!\n")
		os.exit(1)
	}
}

CreateDebugUtilsMessengerEXT :: proc(
	instance: vk.Instance,
	pCreateInfo: ^vk.DebugUtilsMessengerCreateInfoEXT,
	pAllocator: ^vk.AllocationCallbacks,
	pDebugMessenger: ^vk.DebugUtilsMessengerEXT,
) -> vk.Result {
	//(PFN_vkCreateDebugUtilsMessengerEXT) was cast to this
	func := vk.ProcCreateDebugUtilsMessengerEXT(
		vk.GetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT"),
	)
	if (func != nil) {
		return func(instance, pCreateInfo, pAllocator, pDebugMessenger)
	} else {
		return vk.Result.ERROR_EXTENSION_NOT_PRESENT
	}
}

DestroyDebugUtilsMessengerEXT :: proc(
	instance: vk.Instance,
	debugMessenger: vk.DebugUtilsMessengerEXT,
	pAllocator: ^vk.AllocationCallbacks,
) {
	func := vk.ProcDestroyDebugUtilsMessengerEXT(
		vk.GetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT"),
	)
	if (func != nil) {
		func(instance, debugMessenger, pAllocator)
	}
}

isDeviceSuitable :: proc(ctx: ^Context, physicalDevice: vk.PhysicalDevice) -> bool {
	// deviceProperties : vk.PhysicalDeviceProperties;
	// vk.GetPhysicalDeviceProperties(device, &deviceProperties);

	// deviceFeatures : vk.PhysicalDeviceFeatures;
	// vk.GetPhysicalDeviceFeatures(device, &deviceFeatures);

	indices := findQueueFamilies(ctx, physicalDevice)

	extensionsSupported := checkDeviceExtensionSupport(physicalDevice)

	swapChainAdequate := false
	if (extensionsSupported) {
		ctx.swap_chain.support = querySwapChainSupport(ctx, physicalDevice)
		swapChainAdequate =
		!(len(ctx.swap_chain.support.formats) == 0 ||
			len(ctx.swap_chain.support.present_modes) == 0)
	}

	return queueFamilyIndicesIsComplete(indices) && extensionsSupported && swapChainAdequate
}

checkDeviceExtensionSupport :: proc(physical_device: vk.PhysicalDevice) -> bool {
	extensionCount: u32
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &extensionCount, nil)

	available_extensions := make([]vk.ExtensionProperties, extensionCount)
	vk.EnumerateDeviceExtensionProperties(
		physical_device,
		nil,
		&extensionCount,
		raw_data(available_extensions),
	)

	for ext in DEVICE_EXTENSIONS {
		found: b32
		for available in &available_extensions {
			if cstring(&available.extensionName[0]) == ext {
				found = true
				break
			}
		}
		if !found do return false
	}
	return true
}


queueFamilyIndicesIsComplete :: proc(using indicies: QueueFamilyIndices) -> bool {
	return graphicsFamilySet && presentFamilySet
}

findQueueFamilies :: proc(ctx: ^Context, physicalDevice: vk.PhysicalDevice) -> QueueFamilyIndices {
	indices: QueueFamilyIndices

	queue_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queue_count, nil)
	queueFamilies := make([]vk.QueueFamilyProperties, queue_count)
	vk.GetPhysicalDeviceQueueFamilyProperties(
		physicalDevice,
		&queue_count,
		raw_data(queueFamilies),
	)


	for queueFamily, i in queueFamilies {
		if vk.QueueFlag.GRAPHICS in queueFamily.queueFlags {
			indices.graphicsFamily = u32(i)
			indices.graphicsFamilySet = true
		}

		presentSupport: b32 = false
		vk.GetPhysicalDeviceSurfaceSupportKHR(physicalDevice, u32(i), ctx.surface, &presentSupport)

		if (presentSupport) {
			indices.presentFamily = u32(i)
			indices.presentFamilySet = true
		}

		if (queueFamilyIndicesIsComplete(indices)) {
			break
		}
	}

	return indices

}

/////////////////// SWAP CHAIN //////////////////

querySwapChainSupport :: proc(
	ctx: ^Context,
	physicalDevice: vk.PhysicalDevice,
) -> SwapChainSupportDetails {
	details: SwapChainSupportDetails

	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physicalDevice, ctx.surface, &details.capabilities)

	formatCount: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(physicalDevice, ctx.surface, &formatCount, nil)

	if (formatCount > 0) {
		details.formats = make([]vk.SurfaceFormatKHR, formatCount)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(
			physicalDevice,
			ctx.surface,
			&formatCount,
			raw_data(details.formats),
		)
	}

	present_mode_count: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(
		physicalDevice,
		ctx.surface,
		&present_mode_count,
		nil,
	)
	if present_mode_count > 0 {
		details.present_modes = make([]vk.PresentModeKHR, present_mode_count)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(
			physicalDevice,
			ctx.surface,
			&present_mode_count,
			raw_data(details.present_modes),
		)
	}


	return details
}

choose_surface_format :: proc(using ctx: ^Context) -> vk.SurfaceFormatKHR {
	for v in swap_chain.support.formats {
		if v.format == .B8G8R8A8_SRGB && v.colorSpace == .SRGB_NONLINEAR do return v
	}

	return swap_chain.support.formats[0]
}

choose_present_mode :: proc(using ctx: ^Context) -> vk.PresentModeKHR {
	for v in swap_chain.support.present_modes {
		if v == .MAILBOX do return v
	}

	return .FIFO
}

choose_swap_extent :: proc(using ctx: ^Context) -> vk.Extent2D {
	if (swap_chain.support.capabilities.currentExtent.width != max(u32)) {
		return swap_chain.support.capabilities.currentExtent
	} else {
		width, height := glfw.GetFramebufferSize(window)

		extent := vk.Extent2D{u32(width), u32(height)}

		extent.width = clamp(
			extent.width,
			swap_chain.support.capabilities.minImageExtent.width,
			swap_chain.support.capabilities.maxImageExtent.width,
		)
		extent.height = clamp(
			extent.height,
			swap_chain.support.capabilities.minImageExtent.height,
			swap_chain.support.capabilities.maxImageExtent.height,
		)

		return extent
	}
}

create_swap_chain :: proc(using ctx: ^Context) {
	using ctx.swap_chain.support
	swap_chain.format = choose_surface_format(ctx)
	swap_chain.present_mode = choose_present_mode(ctx)
	swap_chain.extent = choose_swap_extent(ctx)
	swap_chain.image_count = capabilities.minImageCount + 1

	if capabilities.maxImageCount > 0 && swap_chain.image_count > capabilities.maxImageCount {
		swap_chain.image_count = capabilities.maxImageCount
	}

	create_info: vk.SwapchainCreateInfoKHR
	create_info.sType = .SWAPCHAIN_CREATE_INFO_KHR
	create_info.surface = surface
	create_info.imageFormat = swap_chain.format.format
	create_info.imageColorSpace = swap_chain.format.colorSpace
	create_info.imageExtent = swap_chain.extent
	create_info.imageArrayLayers = 1
	create_info.imageUsage = {.COLOR_ATTACHMENT}

	indices := findQueueFamilies(ctx, physicalDevice)

	queue_family_indices := [2]u32{indices.graphicsFamily, indices.presentFamily}

	if indices.graphicsFamily != indices.presentFamily {
		create_info.imageSharingMode = .CONCURRENT
		create_info.queueFamilyIndexCount = 2
		create_info.pQueueFamilyIndices = &queue_family_indices[0]
	} else {
		create_info.imageSharingMode = .EXCLUSIVE
		create_info.queueFamilyIndexCount = 0
		create_info.pQueueFamilyIndices = nil
	}

	create_info.preTransform = capabilities.currentTransform
	create_info.compositeAlpha = {.OPAQUE}
	create_info.presentMode = swap_chain.present_mode
	create_info.clipped = true
	create_info.oldSwapchain = vk.SwapchainKHR{}

	if res := vk.CreateSwapchainKHR(device, &create_info, nil, &swap_chain.handle);
	   res != .SUCCESS {
		fmt.eprintf("Error: failed to create swap chain!\n")
		os.exit(1)
	}

	vk.GetSwapchainImagesKHR(device, swap_chain.handle, &swap_chain.image_count, nil)
	swap_chain.images = make([]vk.Image, swap_chain.image_count)
	vk.GetSwapchainImagesKHR(
		device,
		swap_chain.handle,
		&swap_chain.image_count,
		raw_data(swap_chain.images),
	)
}

/////////////////// Image Views //////////////////
create_image_views :: proc(ctx: ^Context) {
	using ctx.swap_chain

	image_views = make([]vk.ImageView, len(images))

	for _, i in images {
		create_info: vk.ImageViewCreateInfo
		create_info.sType = .IMAGE_VIEW_CREATE_INFO
		create_info.image = images[i]
		create_info.viewType = .D2
		create_info.format = format.format
		create_info.components.r = .IDENTITY
		create_info.components.g = .IDENTITY
		create_info.components.b = .IDENTITY
		create_info.components.a = .IDENTITY
		create_info.subresourceRange.aspectMask = {.COLOR}
		create_info.subresourceRange.baseMipLevel = 0
		create_info.subresourceRange.levelCount = 1
		create_info.subresourceRange.baseArrayLayer = 0
		create_info.subresourceRange.layerCount = 1

		if res := vk.CreateImageView(ctx.device, &create_info, nil, &image_views[i]);
		   res != .SUCCESS {
			fmt.eprintf("Error: failed to create image view!")
			os.exit(1)
		}
	}
}

createGraphicsPipeline :: proc(ctx: ^Context) {
	vertShaderCode: []byte = readFile("shaders/shader.vert.spv")
	fragShaderCode: []byte = readFile("shaders/shader.frag.spv")

	vertShaderModule := createShaderModule(ctx, vertShaderCode)
	fragShaderModule := createShaderModule(ctx, fragShaderCode)

	vertShaderStageInfo: vk.PipelineShaderStageCreateInfo
	vertShaderStageInfo.sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	vertShaderStageInfo.stage = {.VERTEX}
	vertShaderStageInfo.module = vertShaderModule
	vertShaderStageInfo.pName = "main"

	fragShaderStageInfo: vk.PipelineShaderStageCreateInfo
	fragShaderStageInfo.sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	fragShaderStageInfo.stage = {.FRAGMENT}
	fragShaderStageInfo.module = fragShaderModule
	fragShaderStageInfo.pName = "main"

	shader_stages := [?]vk.PipelineShaderStageCreateInfo{vertShaderStageInfo, fragShaderStageInfo}

	dynamic_states := [?]vk.DynamicState{.VIEWPORT, .SCISSOR}

	dynamicState: vk.PipelineDynamicStateCreateInfo
	dynamicState.sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO
	dynamicState.dynamicStateCount = len(dynamic_states)
	dynamicState.pDynamicStates = &dynamic_states[0]

	vertexInputInfo: vk.PipelineVertexInputStateCreateInfo
	vertexInputInfo.sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
	vertexInputInfo.vertexBindingDescriptionCount = 0
	vertexInputInfo.pVertexBindingDescriptions = nil // Optional
	vertexInputInfo.vertexAttributeDescriptionCount = 0
	vertexInputInfo.pVertexAttributeDescriptions = nil // Optional

	inputAssembly: vk.PipelineInputAssemblyStateCreateInfo
	inputAssembly.sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
	inputAssembly.topology = .TRIANGLE_LIST
	inputAssembly.primitiveRestartEnable = false

	viewport: vk.Viewport
	viewport.x = 0.0
	viewport.y = 0.0
	viewport.width = cast(f32)ctx.swap_chain.extent.width
	viewport.height = cast(f32)ctx.swap_chain.extent.height
	viewport.minDepth = 0.0
	viewport.maxDepth = 1.0

	scissor: vk.Rect2D
	scissor.offset = {0, 0}
	scissor.extent = ctx.swap_chain.extent

	viewportState: vk.PipelineViewportStateCreateInfo
	viewportState.sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO
	viewportState.viewportCount = 1
	viewportState.pViewports = &viewport
	viewportState.scissorCount = 1
	viewportState.pScissors = &scissor

	rasterizer: vk.PipelineRasterizationStateCreateInfo
	rasterizer.sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO
	rasterizer.depthClampEnable = false
	rasterizer.rasterizerDiscardEnable = false
	rasterizer.polygonMode = .FILL
	rasterizer.lineWidth = 1.0
	rasterizer.cullMode = {.BACK}
	rasterizer.frontFace = .CLOCKWISE
	rasterizer.depthBiasEnable = false
	rasterizer.depthBiasConstantFactor = 0.0 // Optional
	rasterizer.depthBiasClamp = 0.0 // Optional
	rasterizer.depthBiasSlopeFactor = 0.0 // Optional

	multisampling: vk.PipelineMultisampleStateCreateInfo
	multisampling.sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
	multisampling.sampleShadingEnable = false
	multisampling.rasterizationSamples = {._1}
	multisampling.minSampleShading = 1.0 // Optional
	multisampling.pSampleMask = nil // Optional
	multisampling.alphaToCoverageEnable = false // Optional
	multisampling.alphaToOneEnable = false // Optional

	colorBlendAttachment: vk.PipelineColorBlendAttachmentState
	colorBlendAttachment.colorWriteMask = {.R, .G, .B, .A}
	colorBlendAttachment.blendEnable = false
	colorBlendAttachment.srcColorBlendFactor = .ONE // Optional
	colorBlendAttachment.dstColorBlendFactor = .ZERO // Optional
	colorBlendAttachment.colorBlendOp = .ADD // Optional
	colorBlendAttachment.srcAlphaBlendFactor = .ONE // Optional
	colorBlendAttachment.dstAlphaBlendFactor = .ZERO // Optional
	colorBlendAttachment.alphaBlendOp = .ADD // Optional

	colorBlendAttachment.blendEnable = true
	colorBlendAttachment.srcColorBlendFactor = .SRC_ALPHA
	colorBlendAttachment.dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA
	colorBlendAttachment.colorBlendOp = .ADD
	colorBlendAttachment.srcAlphaBlendFactor = .ONE
	colorBlendAttachment.dstAlphaBlendFactor = .ZERO
	colorBlendAttachment.alphaBlendOp = .ADD

	colorBlending: vk.PipelineColorBlendStateCreateInfo
	colorBlending.sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
	colorBlending.logicOpEnable = false
	colorBlending.logicOp = .COPY // Optional
	colorBlending.attachmentCount = 1
	colorBlending.pAttachments = &colorBlendAttachment
	colorBlending.blendConstants[0] = 0.0 // Optional
	colorBlending.blendConstants[1] = 0.0 // Optional
	colorBlending.blendConstants[2] = 0.0 // Optional
	colorBlending.blendConstants[3] = 0.0 // Optional

	pipelineLayoutInfo: vk.PipelineLayoutCreateInfo
	pipelineLayoutInfo.sType = .PIPELINE_LAYOUT_CREATE_INFO
	pipelineLayoutInfo.setLayoutCount = 0 // Optional
	pipelineLayoutInfo.pSetLayouts = nil // Optional
	pipelineLayoutInfo.pushConstantRangeCount = 0 // Optional
	pipelineLayoutInfo.pPushConstantRanges = nil // Optional

	if res := vk.CreatePipelineLayout(ctx.device, &pipelineLayoutInfo, nil, &ctx.pipeline_layout);
	   res != .SUCCESS {
		fmt.eprintf("Error: Failed to create pipeline layout!\n")
		os.exit(1)
	}

	pipelineInfo: vk.GraphicsPipelineCreateInfo
	pipelineInfo.sType = .GRAPHICS_PIPELINE_CREATE_INFO
	pipelineInfo.stageCount = 2
	pipelineInfo.pStages = &shader_stages[0]
	pipelineInfo.pVertexInputState = &vertexInputInfo
	pipelineInfo.pInputAssemblyState = &inputAssembly
	pipelineInfo.pViewportState = &viewportState
	pipelineInfo.pRasterizationState = &rasterizer
	pipelineInfo.pMultisampleState = &multisampling
	pipelineInfo.pDepthStencilState = nil // Optional
	pipelineInfo.pColorBlendState = &colorBlending
	pipelineInfo.pDynamicState = &dynamicState
	pipelineInfo.layout = ctx.pipeline_layout
	pipelineInfo.renderPass = ctx.render_pass
	pipelineInfo.subpass = 0
	pipelineInfo.basePipelineHandle = vk.Pipeline{} // Optional
	pipelineInfo.basePipelineIndex = -1 // Optional

	res := vk.CreateGraphicsPipelines(ctx.device, 0, 1, &pipelineInfo, nil, &ctx.graphicsPipeline)
	if res != .SUCCESS {
		fmt.eprintf("Error: Failed to create graphics pipeline! %s \n", res)
		os.exit(1)
	}

	vk.DestroyShaderModule(ctx.device, fragShaderModule, nil)
	vk.DestroyShaderModule(ctx.device, vertShaderModule, nil)
}

readFile :: proc(filename: string) -> []byte {
	data, ok := os.read_entire_file_from_filename(filename)

	if !ok {
		fmt.eprintf("Error: failed to read file!\n")
		os.exit(1)
	}

	defer delete(data)

	return data
}

createShaderModule :: proc(ctx: ^Context, code: []u8) -> vk.ShaderModule {

	createInfo: vk.ShaderModuleCreateInfo
	createInfo.sType = .SHADER_MODULE_CREATE_INFO
	createInfo.codeSize = len(code)
	createInfo.pCode = cast(^u32)raw_data(code)


	shaderModule: vk.ShaderModule
	if vk.CreateShaderModule(ctx.device, &createInfo, nil, &shaderModule) != .SUCCESS {
		fmt.eprintf("Error: failed to create shader module!\n")
		os.exit(1)
	}

	return shaderModule
}


createRenderPass :: proc(ctx: ^Context) {
	colorAttachment: vk.AttachmentDescription
	colorAttachment.format = ctx.swap_chain.format.format
	colorAttachment.samples = {._1}
	colorAttachment.loadOp = .CLEAR
	colorAttachment.storeOp = .STORE
	colorAttachment.stencilLoadOp = .DONT_CARE
	colorAttachment.stencilStoreOp = .DONT_CARE
	colorAttachment.initialLayout = .UNDEFINED
	colorAttachment.finalLayout = .PRESENT_SRC_KHR

	colorAttachmentRef: vk.AttachmentReference
	colorAttachmentRef.attachment = 0
	colorAttachmentRef.layout = .COLOR_ATTACHMENT_OPTIMAL

	subpass: vk.SubpassDescription
	subpass.pipelineBindPoint = .GRAPHICS
	subpass.colorAttachmentCount = 1
	subpass.pColorAttachments = &colorAttachmentRef

	renderPassInfo: vk.RenderPassCreateInfo
	renderPassInfo.sType = .RENDER_PASS_CREATE_INFO
	renderPassInfo.attachmentCount = 1
	renderPassInfo.pAttachments = &colorAttachment
	renderPassInfo.subpassCount = 1
	renderPassInfo.pSubpasses = &subpass

	if res := vk.CreateRenderPass(ctx.device, &renderPassInfo, nil, &ctx.render_pass);
	   res != .SUCCESS {
		fmt.eprintf("Error: Failed to create render pass!\n")
		os.exit(1)
	}
}
