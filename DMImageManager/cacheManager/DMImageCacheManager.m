//
//  DMImageCacheManager.m
//  DMImageManager
//
//  Created by Dima Avvakumov on 04.04.14.
//  Copyright (c) 2014 Dima Avvakumov. All rights reserved.
//

#import "DMImageCacheManager.h"

@interface DMImageCacheManager()

@property (strong, nonatomic) NSMutableDictionary *cachedImages;

@end

@implementation DMImageCacheManager

- (id) init {
    self = [super init];
    if (self) {
        self.cachedImages = [NSMutableDictionary dictionaryWithCapacity: 100];
    }
    return self;
}

- (UIImage *) cachedImageWithPath: (NSString *) path {
    return [self cachedImageWithPath:path andSuffix:nil];
}

- (UIImage *) cachedImageWithPath: (NSString *) path andSuffix: (NSString *) suffix {
    NSString *cacheKey = [self cacheKeyForPath:path andSuffix:suffix];
    return [_cachedImages objectForKey: cacheKey];
}

- (void) addToCacheImage: (UIImage *) image withPath: (NSString *) path {
    [self addToCacheImage:image withPath:path andSuffix:nil];
}

- (void) addToCacheImage: (UIImage *) image withPath: (NSString *) path andSuffix: (NSString *) suffix {
    if (image == nil) {
        NSLog(@"try to set nil value in cache images");
        return;
    }
    if (![image isKindOfClass:[UIImage class]]) {
        NSLog(@"try to set not image value in cache images ");
        return;
    }
    
    NSString *cacheKey = [self cacheKeyForPath:path andSuffix:suffix];
    [_cachedImages setObject:image forKey:cacheKey];
}

- (void) clearCachedImages {
    [_cachedImages removeAllObjects];
}

#pragma mark - Key functions

- (NSString *) cacheKeyForPath: (NSString *) path andSuffix: (NSString *) suffix {
    if (suffix == nil) return path;
    
    return [NSString stringWithFormat:@"%@_%@", path, suffix];
}

@end
