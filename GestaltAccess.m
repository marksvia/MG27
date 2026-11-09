//
//  GestaltAccess.m
//  GestaltLab
//

#import "GestaltAccess.h"
#import "worse_query.h"

#import <errno.h>
#import <fcntl.h>
#import <sys/sysctl.h>
#import <unistd.h>

static NSString * const kGestaltPlistFileName = @"com.apple.MobileGestalt.plist";

// The path the extension is taken on. /var and /private/var are the same tree;
// the /private form is what the container manager reports.
static NSString * const kGestaltCacheDirectory =
    @"/private/var/containers/Shared/SystemGroup/"
     "systemgroup.com.apple.mobilegestaltcache/Library/Caches";

// App Group that owns the container we use as the symlink host. Must match the
// entitlement and the embedded provisioning profile.
static NSString * const kSymlinkGroup = @"group.2e78c44b8cf32f80.1";

static NSError *GestaltError(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:@"com.gestaltlab.access"
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: message }];
}

static BOOL GestaltCanOpenReadWrite(NSString *path)
{
    int fd = open(path.fileSystemRepresentation, O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return NO;
    close(fd);
    return YES;
}

static BOOL GestaltWriteAll(int fd, NSData *data)
{
    const uint8_t *bytes = data.bytes;
    NSUInteger remaining = data.length;
    while (remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) return NO;
        bytes += written;
        remaining -= (NSUInteger)written;
    }
    return YES;
}

@interface GestaltAccess ()
@property (nonatomic, readwrite, copy, nullable) NSString *plistPath;
@property (nonatomic, assign) NSPropertyListFormat lastReadFormat;
@end

@implementation GestaltAccess
{
    int64_t _sandboxHandle;
}

+ (instancetype)shared
{
    static GestaltAccess *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [GestaltAccess new]; });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init])) { _sandboxHandle = -1; }
    return self;
}

+ (NSString *)currentOSBuild
{
    size_t length = 0;
    if (sysctlbyname("kern.osversion", NULL, &length, NULL, 0) != 0 || length == 0)
        return @"";

    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (sysctlbyname("kern.osversion", data.mutableBytes, &length, NULL, 0) != 0)
        return @"";

    return [NSString stringWithUTF8String:data.bytes] ?: @"";
}

+ (BOOL)isRunningSupportedOS
{
    NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
    // worse_query only. The App Group symlink reaches SystemGroup on iOS 27;
    // the 26 fallback was removed.
    return version.majorVersion == 27;
}

#pragma mark - Connection

- (BOOL)connectWithError:(NSError **)error
{
    if (!GestaltAccess.isRunningSupportedOS) {
        if (error) *error = GestaltError(0, @"This build targets iOS 27.");
        return NO;
    }

    if (self.plistPath.length > 0 && _sandboxHandle > 0 && GestaltCanOpenReadWrite(self.plistPath)) {
        if (error) *error = nil;
        return YES;
    }

    [self disconnect];

    NSString *target = [kGestaltCacheDirectory stringByAppendingPathComponent:kGestaltPlistFileName];

    // The extension is taken on the plist itself first; if the container
    // manager refuses that, the parent Caches directory is used, whose token
    // covers the whole subtree.
    NSArray<NSString *> *candidates = @[
        target,
        kGestaltCacheDirectory,
        [kGestaltCacheDirectory stringByDeletingLastPathComponent],
    ];

    NSMutableArray<NSString *> *failures = [NSMutableArray array];

    // worse_query: App Group symlink. The app replaces its own group
    // container's Library/Caches with a symlink to the target, and the class 7
    // / part 3 query makes containermanagerd resolve it and issue a token for
    // the target path.
    for (NSString *candidate in candidates) {
        for (NSNumber *flagsNum in @[@0x0000008000000000ULL, @0x0000000800000000ULL]) {
            uint64_t flags = flagsNum.unsignedLongLongValue;
            int64_t handle = worse_query_ex(candidate, kSymlinkGroup, 7, 3, flags, false);
            if (handle > 0) {
                _sandboxHandle = handle;
                if (GestaltCanOpenReadWrite(target)) {
                    self.plistPath = target;
                    if (error) *error = nil;
                    return YES;
                }
                // Token landed but the plist is not writable — keep trying.
                worse_query_release(handle);
                _sandboxHandle = -1;
                [failures addObject:[NSString stringWithFormat:@"%@ (not writable)", candidate]];
                continue;
            }
            [failures addObject:[NSString stringWithFormat:@"%@ (code %lld, errno %d)",
                                 candidate, handle, worse_query_last_errno()]];
        }
    }

    if (error) {
        *error = GestaltError(2, [NSString stringWithFormat:
            @"Could not obtain a sandbox extension for the MobileGestalt cache.\n%@",
            [failures componentsJoinedByString:@"\n"]]);
    }
    return NO;
}

- (void)disconnect
{
    if (_sandboxHandle > 0) {
        worse_query_release(_sandboxHandle);
        _sandboxHandle = -1;
    }
    self.plistPath = nil;
}

- (void)dealloc
{
    [self disconnect];
}

#pragma mark - Read / Write

- (NSData *)readGestaltDataWithError:(NSError **)error
{
    if (![self connectWithError:error]) return nil;

    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfFile:self.plistPath
                                          options:NSDataReadingMappedIfSafe
                                            error:&readError];
    if (!data) {
        if (error) *error = readError ?: GestaltError(4, @"Failed to read the plist.");
        return nil;
    }
    if (error) *error = nil;
    return data;
}

- (NSDictionary *)readGestaltWithError:(NSError **)error
{
    NSData *data = [self readGestaltDataWithError:error];
    if (!data) return nil;

    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    NSError *parseError = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data
                                                         options:0
                                                          format:&format
                                                           error:&parseError];
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = parseError ?: GestaltError(5, @"The plist top level is not a dictionary.");
        return nil;
    }
    self.lastReadFormat = format;
    return plist;
}

- (BOOL)saveGestalt:(NSDictionary *)plist error:(NSError **)error
{
    if (![self connectWithError:error]) return NO;
    if (![plist isKindOfClass:NSDictionary.class]) {
        if (error) *error = GestaltError(6, @"The content to save is not a dictionary.");
        return NO;
    }

    NSPropertyListFormat format = self.lastReadFormat;
    if (format != NSPropertyListXMLFormat_v1_0 && format != NSPropertyListBinaryFormat_v1_0)
        format = NSPropertyListBinaryFormat_v1_0;

    NSError *serializeError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:format
                                                             options:0
                                                               error:&serializeError];
    if (!data) {
        if (error) *error = serializeError ?: GestaltError(7, @"Failed to serialize the plist.");
        return NO;
    }

    NSString *targetPath = self.plistPath;
    NSData *original = [NSData dataWithContentsOfFile:targetPath];
    if (!original) {
        if (error) *error = GestaltError(8, @"Failed to read the original plist for rollback.");
        return NO;
    }

    int fd = open(targetPath.fileSystemRepresentation, O_WRONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) {
        if (error) *error = GestaltError(9, [NSString stringWithFormat:
            @"Failed to open the plist (errno=%d).", errno]);
        return NO;
    }

    BOOL wrote = ftruncate(fd, 0) == 0 &&
        lseek(fd, 0, SEEK_SET) == 0 &&
        GestaltWriteAll(fd, data) &&
        fsync(fd) == 0;
    int writeErrno = errno;

    if (!wrote) {
        ftruncate(fd, 0);
        lseek(fd, 0, SEEK_SET);
        GestaltWriteAll(fd, original);
        fsync(fd);
        close(fd);
        if (error) *error = GestaltError(10, [NSString stringWithFormat:
            @"Failed to write the plist (errno=%d).", writeErrno]);
        return NO;
    }
    close(fd);

    NSData *verification = [NSData dataWithContentsOfFile:targetPath];
    if (![verification isEqualToData:data]) {
        if (error) *error = GestaltError(11, @"Post-write verification failed.");
        return NO;
    }

    if (error) *error = nil;
    return YES;
}

@end
