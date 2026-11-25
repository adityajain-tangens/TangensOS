pragma Singleton

import QtQuick
import QtWebEngine

// The browser memory every web page shares (WebViewItem): cookies, logins, the cache and site permissions.
// Saved to disk, not forgotten when the app quits, so sites like Google remember it between launches.
// Kept in a folder named after storageName, the same for every build.
WebEngineProfile {
    storageName: "Tangens"
    // Off the record is Qt's private browsing, which keeps everything only in memory. It's on unless turned off.
    offTheRecord: false
}
