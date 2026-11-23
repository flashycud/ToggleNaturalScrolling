#import <Foundation/Foundation.h>

static CFStringRef const ScrollKey = CFSTR("com.apple.swipescrolldirection");

typedef struct {
    void *context;
    CFPropertyListRef (*read)(void *, CFStringRef);
    void (*write)(void *, CFStringRef, CFPropertyListRef);
    BOOL (*sync)(void *, CFStringRef);
    BOOL (*apply)(void *, NSString **);
} ToggleOperations;

static BOOL runProcess(NSString *path, NSArray<NSString *> *arguments, NSString **error) {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:path];
    task.arguments = arguments;
    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
        *error = [NSString stringWithFormat:@"Could not start %@: %@", path, launchError.localizedDescription];
        return NO;
    }
    [task waitUntilExit];
    if (task.terminationReason != NSTaskTerminationReasonExit || task.terminationStatus != 0) {
        *error = [NSString stringWithFormat:@"%@ did not complete successfully (status %d).", path, task.terminationStatus];
        return NO;
    }
    return YES;
}

static CFPropertyListRef readPreference(void *context, CFStringRef host) {
    (void)context;
    return CFPreferencesCopyValue(ScrollKey, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, host);
}

static void writePreference(void *context, CFStringRef host, CFPropertyListRef value) {
    (void)context;
    CFPreferencesSetValue(ScrollKey, value, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, host);
}

static BOOL syncPreference(void *context, CFStringRef host) {
    (void)context;
    return CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, host);
}

static BOOL applyPreference(void *context, NSString **error) {
    (void)context;
    return runProcess(@"/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings", @[@"-u"], error);
}

static BOOL writeAndVerify(ToggleOperations ops, CFStringRef host, CFPropertyListRef value) {
    ops.write(ops.context, host, value);
    if (!ops.sync(ops.context, host)) {
        return NO;
    }
    CFPropertyListRef actual = ops.read(ops.context, host);
    BOOL matches = (actual == NULL && value == NULL) ||
        (actual != NULL && value != NULL && CFEqual(actual, value));
    if (actual != NULL) CFRelease(actual);
    return matches;
}

static BOOL toggleScrolling(ToggleOperations ops, BOOL *natural, NSString **error) {
    CFStringRef hosts[] = {kCFPreferencesAnyHost, kCFPreferencesCurrentHost};
    CFPropertyListRef previous[] = {NULL, NULL};
    BOOL result = NO;
    for (int i = 0; i < 2; i++) {
        if (!ops.sync(ops.context, hosts[i])) {
            *error = @"Could not read the scroll direction preferences.";
            goto cleanup;
        }
        previous[i] = ops.read(ops.context, hosts[i]);
        if (previous[i] != NULL && CFGetTypeID(previous[i]) != CFBooleanGetTypeID()) {
            *error = @"A scroll direction preference has an unexpected type. No changes were made.";
            goto cleanup;
        }
    }

    *natural = previous[0] == NULL ? NO : !CFBooleanGetValue(previous[0]);
    CFPropertyListRef next = *natural ? kCFBooleanTrue : kCFBooleanFalse;
    BOOL saved = writeAndVerify(ops, hosts[0], next);
    if (saved) saved = writeAndVerify(ops, hosts[1], next);
    NSString *applyError = nil;
    if (saved && ops.apply(ops.context, &applyError)) {
        result = YES;
        goto cleanup;
    }

    BOOL restoredAny = writeAndVerify(ops, hosts[0], previous[0]);
    BOOL restoredCurrent = writeAndVerify(ops, hosts[1], previous[1]);
    NSString *reason = saved ? applyError : @"Could not save the scroll direction preferences.";
    NSString *rollback = restoredAny && restoredCurrent
        ? @"The previous saved preferences were restored, but the active setting may need to be checked in System Settings."
        : @"The previous preferences could not be fully restored. Check scrolling in System Settings.";
    *error = [NSString stringWithFormat:@"%@ %@", reason, rollback];

cleanup:
    for (int i = 0; i < 2; i++) {
        if (previous[i] != NULL) CFRelease(previous[i]);
    }
    return result;
}

static BOOL showDialog(NSString *message, NSString **error) {
    return runProcess(@"/usr/bin/osascript", @[@"-e",
        @"on run argv\n display dialog (item 1 of argv) with title \"Toggle Natural Scrolling\" buttons {\"OK\"} default button \"OK\" with icon caution\nend run",
        message], error);
}

#ifndef TOGGLE_SCROLLING_TEST
int main(void) {
    @autoreleasepool {
        ToggleOperations ops = {NULL, readPreference, writePreference, syncPreference, applyPreference};
        BOOL natural = NO;
        NSString *error = nil;
        if (!toggleScrolling(ops, &natural, &error)) {
            NSString *dialogError = nil;
            if (!showDialog(error, &dialogError)) {
                NSLog(@"%@ %@", error, dialogError);
            }
            return 1;
        }

        NSString *direction = natural ? @"Natural" : @"Traditional";
        NSString *notificationError = nil;
        if (!runProcess(@"/usr/bin/osascript", @[@"-e",
            @"on run argv\n display notification (\"Scrolling → \" & item 1 of argv) with title \"Toggle Natural Scrolling\" sound name \"Funk\"\nend run",
            direction], &notificationError)) {
            NSString *dialogError = nil;
            NSString *message = [NSString stringWithFormat:@"Scrolling changed to %@, but the notification could not be shown. %@", direction, notificationError];
            if (!showDialog(message, &dialogError)) NSLog(@"%@ %@", message, dialogError);
        }
    }
    return 0;
}
#endif
