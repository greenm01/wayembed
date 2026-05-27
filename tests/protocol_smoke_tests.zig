//! Protocol-layer smoke tests. Every delegate's `create()` must return a
//! zero-init struct without crashing. Real behavior tests land here as
//! interfaces are implemented.

const builtin = @import("builtin");
const std = @import("std");
const wayplug = @import("wayplug");

const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("sys/stat.h");
    @cInclude("unistd.h");
});

const wlc = wayplug.wayland.client.c;
const wlp = wayplug.wayland.protocols;

const SmokeCompositor = enum {
    weston,
    river,
};

const SmokeFilter = enum {
    available,
    weston,
    river,
    all,
};

const CompositorSmokeSpec = struct {
    compositor: SmokeCompositor,
    name: []const u8,
    socket_name: ?[]const u8,
    argv: []const []const u8,
    extra_env: []const EnvPair = &.{},
    required: bool,
};

const EnvPair = struct {
    key: []const u8,
    value: []const u8,
};

test "every protocol delegate has a create() that compiles" {
    _ = wayplug.protocol.server_display.create();
    _ = wayplug.protocol.registry.create();
    _ = wayplug.protocol.compositor.create();
    _ = wayplug.protocol.surface.create();
    _ = wayplug.protocol.subcompositor.create();
    _ = wayplug.protocol.subsurface.create();
    _ = wayplug.protocol.shm.create();
    _ = wayplug.protocol.shm_pool.create();
    _ = wayplug.protocol.buffer.create();
    _ = wayplug.protocol.callback.create();
    _ = wayplug.protocol.region.create();
    _ = wayplug.protocol.seat.create();
    _ = wayplug.protocol.pointer.create();
    _ = wayplug.protocol.keyboard.create();
    _ = wayplug.protocol.touch.create();
    _ = wayplug.protocol.output.create();
    _ = wayplug.protocol.xdg_wm_base.create();
    _ = wayplug.protocol.xdg_positioner.create();
    _ = wayplug.protocol.xdg_surface.create();
    _ = wayplug.protocol.xdg_toplevel.create();
    _ = wayplug.protocol.xdg_popup.create();
}

test "active protocol bindings instantiate against server runtime" {
    const Server = wayplug.server.Server;
    const ResourceData = wayplug.server.ResourceData;

    const Registry = wayplug.protocol.registry.Bindings(Server, ResourceData);
    _ = Registry.bindCompositor;
    _ = Registry.bindSubcompositor;
    _ = Registry.bindShm;
    _ = Registry.bindSeat;
    _ = Registry.bindOutput;
    _ = Registry.bindXdgWmBase;

    const Compositor = wayplug.protocol.compositor.Bindings(Server, ResourceData);
    _ = Compositor.impl;
    const Surface = wayplug.protocol.surface.Bindings(Server, ResourceData);
    _ = Surface.impl;
    const Subcompositor = wayplug.protocol.subcompositor.Bindings(Server, ResourceData);
    _ = Subcompositor.impl;
    const Subsurface = wayplug.protocol.subsurface.Bindings(Server, ResourceData);
    _ = Subsurface.impl;
    const Shm = wayplug.protocol.shm.Bindings(Server, ResourceData);
    _ = Shm.impl;
    const ShmPool = wayplug.protocol.shm_pool.Bindings(Server, ResourceData);
    _ = ShmPool.impl;
    const Buffer = wayplug.protocol.buffer.Bindings(Server, ResourceData);
    _ = Buffer.impl;
    _ = Buffer.listener;
    const Callback = wayplug.protocol.callback.Bindings(Server, ResourceData);
    _ = Callback.listener;
    const Region = wayplug.protocol.region.Bindings(Server, ResourceData);
    _ = Region.impl;
    const Seat = wayplug.protocol.seat.Bindings(Server, ResourceData);
    _ = Seat.impl;
    const Pointer = wayplug.protocol.pointer.Bindings(Server, ResourceData);
    _ = Pointer.impl;
    _ = Pointer.listener;
    const Keyboard = wayplug.protocol.keyboard.Bindings(Server, ResourceData);
    _ = Keyboard.impl;
    _ = Keyboard.listener;
    const Touch = wayplug.protocol.touch.Bindings(Server, ResourceData);
    _ = Touch.impl;
    _ = Touch.listener;
    const Output = wayplug.protocol.output.Bindings(Server, ResourceData);
    _ = Output.impl;
    const XdgWmBase = wayplug.protocol.xdg_wm_base.Bindings(Server, ResourceData);
    _ = XdgWmBase.impl;
    _ = XdgWmBase.listener;
    const XdgPositioner = wayplug.protocol.xdg_positioner.Bindings(Server, ResourceData);
    _ = XdgPositioner.impl;
    const XdgSurface = wayplug.protocol.xdg_surface.Bindings(Server, ResourceData);
    _ = XdgSurface.impl;
    _ = XdgSurface.listener;
    const XdgToplevel = wayplug.protocol.xdg_toplevel.Bindings(Server, ResourceData);
    _ = XdgToplevel.impl;
    _ = XdgToplevel.listener;
    const XdgPopup = wayplug.protocol.xdg_popup.Bindings(Server, ResourceData);
    _ = XdgPopup.impl;
    _ = XdgPopup.listener;
}

const RegistryState = struct {
    compositor: ?*wlp.wl_compositor = null,
    subcompositor: ?*wlp.wl_subcompositor = null,
    shm: ?*wlp.wl_shm = null,
    seat: ?*wlp.wl_seat = null,
    seat_capabilities: u32 = 0,
    output: ?*wlp.wl_output = null,
    output_seen: bool = false,
    output_mode_width: i32 = 1,
    output_mode_height: i32 = 1,
    output_scale: i32 = 1,
    xdg_wm_base: ?*wlp.xdg_wm_base = null,
};

const HostSmokeState = struct {
    compositor: ?*wlp.wl_compositor = null,
    subcompositor: ?*wlp.wl_subcompositor = null,
    shm: ?*wlp.wl_shm = null,
    seat: ?*wlp.wl_seat = null,
    seat_capabilities: u32 = 0,
    output_seen: bool = false,
    output_mode_width: i32 = 1,
    output_mode_height: i32 = 1,
    output_scale: i32 = 1,
    xdg_wm_base: ?*wlp.xdg_wm_base = null,
    parent_surface: ?*wlp.wl_surface = null,
    surface_created_count: std.atomic.Value(u32) = .init(0),
    embed_attached: std.atomic.Value(bool) = .init(false),
    embed_mapped_count: std.atomic.Value(u32) = .init(0),
    embed_resized_count: std.atomic.Value(u32) = .init(0),
    embed_destroyed_count: std.atomic.Value(u32) = .init(0),
    client_closed_count: std.atomic.Value(u32) = .init(0),
};

const ServerThreadContext = struct {
    server: *wayplug.server.Server,
    running: std.atomic.Value(bool) = .init(true),

    fn run(self: *@This()) void {
        while (self.running.load(.acquire)) {
            self.server.dispatch();
            self.server.flush();
            sleepMs(1);
        }
    }
};

const registry_listener = wlc.struct_wl_registry_listener{
    .global = registryGlobal,
    .global_remove = registryGlobalRemove,
};

const shm_listener = wlc.struct_wl_shm_listener{
    .format = shmFormat,
};

const seat_listener = wlc.struct_wl_seat_listener{
    .capabilities = seatCapabilities,
    .name = seatName,
};

const output_listener = wlc.struct_wl_output_listener{
    .geometry = outputGeometry,
    .mode = outputMode,
    .done = outputDone,
    .scale = outputScale,
    .name = outputName,
    .description = outputDescription,
};

fn registryGlobal(
    data: ?*anyopaque,
    registry: ?*wlc.struct_wl_registry,
    name: u32,
    interface: [*c]const u8,
    version: u32,
) callconv(.c) void {
    const state: *RegistryState = @ptrCast(@alignCast(data orelse return));
    const reg = registry orelse return;
    const raw_interface = interface orelse return;
    const interface_name = std.mem.span(@as([*:0]const u8, @ptrCast(raw_interface)));
    if (std.mem.eql(u8, interface_name, "wl_compositor")) {
        const bound = wlc.wl_registry_bind(reg, name, &wlc.wl_compositor_interface, @min(version, 4)) orelse return;
        state.compositor = @ptrCast(bound);
    } else if (std.mem.eql(u8, interface_name, "wl_subcompositor")) {
        const bound = wlc.wl_registry_bind(reg, name, &wlc.wl_subcompositor_interface, @min(version, 1)) orelse return;
        state.subcompositor = @ptrCast(bound);
    } else if (std.mem.eql(u8, interface_name, "wl_shm")) {
        const bound = wlc.wl_registry_bind(reg, name, &wlc.wl_shm_interface, @min(version, 1)) orelse return;
        const shm: *wlp.wl_shm = @ptrCast(bound);
        state.shm = shm;
        _ = wlc.wl_shm_add_listener(shm, &shm_listener, state);
    } else if (std.mem.eql(u8, interface_name, "wl_seat")) {
        const bound = wlc.wl_registry_bind(reg, name, &wlc.wl_seat_interface, @min(version, 4)) orelse return;
        const seat: *wlp.wl_seat = @ptrCast(bound);
        state.seat = seat;
        _ = wlc.wl_seat_add_listener(seat, &seat_listener, state);
    } else if (std.mem.eql(u8, interface_name, "wl_output")) {
        const bound = wlc.wl_registry_bind(reg, name, &wlc.wl_output_interface, @min(version, 4)) orelse return;
        const output: *wlp.wl_output = @ptrCast(bound);
        state.output = output;
        _ = wlc.wl_output_add_listener(output, &output_listener, state);
    } else if (std.mem.eql(u8, interface_name, "xdg_wm_base")) {
        const bound = wlc.wl_registry_bind(reg, name, &wlc.xdg_wm_base_interface, @min(version, 7)) orelse return;
        state.xdg_wm_base = @ptrCast(bound);
    }
}

fn registryGlobalRemove(
    _: ?*anyopaque,
    _: ?*wlc.struct_wl_registry,
    _: u32,
) callconv(.c) void {}

fn shmFormat(_: ?*anyopaque, _: ?*wlp.wl_shm, _: u32) callconv(.c) void {}

fn seatCapabilities(data: ?*anyopaque, _: ?*wlp.wl_seat, capabilities: u32) callconv(.c) void {
    const state: *RegistryState = @ptrCast(@alignCast(data orelse return));
    state.seat_capabilities = capabilities;
}

fn seatName(_: ?*anyopaque, _: ?*wlp.wl_seat, _: [*c]const u8) callconv(.c) void {}

fn outputGeometry(
    data: ?*anyopaque,
    _: ?*wlp.wl_output,
    _: i32,
    _: i32,
    _: i32,
    _: i32,
    _: i32,
    _: [*c]const u8,
    _: [*c]const u8,
    _: i32,
) callconv(.c) void {
    const state: *RegistryState = @ptrCast(@alignCast(data orelse return));
    state.output_seen = true;
}

fn outputMode(
    data: ?*anyopaque,
    _: ?*wlp.wl_output,
    flags: u32,
    width: i32,
    height: i32,
    _: i32,
) callconv(.c) void {
    const state: *RegistryState = @ptrCast(@alignCast(data orelse return));
    if ((flags & @as(u32, @intCast(wlc.WL_OUTPUT_MODE_CURRENT))) != 0) {
        state.output_mode_width = width;
        state.output_mode_height = height;
    }
    state.output_seen = true;
}

fn outputDone(data: ?*anyopaque, _: ?*wlp.wl_output) callconv(.c) void {
    const state: *RegistryState = @ptrCast(@alignCast(data orelse return));
    state.output_seen = true;
}

fn outputScale(data: ?*anyopaque, _: ?*wlp.wl_output, factor: i32) callconv(.c) void {
    const state: *RegistryState = @ptrCast(@alignCast(data orelse return));
    state.output_scale = factor;
    state.output_seen = true;
}

fn outputName(data: ?*anyopaque, _: ?*wlp.wl_output, _: [*c]const u8) callconv(.c) void {
    const state: *RegistryState = @ptrCast(@alignCast(data orelse return));
    state.output_seen = true;
}

fn outputDescription(data: ?*anyopaque, _: ?*wlp.wl_output, _: [*c]const u8) callconv(.c) void {
    const state: *RegistryState = @ptrCast(@alignCast(data orelse return));
    state.output_seen = true;
}

fn hostCompositor(userdata: ?*anyopaque) callconv(.c) ?*wlp.wl_compositor {
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return null));
    return state.compositor;
}

fn hostSubcompositor(userdata: ?*anyopaque) callconv(.c) ?*wlp.wl_subcompositor {
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return null));
    return state.subcompositor;
}

fn hostShm(userdata: ?*anyopaque) callconv(.c) ?*wlp.wl_shm {
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return null));
    return state.shm;
}

fn hostSeat(userdata: ?*anyopaque) callconv(.c) ?*wlp.wl_seat {
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return null));
    return state.seat;
}

fn hostXdgWmBase(userdata: ?*anyopaque) callconv(.c) ?*wlp.xdg_wm_base {
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return null));
    return state.xdg_wm_base;
}

fn hostOutputInfo(userdata: ?*anyopaque, info: *wayplug.c_api.WayplugOutputInfo) callconv(.c) bool {
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return false));
    if (!state.output_seen) return false;
    info.mode_width = state.output_mode_width;
    info.mode_height = state.output_mode_height;
    info.scale = state.output_scale;
    info.make = "wayplug";
    info.model = "smoke-output";
    info.name = "wayplug-smoke-0";
    info.description = "wayplug smoke output";
    return true;
}

fn hostSeatCapabilities(userdata: ?*anyopaque) callconv(.c) u32 {
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return 0));
    return state.seat_capabilities;
}

fn hostSubsurfaceOffset(
    _: ?*anyopaque,
    x: *i32,
    y: *i32,
    _: *wayplug.wayland.client.wl_display,
    _: *wlp.wl_surface,
    _: *wlp.wl_surface,
) callconv(.c) bool {
    x.* = 0;
    y.* = 0;
    return true;
}

fn hostSurfaceCreated(
    userdata: ?*anyopaque,
    client: ?*wayplug.c_api.wayplug_client,
    child_surface: ?*wlp.wl_surface,
) callconv(.c) void {
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return));
    const handle: *wayplug.server.ClientHandle = @ptrCast(@alignCast(client orelse return));
    const parent = state.parent_surface orelse return;
    const child = child_surface orelse return;
    const attached = handle.server.embedAttach(handle, parent, child);
    state.embed_attached.store(attached, .release);
    _ = state.surface_created_count.fetchAdd(1, .acq_rel);
}

fn hostEmbedMapped(userdata: ?*anyopaque, embed_id: u32) callconv(.c) void {
    if (embed_id == 0) return;
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return));
    _ = state.embed_mapped_count.fetchAdd(1, .acq_rel);
}

fn hostEmbedResized(
    userdata: ?*anyopaque,
    embed_id: u32,
    width: i32,
    height: i32,
) callconv(.c) void {
    if (embed_id == 0 or width != 64 or height != 48) return;
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return));
    _ = state.embed_resized_count.fetchAdd(1, .acq_rel);
}

fn hostEmbedDestroyed(userdata: ?*anyopaque, embed_id: u32) callconv(.c) void {
    if (embed_id == 0) return;
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return));
    _ = state.embed_destroyed_count.fetchAdd(1, .acq_rel);
}

fn hostClientClosed(userdata: ?*anyopaque, client: ?*wayplug.c_api.wayplug_client) callconv(.c) void {
    if (client == null) return;
    const state: *HostSmokeState = @ptrCast(@alignCast(userdata orelse return));
    _ = state.client_closed_count.fetchAdd(1, .acq_rel);
}

test "weston headless smoke forwards create attach commit and embed" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const filter = smokeFilter();
    const required = filter == .weston or filter == .all;
    if (filter == .river) return error.SkipZigTest;

    const nonce = c.getpid();
    const socket_name = try std.fmt.allocPrintSentinel(allocator, "wayplug-smoke-{d}", .{nonce}, 0);
    defer allocator.free(socket_name);
    const socket_arg = try std.fmt.allocPrint(allocator, "--socket={s}", .{socket_name});
    defer allocator.free(socket_arg);
    const log_path = try std.fmt.allocPrintSentinel(allocator, "/tmp/wayplug-smoke-weston-{d}/weston.log", .{nonce}, 0);
    defer allocator.free(log_path);
    const log_arg = try std.fmt.allocPrint(allocator, "--log={s}", .{log_path});
    defer allocator.free(log_arg);

    const weston_argv = [_][]const u8{
        "weston",
        "--backend=headless",
        "--renderer=pixman",
        "--shell=kiosk",
        "--no-config",
        "--idle-time=0",
        "--width=320",
        "--height=240",
        socket_arg,
        log_arg,
    };
    try runCompositorSmoke(.{
        .compositor = .weston,
        .name = "weston",
        .socket_name = socket_name,
        .argv = weston_argv[0..],
        .required = required,
    });
    _ = c.unlink(log_path.ptr);
}

test "river headless smoke forwards create attach commit and embed" {
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const filter = smokeFilter();
    const required = filter == .river or filter == .all;
    if (filter == .weston) return error.SkipZigTest;

    const river_bin = getenvSlice("WAYPLUG_RIVER_BIN") orelse "river";
    const river_argv = [_][]const u8{
        river_bin,
        "-no-xwayland",
        "-log-level",
        "error",
        "-c",
        "true",
    };
    const river_env = [_]EnvPair{
        .{ .key = "WLR_BACKENDS", .value = "headless" },
        .{ .key = "WLR_LIBINPUT_NO_DEVICES", .value = "1" },
    };
    try runCompositorSmoke(.{
        .compositor = .river,
        .name = "river",
        .socket_name = null,
        .argv = river_argv[0..],
        .extra_env = river_env[0..],
        .required = required,
    });
}

fn runCompositorSmoke(spec: CompositorSmokeSpec) !void {
    const allocator = std.testing.allocator;
    const nonce = c.getpid();
    const runtime_dir = try std.fmt.allocPrintSentinel(
        allocator,
        "/tmp/wayplug-smoke-{s}-{d}",
        .{ spec.name, nonce },
        0,
    );
    defer allocator.free(runtime_dir);

    if (c.mkdir(runtime_dir.ptr, 0o700) != 0) return error.SkipZigTest;
    defer _ = c.rmdir(runtime_dir.ptr);
    _ = c.chmod(runtime_dir.ptr, 0o700);

    const old_runtime_dir = if (getenvSlice("XDG_RUNTIME_DIR")) |value|
        try std.fmt.allocPrintSentinel(allocator, "{s}", .{value}, 0)
    else
        null;
    defer if (old_runtime_dir) |value| allocator.free(value);
    defer {
        if (old_runtime_dir) |value| {
            _ = c.setenv("XDG_RUNTIME_DIR", value.ptr, 1);
        } else {
            _ = c.unsetenv("XDG_RUNTIME_DIR");
        }
    }
    if (c.setenv("XDG_RUNTIME_DIR", runtime_dir.ptr, 1) != 0) return error.EnvironmentSetupFailed;

    var env_map = try childEnvironment(allocator, runtime_dir, spec.socket_name, spec.extra_env);
    defer env_map.deinit();

    var compositor = std.process.spawn(std.testing.io, .{
        .argv = spec.argv,
        .environ_map = &env_map,
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    }) catch |err| {
        if (spec.required) return err;
        return error.SkipZigTest;
    };
    var compositor_running = true;
    defer if (compositor_running) {
        compositor.kill(std.testing.io);
    };

    const socket_name = if (spec.socket_name) |name|
        name
    else
        waitForWaylandSocket(allocator, runtime_dir) orelse {
            if (spec.required) return error.CompositorSocketTimedOut;
            return error.SkipZigTest;
        };
    const owns_socket_name = spec.socket_name == null;
    defer if (owns_socket_name) allocator.free(socket_name);

    const socket_path = try std.fmt.allocPrintSentinel(allocator, "{s}/{s}", .{ runtime_dir, socket_name }, 0);
    defer allocator.free(socket_path);
    defer _ = c.unlink(socket_path.ptr);

    const socket_name_z = try std.fmt.allocPrintSentinel(allocator, "{s}", .{socket_name}, 0);
    defer allocator.free(socket_name_z);

    if (!waitForSocket(socket_path)) {
        if (spec.required) return error.CompositorSocketTimedOut;
        return error.SkipZigTest;
    }

    const host_display = wlc.wl_display_connect(socket_name_z.ptr) orelse return error.HostDisplayConnectFailed;
    defer wlc.wl_display_disconnect(host_display);
    const host_registry_state = try bindCoreGlobals(host_display);
    const parent_surface = wlc.wl_compositor_create_surface(host_registry_state.compositor.?) orelse return error.CreateParentSurfaceFailed;
    defer wlc.wl_surface_destroy(parent_surface);

    var host_state = HostSmokeState{
        .compositor = host_registry_state.compositor,
        .subcompositor = host_registry_state.subcompositor,
        .shm = host_registry_state.shm,
        .seat = host_registry_state.seat,
        .seat_capabilities = host_registry_state.seat_capabilities,
        .output_seen = host_registry_state.output_seen,
        .output_mode_width = host_registry_state.output_mode_width,
        .output_mode_height = host_registry_state.output_mode_height,
        .output_scale = host_registry_state.output_scale,
        .xdg_wm_base = host_registry_state.xdg_wm_base,
        .parent_surface = parent_surface,
    };
    const iface = wayplug.c_api.WayplugHostInterface{
        .size = @sizeOf(wayplug.c_api.WayplugHostInterface),
        .version = wayplug.c_api.abi_version,
        .userdata = &host_state,
        .get_compositor = hostCompositor,
        .get_subcompositor = hostSubcompositor,
        .get_shm = hostShm,
        .get_seat = hostSeat,
        .get_xdg_wm_base = hostXdgWmBase,
        .get_dmabuf = null,
        .get_seat_capabilities = hostSeatCapabilities,
        .get_seat_name = null,
        .get_output_info = hostOutputInfo,
        .get_subsurface_offset = hostSubsurfaceOffset,
        .on_client_connected = null,
        .on_surface_created = hostSurfaceCreated,
        .on_client_closed = hostClientClosed,
        .on_protocol_error = null,
        .on_embed_mapped = hostEmbedMapped,
        .on_embed_resized = hostEmbedResized,
        .on_embed_destroyed = hostEmbedDestroyed,
    };
    const server = try wayplug.server.Server.create(allocator, &iface, null);
    defer server.destroy();

    const plugin_display = server.openClientDisplay() orelse return error.PluginDisplayOpenFailed;
    var plugin_display_open = true;
    defer if (plugin_display_open) {
        _ = server.closeClientDisplay(plugin_display);
        server.dispatch();
    };
    var thread_context = ServerThreadContext{ .server = server };
    var server_thread: ?std.Thread = try std.Thread.spawn(.{}, ServerThreadContext.run, .{&thread_context});
    defer {
        thread_context.running.store(false, .release);
        if (server_thread) |thread| thread.join();
    }

    const plugin_registry_state = try bindCoreGlobals(plugin_display);
    if (host_registry_state.seat != null) {
        try std.testing.expect(plugin_registry_state.seat != null);
        try std.testing.expectEqual(host_registry_state.seat_capabilities, plugin_registry_state.seat_capabilities);
    }
    if (host_registry_state.xdg_wm_base != null) {
        try std.testing.expect(plugin_registry_state.xdg_wm_base != null);
    }
    if (host_registry_state.output_seen) {
        try std.testing.expect(plugin_registry_state.output != null);
        try std.testing.expect(plugin_registry_state.output_seen);
        try std.testing.expectEqual(host_registry_state.output_mode_width, plugin_registry_state.output_mode_width);
        try std.testing.expectEqual(host_registry_state.output_mode_height, plugin_registry_state.output_mode_height);
        try std.testing.expectEqual(host_registry_state.output_scale, plugin_registry_state.output_scale);
    }
    const plugin_surface = wlc.wl_compositor_create_surface(plugin_registry_state.compositor.?) orelse return error.CreatePluginSurfaceFailed;
    try flushDisplay(plugin_display);
    try waitForSurfaceCreated(&host_state);

    const buffer = try createPluginBuffer(plugin_registry_state.shm.?);
    wlc.wl_surface_attach(plugin_surface, buffer, 0, 0);
    wlc.wl_surface_damage(plugin_surface, 0, 0, 16, 16);
    wlc.wl_surface_commit(plugin_surface);
    try flushDisplay(plugin_display);
    try std.testing.expect(server.embedResize(server.client_handles.items[0], 64, 48));
    try roundtripDisplay(plugin_display);
    try waitForEmbedCallbacks(&host_state);

    thread_context.running.store(false, .release);
    server_thread.?.join();
    server_thread = null;
    try roundtripDisplay(host_display);

    try std.testing.expectEqual(@as(u32, 1), host_state.surface_created_count.load(.acquire));
    try std.testing.expect(host_state.embed_attached.load(.acquire));
    try std.testing.expectEqual(@as(u32, 1), host_state.embed_mapped_count.load(.acquire));
    try std.testing.expectEqual(@as(u32, 1), host_state.embed_resized_count.load(.acquire));
    try std.testing.expectEqual(@as(usize, 1), server.engine.model.embeds.count());
    try std.testing.expectEqual(@as(usize, 2), server.engine.model.surfaces.count());
    try std.testing.expectEqual(@as(usize, 1), server.engine.model.buffers.count());
    const expected_resource_count: usize = 7 +
        @as(usize, if (plugin_registry_state.seat != null) 1 else 0) +
        @as(usize, if (plugin_registry_state.output != null) 1 else 0) +
        @as(usize, if (plugin_registry_state.xdg_wm_base != null) 1 else 0);
    try std.testing.expectEqual(expected_resource_count, server.engine.model.resources.count());
    try std.testing.expectEqual(@as(c_int, 0), wlc.wl_display_get_error(plugin_display));
    try std.testing.expectEqual(@as(c_int, 0), wlc.wl_display_get_error(host_display));

    try std.testing.expect(server.closeClientDisplay(plugin_display));
    plugin_display_open = false;
    server.dispatch();
    try roundtripDisplay(host_display);

    try std.testing.expectEqual(@as(u32, 1), host_state.embed_destroyed_count.load(.acquire));
    try std.testing.expectEqual(@as(u32, 1), host_state.client_closed_count.load(.acquire));
    try std.testing.expectEqual(@as(usize, 0), server.client_handles.items.len);
    try std.testing.expectEqual(@as(usize, 0), server.engine.model.embeds.count());
    try std.testing.expectEqual(@as(usize, 0), server.engine.model.surfaces.count());
    try std.testing.expectEqual(@as(usize, 0), server.engine.model.buffers.count());
    try std.testing.expectEqual(@as(usize, 0), server.engine.model.resources.count());

    compositor_running = false;
    compositor.kill(std.testing.io);
}

fn bindCoreGlobals(display: *wlc.struct_wl_display) !RegistryState {
    var state = RegistryState{};
    const registry = wlc.wl_display_get_registry(display) orelse return error.GetRegistryFailed;
    defer wlc.wl_registry_destroy(registry);
    _ = wlc.wl_registry_add_listener(registry, &registry_listener, &state);
    try roundtripDisplay(display);
    if (state.compositor == null or state.subcompositor == null or state.shm == null) {
        return error.MissingCoreGlobals;
    }
    try roundtripDisplay(display);
    return state;
}

fn roundtripDisplay(display: *wlc.struct_wl_display) !void {
    try std.testing.expect(wlc.wl_display_roundtrip(display) >= 0);
}

fn flushDisplay(display: *wlc.struct_wl_display) !void {
    try std.testing.expect(wlc.wl_display_flush(display) >= 0);
}

fn smokeFilter() SmokeFilter {
    const raw = getenvSlice("WAYPLUG_SMOKE_COMPOSITOR") orelse return .available;
    if (std.mem.eql(u8, raw, "weston")) return .weston;
    if (std.mem.eql(u8, raw, "river")) return .river;
    if (std.mem.eql(u8, raw, "all")) return .all;
    return .available;
}

fn childEnvironment(
    allocator: std.mem.Allocator,
    runtime_dir: [:0]const u8,
    socket_name: ?[]const u8,
    extra: []const EnvPair,
) !std.process.Environ.Map {
    var map = std.process.Environ.Map.init(allocator);
    errdefer map.deinit();

    if (getenvSlice("PATH")) |path| try map.put("PATH", path);
    if (getenvSlice("HOME")) |home| try map.put("HOME", home);
    try map.put("XDG_RUNTIME_DIR", runtime_dir);
    if (socket_name) |name| try map.put("WAYLAND_DISPLAY", name);
    for (extra) |pair| try map.put(pair.key, pair.value);
    return map;
}

fn getenvSlice(name: [*:0]const u8) ?[]const u8 {
    const value = c.getenv(name) orelse return null;
    return std.mem.span(@as([*:0]const u8, @ptrCast(value)));
}

fn waitForSocket(path: [:0]const u8) bool {
    for (0..200) |_| {
        if (c.access(path.ptr, c.F_OK) == 0) return true;
        sleepMs(10);
    }
    return false;
}

fn waitForWaylandSocket(allocator: std.mem.Allocator, runtime_dir: [:0]const u8) ?[]u8 {
    for (0..200) |_| {
        if (findWaylandSocket(allocator, runtime_dir)) |socket_name| return socket_name;
        sleepMs(10);
    }
    return null;
}

fn findWaylandSocket(allocator: std.mem.Allocator, runtime_dir: [:0]const u8) ?[]u8 {
    var dir = std.Io.Dir.openDirAbsolute(std.testing.io, runtime_dir, .{ .iterate = true }) catch return null;
    defer dir.close(std.testing.io);

    var iter = dir.iterate();
    while (iter.next(std.testing.io) catch return null) |entry| {
        if (!std.mem.startsWith(u8, entry.name, "wayland-")) continue;
        if (std.mem.endsWith(u8, entry.name, ".lock")) continue;
        return allocator.dupe(u8, entry.name) catch return null;
    }
    return null;
}

fn waitForSurfaceCreated(state: *const HostSmokeState) !void {
    for (0..200) |_| {
        if (state.surface_created_count.load(.acquire) > 0) {
            try std.testing.expect(state.embed_attached.load(.acquire));
            return;
        }
        sleepMs(10);
    }
    return error.SurfaceCreatedTimedOut;
}

fn waitForEmbedCallbacks(state: *const HostSmokeState) !void {
    for (0..200) |_| {
        if (state.embed_mapped_count.load(.acquire) > 0 and
            state.embed_resized_count.load(.acquire) > 0)
        {
            return;
        }
        sleepMs(10);
    }
    return error.EmbedCallbacksTimedOut;
}

fn sleepMs(ms: u32) void {
    _ = c.usleep(ms * 1000);
}

fn createPluginBuffer(shm: *wlp.wl_shm) !*wlp.wl_buffer {
    const width = 16;
    const height = 16;
    const stride = width * 4;
    const size = stride * height;
    const fd = try std.posix.memfd_create("wayplug-smoke-buffer", 0);
    defer _ = c.close(fd);
    if (c.ftruncate(fd, size) != 0) return error.TruncateBufferFailed;
    var pixels: [size]u8 = undefined;
    for (&pixels, 0..) |*byte, i| {
        byte.* = if (i % 4 == 3) 0xff else 0x40;
    }
    var written: usize = 0;
    while (written < pixels.len) {
        const rc = c.write(fd, pixels[written..].ptr, pixels.len - written);
        if (rc <= 0) return error.WriteBufferFailed;
        written += @intCast(rc);
    }
    const pool = wlc.wl_shm_create_pool(shm, fd, size) orelse return error.CreateShmPoolFailed;
    defer wlc.wl_shm_pool_destroy(pool);
    return wlc.wl_shm_pool_create_buffer(pool, 0, width, height, stride, wlc.WL_SHM_FORMAT_XRGB8888) orelse error.CreateBufferFailed;
}
