#!/usr/bin/env bash
set -euo pipefail

readonly PRODUCT_PATHS=(Packages/TeleprompterCore/Sources PrivatePresenterApp project.yml Config)
readonly FORBIDDEN_SOURCE_PATTERN='Electron|import[[:space:]]+(WebKit|JavaScriptCore|Network)|WKWebView|WebView|JSContext|URLSession|URLRequest|NSURLConnection|CFHTTP|NWConnection|CGEventTap|CGEvent\.tapCreate|AXIsProcessTrusted|addGlobalMonitorForEvents|Sentry|Firebase|Amplitude|Mixpanel|telemetry|analytics'
readonly FORBIDDEN_ENTITLEMENT_PATTERN='com\.apple\.security\.network\.(client|server)|com\.apple\.security\.automation\.apple-events|com\.apple\.security\.device\.(audio-input|camera)|com\.apple\.security\.personal-information|com\.apple\.developer\.icloud|NSAppTransportSecurity'

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

echo "No prohibited product network, web runtime, telemetry, automation, event-tap, or global-monitor surface found."
