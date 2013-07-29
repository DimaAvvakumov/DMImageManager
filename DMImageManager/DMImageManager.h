//
//  DMImageManager.h
//  DMImageManager
//
//  Created by Dima Avvakumov on 29.07.13.
//  Copyright (c) 2012 Dima Avvakumov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DMImageOperation.h"

@interface DMImageManager : NSObject

#pragma mark - Custom methods

+ (DMImageManager *) defaultManager;

- (void) bindImage: (NSString *) path withIdentifier: (NSString *) identifier completition: (void (^)(UIImage *image)) block;
- (void) cancelBindingByIdentifier: (NSString *) identifier;

- (void) addOperation: (DMImageOperation *) operation;

+ (CGSize) resize: (CGSize) originalSize toSize: (CGSize) maxSize withCroping: (BOOL) cropImage;

@end
