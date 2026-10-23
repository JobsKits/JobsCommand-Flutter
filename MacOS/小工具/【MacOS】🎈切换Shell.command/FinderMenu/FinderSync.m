#import <Cocoa/Cocoa.h>
#import <FinderSync/FinderSync.h>
#import <pwd.h>
#import <unistd.h>

@interface JobsShellFinderSync : FIFinderSync
@end

@implementation JobsShellFinderSync

- (instancetype)init {
    self = [super init];
    if (self) {
        [self updateDirectories:nil];
        NSNotificationCenter *center = NSWorkspace.sharedWorkspace.notificationCenter;
        [center addObserver:self selector:@selector(updateDirectories:)
                       name:NSWorkspaceDidMountNotification object:nil];
        [center addObserver:self selector:@selector(updateDirectories:)
                       name:NSWorkspaceDidUnmountNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
}

- (void)updateDirectories:(NSNotification *)notification {
    // Finder Sync 管理目录及其子目录；不遍历磁盘、不读取目录中的文件。
    NSMutableSet<NSURL *> *roots = [NSMutableSet setWithObject:
        [NSURL fileURLWithPath:@"/" isDirectory:YES]];
    NSArray<NSURL *> *volumes = [NSFileManager.defaultManager
        mountedVolumeURLsIncludingResourceValuesForKeys:nil options:0];
    [roots addObjectsFromArray:volumes ?: @[]];
    // 沙盒内 NSHomeDirectory 指向容器，桌面必须从真实用户主目录解析。
    struct passwd *user = getpwuid(getuid());
    if (user && user->pw_dir) {
        NSString *home = [NSString stringWithUTF8String:user->pw_dir];
        [roots addObject:[NSURL fileURLWithPath:
            [home stringByAppendingPathComponent:@"Desktop"] isDirectory:YES]];
    }
    FIFinderSyncController.defaultController.directoryURLs = roots;
}

- (NSMenu *)menuForMenuKind:(FIMenuKind)menuKind {
    // 仅供桌面、Finder 窗口空白处使用；不依赖是否选中了某个文件。
    if (menuKind != FIMenuKindContextualMenuForContainer) return nil;
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *item = [menu addItemWithTitle:@"🎈 切换 Shell…"
                                      action:@selector(switchShell:)
                               keyEquivalent:@""];
    item.target = self;
    return menu;
}

- (void)switchShell:(id)sender {
    // 从当前扩展定位宿主，避免仓库移动、路径含空格/中文或 URL scheme 冲突。
    NSURL *appURL = NSBundle.mainBundle.bundleURL;
    for (NSUInteger i = 0; i < 3; i++) appURL = appURL.URLByDeletingLastPathComponent;
    NSWorkspaceOpenConfiguration *config = NSWorkspaceOpenConfiguration.configuration;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:appURL configuration:config
        completionHandler:^(NSRunningApplication *app, NSError *error) {
            if (!error) return;
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"无法打开切换 Shell";
                alert.informativeText = error.localizedDescription;
                [alert runModal];
            });
        }];
}
@end
