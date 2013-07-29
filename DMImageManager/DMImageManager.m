//
//  DMImageManager.m
//  DMImageManager
//
//  Created by Dima Avvakumov on 29.07.13.
//  Copyright (c) 2012 Dima Avvakumov. All rights reserved.
//

#import "DMImageManager.h"

@interface DMImageManager ()

@property (strong, nonatomic) NSOperationQueue *queue;
@property (strong, nonatomic) NSOperationQueue *downloadQueue;

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
    }
    return self;
}

#pragma mark - Custom methods

- (void) bindImage: (NSString *) path withIdentifier:(NSString *)identifier completition: (void (^)(UIImage *image)) block {
    DMImageOperation *operation = [[DMImageOperation alloc] initWithImagePath: path
                                                                        identifer: identifier
                                                                         andBlock: block];
    [_queue addOperation: operation];
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
        DMImageOperation *operation = [operations objectAtIndex: i];
        
        if ([[operation identifier] isEqualToString: identifier]) {
            [operation cancel];
        }
    }
}

- (void) addOperation: (DMImageOperation *) operation {
    if (operation.downloadURL == nil) {
        [_queue addOperation: operation];
    } else {
        if ([operation imageExist]) {
            [_queue addOperation: operation];
        } else {
            [_downloadQueue addOperation: operation];
        }
    }
}

+ (CGSize) resize: (CGSize) originalSize toSize: (CGSize) maxSize withCroping: (BOOL) cropImage {
    return [DMImageOperation resize:originalSize toSize:maxSize withCroping:cropImage];
}

@end
