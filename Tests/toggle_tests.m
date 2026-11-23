#define TOGGLE_SCROLLING_TEST
#import "../Resources/main.m"

typedef struct {
    CFPropertyListRef values[2];
    int syncCount;
    int failSyncAt;
    BOOL failApply;
    int applyCount;
} FakePreferences;

static int hostIndex(CFStringRef host) {
    return CFEqual(host, kCFPreferencesAnyHost) ? 0 : 1;
}

static CFPropertyListRef fakeRead(void *context, CFStringRef host) {
    FakePreferences *fake = context;
    CFPropertyListRef value = fake->values[hostIndex(host)];
    return value == NULL ? NULL : CFRetain(value);
}

static void fakeWrite(void *context, CFStringRef host, CFPropertyListRef value) {
    FakePreferences *fake = context;
    fake->values[hostIndex(host)] = value;
}

static BOOL fakeSync(void *context, CFStringRef host) {
    (void)host;
    FakePreferences *fake = context;
    return ++fake->syncCount != fake->failSyncAt;
}

static BOOL fakeApply(void *context, NSString **error) {
    FakePreferences *fake = context;
    fake->applyCount++;
    if (fake->failApply) {
        *error = @"Applying the setting failed.";
        return NO;
    }
    return YES;
}

static ToggleOperations operations(FakePreferences *fake) {
    return (ToggleOperations){fake, fakeRead, fakeWrite, fakeSync, fakeApply};
}

static void require(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        BOOL natural = NO;
        NSString *error = nil;
        FakePreferences fake = {{kCFBooleanTrue, kCFBooleanFalse}, 0, 0, NO, 0};
        require(toggleScrolling(operations(&fake), &natural, &error), @"natural to traditional");
        require(!natural && fake.values[0] == kCFBooleanFalse && fake.values[1] == kCFBooleanFalse, @"both domains traditional");
        require(toggleScrolling(operations(&fake), &natural, &error), @"traditional to natural");
        require(natural && fake.values[0] == kCFBooleanTrue && fake.values[1] == kCFBooleanTrue, @"both domains natural");

        fake = (FakePreferences){{NULL, NULL}, 0, 0, NO, 0};
        require(toggleScrolling(operations(&fake), &natural, &error) && !natural, @"missing preference uses natural default");

        fake = (FakePreferences){{CFSTR("invalid"), NULL}, 0, 0, NO, 0};
        require(!toggleScrolling(operations(&fake), &natural, &error), @"invalid preference rejected");
        require(fake.applyCount == 0 && CFEqual(fake.values[0], CFSTR("invalid")), @"invalid value unchanged");

        fake = (FakePreferences){{kCFBooleanTrue, NULL}, 0, 4, NO, 0};
        require(!toggleScrolling(operations(&fake), &natural, &error), @"write synchronization failure");
        require(fake.values[0] == kCFBooleanTrue && fake.values[1] == NULL && fake.applyCount == 0, @"write failure restores both values");

        fake = (FakePreferences){{kCFBooleanFalse, kCFBooleanTrue}, 0, 0, YES, 0};
        require(!toggleScrolling(operations(&fake), &natural, &error), @"apply failure");
        require(fake.values[0] == kCFBooleanFalse && fake.values[1] == kCFBooleanTrue, @"apply failure restores both values");
        require([error containsString:@"previous saved preferences were restored"], @"rollback reported");

        fake = (FakePreferences){{kCFBooleanFalse, kCFBooleanTrue}, 0, 5, YES, 0};
        require(!toggleScrolling(operations(&fake), &natural, &error), @"rollback synchronization failure");
        require([error containsString:@"could not be fully restored"], @"incomplete rollback reported");
        NSLog(@"Toggle tests passed");
    }
    return 0;
}
