#!/usr/bin/env bash
set -euo pipefail

readonly PRODUCT_PATHS=(Packages/TeleprompterCore/Sources PrivatePresenterApp project.yml Config)
readonly FORBIDDEN_SOURCE_PATTERN='Electron|import[[:space:]]+(WebKit|JavaScriptCore|Network|ApplicationServices|ScriptingBridge)|WKWebView|WebView|JSContext|URLSession|URLRequest|NSURLConnection|CFHTTP|NWConnection|CGEventTap|CGEvent\.tapCreate|AXIsProcessTrusted|AXUIElement|AXObserver|add(Global|Local)MonitorForEvents|NSEvent\.pressedMouseButtons|CGEventSource\.keyState|GetKeys|GetCurrentKeyModifiers|AECreateAppleEvent|NSAppleScript|Sentry|Firebase|Amplitude|Mixpanel|telemetry|analytics'
readonly FORBIDDEN_ENTITLEMENT_PATTERN='com\.apple\.security\.network\.(client|server)|com\.apple\.security\.automation\.apple-events|com\.apple\.security\.device\.(audio-input|camera)|com\.apple\.security\.personal-information|com\.apple\.developer\.icloud|NSAppTransportSecurity'
readonly FORBIDDEN_PHASE_A_PATTERN='NSApp\.activate[[:space:]]*\(|NSRunningApplication[^[:cntrl:]]*\.activate[[:space:]]*\(|makeKeyAndOrderFront[[:space:]]*\(|\.screenSaver([^[:alnum:]_]|$)|NSWindow\.Level[[:space:]]*\([[:space:]]*rawValue|CGWindowLevelForKey[[:space:]]*\(|GetEventDispatcherTarget[[:space:]]*\(|performWindowDrag[[:space:]]*\(|styleMask[^[:cntrl:]]*(insert|formUnion)[^[:cntrl:]]*\.resizable|styleMask[[:space:]]*[:=][^[:cntrl:]]*\.resizable'

for path in "${PRODUCT_PATHS[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "error: product audit path is missing: ${path}" >&2
    exit 1
  fi
done

if grep -RInE --include='*.swift' --include='*.plist' --include='*.entitlements' --include='*.yml' --include='*.xcconfig' "$FORBIDDEN_SOURCE_PATTERN" "${PRODUCT_PATHS[@]}"; then
  echo "error: prohibited runtime/network/permission-fallback marker found in product sources." >&2
  exit 1
fi
if grep -RInE --include='*.plist' --include='*.entitlements' --include='*.yml' "$FORBIDDEN_ENTITLEMENT_PATTERN" "${PRODUCT_PATHS[@]}"; then
  echo "error: prohibited entitlement or transport configuration found." >&2
  exit 1
fi
if grep -RInE --include='*.swift' "$FORBIDDEN_PHASE_A_PATTERN" \
  Packages/TeleprompterCore/Sources PrivatePresenterApp \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//'; then
  echo "error: prohibited Phase A focus/window/Carbon behavior marker found." >&2
  exit 1
fi

hot_key_source='PrivatePresenterApp/Services/DiagnosticHotKeyService.swift'
grep -q 'GetApplicationEventTarget()' "$hot_key_source"
grep -q 'kVK_ANSI_H' "$hot_key_source"
grep -q 'kVK_ANSI_L' "$hot_key_source"
grep -q 'Control-Option-H' "$hot_key_source"
grep -q 'Control-Option-L' "$hot_key_source"

product_hot_key_source='PrivatePresenterApp/Services/CarbonHotKeyService.swift'
grep -q 'GetApplicationEventTarget()' "$product_hot_key_source"
grep -q 'RegisterEventHotKey(' "$product_hot_key_source"
grep -q 'UnregisterEventHotKey(' "$product_hot_key_source"
grep -q 'InstallEventHandler(' "$product_hot_key_source"
grep -q 'RemoveEventHandler(' "$product_hot_key_source"

echo "No prohibited product network, web runtime, telemetry, automation, focus workaround, event-tap, event-monitor, key-polling, or unbounded window-level surface found."
