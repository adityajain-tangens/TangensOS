#include "AppWindows.h"

#include <QCoreApplication>
#include <QPointer>

#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

// A CGImage as a PNG data: URL
static QString pngDataUrl(CGImageRef image)
{
    NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return "data:image/png;base64," + QString::fromLatin1(QByteArray::fromNSData(png).toBase64());
}

AppWindows::AppWindows(QObject *parent) : QObject(parent) {}

QVariantList AppWindows::openApps() const
{
    QVariantList apps;
    const pid_t self = NSProcessInfo.processInfo.processIdentifier;
    for (NSRunningApplication *app in NSWorkspace.sharedWorkspace.runningApplications) {
        // Only apps with a Dock icon, not background helpers
        if (app.activationPolicy != NSApplicationActivationPolicyRegular || app.processIdentifier == self)
            continue;
        NSRect size = NSMakeRect(0, 0, 128, 128);
        CGImageRef icon = [app.icon CGImageForProposedRect:&size context:nil hints:nil];
        apps.append(QVariantMap{
            { "pid", app.processIdentifier },
            { "name", QString::fromNSString(app.localizedName) },
            { "icon", icon ? pngDataUrl(icon) : QString() },
        });
    }
    return apps;
}

void AppWindows::capture(int pid, int windowId)
{
    // The answers come on another thread: hand them back to this one, if it's still around
    QPointer<AppWindows> guard(this);
    auto fail = [guard](const QString &error) {
        QMetaObject::invokeMethod(qApp, [guard, error] { if (guard) emit guard->failed(error); }, Qt::QueuedConnection);
    };

    // Asks for the Screen Recording permission the first time, and fails until it's given.
    // A window asked for by its id is looked for off screen too, like on another desktop.
    [SCShareableContent getShareableContentExcludingDesktopWindows:YES onScreenWindowsOnly:windowId == 0
        completionHandler:^(SCShareableContent *content, NSError *error) {
        if (error) {
            fail("Allow Tangens in System Settings › Privacy & Security › Screen Recording, then try again.");
            return;
        }

        // The window with that id, or else the app's biggest normal window
        SCWindow *window = nil;
        for (SCWindow *w in content.windows) {
            if (w.owningApplication.processID != pid || w.windowLayer != 0)
                continue;
            if (windowId != 0) {
                if (w.windowID == (CGWindowID)windowId)
                    window = w;
            } else if (!window || w.frame.size.width * w.frame.size.height > window.frame.size.width * window.frame.size.height) {
                window = w;
            }
        }
        if (!window) {
            fail(windowId != 0 ? "This window isn't open anymore." : "This app has no window open.");
            return;
        }
        const int shown = window.windowID;

        SCContentFilter *filter = [[SCContentFilter alloc] initWithDesktopIndependentWindow:window];
        SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
        config.width = filter.contentRect.size.width * filter.pointPixelScale;
        config.height = filter.contentRect.size.height * filter.pointPixelScale;
        config.showsCursor = NO;

        [SCScreenshotManager captureImageWithFilter:filter configuration:config
            completionHandler:^(CGImageRef image, NSError *error) {
            if (error || !image) {
                fail("Couldn't take a picture of the window.");
                return;
            }
            const QString url = pngDataUrl(image);
            QMetaObject::invokeMethod(qApp, [guard, url, shown] { if (guard) emit guard->captured(url, shown); }, Qt::QueuedConnection);
        }];
    }];
}

// The biggest window of the app with this pid, like the one capture() takes a picture of, or null.
// The caller releases it.
static AXUIElementRef biggestWindow(int pid)
{
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    CFArrayRef windows = nullptr;
    AXUIElementCopyAttributeValue(app, kAXWindowsAttribute, (CFTypeRef *)&windows);
    CFRelease(app);
    if (!windows)
        return nullptr;

    AXUIElementRef window = nullptr;
    double biggest = 0;
    for (CFIndex i = 0; i < CFArrayGetCount(windows); ++i) {
        AXUIElementRef w = (AXUIElementRef)CFArrayGetValueAtIndex(windows, i);
        AXValueRef value = nullptr;
        CGSize size = CGSizeZero;
        if (AXUIElementCopyAttributeValue(w, kAXSizeAttribute, (CFTypeRef *)&value) == kAXErrorSuccess) {
            AXValueGetValue(value, (AXValueType)kAXValueTypeCGSize, &size);
            CFRelease(value);
        }
        if (!window || size.width * size.height > biggest) {
            window = w;
            biggest = size.width * size.height;
        }
    }
    if (window)
        CFRetain(window);
    CFRelease(windows);
    return window;
}

bool AppWindows::placeWindow(int pid, const QRect &rect)
{
    // Asks for the Accessibility permission the first time
    NSDictionary *options = @{ (__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES };
    if (!AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options))
        return false;

    AXUIElementRef window = biggestWindow(pid);
    if (!window)
        return false;

    CGPoint position = CGPointMake(rect.x(), rect.y());
    CGSize size = CGSizeMake(rect.width(), rect.height());
    AXValueRef positionValue = AXValueCreate((AXValueType)kAXValueTypeCGPoint, &position);
    AXValueRef sizeValue = AXValueCreate((AXValueType)kAXValueTypeCGSize, &size);
    // Moved again after resizing, as some apps shift a window that's resized near a screen's edge
    AXUIElementSetAttributeValue(window, kAXPositionAttribute, positionValue);
    AXUIElementSetAttributeValue(window, kAXSizeAttribute, sizeValue);
    const bool placed = AXUIElementSetAttributeValue(window, kAXPositionAttribute, positionValue) == kAXErrorSuccess;
    CFRelease(positionValue);
    CFRelease(sizeValue);

    AXUIElementPerformAction(window, kAXRaiseAction);
    [[NSRunningApplication runningApplicationWithProcessIdentifier:pid] activateWithOptions:0];
    CFRelease(window);
    return placed;
}

QRect AppWindows::windowRect(int pid) const
{
    if (!AXIsProcessTrusted())
        return {};
    AXUIElementRef window = biggestWindow(pid);
    if (!window)
        return {};

    CGPoint position = CGPointZero;
    CGSize size = CGSizeZero;
    AXValueRef value = nullptr;
    if (AXUIElementCopyAttributeValue(window, kAXPositionAttribute, (CFTypeRef *)&value) == kAXErrorSuccess) {
        AXValueGetValue(value, (AXValueType)kAXValueTypeCGPoint, &position);
        CFRelease(value);
    }
    if (AXUIElementCopyAttributeValue(window, kAXSizeAttribute, (CFTypeRef *)&value) == kAXErrorSuccess) {
        AXValueGetValue(value, (AXValueType)kAXValueTypeCGSize, &size);
        CFRelease(value);
    }
    CFRelease(window);
    return QRect(qRound(position.x), qRound(position.y), qRound(size.width), qRound(size.height));
}
