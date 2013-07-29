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

- (void) finish;

- (AFHTTPRequestOperation *) operationForURL: (NSURL *) url;

@end

@implementation DMImageOperation
@synthesize imagePath = _imagePath;
@synthesize block = _block;
@synthesize identifier = _identifier;

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
    
    // check download state
    if ([[NSFileManager defaultManager] fileExistsAtPath: _imagePath] == NO) {
        // file not exist and can`t be downloaded - finish
        if (_imageUrlForDownload == nil) {
            [self finish];
            return;
        }
        
        // try to download
        self.whileDownloading = YES;
        AFHTTPRequestOperation *operation = [self operationForURL: _imageUrlForDownload];
        if (operation == nil) {
            NSLog(@"DMImageManager error: %@", _error);
            
            [self finish];
            return;
        }
        
        [operation start];
//        [operation waitUntilFinished];
        
        while (_whileDownloading) {
            if (_isCancelled) {
                [operation cancel];
                [self finish];
                return;
            }
            if ([operation isCancelled]) {
                break;
            }
            
            [NSThread sleepForTimeInterval: 0.1];
        }
        
        if (_successDownload == NO) {
            DLog(@"remove file error: %@", _error);
            
            [self finish];
            return;
        }
    }
    
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
    
//    CGImageRef originalImage = [image CGImage];
//    if (originalImage == NULL) {
//        [image release];
//        return;
//    }
//    
//    CFDataRef imageData = CGDataProviderCopyData(CGImageGetDataProvider(originalImage));
//    CGDataProviderRef imageDataProvider = CGDataProviderCreateWithCFData(imageData);
//    if (imageData != NULL) {
//        CFRelease(imageData);
//    }
//    CGImageRef imageRef = CGImageCreate(CGImageGetWidth(originalImage),
//                                        CGImageGetHeight(originalImage),
//                                        CGImageGetBitsPerComponent(originalImage),
//                                        CGImageGetBitsPerPixel(originalImage),
//                                        CGImageGetBytesPerRow(originalImage),
//                                        CGImageGetColorSpace(originalImage),
//                                        CGImageGetBitmapInfo(originalImage),
//                                        imageDataProvider,
//                                        CGImageGetDecode(originalImage),
//                                        CGImageGetShouldInterpolate(originalImage),
//                                        CGImageGetRenderingIntent(originalImage));
//    if (imageDataProvider != NULL) {
//        CGDataProviderRelease(imageDataProvider);
//    }
//    
//    UIImage *decodeImage = [[UIImage alloc] initWithCGImage: imageRef];
//    CGImageRelease( imageRef );
//    [image release];
    
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

- (AFHTTPRequestOperation *) operationForURL: (NSURL *) url {
    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                                         timeoutInterval:30.0];
    
    NSString *destPath = _imagePath;
    NSString *folder = [destPath stringByDeletingLastPathComponent];
    
    NSString *tmpPath = [destPath stringByAppendingString: @".tmp"];
    
    NSError *error = nil;
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES
                                                              attributes:nil error:&error];
    if (!success) {
        self.error = error;
        return nil;
    }
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.outputStream = [NSOutputStream outputStreamToFileAtPath: tmpPath append: NO];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSError *error = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:destPath]) {
            if (![[NSFileManager defaultManager] removeItemAtPath:destPath error:&error]) {
                self.error = error;
                
                self.whileDownloading = NO;
                self.successDownload = NO;
                return;
            }
        }
        
        if (![[NSFileManager defaultManager] moveItemAtPath:tmpPath toPath:destPath error:&error]) {
            self.error = error;
            
            self.whileDownloading = NO;
            self.successDownload = NO;
            return;
        }
        
        self.whileDownloading = NO;
        self.successDownload = YES;
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        self.error = error;
        
        self.whileDownloading = NO;
        self.successDownload = NO;
    }];
//    if (_progressBlock) {
//        [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
//            downloadedSize += bytesRead;
//            
//            float progress = downloadedSize / (float) downloadTotalSize;
//            
//            _progressBlock([NSNumber numberWithFloat: progress]);
//        }];
//    }
    
    return operation;
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
    NSString *thumbFile = [[_imagePath lastPathComponent] stringByDeletingPathExtension];
    NSString *thumbFolder = [[_imagePath stringByDeletingLastPathComponent] stringByAppendingString: @"/_thumbs/"];
    float thumbWidth = _thumbSize.width;
    float thumbheight = _thumbSize.height;
    NSString *thumbPath = [NSString stringWithFormat: @"%@%@_%dx%d_%d.%@", thumbFolder, thumbFile, (int) thumbWidth, (int) thumbheight, (_cropThumb) ? 1 : 0, thumbExt];
    
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

@end
