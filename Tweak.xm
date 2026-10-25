#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString *const kPrefsDomain = @"com.zilvyn.lockwidgetsize";
static CFStringRef const kPrefsChanged = CFSTR("com.zilvyn.lockwidgetsize/prefschanged");
static NSString *const kLogPath = @"/var/mobile/Library/Preferences/LockWidgetSize-classes.txt";

static BOOL tweakEnabled = YES;
static CGFloat widgetScale = 1.0;           // 1.0 = ukuran asli
static NSString *widgetKeyword = @"Widget"; // potongan nama class view yang di-scale
static BOOL debugLog = NO;                  // catat nama class ke file untuk diagnosa

static BOOL isSpringBoard = NO;
static NSString *processID = @"";

// Referensi lemah supaya bisa di-refresh langsung saat slider digeser
static NSHashTable *widgetViews;
static NSMutableDictionary<NSString *, NSNumber *> *classMatchCache;
static NSMutableSet<NSString *> *loggedLines;

static void loadPrefs(void) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:kPrefsDomain];

    id enabledValue = [prefs objectForKey:@"enabled"];
    tweakEnabled = enabledValue ? [enabledValue boolValue] : YES;

    id scaleValue = [prefs objectForKey:@"widgetScale"];
    CGFloat scale = scaleValue ? [scaleValue floatValue] : 1.0;
    if (scale < 0.3) scale = 0.3;
    if (scale > 2.0) scale = 2.0;
    widgetScale = scale;

    NSString *keyword = [prefs stringForKey:@"widgetKeyword"];
    widgetKeyword = keyword.length > 0 ? keyword : @"Widget";

    debugLog = [prefs boolForKey:@"debugLog"];
}

static BOOL classNameMatches(UIView *view) {
    NSString *name = NSStringFromClass([view class]);
    NSNumber *cached = classMatchCache[name];
    if (cached) return cached.boolValue;

    BOOL match = NO;
    // Widget Home Screen memakai awalan SBH, jangan ikut di-scale
    if (widgetKeyword.length > 0 && ![name hasPrefix:@"SBH"]) {
        match = [name rangeOfString:widgetKeyword options:NSCaseInsensitiveSearch].location != NSNotFound;
    }
    classMatchCache[name] = @(match);
    return match;
}

static BOOL inLockScreenWindow(UIView *view) {
    if (!isSpringBoard) return YES; // PosterBoard hanya dipakai untuk lockscreen
    NSString *windowName = NSStringFromClass([view.window class]);
    return [windowName rangeOfString:@"CoverSheet" options:NSCaseInsensitiveSearch].location != NSNotFound
        || [windowName rangeOfString:@"Lock" options:NSCaseInsensitiveSearch].location != NSNotFound
        || [windowName rangeOfString:@"Poster" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL shouldScaleWidget(UIView *view) {
    if (!classNameMatches(view)) return NO;
    if (!inLockScreenWindow(view)) return NO;
    // Hindari scale ganda kalau view induknya sudah cocok
    for (UIView *parent = view.superview; parent; parent = parent.superview) {
        if (classNameMatches(parent)) return NO;
    }
    return YES;
}

static void applyWidget(UIView *view) {
    if (tweakEnabled && widgetScale != 1.0) {
        view.transform = CGAffineTransformMakeScale(widgetScale, widgetScale);
    } else {
        view.transform = CGAffineTransformIdentity;
    }
}

static void logLine(NSString *line) {
    if (!loggedLines) loggedLines = [NSMutableSet set];
    if ([loggedLines containsObject:line]) return;
    [loggedLines addObject:line];

    NSString *out = [line stringByAppendingString:@"\n"];
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
    if (!handle) {
        [out writeToFile:kLogPath atomically:NO encoding:NSUTF8StringEncoding error:nil];
        return;
    }
    [handle seekToEndOfFile];
    [handle writeData:[out dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

static void logIfInteresting(UIView *view, BOOL scaled) {
    NSString *name = NSStringFromClass([view class]);
    NSString *lower = name.lowercaseString;
    if ([lower containsString:@"widget"] || [lower containsString:@"poster"] || [lower containsString:@"lock"]) {
        logLine([NSString stringWithFormat:@"[%@] view=%@ window=%@ scaled=%@",
                 processID, name, NSStringFromClass([view.window class]), scaled ? @"YES" : @"NO"]);
    }
}

static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        loadPrefs();
        [classMatchCache removeAllObjects];
        for (UIView *view in [widgetViews allObjects]) {
            applyWidget(view);
        }
    });
}

%hook UIView

- (void)didMoveToWindow {
    %orig;
    if (!self.window) return;

    BOOL scaled = shouldScaleWidget(self);
    if (debugLog) logIfInteresting(self, scaled);
    if (scaled) {
        [widgetViews addObject:self];
        applyWidget(self);
    }
}

%end

%ctor {
    processID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    isSpringBoard = [processID isEqualToString:@"com.apple.springboard"];

    widgetViews = [NSHashTable weakObjectsHashTable];
    classMatchCache = [NSMutableDictionary dictionary];
    loadPrefs();

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        prefsChanged,
        kPrefsChanged,
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );

    %init;
}
