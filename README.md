# TVRemote

An iPhone remote for an Android TV, written in SwiftUI and built entirely on Linux.

There is no Xcode anywhere in this project. [xtool](https://github.com/xtool-org/xtool)
compiles the SwiftPM package against Apple's iOS SDK, signs it, and packs the
`.ipa`. The app talks to the TV directly over the Android TV remote protocol
(`androidtvremote2`), so nothing leaves the local network and no vendor cloud is
involved.

## What it does

A d-pad, volume, transport keys, and macros that launch apps or switch to the
HDMI input. The TV is found over Bonjour, or you can pin a fixed address if your
network drops multicast.

The part worth having is the Lock Screen. Pinning the remote starts a Live
Activity whose buttons drive the TV without unlocking the phone, so switching the
input no longer means opening an app to press one button and closing it again.

There are also optional automations: raising the remote when the TV comes on,
offering the phone keyboard when the TV focuses a text field, and pausing
playback during a call. All of them are off by default because they need the app
awake in the background, which costs battery.

## How it is put together

Three targets, split by what has to be visible where.

`TVRemoteCore` holds the things both binaries need: `RemoteKey`, macros, the
colour tokens, the Live Activity's `ActivityAttributes`, and the App Intents. The
intents have to be compiled into the widget so it can build a `Button(intent:)`,
and into the app so `perform()` can run there, which is why they live in a shared
module rather than in either one.

`TVRemote` is the app. It owns the transport, discovery, preferences, and the
views.

`TVRemoteWidget` is a WidgetKit extension containing only the Live Activity's
UI. It renders whatever `ContentState` it is handed and never touches the
network.

### Talking to the TV

`AndroidTVTransport` opens a TLS session to port 6466 using a client certificate
stored in the keychain, then runs the protocol's handshake: configure, set
active, and a ping the TV repeats on its own schedule. Messages are encoded by a
small hand-written protobuf writer in `Protocol/`, because pulling in a full
protobuf runtime for eleven message types was not worth it.

Two details that took a while to get right. The certificate is stored with
`kSecAttrAccessibleAfterFirstUnlock`, so the app can read it while the phone is
locked, which the Lock Screen remote depends on. And zero-valued protobuf fields
must be omitted rather than written: proto3 does not serialise defaults, and the
TV ignores a message that sets `ime_counter` to an explicit `0`.

### App Intents on a toolchain that does not support them

Every Lock Screen button is a `Button(intent:)` whose intent conforms to
`LiveActivityIntent`, which is what makes iOS run it in the app's process where
the TLS session lives, rather than in the widget's.

iOS will not dispatch those taps unless the bundle contains a
`Metadata.appintents` directory, and Xcode generates that with a proprietary tool
xtool has no equivalent for. Without it the buttons highlight and nothing
happens. `Tools/generate-appintents-metadata.py` writes the bundle instead,
following a schema copied from real Xcode output, and `xtool.yml` copies it into
both the app and the extension. Re-run it after adding or renaming an intent.

## Getting it running

Pair once, then build.

Set `HOST` at the top of `.protocol-probe/pair.py` to the TV's address and run it
from the repository root. It prints a six digit code on the TV, takes it back on
stdin, and writes `cert.pem` and `key.pem`.

```
python .protocol-probe/pair.py
```

The app wants those as a PKCS#12 bundle with the passphrase `tvremote`, which is
what `Credentials.swift` imports with:

```
openssl pkcs12 -export -inkey key.pem -in cert.pem \
  -name TVRemote -passout pass:tvremote -out client.p12
base64 -w0 client.p12
```

Paste that base64 into Settings under TV credential. The pairing directory is not
tracked, because it holds your private key.

```
xtool dev build --ipa     # writes xtool/TVRemote.ipa
xtool dev                 # build, sign, install, and launch on a connected phone
```

The deployment target is iOS 18, which `supplementalActivityFamilies` needs in
order to put the remote in the Apple Watch Smart Stack.

## Controlling it from elsewhere

Two intents are exposed to Shortcuts. `Control the TV` takes a key name such as
`ok` or `volumeUp`, or a macro id such as `xbox`. `Send Link to TV` takes a URL
and rewrites YouTube and Spotify links into something the TV will open, so
wrapping it in a shortcut that accepts URLs puts it in the share sheet. Either
can be bound to the Action Button. Settings has a switch that turns outside
control off without affecting the Lock Screen buttons.

There is also a `lumindtv://` URL scheme, kept from before App Intents worked.

## Known limits

Typing depends on the app you are typing into. Key events reach the TV but are
injected as a remote control rather than a keyboard, so a text field ignores the
letters while still honouring enter and delete. Text is sent as an IME batch edit
instead, which works in some apps and not others.

The foreground app never arrives over the protocol on this panel. It reports an
empty string, so anything driven from it cannot work.

Absolute volume and the power keycode are guesses about what the protocol
accepts, so both sit behind switches in Settings and default to off. Run
`Tools/probe-volume-and-power.py <tv-ip>` against the TV to find out whether
either works before trusting them.

## Layout

```
Sources/TVRemoteCore      shared: keys, macros, theme, activity attributes, intents
Sources/TVRemote          app: transport, discovery, preferences, views
Sources/TVRemoteWidget    Live Activity UI
Metadata.appintents       generated; makes iOS dispatch the Lock Screen buttons
Tools/                    metadata generator, protocol probe
.protocol-probe/          pairing and reverse-engineering scripts (untracked)
```
