//
//  AppModel.h
//  DMImageManager
//
//  Created by Dima Avvakumov on 29.07.13.
//  Copyright (c) 2013 Dima Avvakumov. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AppModel : NSObject

@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *imagePath;
@property (strong, nonatomic) NSURL *imageURL;

@end
