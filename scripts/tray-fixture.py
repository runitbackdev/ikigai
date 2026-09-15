#!/usr/bin/env python3
"""A tray item with a submenu, for trying the rail's tray menus by hand (`just tray-fixture`).

Registers a StatusNotifierItem named "ikigai-fixture" with a dbusmenu of two plain entries,
a checked one, a separator, and a "More" submenu holding three entries of its own. Every
click is printed. Ctrl-C removes it. Needs PyGObject: the python ikigai-caffeinate runs with.
"""
import os
import signal
import sys
import warnings

warnings.simplefilter("ignore", DeprecationWarning)  # register_object, still the way with Gio

import gi
gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib

SNI_XML = """
<node>
  <interface name="org.kde.StatusNotifierItem">
    <property name="Category" type="s" access="read"/>
    <property name="Id" type="s" access="read"/>
    <property name="Title" type="s" access="read"/>
    <property name="Status" type="s" access="read"/>
    <property name="IconName" type="s" access="read"/>
    <property name="Menu" type="o" access="read"/>
    <property name="ItemIsMenu" type="b" access="read"/>
    <method name="Activate"><arg type="i" name="x" direction="in"/><arg type="i" name="y" direction="in"/></method>
    <method name="ContextMenu"><arg type="i" name="x" direction="in"/><arg type="i" name="y" direction="in"/></method>
  </interface>
</node>
"""

MENU_XML = """
<node>
  <interface name="com.canonical.dbusmenu">
    <property name="Version" type="u" access="read"/>
    <property name="Status" type="s" access="read"/>
    <method name="GetLayout">
      <arg type="i" name="parentId" direction="in"/>
      <arg type="i" name="recursionDepth" direction="in"/>
      <arg type="as" name="propertyNames" direction="in"/>
      <arg type="u" name="revision" direction="out"/>
      <arg type="(ia{sv}av)" name="layout" direction="out"/>
    </method>
    <method name="GetGroupProperties">
      <arg type="ai" name="ids" direction="in"/>
      <arg type="as" name="propertyNames" direction="in"/>
      <arg type="a(ia{sv})" name="properties" direction="out"/>
    </method>
    <method name="GetProperty">
      <arg type="i" name="id" direction="in"/>
      <arg type="s" name="name" direction="in"/>
      <arg type="v" name="value" direction="out"/>
    </method>
    <method name="Event">
      <arg type="i" name="id" direction="in"/>
      <arg type="s" name="eventId" direction="in"/>
      <arg type="v" name="data" direction="in"/>
      <arg type="u" name="timestamp" direction="in"/>
    </method>
    <method name="AboutToShow">
      <arg type="i" name="id" direction="in"/>
      <arg type="b" name="needUpdate" direction="out"/>
    </method>
    <signal name="LayoutUpdated"><arg type="u" name="revision"/><arg type="i" name="parent"/></signal>
    <signal name="ItemsPropertiesUpdated"><arg type="a(ia{sv})" name="updatedProps"/><arg type="a(ias)" name="removedProps"/></signal>
  </interface>
</node>
"""

# id -> (properties, children ids)
MENU = {
    0: ({"children-display": "submenu"}, [1, 2, 3, 4, 5, 9]),
    1: ({"label": "Open"}, []),
    2: ({"label": "Greyed out", "enabled": False}, []),
    3: ({"label": "Checked", "toggle-type": "checkmark", "toggle-state": 1}, []),
    4: ({"type": "separator"}, []),
    5: ({"label": "More", "children-display": "submenu"}, [6, 7, 8]),
    6: ({"label": "Inner one"}, []),
    7: ({"label": "Inner two"}, []),
    8: ({"label": "Deeper", "children-display": "submenu"}, [10]),
    9: ({"label": "Quit"}, []),
    10: ({"label": "Bottom"}, []),
}


def props(item_id, names):
    out = {}
    for key, value in MENU[item_id][0].items():
        if names and key not in names:
            continue
        if isinstance(value, bool):
            out[key] = GLib.Variant("b", value)
        elif isinstance(value, int):
            out[key] = GLib.Variant("i", value)
        else:
            out[key] = GLib.Variant("s", value)
    return out


def layout(item_id, depth, names):
    children = []
    if depth != 0:
        children = [GLib.Variant("(ia{sv}av)", layout(c, depth - 1, names)) for c in MENU[item_id][1]]
    return (item_id, props(item_id, names), children)


def on_menu_call(conn, sender, path, iface, method, params, invocation):
    if method == "GetLayout":
        parent, depth, names = params.unpack()
        invocation.return_value(GLib.Variant("(u(ia{sv}av))", (1, layout(parent, depth, names))))
    elif method == "GetGroupProperties":
        ids, names = params.unpack()
        ids = ids or list(MENU)
        invocation.return_value(GLib.Variant("(a(ia{sv}))", ([(i, props(i, names)) for i in ids],)))
    elif method == "GetProperty":
        item_id, name = params.unpack()
        invocation.return_value(GLib.Variant("(v)", (props(item_id, [name]).get(name, GLib.Variant("s", "")),)))
    elif method == "Event":
        item_id, event, _data, _ts = params.unpack()
        print(f"event {event} on {item_id} ({MENU[item_id][0].get('label', '?')})", flush=True)
        if item_id == 9 and event == "clicked":
            GLib.idle_add(loop.quit)
        invocation.return_value(None)
    elif method == "AboutToShow":
        invocation.return_value(GLib.Variant("(b)", (False,)))
    else:
        invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", method)


def on_menu_get(conn, sender, path, iface, prop):
    return {"Version": GLib.Variant("u", 3), "Status": GLib.Variant("s", "normal")}[prop]


def on_sni_get(conn, sender, path, iface, prop):
    return {
        "Category": GLib.Variant("s", "ApplicationStatus"),
        "Id": GLib.Variant("s", "ikigai-fixture"),
        "Title": GLib.Variant("s", "Ikigai tray fixture"),
        "Status": GLib.Variant("s", "Active"),
        "IconName": GLib.Variant("s", "dialog-information"),
        "Menu": GLib.Variant("o", "/MenuBar"),
        "ItemIsMenu": GLib.Variant("b", True),
    }[prop]


def on_sni_call(conn, sender, path, iface, method, params, invocation):
    print(f"{method} {params.unpack()}", flush=True)
    invocation.return_value(None)


loop = GLib.MainLoop()


def on_bus(conn, name):
    conn.register_object("/StatusNotifierItem", Gio.DBusNodeInfo.new_for_xml(SNI_XML).interfaces[0], on_sni_call, on_sni_get, None)
    conn.register_object("/MenuBar", Gio.DBusNodeInfo.new_for_xml(MENU_XML).interfaces[0], on_menu_call, on_menu_get, None)
    conn.call_sync("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
                   "RegisterStatusNotifierItem", GLib.Variant("(s)", (name,)), None, Gio.DBusCallFlags.NONE, -1, None)
    print(f"registered as {name}; Ctrl-C or Quit removes it", flush=True)


def main():
    name = f"org.kde.StatusNotifierItem-{os.getpid()}-1"
    Gio.bus_own_name(Gio.BusType.SESSION, name, Gio.BusNameOwnerFlags.NONE, lambda c, n: on_bus(c, n), None,
                     lambda c, n: sys.exit(f"could not own {n}"))
    signal.signal(signal.SIGINT, lambda *_: loop.quit())
    signal.signal(signal.SIGTERM, lambda *_: loop.quit())
    loop.run()


if __name__ == "__main__":
    main()
