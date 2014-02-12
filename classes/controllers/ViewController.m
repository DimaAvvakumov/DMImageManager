//
//  ViewController.m
//  DMImageManager
//
//  Created by Dima Avvakumov on 29.07.13.
//  Copyright (c) 2013 Dima Avvakumov. All rights reserved.
//

#define ImageHeight 102.0

#import "ViewController.h"
#import "AppDelegate.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (weak, nonatomic) NSArray *items;
@property (strong, nonatomic) UIImage *phImage;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self placeholderImage];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload {
    [self setTableView:nil];
    [super viewDidUnload];
}

- (void) reloadData {
    AppDelegate *appDelegate = (AppDelegate *) [[UIApplication sharedApplication] delegate];
    self.items = appDelegate.appItems;
    
    [_tableView reloadData];
}

#pragma UITableViewDelegate, UITableViewDataSource

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!_items) return 0;
    
    return [_items count];
}

- (float) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return ImageHeight;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    AppModel *model = [_items objectAtIndex: indexPath.row];
    
    NSString *rowIdentifier = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: rowIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rowIdentifier];
    }
    
    [cell.textLabel setText: model.name];
    [cell.imageView setImage: [self placeholderImage]];
    [cell.imageView setAlpha: 0.0];
    
    NSInteger pieTag = 22;
    SSPieProgressView *pieProgress = (SSPieProgressView *) [cell.contentView viewWithTag: pieTag];
    if (pieProgress == nil) {
        pieProgress = [[SSPieProgressView alloc] initWithFrame: CGRectMake(10.0, 10.0, 40.0, 40.0)];
        pieProgress.tag = 22;
        
        [cell.contentView addSubview:pieProgress];
    }
    pieProgress.progress = 0.0;
    [pieProgress setHidden: NO];
    
    NSString *operationIdentifier = [NSString stringWithFormat: @"%p", cell];
    [[DMImageManager defaultManager] cancelBindingByIdentifier: operationIdentifier];
    
    DMImageOperation *operation = [[DMImageOperation alloc] initWithImagePath:model.imagePath identifer:operationIdentifier andBlock:^(UIImage *image) {
        
        [cell.imageView setImage: image];
        [pieProgress setHidden: YES];
        
        [UIView animateWithDuration:0.3 animations:^{
            [cell.imageView setAlpha: 1.0];
        }];
        
    }];
    operation.progressBlock = ^(NSNumber *progress) {
        [pieProgress setProgress: [progress floatValue]];
    };
    operation.processingBlock = ^UIImage*(UIImage *image) {
        UIImage *decodeImage = nil;
        // decodeImage = [image applyLightEffect];
        
        return decodeImage;
    };
    [operation setFailureBlock:^(NSError *error) {
        [cell.imageView setImage: _phImage];
        [cell.imageView setAlpha: 1.0];
        [pieProgress setHidden: YES];
    }];
    [operation setDownloadURL: model.imageURL];
    [operation setThumbSize: CGSizeMake(ImageHeight, ImageHeight)];
    [[DMImageManager defaultManager] addOperation: operation];
    
    return cell;
}

- (UIImage *) placeholderImage {
    if (_phImage) return _phImage;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(ImageHeight, ImageHeight), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, kCGInterpolationNone);
    
    CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
    CGContextFillRect(context, CGRectMake(0.0, 0.0, ImageHeight, ImageHeight));
    
    self.phImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return _phImage;
}

@end
