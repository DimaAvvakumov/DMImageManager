//
//  DMImageDownloadOperation.h
//  DMImageManager
//
//  Created by Dima Avvakumov on 05.12.13.
//  Copyright (c) 2013 Dima Avvakumov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"

typedef void (^DMImageDownloadOperationCompetitionBlock)();
typedef void (^DMImageDownloadOperationProgressBlock)(NSNumber *progress);
typedef void (^DMImageDownloadOperationFailureBlock)(NSError *error);

@interface DMImageDownloadOperation : NSOperation

@property (nonatomic, copy) DMImageDownloadOperationCompetitionBlock competitionBlock;
@property (nonatomic, copy) DMImageDownloadOperationProgressBlock progressBlock;
@property (nonatomic, copy) DMImageDownloadOperationFailureBlock failureBlock;

- (id) initWithImagePath: (NSString *) imagePath andDownloadURL: (NSURL *) downloadURL;

- (NSString *) path;
- (NSURL *) downloadURL;
- (NSString *) downloadIdentifier;

@end
