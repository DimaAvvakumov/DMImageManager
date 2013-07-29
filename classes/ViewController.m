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
	// Do any additional setup after loading the view, typically from a nib.
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
    
    NSString *operationIdentifier = [NSString stringWithFormat: @"%p", cell];
    [[DMImageManager defaultManager] cancelBindingByIdentifier: operationIdentifier];
    DMImageOperation *operation = [[DMImageOperation alloc] initWithImagePath:model.imagePath identifer:operationIdentifier andBlock:^(UIImage *image) {
        
        [cell.imageView setImage: image];
        
        [UIView animateWithDuration:0.3 animations:^{
            [cell.imageView setAlpha: 1.0];
        }];
        
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
    
    self.phImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return _phImage;
}

@end
