//
//  DMImageDownloadOperation.m
//  DMImageManager
//
//  Created by Dima Avvakumov on 05.12.13.
//  Copyright (c) 2013 Dima Avvakumov. All rights reserved.
//

#import "DMImageDownloadOperation.h"

@interface DMImageDownloadOperation() {
    BOOL _isReady;
    BOOL _finished;
    BOOL _executing;
    BOOL _isCancelled;
}

@property (strong, nonatomic) NSString *imagePath;
@property (strong, nonatomic) NSURL *imageUrlForDownload;
@property (strong, nonatomic) NSString *imageDownloadIdentifier;

@property (atomic, assign) BOOL whileDownloading;
@property (atomic, assign) BOOL successDownload;
@property (strong, nonatomic) NSError *error;

@end

@implementation DMImageDownloadOperation

- (id) initWithImagePath:(NSString *)imagePath andDownloadURL:(NSURL *)downloadURL {
    self = [super init];
    if (self) {
        _isReady = YES;
        _finished = NO;
        _executing = NO;
        _isCancelled = NO;
        
        self.imagePath = imagePath;
        self.imageUrlForDownload = downloadURL;
        self.imageDownloadIdentifier = [downloadURL absoluteString];
        
        self.whileDownloading = NO;
        self.successDownload = NO;
        
        self.error = nil;
    }
    return self;
}

#pragma mark - Custom methods

- (NSString *) path {
    return _imagePath;
}

- (NSURL *) downloadURL {
    return _imageUrlForDownload;
}

- (NSString *) downloadIdentifier {
    return _imageDownloadIdentifier;
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
        NSLog(@"remove file error: %@", _error);
        
        if (_failureBlock) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                _failureBlock(_error);
            });
        }

        [self finish];
        return;
    }
    
    if (_competitionBlock && !_isCancelled) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            _competitionBlock();
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
    if (_progressBlock) {
        [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
            
            double progress = totalBytesRead / (double) totalBytesExpectedToRead;
            
            _progressBlock([NSNumber numberWithDouble:progress]);
        }];
    }
    
    return operation;
}

@end
