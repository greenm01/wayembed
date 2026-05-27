//! Delegate for wl_pointer. Forwards pointer events from the host seat
//! and translates embedded-child enter/motion coordinates.

const std = @import("std");
const runtime = @import("runtime.zig");
const wlc = @import("../wayland/client.zig");
const wlp = @import("../wayland/protocols.zig");
const wls = @import("../wayland/server.zig");

pub const Delegate = struct {};

pub fn create() Delegate {
    return .{};
}

pub fn translateFixedByOffset(value: wls.c.wl_fixed_t, offset: i32) wls.c.wl_fixed_t {
    return value - wlc.c.wl_fixed_from_int(offset);
}

pub fn Bindings(comptime Server: type, comptime ResourceData: type) type {
    const H = runtime.Helpers(Server, ResourceData);

    return struct {
        pub const impl = wls.c.struct_wl_pointer_interface{
            .set_cursor = pointerSetCursor,
            .release = pointerRelease,
        };

        pub const listener = wlc.c.struct_wl_pointer_listener{
            .enter = pointerEnter,
            .leave = pointerLeave,
            .motion = pointerMotion,
            .button = pointerButton,
            .axis = pointerAxis,
            .frame = pointerFrame,
            .axis_source = pointerAxisSource,
            .axis_stop = pointerAxisStop,
            .axis_discrete = pointerAxisDiscrete,
            .axis_value120 = pointerAxisValue120,
            .axis_relative_direction = pointerAxisRelativeDirection,
        };

        fn pointerSetCursor(
            _: ?*wls.wl_client,
            resource: ?*wls.wl_resource,
            serial: u32,
            surface: ?*wls.wl_resource,
            hotspot_x: i32,
            hotspot_y: i32,
        ) callconv(.c) void {
            const pointer = H.resourceProxyAs(wlp.wl_pointer, resource) orelse return;
            const cursor_surface = H.resourceProxyAs(wlp.wl_surface, surface);
            wlc.c.wl_pointer_set_cursor(pointer, serial, cursor_surface, hotspot_x, hotspot_y);
        }

        fn pointerRelease(_: ?*wls.wl_client, resource: ?*wls.wl_resource) callconv(.c) void {
            if (H.dataForResource(resource)) |data| {
                if (H.proxyAs(wlp.wl_pointer, data.upstream_proxy)) |pointer| {
                    wlc.c.wl_pointer_destroy(pointer);
                    data.upstream_proxy = null;
                }
            }
            H.resourceRelease(null, resource);
        }

        fn pointerEnter(
            userdata: ?*anyopaque,
            _: ?*wlp.wl_pointer,
            serial: u32,
            surface: ?*wlp.wl_surface,
            surface_x: wlc.c.wl_fixed_t,
            surface_y: wlc.c.wl_fixed_t,
        ) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            const upstream_surface = surface orelse return;
            const plugin_surface = data.server.surfaceResourceForUpstreamSurface(upstream_surface) orelse return;
            data.pointer_focus_surface = plugin_surface;
            data.pointer_focus_upstream_surface = upstream_surface;
            const translated = data.server.translatePointerCoords(data.client_id, upstream_surface, surface_x, surface_y);
            wls.c.wl_pointer_send_enter(data.wl_resource, serial, plugin_surface, translated.x, translated.y);
        }

        fn pointerLeave(
            userdata: ?*anyopaque,
            _: ?*wlp.wl_pointer,
            serial: u32,
            surface: ?*wlp.wl_surface,
        ) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            const upstream_surface = surface orelse return;
            const plugin_surface = data.server.surfaceResourceForUpstreamSurface(upstream_surface) orelse return;
            wls.c.wl_pointer_send_leave(data.wl_resource, serial, plugin_surface);
            if (data.pointer_focus_upstream_surface == upstream_surface) {
                data.pointer_focus_surface = null;
                data.pointer_focus_upstream_surface = null;
            }
        }

        fn pointerMotion(
            userdata: ?*anyopaque,
            _: ?*wlp.wl_pointer,
            time: u32,
            surface_x: wlc.c.wl_fixed_t,
            surface_y: wlc.c.wl_fixed_t,
        ) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            const focus = data.pointer_focus_upstream_surface orelse return;
            const translated = data.server.translatePointerCoords(data.client_id, focus, surface_x, surface_y);
            wls.c.wl_pointer_send_motion(data.wl_resource, time, translated.x, translated.y);
        }

        fn pointerButton(
            userdata: ?*anyopaque,
            _: ?*wlp.wl_pointer,
            serial: u32,
            time: u32,
            button: u32,
            state: u32,
        ) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            wls.c.wl_pointer_send_button(data.wl_resource, serial, time, button, state);
        }

        fn pointerAxis(
            userdata: ?*anyopaque,
            _: ?*wlp.wl_pointer,
            time: u32,
            axis: u32,
            value: wlc.c.wl_fixed_t,
        ) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            wls.c.wl_pointer_send_axis(data.wl_resource, time, axis, value);
        }

        fn pointerFrame(userdata: ?*anyopaque, _: ?*wlp.wl_pointer) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            if (resourceVersionAtLeast(data.wl_resource, 5)) wls.c.wl_pointer_send_frame(data.wl_resource);
        }

        fn pointerAxisSource(userdata: ?*anyopaque, _: ?*wlp.wl_pointer, axis_source: u32) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            if (resourceVersionAtLeast(data.wl_resource, 5)) wls.c.wl_pointer_send_axis_source(data.wl_resource, axis_source);
        }

        fn pointerAxisStop(userdata: ?*anyopaque, _: ?*wlp.wl_pointer, time: u32, axis: u32) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            if (resourceVersionAtLeast(data.wl_resource, 5)) wls.c.wl_pointer_send_axis_stop(data.wl_resource, time, axis);
        }

        fn pointerAxisDiscrete(userdata: ?*anyopaque, _: ?*wlp.wl_pointer, axis: u32, discrete: i32) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            if (resourceVersionAtLeast(data.wl_resource, 5) and !resourceVersionAtLeast(data.wl_resource, 8)) {
                wls.c.wl_pointer_send_axis_discrete(data.wl_resource, axis, discrete);
            }
        }

        fn pointerAxisValue120(userdata: ?*anyopaque, _: ?*wlp.wl_pointer, axis: u32, value120: i32) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            if (resourceVersionAtLeast(data.wl_resource, 8)) wls.c.wl_pointer_send_axis_value120(data.wl_resource, axis, value120);
        }

        fn pointerAxisRelativeDirection(userdata: ?*anyopaque, _: ?*wlp.wl_pointer, axis: u32, direction: u32) callconv(.c) void {
            const data = dataFromListener(userdata) orelse return;
            if (resourceVersionAtLeast(data.wl_resource, 9)) {
                wls.c.wl_pointer_send_axis_relative_direction(data.wl_resource, axis, direction);
            }
        }

        fn dataFromListener(userdata: ?*anyopaque) ?*ResourceData {
            const ptr = userdata orelse return null;
            return @ptrCast(@alignCast(ptr));
        }

        fn resourceVersionAtLeast(resource: *wls.wl_resource, version: c_int) bool {
            return wls.c.wl_resource_get_version(resource) >= version;
        }
    };
}

test "fixed coordinate translation subtracts integer offset" {
    const x = wlc.c.wl_fixed_from_int(12);
    try std.testing.expectEqual(wlc.c.wl_fixed_from_int(7), translateFixedByOffset(x, 5));
}

test "compiles" {
    _ = create();
}
