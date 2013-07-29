//
//  AppDelegate.h
//  DMImageManager
//
//  Created by Dima Avvakumov on 29.07.13.
//  Copyright (c) 2013 Dima Avvakumov. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) ViewController *viewController;

@property (strong, nonatomic) NSMutableArray *appItems;

@end
