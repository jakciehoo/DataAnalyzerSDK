//
//  YRKViewController.m
//  YRKDataAnalyzer
//
//  Created by 胡江华 on 02/20/2019.
//  Copyright (c) 2019 胡江华. All rights reserved.
//

#import "YRKViewController.h"
#import <YRKDataAnalyzer/YRKDataAnalyzer.h>

@interface YRKViewController ()

@end

@implementation YRKViewController
- (IBAction)buton1:(UIButton *)sender {
    [[YRKDataAnalyzer sharedInstance] track:@"test" withProperties:@{@"aa": @"bb"}];
}

- (IBAction)button100:(UIButton *)sender {
    
    for (int i = 0; i < 100; i++) {
        [[YRKDataAnalyzer sharedInstance] track:@"test" withProperties:@{@"aa": @"bb"}];
    }
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSString *path = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject].absoluteString;
    
    NSLog(@"***sqlitePath:%@",path);

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
