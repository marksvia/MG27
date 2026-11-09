//
//  worse_query.h
//  MG27
//
//  Port of forcequitOS/worse_query (GPL-3.0) by Taj C (forcequit).
//
//  An app that owns an App Group container replaces the container's
//  Library/Caches with a symlink to an arbitrary path. A container query for
//  class 7 (appGroup) part 3 (Library/Caches) makes containermanagerd resolve
//  that symlink and hand back a sandbox token for the *target* path, which is
//  then consumed to escape the sandbox.
//

#ifndef worse_query_h
#define worse_query_h

#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stdbool.h>

int64_t worse_query(NSString *path, NSString *group, bool alt_flags, bool create_dir);
int64_t worse_query_ex(NSString *path, NSString *group, uint64_t cls, uint64_t part,
                       uint64_t flags, bool create_dir);
int worse_query_last_errno(void);
void worse_query_release(int64_t handle);

#endif
