//
//  AppDelegate.m
//  DMImageManager
//
//  Created by Dima Avvakumov on 29.07.13.
//  Copyright (c) 2013 Dima Avvakumov. All rights reserved.
//

#import "AppDelegate.h"

#import "ViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    NSString *path = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
    
    NSLog(@"%@", path);
    
    [self parseInfo];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.viewController = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Parse

- (void) parseInfo {
    NSURL *url = [NSURL URLWithString: @"http://phobos.apple.com/WebObjects/MZStoreServices.woa/ws/RSS/toppaidapplications/limit=75/json"];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringCacheData
                                         timeoutInterval:30.0];
    
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        
        #pragma mark parse entity
        NSDictionary *feed = [JSON objectForKey: @"feed"];
        if (!feed) return;
        
        NSArray *items = [feed objectForKey: @"entry"];
        if (!items) return;
        
        self.appItems = [NSMutableArray arrayWithCapacity: [items count]];
        
        for (NSDictionary *itemInfo in items) {
            NSString *title = [[itemInfo objectForKey: @"im:name"] objectForKey: @"label"];
            
            NSArray *images = [itemInfo objectForKey: @"im:image"];
            NSString *imageSmallPath = [[images objectAtIndex: 0] objectForKey: @"label"];
            
            NSString *imageBigPath = [imageSmallPath stringByReplacingOccurrencesOfString:@"53x53-50" withString:@"512x512-75"];
            
            NSString *imageSafePath = [imageBigPath stringByReplacingOccurrencesOfString:@"http://" withString:@""];
            NSString *imagePath = [[[NSFileManager defaultManager] cacheDataPath] stringByAppendingPathComponent: imageSafePath];
            
            AppModel *model = [[AppModel alloc] init];
            model.name = title;
            model.imagePath = imagePath;
            model.imageURL = [NSURL URLWithString: imageBigPath];
            
            // add to array
            [_appItems addObject: model];
        }
        
        [_viewController reloadData];
        
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Error" message: @"Pleace, check you internet connection" delegate:self cancelButtonTitle:nil otherButtonTitles:@"Повторить", nil];
        [alert setTag: 1];
        [alert show];
    }];
    
    [operation start];
}

#pragma mark - UIAlertViewDelegate

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1) {
        [self parseInfo];
    }
}

@end
