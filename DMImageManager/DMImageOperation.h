//
//  DMImageOperation.h
//  DMImageManager
//
//  Created by Dima Avvakumov on 29.07.13.
//  Copyright (c) 2012 Dima Avvakumov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFNetworking.h"

typedef void (^DMImageOperationCompetitionBlock)(UIImage *image);

@interface DMImageOperation : NSOperation

@property (assign, nonatomic) CGSize thumbSize;
@property (assign, nonatomic) BOOL cropThumb;

- (id) initWithImagePath: (NSString *) imagePath identifer: (NSString *) identifier andBlock: (DMImageOperationCompetitionBlock) block;

- (NSString *) path;
- (NSString *) identifier;

- (BOOL) imageExist;

- (NSURL *) downloadURL;
- (void) setDownloadURL: (NSURL *) url;

+ (CGSize) resize: (CGSize) originalSize toSize: (CGSize) maxSize withCroping: (BOOL) cropImage;

@end
