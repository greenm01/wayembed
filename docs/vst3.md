# VST3 Wayland Notes

VST3 3.8 changes the map for native Linux plugin UIs. It gives Wayland
embedding an official VST3 path instead of leaving every host to invent one.

The shape matches `wayembed`: a native Wayland host application acts as both a
Wayland client and a compositor for the plugin. The plugin does not connect to
the system compositor. It asks the host for a Wayland connection through
`IWaylandHost::openWaylandConnection()`.

That is the delegated-server model.

## Relevant VST3 Pieces

The VST3 3.8 Wayland path introduces:

- `IWaylandHost`: implemented by the host and exposed through
  `IHostApplication::createInstance`.
- `IWaylandFrame`: implemented by the host's `IPlugFrame` object for popups,
  menus, dialogs, and related child windows.
- `WaylandSurfaceID`: the platform UI type used when `IPlugView::attached()`
  receives a parent `wl_surface`.

The platform UI type matters. In this path, the `parent` argument passed to
`IPlugView::attached(parent, type)` is a `wl_surface *`.

Official references:

- VST3 3.8 Wayland support:
  <https://steinbergmedia.github.io/vst3_dev_portal/pages/Technical%2BDocumentation/Change%2BHistory/3.8.0/IWaylandHost.html>
- `IWaylandHost`:
  <https://steinbergmedia.github.io/vst3_doc/vstinterfaces/classSteinberg_1_1IWaylandHost.html>
- VST3 platform UI types:
  <https://steinbergmedia.github.io/vst3_doc/vstinterfaces/group__platformUIType.html>

## What This Means For wayembed

VST3 validates the core `wayembed` approach. The host-side shape Steinberg
describes is close to what `wayembed` already provides:

```text
host app
  owns real compositor connection
  owns parent editor wl_surface
  owns wayembed_server

plugin
  opens host-provided Wayland connection
  creates child wl_surface
  renders into that child surface

wayembed
  delegates plugin Wayland objects
  tracks the plugin-created child subsurface
  forwards input, output, xdg, shm, and lifecycle events
```

VST3 does not reshape the core. The core stays format-neutral. The adapter
layer names the VST3 platform type and validates the handoff. Real VST3 hosts
still own SDK loading, component creation, `IPlugView`, `IPlugFrame`,
`IWaylandHost`, and `IWaylandFrame`.

## Adapter Mapping

The wayembed adapter constant is:

```c
WAYEMBED_ADAPTER_VST3_PLATFORM_TYPE_WAYLAND_SURFACE_ID
```

Its value is:

```text
WaylandSurfaceID
```

This is not a new plugin protocol. It is the VST3 platform UI type that says
the host is passing a parent `wl_surface`.

A VST3 host integration maps the pieces this way:

```text
IWaylandHost::openWaylandConnection()
  -> wayembed_server_open_client_display()
     or wayembed_server_open_client_fd()

IPlugView::attached(parent, WaylandSurfaceID)
  -> parent is a proxy for the host editor wl_surface on the plugin display
  -> plugin creates child wl_surface on the wayembed display
  -> plugin creates wl_subsurface(child, parent)
  -> host adopts that subsurface through wayembed_embed_adopt_subsurface()

IPlugView resize path
  -> wayembed_adapter_resize_validate()
  -> wayembed_embed_resize()

IWaylandFrame popup path
  -> host exposes parent xdg_surface data for menus/tooltips/dialogs
  -> wayembed forwards xdg popup protocol as needed
```

The sandbox proof stays light. It proves the order and the Wayland surface
handoff without linking the VST3 SDK.

## What Not To Do

Do not put VST3 SDK types in `include/wayembed.h`.

Do not make `wayembed` load `.vst3` bundles.

Do not let VST3 host policy leak into protocol delegates.

Do not treat `WaylandSurfaceID` as a replacement for CLAP or LV2 adapter
tokens. It is VST3's platform type.

Do not drop generated controls or XWayland fallback plans. Many VST3 plugins
will not support the 3.8 Wayland path yet.

The fallback boundary lives in
[plugin-ui-fallbacks.md](plugin-ui-fallbacks.md). VST3 glue can choose a
fallback, but it should not pull that policy into `wayembed` core.

## Priority Shift

Before VST3 3.8, CLAP and LV2 were the cleanest places to prove the adapter
contract, even though both needed experimental wayembed-specific glue for
embedded Wayland UIs.

After VST3 3.8, VST3 becomes the strongest real-host target for native Wayland
embedding. It has an upstream contract. The cost is C++ SDK integration, which
belongs in the host or in a host-specific helper, not in `wayembed` core.

The practical path:

```text
wayembed core
  format-neutral delegated Wayland server

wayembed_adapters
  CLAP experimental token
  LV2 experimental URI
  VST3 WaylandSurfaceID mapping

wayembed-sandbox
  proof harness only

real host integration
  VST3 SDK glue
  plugin loading
  IPlugView/IPlugFrame/IWaylandHost wiring
```

That split keeps the core small and gives VST3 a serious path when a host is
ready to own the SDK work.

## Real-Host Spike Boundary

The first real-host spike uses nilamp as a controlled VST3 plugin and
`wayembed-sandbox` as the controlled host. It is intentionally a proof harness,
not a general VST3 host.

For strict VST3 Wayland conformance, the parent pointer passed to
`IPlugView::attached(parent, WaylandSurfaceID)` must belong to the plugin's
wayembed client display. If the host already has a real `wl_surface *` on its
compositor connection, it needs a plugin-display proxy before passing the parent
to the plugin.

`wayembed_server_create_proxy()` provides that shape for parent `wl_surface`
objects. The nilamp smoke editor validates that the parent belongs to the
host-provided plugin display, creates a child surface, and assigns the
subsurface role with `wl_subcompositor.get_subsurface(child, parent)`.

The host must not call `wayembed_embed_attach()` for that strict path because
the child surface already has a role. Instead, after dispatching the plugin's
`get_subsurface` request, the host calls `wayembed_embed_adopt_subsurface()`.
That records the existing parent-child relationship in the embed model and
enables resize, offset, input, and lifecycle callbacks without creating a second
subsurface.
