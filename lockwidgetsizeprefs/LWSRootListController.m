#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface LWSRootListController : PSListController
@end

@implementation LWSRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)resetSize {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.zilvyn.lockwidgetsize"];
    [prefs setFloat:1.0 forKey:@"widgetScale"];
    [prefs synchronize];
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.zilvyn.lockwidgetsize/prefschanged"),
        NULL, NULL, YES);
    [self reloadSpecifiers];
}

@end
