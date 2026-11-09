//
//  GestaltAccess.h
//  GestaltLab
//
//  Reads and writes /private/var/containers/Shared/SystemGroup/
//  systemgroup.com.apple.mobilegestaltcache/Library/Caches/
//  com.apple.MobileGestalt.plist through a worse_query sandbox extension.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GestaltAccess : NSObject

+ (instancetype)shared;

/// Darwin build identifier, e.g. "24A446". Empty when unreadable.
+ (NSString *)currentOSBuild;

/// YES when the currently running OS is one this build targets.
+ (BOOL)isRunningSupportedOS;

/// Acquires the sandbox extension and verifies the plist is read/write.
/// Idempotent: a live lease is reused.
- (BOOL)connectWithError:(NSError **)error;

/// Releases the extension. Safe to call when not connected.
- (void)disconnect;

/// Absolute path of the live plist, or nil when not connected.
@property (nonatomic, readonly, nullable) NSString *plistPath;

/// Reads the live plist without parsing it.
- (nullable NSData *)readGestaltDataWithError:(NSError **)error;

/// Reads and parses the live plist, remembering its on-disk format.
- (nullable NSDictionary *)readGestaltWithError:(NSError **)error;

/// Rewrites the plist in place, preserving inode, ownership and xattrs.
/// Rolls back to the original bytes if the write or verification fails.
- (BOOL)saveGestalt:(NSDictionary *)plist error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
