#import <Foundation/Foundation.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        // Read current setting from NSGlobalDomain (AnyHost)
        NSString *key = @"com.apple.swipescrolldirection";
        CFPropertyListRef existing = CFPreferencesCopyValue(
            (__bridge CFStringRef)key,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        );

        BOOL currentValue = YES; // macOS default is natural scrolling ON
        if (existing != NULL) {
            currentValue = CFBooleanGetValue(existing);
            CFRelease(existing);
        }

        // Toggle
        BOOL newValue = !currentValue;

        // Write to both AnyHost and CurrentHost for full coverage
        CFPreferencesSetValue(
            (__bridge CFStringRef)key,
            newValue ? kCFBooleanTrue : kCFBooleanFalse,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        );
        CFPreferencesSetValue(
            (__bridge CFStringRef)key,
            newValue ? kCFBooleanTrue : kCFBooleanFalse,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        );
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication);

        // Apply immediately via activateSettings
        NSString *activatePath = @"/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings";
        if ([[NSFileManager defaultManager] fileExistsAtPath:activatePath]) {
            NSTask *task = [[NSTask alloc] init];
            task.executableURL = [NSURL fileURLWithPath:activatePath];
            task.arguments = @[@"-u"];
            [task launchAndReturnError:nil];
            [task waitUntilExit];
        }

        // Show notification
        NSString *direction = newValue ? @"Natural" : @"Traditional";
        NSString *script = [NSString stringWithFormat:
            @"display notification \"Scrolling → %@\" with title \"Toggle Natural Scrolling\" sound name \"Funk\"",
            direction];
        NSTask *osa = [[NSTask alloc] init];
        osa.executableURL = [NSURL fileURLWithPath:@"/usr/bin/osascript"];
        osa.arguments = @[@"-e", script];
        [osa launchAndReturnError:nil];
        [osa waitUntilExit];
    }
    return 0;
}
