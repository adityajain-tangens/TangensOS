#include "AppWindows.h"

#include <QCoreApplication>
#include <QPointer>

#import <AppKit/AppKit.h>
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

void AppWindows::capture(int pid)
{
    // The answers come on another thread: hand them back to this one, if it's still around
    QPointer<AppWindows> guard(this);
    auto fail = [guard](const QString &error) {
        QMetaObject::invokeMethod(qApp, [guard, error] { if (guard) emit guard->failed(error); }, Qt::QueuedConnection);
    };

    // Asks for the Screen Recording permission the first time, and fails until it's given
    [SCShareableContent getShareableContentExcludingDesktopWindows:YES onScreenWindowsOnly:YES
        completionHandler:^(SCShareableContent *content, NSError *error) {
        if (error) {
            fail("Allow Tangens in System Settings › Privacy & Security › Screen Recording, then try again.");
            return;
        }

        // The app's biggest normal window
        SCWindow *window = nil;
        for (SCWindow *w in content.windows) {
            if (w.owningApplication.processID != pid || w.windowLayer != 0)
                continue;
            if (!window || w.frame.size.width * w.frame.size.height > window.frame.size.width * window.frame.size.height)
                window = w;
        }
        if (!window) {
            fail("This app has no window open.");
            return;
        }

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
            QMetaObject::invokeMethod(qApp, [guard, url] { if (guard) emit guard->captured(url); }, Qt::QueuedConnection);
        }];
    }];
}
