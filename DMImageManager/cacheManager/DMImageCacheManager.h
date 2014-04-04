//
//  DMImageCacheManager.h
//  DMImageManager
//
//  Created by Dima Avvakumov on 04.04.14.
//  Copyright (c) 2014 Dima Avvakumov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DMImageCacheManager : NSObject

- (UIImage *) cachedImageWithPath: (NSString *) path;
- (UIImage *) cachedImageWithPath: (NSString *) path andSuffix: (NSString *) suffix;
- (void) addToCacheImage: (UIImage *) image withPath: (NSString *) path;
- (void) addToCacheImage: (UIImage *) image withPath: (NSString *) path andSuffix: (NSString *) suffix;
- (void) clearCachedImages;

@end
