# xdg_foreign And Floating Editors

Embedded editors and floating editors are different jobs.

The embedded path uses a delegated Wayland server. The plugin creates a child
`wl_surface`; the host attaches it under a host surface with `wl_subsurface`.
`xdg_foreign` does not help there. It relates toplevel windows. It does not
put plugin pixels inside a host panel.

Floating editors and transient dialogs are the cases where `xdg_foreign` can
matter. A plugin may create its own `xdg_toplevel` editor. A helper process may
show a file dialog. A toolkit may insist on a separate toplevel for a menu or
preferences window. Those windows still need a parent relation to the host so
the compositor can stack them sanely.

## What xdg_foreign Does

`xdg_foreign_unstable_v2` has two halves:

- `zxdg_exporter_v2` exports a toplevel and sends back an opaque string handle.
- `zxdg_importer_v2` imports that handle and creates an imported reference.

The importer can then call `set_parent_of()` on one of its own toplevel
surfaces. That gives the compositor the same kind of parent relation as
`xdg_toplevel.set_parent`, but across client boundaries.

The handle must move through some side channel. The protocol does not define
that transport. For plugins, the host or adapter glue would carry it through
the plugin format, process launcher, IPC channel, or a small host-owned
message.

## First Path: Host-Parented Delegated Toplevels

The first wayembed floating-editor path does not need a full `xdg_foreign`
bridge.

When a plugin connects to the wayembed display, wayembed creates the upstream
`xdg_toplevel` on the host's real Wayland connection. That means the host and
plugin toplevels may already live in the same real Wayland client namespace.
In that case, the smaller feature is a host callback that returns the parent
`xdg_toplevel` for a plugin toplevel. The existing `xdg_toplevel.set_parent`
forwarding can then do the right thing upstream.

This path fits wayembed's current shape:

```text
plugin creates xdg_toplevel on wayembed display
        |
        v
wayembed creates real upstream xdg_toplevel
        |
        v
host supplies parent xdg_toplevel for this editor/dialog
        |
        v
wayembed calls upstream xdg_toplevel.set_parent(parent)
```

This keeps `xdg_foreign` out of the core until there is a true cross-client
case. It also avoids inventing handle transport before a real host needs it.

## When xdg_foreign Is The Right Tool

Use `xdg_foreign` when the parent and child toplevels are owned by different
real Wayland clients and neither side can share a direct `xdg_toplevel`
pointer.

Likely cases:

- an out-of-process plugin UI that connects directly to the system compositor;
- a helper process launched by the plugin for a dialog;
- a sandbox boundary where the parent handle must cross IPC;
- a host toolkit that exposes only a foreign toplevel handle path.

In those cases the host exports its editor toplevel, passes the handle to the
plugin side, and lets the plugin side import the handle and parent its
toplevel. If wayembed grows this support, it exposes only the minimum host
callbacks needed to move handles. The host still owns process launch and
plugin-format transport.

## Related Protocols

`xdg-dialog` is a hint layered on `xdg_toplevel.set_parent`. It marks a
toplevel as a dialog and can mark it modal. It does not replace
`xdg_foreign`; it still needs a parent relation.

`xdg-activation` helps a client request activation for a toplevel. It can
matter for floating plugin editors because compositors may block focus stealing.
It does not create a parent relation.

Both protocols belong in the floating-window track. Neither is needed for the
embedded subsurface path.

## Lifetime Rules

Floating editor support needs strict teardown.

If the plugin closes its toplevel, wayembed should release the upstream
toplevel and clear any parent relation it owns. If the host editor closes,
wayembed should close plugin clients before destroying the parent objects. If a
foreign handle is revoked, imported children must become unparented or close.

Do not keep a floating plugin editor alive after its audio plugin instance
ends. Do not let a dialog outlive the plugin client that created it. These are
host policy rules, but wayembed makes the easy path the safe one.

## API Boundary

No public API is chosen yet.

The likely first API is a host callback for delegated floating toplevels:
given a client and plugin toplevel, return a host parent `xdg_toplevel *` or
decline parenting. That callback would belong near the existing host callbacks,
not in the adapter helpers.

The `xdg_foreign` API should wait for a real cross-client host path. If it
lands, keep it handle-based and small: export host toplevel, import child
parent handle, destroy exported/imported handles, and report revocation. Do not
turn wayembed into a desktop-window policy layer.
