//
//  YRKViewController.m
//  YRKDataAnalyzer
//
//  Created by 胡江华 on 02/20/2019.
//  Copyright (c) 2019 胡江华. All rights reserved.
//

#import "YRKViewController.h"
#import <YRKDataAnalyzer/YRKDataAnalyzer.h>
#import <YRKDataAnalyzer/DeviceInfoManager.h>

@interface YRKViewController ()

@property (weak, nonatomic) IBOutlet UILabel *cupLabel;

@property (nonatomic, strong) NSTimer *timer;
@end

@implementation YRKViewController
- (IBAction)buton1:(UIButton *)sender {
    [[YRKDataAnalyzer sharedInstance] track:@"test" withProperties:@{@"aa": @"bb"}];
}

- (IBAction)button100:(UIButton *)sender {
    
    for (int i = 0; i < 100; i++) {
        [[YRKDataAnalyzer sharedInstance] track:@"test100" withProperties:@{@"aa": @"bb"}];
    }
}

- (IBAction)button50000:(id)sender {
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i < 5000; i++) {
            [[YRKDataAnalyzer sharedInstance] track:@"test50000" withProperties:@{@"aa": @"bb"}];
        }
    });
}
- (IBAction)buttonConcurrent:(id)sender {
    for (int i = 0; i < 50000; i++) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [[YRKDataAnalyzer sharedInstance] track:@"test50000" withProperties:@{@"aa": @"bb", @"index" : @(i)}];
            
        });

    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSString *path = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject].absoluteString;
    
    NSLog(@"***sqlitePath:%@",path);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.timer = [NSTimer scheduledTimerWithTimeInterval:3
                                                      target:self
                                                    selector:@selector(getCPUUsage)
                                                    userInfo:nil
                                                     repeats:YES];
        [[NSRunLoop currentRunLoop]addTimer:self.timer forMode:NSRunLoopCommonModes];
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)getCPUUsage {
    float cupUsage = [[DeviceInfoManager sharedManager] getCPUUsage];
    
    float menUsage = (float)[[DeviceInfoManager sharedManager] getUsedMemory]/ (float)[[DeviceInfoManager sharedManager] getTotalMemory];
    float totalUsage = [[DeviceInfoManager sharedManager] getTotalMemory];
    
    NSString *appSize = [[DeviceInfoManager sharedManager] getApplicationSize];


    self.cupLabel.text = [NSString stringWithFormat:@"cpu使用率：%f%%\n 总内存大小%f，使用内存率:%f%%\n app包大小：%@", cupUsage, totalUsage, menUsage, appSize];
}

@end
