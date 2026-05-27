const std = @import("std");

pub const c = @cImport({
    @cInclude("stdint.h");
});

pub const abi_version: u32 = 1;

pub const wl_compositor = opaque {};
pub const wl_display = opaque {};
pub const wl_event_queue = opaque {};
pub const wl_proxy = opaque {};
pub const wl_seat = opaque {};
pub const wl_shm = opaque {};
pub const wl_subcompositor = opaque {};
pub const wl_surface = opaque {};
pub const xdg_wm_base = opaque {};
pub const zwp_linux_dmabuf_v1 = opaque {};

pub const WayplugHostInterface = extern struct {
    size: u32,
    version: u32,
    userdata: ?*anyopaque,

    get_compositor: ?*const fn (?*anyopaque) callconv(.c) ?*wl_compositor,
    get_subcompositor: ?*const fn (?*anyopaque) callconv(.c) ?*wl_subcompositor,
    get_shm: ?*const fn (?*anyopaque) callconv(.c) ?*wl_shm,
    get_seat: ?*const fn (?*anyopaque) callconv(.c) ?*wl_seat,
    get_xdg_wm_base: ?*const fn (?*anyopaque) callconv(.c) ?*xdg_wm_base,
    get_dmabuf: ?*const fn (?*anyopaque) callconv(.c) ?*zwp_linux_dmabuf_v1,

    get_subsurface_offset: ?*const fn (
        ?*anyopaque,
        ?*i32,
        ?*i32,
        ?*wl_display,
        ?*wl_surface,
        ?*wl_surface,
    ) callconv(.c) bool,
};

const WayplugServer = extern struct {
    host: *const WayplugHostInterface,
    queue: ?*wl_event_queue,
};

export fn wayplug_abi_version() callconv(.c) u32 {
    return abi_version;
}

export fn wayplug_server_create(
    host: ?*const WayplugHostInterface,
    queue: ?*wl_event_queue,
) callconv(.c) ?*WayplugServer {
    const valid_host = host orelse return null;
    if (valid_host.size < @sizeOf(WayplugHostInterface)) return null;
    if (valid_host.version != abi_version) return null;

    const server = std.heap.c_allocator.create(WayplugServer) catch return null;
    server.* = .{
        .host = valid_host,
        .queue = queue,
    };
    return server;
}

export fn wayplug_server_destroy(server: ?*WayplugServer) callconv(.c) void {
    const valid_server = server orelse return;
    std.heap.c_allocator.destroy(valid_server);
}

export fn wayplug_server_get_fd(server: ?*WayplugServer) callconv(.c) c_int {
    _ = server;
    return -1;
}

export fn wayplug_server_dispatch(server: ?*WayplugServer) callconv(.c) void {
    _ = server;
}

export fn wayplug_server_flush(server: ?*WayplugServer) callconv(.c) void {
    _ = server;
}

export fn wayplug_server_open_client_display(server: ?*WayplugServer) callconv(.c) ?*wl_display {
    _ = server;
    return null;
}

export fn wayplug_server_close_client_display(
    server: ?*WayplugServer,
    display: ?*wl_display,
) callconv(.c) bool {
    _ = server;
    _ = display;
    return false;
}

export fn wayplug_server_create_proxy(
    server: ?*WayplugServer,
    client_display: ?*wl_display,
    host_object: ?*wl_proxy,
) callconv(.c) ?*wl_proxy {
    _ = server;
    _ = client_display;
    _ = host_object;
    return null;
}

export fn wayplug_server_destroy_proxy(
    server: ?*WayplugServer,
    proxy: ?*wl_proxy,
) callconv(.c) void {
    _ = server;
    _ = proxy;
}

test "ABI version is stable" {
    try std.testing.expectEqual(@as(u32, 1), wayplug_abi_version());
}
