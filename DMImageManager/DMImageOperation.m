//
//  DMImageOperation.m
//  DMImageManager
//
//  Created by Dima Avvakumov on 29.07.13.
//  Copyright (c) 2012 Dima Avvakumov. All rights reserved.
//

#import "DMImageOperation.h"

@interface DMImageOperation () {
    BOOL _isReady;
    BOOL _finished;
    BOOL _executing;
    BOOL _isCancelled;
}

@property (strong, nonatomic) NSString *imagePath;
@property (strong, nonatomic) NSString *identifier;
@property (strong, nonatomic) NSURL *imageUrlForDownload;
@property (nonatomic, copy) DMImageOperationCompetitionBlock block;
@property (atomic, assign) BOOL whileDownloading;
@property (atomic, assign) BOOL successDownload;
@property (strong, nonatomic) NSError *error;

@end

@implementation DMImageOperation

- (id) initWithImagePath: (NSString *) imagePath identifer:(NSString *)identifier andBlock:(DMImageOperationCompetitionBlock)block {
    self = [super init];
    if (self) {
        _isReady = YES;
        _finished = NO;
        _executing = NO;
        _isCancelled = NO;
        
        self.imagePath = imagePath;
        self.identifier = identifier;
        self.block = block;
        self.imageUrlForDownload = nil;
        
        self.whileDownloading = NO;
        self.successDownload = NO;
        
        self.thumbSize = CGSizeZero;
        self.cropThumb = NO;
    }
    return self;
}

#pragma mark - Custom methods

- (NSString *) path {
    return _imagePath;
}

- (NSString *) identifier {
    return _identifier;
}

- (BOOL) imageExist {
    return [[NSFileManager defaultManager] fileExistsAtPath: _imagePath];
}

- (NSURL *) downloadURL {
    return _imageUrlForDownload;
}

- (void) setDownloadURL:(NSURL *)url {
    [self setImageUrlForDownload: url];
}

#pragma mark - NSOperation methods

- (void) start {
    if (_isCancelled) {
        [self finish];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    // check resize thumb
    NSString *warmupPath = _imagePath;
    if (_thumbSize.width > 0 && _thumbSize.height > 0) {
        warmupPath = [self thumbImagePath];
        
        if (warmupPath == nil) {
            [self finish];
            return;
        }
    }
    
    // warmup image
    UIImage *image = [[UIImage alloc] initWithContentsOfFile: warmupPath];
    if (image == nil) {
        [self finish];
        return;
    }
    
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);

    CGRect imageRect = CGRectMake(0.0, 0.0, image.size.width, image.size.height);
    [image drawInRect: imageRect];

    UIImage *decodeImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (_block && !_isCancelled) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            _block(decodeImage);
        });
    }
//    [decodeImage release];
    
    [self finish];
}

- (void) finish {
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    
    _executing = NO;
    _finished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void) cancel {
    _isCancelled = YES;
}

- (BOOL) isConcurrent {
    return YES;
}

- (BOOL) isReady {
    return _isReady;
}

- (BOOL) isExecuting {
    return _executing;
}

- (BOOL) isFinished {
    return _finished;
}

- (NSString *) thumbImagePath {
    NSString *thumbExt;
    BOOL thumbIsPng;
    if ([[_imagePath pathExtension] isEqualToString: @"png"]) {
        thumbExt = @"png";
        thumbIsPng = YES;
    } else {
        thumbExt = @"jpg";
        thumbIsPng = NO;
    }
    
    // define file name
    NSString *thumbFile = [[_imagePath lastPathComponent] stringByDeletingPathExtension];
    NSString *thumbFolder;
    
    // determinate image in cache or other directory
    NSString *cacheDataPath = [DMImageOperation cacheDataPath];
    NSRange range = [_imagePath rangeOfString: cacheDataPath];
    if (range.location != NSNotFound) {
        thumbFolder = [[_imagePath stringByDeletingLastPathComponent] stringByAppendingString: @"/_thumbs/"];
    } else {
        NSString *bundlePath = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
        NSString *safePath = [[_imagePath stringByDeletingLastPathComponent] stringByReplacingOccurrencesOfString:bundlePath withString:@""];
        
        thumbFolder = [NSString stringWithFormat:@"%@%@/_thumbs/", cacheDataPath, safePath];
    }
    
    float thumbWidth = _thumbSize.width;
    float thumbheight = _thumbSize.height;
    NSString *retinaSuffix = ([DMImageOperation isRetina]) ? @"@2x" : @"";
    NSString *thumbPath = [NSString stringWithFormat: @"%@%@_%dx%d_%d%@.%@", thumbFolder, thumbFile, (int) thumbWidth, (int) thumbheight, (_cropThumb) ? 1 : 0, retinaSuffix, thumbExt];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbPath]) {
        return thumbPath;
    }
    
    // generate thumb folder
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:thumbFolder withIntermediateDirectories:YES
                                                              attributes:nil error:&error];
    if (!success) {
        self.error = error;
        return nil;
    }

    // calculate size
    UIImage *originalImage = [[UIImage alloc] initWithContentsOfFile: _imagePath];
    if (originalImage == nil) return nil;
    
    CGSize thumbNewSize = [DMImageOperation resize:originalImage.size toSize:_thumbSize withCroping:_cropThumb];
    
    // generate new image for this size
    UIGraphicsBeginImageContextWithOptions(_thumbSize, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    
    CGRect imageRect = CGRectZero;
    imageRect.origin.x = roundf( (_thumbSize.width  - thumbNewSize.width)  / 2.0 );
    imageRect.origin.y = roundf( (_thumbSize.height - thumbNewSize.height) / 2.0 );
    imageRect.size = thumbNewSize;
    [originalImage drawInRect: imageRect];
    
    UIImage *thumbImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (thumbIsPng) {
        success = [UIImagePNGRepresentation(thumbImage) writeToFile:thumbPath atomically:YES];
    } else {
        success = [UIImageJPEGRepresentation(thumbImage, 1.0) writeToFile:thumbPath atomically:YES];
    }
    
    if (!success) {
        
        self.error = [NSError errorWithDomain:@"ImageManager" code:99 userInfo:nil];
        return nil;
    }
    
    return thumbPath;
}

+ (CGSize) resize: (CGSize) originalSize toSize: (CGSize) maxSize withCroping: (BOOL) cropImage {
    if (originalSize.width <= maxSize.width && originalSize.height <= maxSize.height) {
        return originalSize;
    }
    
    if (cropImage) {
        if (originalSize.width <= maxSize.width || originalSize.height <= maxSize.height) {
            return originalSize;
        }
        
        float width1  = maxSize.width;
        float height1 = roundf(originalSize.height * maxSize.width / originalSize.width);
        
        float width2  = roundf(originalSize.width * maxSize.height / originalSize.height);
        float height2 = maxSize.height;
        
        if (width1 > width2) {
            return CGSizeMake(width1, height1);
        } else {
            return CGSizeMake(width2, height2);
        }
    } else {
        if (originalSize.width > maxSize.width) {
            float factor = originalSize.width / maxSize.width;
            originalSize.width  = roundf(originalSize.width  / factor);
            originalSize.height = roundf(originalSize.height / factor);
            
            if (originalSize.height > maxSize.height) {
                float factor = originalSize.height / maxSize.height;
                originalSize.width  = roundf(originalSize.width  / factor);
                originalSize.height = roundf(originalSize.height / factor);
            }
        } else {
            float factor = originalSize.height / maxSize.height;
            originalSize.width  = roundf(originalSize.width  / factor);
            originalSize.height = roundf(originalSize.height / factor);
        }
    }
    
    return originalSize;
}

#pragma mark - Inner helper function

+ (BOOL) isRetina {
    static float scale = 0.0;
    
    if (scale == 0.0) {
        if ([[UIScreen mainScreen] respondsToSelector:@selector(displayLinkWithTarget:selector:)] && ([UIScreen mainScreen].scale == 2.0)) {
            scale = 2.0;
        } else {
            scale = 1.0;
        }
    }
    
    return (scale == 2.0) ? YES : NO;
}

+ (NSString *) cacheDataPath {
    static NSString *path = nil;
    if (!path) {
        //cache folder
        path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
        
#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
        
        //append application bundle ID on Mac OS
        NSString *identifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleIdentifierKey];
        path = [path stringByAppendingPathComponent:identifier];
        
#endif
        
        //retain path
        path = [[NSString alloc] initWithString:path];
    }
    return path;
}

@end
