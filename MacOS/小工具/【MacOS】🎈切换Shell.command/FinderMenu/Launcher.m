#import <Cocoa/Cocoa.h>

@interface JobsShellLauncher : NSObject <NSApplicationDelegate>
@property BOOL opening;
@end

@implementation JobsShellLauncher
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self openSwitcher];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)app hasVisibleWindows:(BOOL)flag {
    [self openSwitcher];
    return NO;
}
- (void)openSwitcher {
    if (self.opening) return;
    self.opening = YES;
    NSURL *script = [NSBundle.mainBundle URLForResource:@"SwitchShell" withExtension:@"command"];
    NSURL *terminal = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:@"com.apple.Terminal"];
    if (!script || !terminal) {
        [self failWithMessage:@"找不到内置脚本或系统终端，请重新安装右键菜单。"];
        return;
    }
    // 由终端直接打开固定的 .command；不拼接 Shell 或 AppleScript 命令。
    [NSWorkspace.sharedWorkspace openURLs:@[script] withApplicationAtURL:terminal
        configuration:NSWorkspaceOpenConfiguration.configuration
        completionHandler:^(NSRunningApplication *app, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) [self failWithMessage:error.localizedDescription];
                else [NSApp terminate:nil];
            });
        }];
}
- (void)failWithMessage:(NSString *)message {
    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"无法打开切换 Shell";
    alert.informativeText = message;
    [alert runModal];
    [NSApp terminate:nil];
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        JobsShellLauncher *delegate = [[JobsShellLauncher alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
