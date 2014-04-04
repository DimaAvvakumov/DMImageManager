//
//  DMImageManager.m
//  DMImageManager
//
//  Created by Dima Avvakumov on 29.07.13.
//  Copyright (c) 2012 Dima Avvakumov. All rights reserved.
//

#import "DMImageManager.h"
#import "DMImageDownloadOperation.h"

@interface DMImageManager ()

@property (strong, nonatomic) NSOperationQueue *queue;
@property (strong, nonatomic) NSOperationQueue *downloadQueue;

@property (strong, nonatomic) NSMutableDictionary *waitingForDownloadOperation;

@property (strong, nonatomic) NSMutableDictionary *cacheManagers;

@end

@implementation DMImageManager

+ (DMImageManager *) defaultManager {
    
	static DMImageManager *instance = nil;
	if (instance == nil) {
        instance = [[DMImageManager alloc] init];
    }
    return instance;
}

- (id) init {
    self = [super init];
    if (self) {
        self.queue = [[NSOperationQueue alloc] init];
        [_queue setMaxConcurrentOperationCount: 1];
        
        self.downloadQueue = [[NSOperationQueue alloc] init];
        [_downloadQueue setMaxConcurrentOperationCount: 1];
        
        self.waitingForDownloadOperation = [NSMutableDictionary dictionaryWithCapacity: 10];
        
        self.cacheManagers = [NSMutableDictionary dictionaryWithCapacity: 10];
    }
    return self;
}

#pragma mark - Custom methods

- (void) bindImage: (NSString *) path withIdentifier:(NSString *)identifier completition: (void (^)(UIImage *image)) block {
    DMImageOperation *operation = [[DMImageOperation alloc] initWithImagePath: path
                                                                        identifer: identifier
                                                                         andBlock: block];
    [self putOperationToWarmup:operation];
}

- (void) cancelBindingByIdentifier: (NSString *) identifier {
    NSArray *operations = [_queue operations];
    for (int i = 0; i < [operations count]; i++) {
        DMImageOperation *operation = [operations objectAtIndex: i];
        
        if ([[operation identifier] isEqualToString: identifier]) {
            [operation cancel];
        }
    }
    
    operations = [_downloadQueue operations];
    for (int i = 0; i < [operations count]; i++) {
        DMImageDownloadOperation *downloadOperation = [operations objectAtIndex: i];
        NSString *operationKey = [NSString stringWithFormat: @"%p", downloadOperation];
        
        NSMutableSet *operationsList = [_waitingForDownloadOperation objectForKey: operationKey];
        if (operationsList) {
            NSArray *operationArray = [operationsList allObjects];
            for (DMImageOperation *operationItem in operationArray) {
                if ([[operationItem identifier] isEqualToString: identifier]) {
                    [operationsList removeObject:operationItem];
                }
            }
            
            if ([operationsList count] == 0) {
                [_waitingForDownloadOperation removeObjectForKey:operationKey];
                operationsList = nil;
            }
        }
        
        if (operationsList == nil) {
            [downloadOperation cancel];
            
            continue;
        }
    }
}

- (void) addOperation: (DMImageOperation *) operation {
    if (operation.downloadURL == nil) {
        [self putOperationToWarmup:operation];
    } else {
        if ([operation imageExist]) {
            [self putOperationToWarmup:operation];
        } else {
            [self putOperationToDownload: operation];
        }
    }
}

+ (CGSize) resize: (CGSize) originalSize toSize: (CGSize) maxSize withCroping: (BOOL) cropImage {
    return [DMImageOperation resize:originalSize toSize:maxSize withCroping:cropImage];
}

- (DMImageDownloadOperation *) downloadOperationFromQueueByURL: (NSURL *) url {
    NSString *identifier = [url absoluteString];
    
    NSArray *operations = [_downloadQueue operations];
    for (int i = 0; i < [operations count]; i++) {
        DMImageDownloadOperation *operation = [operations objectAtIndex: i];
        
        if ([[operation downloadIdentifier] isEqualToString: identifier]) {
            return operation;
        }
    }
    
    return nil;
}

- (void) putOperationToDownload: (DMImageOperation *) operation {
    NSString *operationKey;
    
    DMImageDownloadOperation *downloadOperation = [self downloadOperationFromQueueByURL: operation.downloadURL];
    if (downloadOperation == nil) {
        downloadOperation = [[DMImageDownloadOperation alloc] initWithImagePath:operation.path andDownloadURL:operation.downloadURL];
        operationKey = [NSString stringWithFormat: @"%p", downloadOperation];
        
        [downloadOperation setCompetitionBlock:^(void) {
            NSMutableSet *operationsList = [_waitingForDownloadOperation objectForKey: operationKey];
            if (operationsList == nil) return;
            
            for (DMImageOperation *operationItem in operationsList) {
                [self putOperationToWarmup:operationItem];
            }
            
            [_waitingForDownloadOperation removeObjectForKey:operationKey];
        }];
        [downloadOperation setProgressBlock:^(NSNumber *progress) {
            NSMutableSet *operationsList = [_waitingForDownloadOperation objectForKey: operationKey];
            if (operationsList == nil) return;
            
            for (DMImageOperation *operationItem in operationsList) {
                if (operationItem.progressBlock) {
                    operationItem.progressBlock( progress );
                }
            }
        }];
        [downloadOperation setFailureBlock:^(NSError *error) {
            NSMutableSet *operationsList = [_waitingForDownloadOperation objectForKey: operationKey];
            if (operationsList == nil) return;
            
            for (DMImageOperation *operationItem in operationsList) {
                if (operationItem.failureBlock) {
                    operationItem.failureBlock( error );
                }
            }
        }];
        
        [_downloadQueue addOperation:downloadOperation];
    } else {
        operationKey = [NSString stringWithFormat: @"%p", downloadOperation];
    }
    
    NSMutableSet *operationsList = [_waitingForDownloadOperation objectForKey: operationKey];
    if (operationsList == nil) {
        operationsList = [NSMutableSet setWithCapacity: 2];
        [_waitingForDownloadOperation setObject: operationsList forKey: operationKey];
    }
    [operationsList addObject: operation];
}

- (void) putOperationToWarmup: (DMImageOperation *) operation {
    if (operation.cacheImage) {
        operation.cacheManager = [self cacheManagerWithName:operation.cacheName];
    }
    
    [_queue addOperation:operation];
}

#pragma mark - Cached methods

- (DMImageCacheManager *) cacheManagerWithName: (NSString *) name {
    DMImageCacheManager *cacheManager = [_cacheManagers objectForKey: name];
    if (cacheManager == nil) {
        cacheManager = [[DMImageCacheManager alloc] init];
        
        [_cacheManagers setObject:cacheManager forKey:name];
    }
    
    return cacheManager;
}

- (void) clearCacheManagerWithName: (NSString *) name {
    DMImageCacheManager *cacheManager = [self cacheManagerWithName: name];
    if (cacheManager) {
        [cacheManager clearCachedImages];
    }
}

- (void) clearAllCacheManagers {
    for (NSString *name in _cacheManagers) {
        DMImageCacheManager *cacheManager = [_cacheManagers objectForKey:name];
        [cacheManager clearCachedImages];
    }
}

@end
