//
//  StandardPaths.h
//
//  Version 1.4.2
//
//  Created by Nick Lockwood on 10/11/2011.
//  Copyright (C) 2012 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/StandardPaths
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//


#import "StandardPaths.h"
#import <objc/runtime.h> 
#include <sys/xattr.h>


//workaround for rdar://problem/11017158 crash is iOS5
extern NSString *const NSURLIsExcludedFromBackupKey __attribute__((weak_import));


#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
#define SP_IS_MACOS() 1
#define SP_IS_HD() 1
#define SP_IS_RETINA4() 0
#define SP_SCREEN_SCALE() ([[NSScreen mainScreen] respondsToSelector:@selector(backingScaleFactor)]? [[NSScreen mainScreen] backingScaleFactor]: 1.0f)
#else
#define SP_IS_MACOS() 0
#define SP_IS_HD() (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone || SP_SCREEN_SCALE() > 1.0f)
#define SP_IS_RETINA4() ([UIScreen mainScreen].bounds.size.height == 568.0f)
#define SP_SCREEN_SCALE() ([UIScreen mainScreen].scale)
#endif
#define SP_IS_RETINA() (SP_SCREEN_SCALE() == 2.0f)


static void SP_swizzleInstanceMethod(Class c, SEL original, SEL replacement)
{
    Method a = class_getInstanceMethod(c, original);
    Method b = class_getInstanceMethod(c, replacement);
    if (class_addMethod(c, original, method_getImplementation(b), method_getTypeEncoding(b)))
    {
        class_replaceMethod(c, replacement, method_getImplementation(a), method_getTypeEncoding(a));
    }
    else
    {
        method_exchangeImplementations(a, b);
    }
}

static void SP_swizzleClassMethod(Class c, SEL original, SEL replacement)
{
    Method a = class_getClassMethod(c, original);
    Method b = class_getClassMethod(c, replacement);
    method_exchangeImplementations(a, b);
}


@interface NSString (SP_Private)

- (NSString *)SP_pathExtension;
- (NSString *)SP_stringByAppendingPathExtension:(NSString *)extension;
- (NSString *)SP_stringByDeletingPathExtension;

@end


@implementation NSFileManager (StandardPaths)

- (NSString *)publicDataPath
{
    @synchronized ([NSFileManager class])
    {
        static NSString *path = nil;
        if (!path)
        {
            //user documents folder
            path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
            
            //retain path
            path = [[NSString alloc] initWithString:path];
        }
        return path;
    }
}

- (NSString *)privateDataPath
{
    @synchronized ([NSFileManager class])
    {
        static NSString *path = nil;
        if (!path)
        {
            //application support folder
            path = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
            
#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
            
            //append application name on Mac OS
            NSString *identifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
            path = [path stringByAppendingPathComponent:identifier];
            
#endif
            
            //create the folder if it doesn't exist
            if (![self fileExistsAtPath:path])
            {
                [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            
            //retain path
            path = [[NSString alloc] initWithString:path];
        }
        return path;
    }
}

- (NSString *)cacheDataPath
{
    @synchronized ([NSFileManager class])
    {
        static NSString *path = nil;
        if (!path)
        {
            //cache folder
            path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
            
#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
            
            //append application bundle ID on Mac OS
            NSString *identifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleIdentifierKey];
            path = [path stringByAppendingPathComponent:identifier];
            
#endif
            
            //create the folder if it doesn't exist
            if (![self fileExistsAtPath:path])
            {
                [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
            }
            
            //retain path
            path = [[NSString alloc] initWithString:path];
        }
        return path;
    }
}

- (NSString *)offlineDataPath
{
    static NSString *path = nil;
    if (!path)
    {
        //offline data folder
        path = [[self privateDataPath] stringByAppendingPathComponent:@"Offline Data"];
        
        //create the folder if it doesn't exist
        if (![self fileExistsAtPath:path])
        {
            [self createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        
        if (&NSURLIsExcludedFromBackupKey && [NSURL instancesRespondToSelector:@selector(setResourceValue:forKey:error:)])
        {
            //use iOS 5.1 method to exclude file from backup
            NSURL *URL = [NSURL fileURLWithPath:path isDirectory:YES];
            [URL setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:NULL];
        }
        else   
        {
            //use the iOS 5.0.1 mobile backup flag to exclude file from backp
            u_int8_t b = 1;
            setxattr([path fileSystemRepresentation], "com.apple.MobileBackup", &b, 1, 0, 0);
        }

        //retain path
        path = [[NSString alloc] initWithString:path];
    }
    return path;
}

- (NSString *)temporaryDataPath
{
    static NSString *path = nil;
    if (!path)
    {
        //temporary directory (shouldn't change during app lifetime)
        path = NSTemporaryDirectory();
        
        //apparently NSTemporaryDirectory() can return nil in some cases
        if (!path)
        {
            path = [[self cacheDataPath] stringByAppendingPathComponent:@"Temporary Files"];
        }
        
        //retain path
        path = [[NSString alloc] initWithString:path];
    }
    return path;
}

- (NSString *)resourcePath
{
    static NSString *path = nil;
    if (!path)
    {
        //bundle path
        path = [[NSString alloc] initWithString:[[NSBundle mainBundle] resourcePath]];
    }
    return path;
}

- (NSString *)pathForPublicFile:(NSString *)file
{
	return [[self publicDataPath] stringByAppendingPathComponent:file];
}

- (NSString *)pathForPrivateFile:(NSString *)file
{
    return [[self privateDataPath] stringByAppendingPathComponent:file];
}

- (NSString *)pathForCacheFile:(NSString *)file
{
    return [[self cacheDataPath] stringByAppendingPathComponent:file];
}

- (NSString *)pathForOfflineFile:(NSString *)file
{
    return [[self offlineDataPath] stringByAppendingPathComponent:file];
}

- (NSString *)pathForTemporaryFile:(NSString *)file
{
    return [[self temporaryDataPath] stringByAppendingPathComponent:file];
}

- (NSString *)pathForResource:(NSString *)file
{
    return [[self resourcePath] stringByAppendingPathComponent:file];
}

- (NSString *)normalizedPathForFile:(NSString *)fileOrPath
{
    @synchronized ([NSFileManager class])
    {
        //set up cache
        static NSCache *cache = nil;
        if (cache == nil)
        {
            cache = [[NSCache alloc] init];
        }
        
        //convert to absolute path
        NSString *path = fileOrPath;
        if (![path isAbsolutePath])
        {
            path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:path];
        }
        
        //check cache
        NSString *cacheKey = path;
        BOOL cachable = [path hasPrefix:[[NSBundle mainBundle] resourcePath]];
        if (cachable)
        {
            NSString *_path = [cache objectForKey:cacheKey];
            if (_path)
            {
                return [_path length]? _path: nil;
            }
        }
        
        NSArray *suffixes = [NSArray arrayWithObject:[[path SP_pathExtension] length]? @"": @".png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        {
            //check for Retina4 version
            if (SP_IS_RETINA4())
            {
                suffixes = [suffixes arrayByAddingObject:SPRetina4Suffix];
            }
            
            //check for Retina
            if (SP_IS_RETINA())
            {
                for (NSString *suffix in [suffixes objectEnumerator])
                {
                    suffixes = [suffixes arrayByAddingObject:[suffix stringByAppendingPathSuffix:SPHDSuffix]];
                    suffixes = [suffixes arrayByAddingObject:[suffix stringByAppendingPathSuffix:SPRetinaSuffix]];
                }
            }

            //add iPhone suffixes
            for (NSString *suffix in [suffixes objectEnumerator])
            {
                suffixes = [suffixes arrayByAddingObject:[suffix stringByAppendingPathSuffix:SPPhoneSuffix]];
            }
        }
        else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            //add HD suffix
            suffixes = [suffixes arrayByAddingObject:SPHDSuffix];
            
            //check for Retina
            if (SP_IS_RETINA())
            {
                for (NSString *suffix in [suffixes objectEnumerator])
                {
                    suffixes = [suffixes arrayByAddingObject:[suffix stringByAppendingPathSuffix:SPRetinaSuffix]];
                }
            }
            
            //add iPad suffixes
            for (NSString *suffix in [suffixes objectEnumerator])
            {
                suffixes = [suffixes arrayByAddingObject:[suffix stringByAppendingPathSuffix:SPPadSuffix]];
            }
        }
        else //mac
        {
            //add HD suffix
            suffixes = [suffixes arrayByAddingObject:SPHDSuffix];
            
            //check for HiDPI tiff file
            for (NSString *suffix in [suffixes objectEnumerator])
            {
                NSString *_path = [[[path stringByAppendingPathSuffix:suffix]
                                    stringByDeletingPathExtension]
                                   stringByAppendingPathExtension:@"tiff"];
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:_path])
                {
                    suffixes = [suffixes arrayByAddingObject:[suffix stringByAppendingString:@".tiff"]];
                }
            }
  
            //check for Retina
            if (SP_IS_RETINA())
            {
                for (NSString *suffix in [suffixes objectEnumerator])
                {
                    suffixes = [suffixes arrayByAddingObject:[suffix stringByAppendingPathSuffix:SPRetinaSuffix]];
                }
            }
            
            //add Mac suffixes
            for (NSString *suffix in [suffixes objectEnumerator])
            {
                suffixes = [suffixes arrayByAddingObject:[suffix stringByAppendingPathSuffix:SPDesktopSuffix]];
            }
        }
        
        //try all suffixes
        NSString *_path = nil;
        for (NSString *suffix in [suffixes reverseObjectEnumerator])
        {
            if ([[suffix SP_pathExtension] length])
            {
                _path = [[path stringByDeletingPathExtension] stringByAppendingString:suffix];
            }
            else
            {
                _path = [path stringByAppendingPathSuffix:suffix];
            }
            if ([[NSFileManager defaultManager] fileExistsAtPath:_path])
            {
                break;
            }
            _path = nil;
        }
        
        //add to cache
        if (cachable)
        {
            [cache setObject:_path ?: @"" forKey:cacheKey];
        }
        
        //return path
        return _path;
    }
}

@end


@implementation NSString (StandardPaths)

- (NSString *)SP_pathExtension
{
    NSString *extension = [self pathExtension];
    if ([extension isEqualToString:@"gz"])
    {
        extension = [[self stringByDeletingPathExtension] pathExtension];
        if ([extension length]) return [extension stringByAppendingPathExtension:@"gz"];
        return @"gz";
    }
    return extension;
}

- (NSString *)SP_stringByAppendingPathExtension:(NSString *)extension
{
    return [extension length]? [self stringByAppendingFormat:@".%@", extension]: self;
}

- (NSString *)SP_stringByDeletingPathExtension
{
    NSString *extension = [self SP_pathExtension];
    if ([extension length])
    {
        return [self substringToIndex:[self length] - [extension length] - 1];
    }
    return self;
}

- (NSString *)stringByAppendingPathSuffix:(NSString *)suffix
{
    NSString *extension = [self SP_pathExtension];
    NSString *path = [[self SP_stringByDeletingPathExtension] stringByAppendingString:suffix];
    return [path SP_stringByAppendingPathExtension:extension];
}

- (NSString *)stringByDeletingPathSuffix:(NSString *)suffix
{
    if ([suffix length])
    {
        NSString *extension = [self SP_pathExtension];
        NSString *path = [self SP_stringByDeletingPathExtension];
        if ([path hasSuffix:suffix])
        {
            path = [path substringToIndex:[path length] - [suffix length]];
            return [path SP_stringByAppendingPathExtension:extension];
        }
    }
    return self;
}

- (BOOL)hasPathSuffix:(NSString *)suffix
{
    return [[self SP_stringByDeletingPathExtension] hasSuffix:suffix];
}

- (NSString *)stringByAppendingSuffixForInterfaceIdiom:(UIUserInterfaceIdiom)idiom
{
    NSString *suffix = @"";
    switch (idiom)
    {
        case UIUserInterfaceIdiomPhone:
        {
            suffix = SPPhoneSuffix;
            break;
        }
        case UIUserInterfaceIdiomPad:
        {
            suffix = SPPadSuffix;
            break;
        }
        default:
        {
            suffix = SPDesktopSuffix;
        }
    }
    return [self stringByAppendingPathSuffix:suffix];
}

- (NSString *)stringByAppendingInterfaceIdiomSuffix
{
    NSString *suffix = @"";
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
    {
        suffix = SPPhoneSuffix;
    }
    else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        suffix = SPPadSuffix;
    }
    else
    {
        suffix = SPDesktopSuffix;
    }
    return [self stringByAppendingPathSuffix:suffix];
}

- (NSString *)stringByDeletingInterfaceIdiomSuffix
{
    return [self stringByDeletingPathSuffix:[self interfaceIdiomSuffix]];
}

- (NSString *)interfaceIdiomSuffix
{
    NSString *path = [self SP_stringByDeletingPathExtension];
    for (NSString *suffix in [NSArray arrayWithObjects:SPPhoneSuffix, SPPadSuffix, SPDesktopSuffix, nil])
    {
        if ([path hasSuffix:suffix]) return suffix;
    }
    return @"";
}

- (UIUserInterfaceIdiom)interfaceIdiom
{
    NSString *suffix = [self interfaceIdiomSuffix];
    if ([suffix isEqualToString:SPPadSuffix])
    {
        return UIUserInterfaceIdiomPad;
    }
    else if ([suffix isEqualToString:SPPhoneSuffix])
    {
        return UIUserInterfaceIdiomPhone;
    }
    return UI_USER_INTERFACE_IDIOM();
}

- (NSString *)stringByAppendingSuffixForScale:(CGFloat)scale
{
    NSString *suffix = [NSString stringWithFormat:@"@%.2gx%@", scale, [self interfaceIdiomSuffix]];
    return [[self stringByDeletingInterfaceIdiomSuffix] stringByAppendingPathSuffix:suffix];
}

- (NSString *)stringByAppendingDeviceScaleSuffix
{
    CGFloat scale = SP_SCREEN_SCALE();
    return (scale > 1.0f)? [self stringByAppendingSuffixForScale:scale]: self;
}

- (NSString *)stringByDeletingScaleSuffix
{
    NSString *scaleSuffix = [self scaleSuffix];
    if ([scaleSuffix length])
    {
        NSString *suffix = [self interfaceIdiomSuffix];
        return [[[self stringByDeletingPathSuffix:suffix]
                 stringByDeletingPathSuffix:scaleSuffix]
                stringByAppendingPathSuffix:suffix];
    }
    return self;
}

- (NSString *)scaleSuffix
{
    NSString *path = [[self SP_stringByDeletingPathExtension] stringByDeletingInterfaceIdiomSuffix];
    if ([path hasSuffix:@"x"])
    {
        NSRange range = [path rangeOfString:@"@" options:NSBackwardsSearch];
        if (range.location != NSNotFound)
        {
            return [path substringFromIndex:range.location];
        }
    }
    return @"";
}

- (BOOL)hasRetinaSuffix
{
    return [[self scaleSuffix] isEqualToString:SPRetinaSuffix];
}

- (NSString *)stringByAppendingHDSuffix
{
    NSString *suffix = [NSString stringWithFormat:@"%@%@%@", SPHDSuffix, [self scaleSuffix], [self interfaceIdiomSuffix]];
    return [[[self stringByDeletingInterfaceIdiomSuffix]
             stringByDeletingScaleSuffix]
            stringByAppendingPathSuffix:suffix];
}

- (NSString *)stringByAppendingHDSuffixIfDeviceIsHD
{
    if (SP_IS_HD())
    {
        return [self stringByAppendingHDSuffix];
    }
    return self;
}

- (NSString *)stringByDeletingHDSuffix
{
    if ([self hasHDSuffix])
    {
        NSString *suffix = [NSString stringWithFormat:@"%@%@", [self scaleSuffix], [self interfaceIdiomSuffix]];
        return [[[self stringByDeletingPathSuffix:suffix]
                 stringByDeletingPathSuffix:SPHDSuffix]
                stringByAppendingPathSuffix:suffix];
    }
    return self;
}

- (BOOL)hasHDSuffix
{
    return [[[self stringByDeletingInterfaceIdiomSuffix] stringByDeletingScaleSuffix] hasPathSuffix:SPHDSuffix];
}

- (NSString *)stringByAppendingRetina4Suffix
{
    NSString *suffix = [NSString stringWithFormat:@"%@%@", [self scaleSuffix], [self interfaceIdiomSuffix]];
    return [[self stringByDeletingPathSuffix:suffix]
            stringByAppendingPathSuffix:[SPRetina4Suffix stringByAppendingString:suffix]];
}

- (NSString *)stringByAppendingRetina4SuffixIfDeviceIsRetina4
{
    if (SP_IS_RETINA4())
    {
        return [self stringByAppendingRetina4Suffix];
    }
    return self;
}

- (NSString *)stringByDeletingRetina4Suffix
{
    if ([self hasRetina4Suffix])
    {
        NSString *suffix = [NSString stringWithFormat:@"%@%@", [self scaleSuffix], [self interfaceIdiomSuffix]];
        return [[[self stringByDeletingPathSuffix:suffix]
                 stringByDeletingPathSuffix:SPRetina4Suffix]
                stringByAppendingPathSuffix:suffix];
    }
    return self;
}

- (BOOL)hasRetina4Suffix
{
    return [[[self stringByDeletingInterfaceIdiomSuffix] stringByDeletingScaleSuffix] hasPathSuffix:SPRetina4Suffix];
}

- (CGFloat)scaleFromSuffix
{
    NSString *scaleSuffix = [self scaleSuffix];
    if ([scaleSuffix length])
    {
        return [[scaleSuffix substringWithRange:NSMakeRange(1, [scaleSuffix length] - 2)] floatValue];
    }
    else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && [self hasHDSuffix])
    {
        return 2.0f;
    }
    return 1.0f;
}

@end


#if SP_SWIZZLE_ENABLED
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED


@implementation UIImage (StandardPaths)

+ (void)load
{
    SP_swizzleClassMethod(self, @selector(imageWithContentsOfFile:), @selector(SP_imageWithContentsOfFile));
    SP_swizzleClassMethod(self, @selector(imageNamed:), @selector(SP_imageNamed:));
}

+ (NSCache *)SP_imageCache
{
    static NSCache *cache = nil;
    if (cache == nil)
    {
        cache = [[NSCache alloc] init];
    }
    return cache;
}

+ (UIImage *)SP_imageWithContentsOfFile:(NSString *)file
{
    NSString *path = [[NSFileManager defaultManager] normalizedPathForFile:file];
    if ([path hasHDSuffix])
    {
        file = [file stringByAppendingHDSuffix];
        CGFloat scale = [path scaleFromSuffix];
        if (![path hasRetinaSuffix] && scale > 1.0f)
        {
            //need to handle loading ourselves
            NSData *data = [NSData dataWithContentsOfFile:file];
            return [UIImage imageWithData:data scale:scale];
        }
    }
    if ([path hasRetina4Suffix])
    {
        file = [file stringByAppendingRetina4Suffix];
    }
    return [self SP_imageWithContentsOfFile:file];
}

+ (UIImage *)SP_imageNamed:(NSString *)name
{
    NSString *path = [[NSFileManager defaultManager] normalizedPathForFile:name];
    if ([path hasHDSuffix])
    {
        CGFloat scale = [path scaleFromSuffix];
        if (![path hasRetinaSuffix] && scale > 1.0f)
        {
            //need to handle loading & caching ourselves
            NSCache *cache = [self SP_imageCache];
            UIImage *image = [cache objectForKey:name];
            if (!image)
            {
                NSData *data = [NSData dataWithContentsOfFile:path];
                image = [UIImage imageWithData:data scale:scale];
                [cache setObject:image forKey:name];
            }
            return image;
        }
        name = [name stringByAppendingHDSuffix];
    }
    else if ([path hasRetina4Suffix])
    {
        name = [name stringByAppendingRetina4Suffix];
    }
    return [self SP_imageNamed:name];
}

@end


@implementation NSBundle (StandardPaths)

+ (void)load
{
    SP_swizzleInstanceMethod(self, @selector(loadNibNamed:owner:options:), @selector(SP_loadNibNamed:owner:options:));
}

- (NSArray *)SP_loadNibNamed:(NSString *)name owner:(id)owner options:(NSDictionary *)options
{
    NSString *path = [[NSFileManager defaultManager] normalizedPathForFile:name];
    if ([path hasHDSuffix])
    {
        name = [name stringByAppendingHDSuffix];
    }
    else if ([path hasRetina4Suffix])
    {
        name = [name stringByAppendingRetina4Suffix];
    }
    return [self SP_loadNibNamed:name owner:owner options:options];
}

@end


@implementation UINib (StandardPaths)

+ (void)load
{
    SP_swizzleClassMethod(self, @selector(nibWithNibName:bundle:), @selector(SP_nibWithNibName:bundle:));
}

+ (UINib *)SP_nibWithNibName:(NSString *)name bundle:(NSBundle *)bundleOrNil
{
    NSString *path = [[NSFileManager defaultManager] normalizedPathForFile:[name stringByAppendingPathExtension:@"nib"]];
    if ([path hasHDSuffix])
    {
        name = [name stringByAppendingHDSuffix];
    }
    else if ([path hasRetina4Suffix])
    {
        name = [name stringByAppendingRetina4Suffix];
    }
    return [self SP_nibWithNibName:name bundle:bundleOrNil];
}

@end


@implementation UIViewController (StandardPaths)

+ (void)load
{
    SP_swizzleInstanceMethod(self, @selector(loadView), @selector(SP_loadView));
}

- (void)SP_loadView
{
    NSString *name = self.nibName;
    if ([name length])
    {
        NSString *path = [[[self.nibBundle resourcePath] stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"nib"];
        path = [[NSFileManager defaultManager] normalizedPathForFile:path];
        if ([path hasRetina4Suffix])
        {
            name = [name stringByAppendingRetina4Suffix];
        }
        [self.nibBundle loadNibNamed:name owner:self options:nil];
    }
    else
    {
        [self SP_loadView];
    }
}

@end


#endif
#endif