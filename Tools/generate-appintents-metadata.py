#!/usr/bin/env python3
"""Emit the Metadata.appintents bundle that xtool cannot produce.

Xcode runs a proprietary `appintentsmetadataprocessor` over the compiled binary
to build this bundle. iOS reads it at install time to learn which app provides
which intent; without it the system has no route for a Live Activity button tap,
so the button highlights and nothing happens. xtool has no equivalent
(xtool-org/xtool#145 is open, and PR #217 which added one was closed unmerged),
so we generate it here.

The schema below is not documented by Apple. Every field, and the shape of a
String `@Parameter`, is copied from a real Xcode-generated bundle for an intent
structurally identical to ours -- a `LiveActivityIntent` with `isDiscoverable`
false, String parameters and a static handler set by the app at launch. Keep our
Swift intents matching that reference (no IntentDescription, no explicit
authenticationPolicy) or this file drifts from what it describes.

Re-run after changing any intent:  python3 Tools/generate-appintents-metadata.py
"""

import json
import pathlib

MODULE = "TVRemoteCore"
OUT = pathlib.Path(__file__).resolve().parent.parent / "Metadata.appintents"

# Matches the reference bundle. It is a build-tools stamp that iOS only surfaces
# for diagnostics, and pinning a value known to be accepted beats inventing one.
TOOLS_VERSION = "17F113"

# Swift's primitive type identifiers, as they appear in `valueType`.
STRING = 0

# A String @Parameter accepts a string, and also the two forms the Shortcuts
# graph can coerce into one. Copied verbatim from the reference.
STRING_INPUT_TYPES = [
    {"kindValue": 0, "valueType": {"primitive": {"wrapper": {"typeIdentifier": 2}}}},
    {"kindValue": 0, "valueType": {"primitive": {"wrapper": {"typeIdentifier": STRING}}}},
    {"kindValue": 0, "valueType": {"array": {"wrapper": {
        "capabilities": 3,
        "memberValueType": {"primitive": {"wrapper": {"typeIdentifier": 2}}},
    }}}},
]

# One intent per entry: (Swift type name, title, [(parameter, title)], discoverable).
#
# Discoverable ones show up in Shortcuts, and so reach Siri, the Action Button
# and the share sheet. The Lock Screen's own buttons stay hidden -- they are not
# useful as Shortcuts actions and would only clutter the list.
INTENTS = [
    ("SendRemoteKeyIntent", "Send Remote Key", [("key", "Key")], False),
    ("RunRemoteMacroIntent", "Run Remote Macro", [("macroID", "Macro")], False),
    ("EndRemoteSessionIntent", "End Remote Session", [], False),
    ("TVRemoteControlIntent", "Control the TV", [("command", "Command")], True),
    ("SendLinkToTVIntent", "Send Link to TV", [("link", "Link")], True),
]


def mangled(module: str, type_name: str) -> str:
    """Swift's mangling for a module-level struct: <len><module><len><name>V."""
    return f"{len(module)}{module}{len(type_name)}{type_name}V"


def string_parameter(name: str, title: str) -> dict:
    return {
        "capabilities": 0,
        "dynamicOptionsSupport": 0,
        "inputConnectionBehavior": 0,
        "isInput": False,
        "isOptional": False,
        "name": name,
        "resolvableInputTypes": STRING_INPUT_TYPES,
        "title": {"alternatives": [], "key": title},
        "typeSpecificMetadata": [],
        "valueType": {"primitive": {"wrapper": {"typeIdentifier": STRING}}},
    }


def action(type_name: str, title: str, parameters: list, discoverable: bool) -> dict:
    name = mangled(MODULE, type_name)
    return {
        "assistantDefinedSchemaTraits": [],
        "assistantDefinedSchemas": [],
        # 0 is the default policy, and the one the reference ships with; it is
        # what lets a Lock Screen button run without unlocking first.
        "authenticationPolicy": 0,
        "availabilityAnnotations": {"LNPlatformNameWildcard": {"introducedVersion": "*"}},
        "effectiveBundleIdentifiers": [],
        "fullyQualifiedTypeName": f"{MODULE}.{type_name}",
        "identifier": type_name,
        "isAuthPolExplicit": False,
        "isDiscoverable": discoverable,
        "mangledTypeName": name,
        "mangledTypeNameByBundleIdentifier": {},
        "mangledTypeNameByBundleIdentifierV2": {},
        "mangledTypeNameV2": name,
        "openAppWhenRun": False,
        "outputFlags": 0,
        "parameters": [string_parameter(n, t) for n, t in parameters],
        "presentationStyle": 0,
        "requiredCapabilities": [],
        "supportedModes": 1,
        # What `LiveActivityIntent` conformance is recorded as. This is the field
        # that tells the system to run the intent in the app's process.
        "systemProtocolMetadata": ["com.apple.link.systemProtocol.SessionStarting", {"empty": {}}],
        "systemProtocolMetadataV2": ["com.apple.link.systemProtocol.SessionStarting", {"empty": {}}],
        "systemProtocols": ["com.apple.link.systemProtocol.SessionStarting"],
        "title": {"alternatives": [], "key": title},
        "typeSpecificMetadata": [],
        "visibilityMetadata": {"assistantOnly": False, "isDiscoverable": discoverable},
    }


def main() -> None:
    actions_data = {
        "actions": {
            name: action(name, title, params, discoverable)
            for name, title, params, discoverable in INTENTS
        },
        "assistantEntities": [],
        "assistantIntentNegativePhrases": [],
        "assistantIntents": [],
        "autoShortcuts": [],
        "entities": {},
        "enums": [],
        "generator": {"name": "xcode-tools", "version": TOOLS_VERSION},
        "negativePhrases": [],
        "queries": {},
        "shortcutTileColor": 14,
        "version": 1,
    }

    OUT.mkdir(parents=True, exist_ok=True)
    # Plain UTF-8 JSON despite the extension -- not a property list.
    (OUT / "extract.actionsdata").write_text(json.dumps(actions_data, indent=2) + "\n")
    (OUT / "version.json").write_text(
        json.dumps({"version": "3.0", "toolsVersion": TOOLS_VERSION}, indent=2) + "\n"
    )
    print(f"wrote {OUT}/extract.actionsdata ({len(actions_data['actions'])} intents)")
    print(f"wrote {OUT}/version.json")


if __name__ == "__main__":
    main()
