//
//  YRKLog.m
//  YRKDataAnalyzer
//
//  Created by jackiehoo on 2019/2/20.
//

#import "YRKLog.h"

static BOOL __enableLog__ ;
static dispatch_queue_t __logQueue__ ;

@implementation YRKLog

+ (void)initialize {
    __enableLog__ = NO;
    __logQueue__ = dispatch_queue_create("com.sensorsdata.analytics.log", DISPATCH_QUEUE_SERIAL);
}

+ (BOOL)isLoggerEnabled {
    __block BOOL enable = NO;
    dispatch_sync(__logQueue__, ^{
        enable = __enableLog__;
    });
    return enable;
}

+ (void)enableLog:(BOOL)enableLog {
    dispatch_async(__logQueue__, ^{
        __enableLog__ = enableLog;
    });
}

+ (instancetype)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

+ (void)log:(BOOL)asynchronous
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... {
    
    //iOS 10.x 有可能触发 [[NSString alloc] initWithFormat:format arguments:args]  crash ，不在启用 Log
    NSInteger systemName = UIDevice.currentDevice.systemName.integerValue;
    if (systemName == 10) {
        return;
    }
    @try{
        va_list args;
        va_start(args, format);

        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        [self.sharedInstance log:asynchronous message:message level:level file:file function:function line:line];
        va_end(args);
    } @catch(NSException *e){
        
    }
}

- (void)log:(BOOL)asynchronous
    message:(NSString *)message
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line {
    @try{
        NSString *logMessage = [[NSString alloc]initWithFormat:@"[DALog][%@]  %s [line %lu]    %s %@",[self descriptionForLevel:level],function,(unsigned long)line,[@"" UTF8String],message];
        if ([YRKLog isLoggerEnabled]) {
            NSLog(@"%@",logMessage);
        }
    } @catch(NSException *e){
        
    }
}

-(NSString *)descriptionForLevel:(DALoggerLevel)level {
    NSString *desc = nil;
    switch (level) {
            case DALoggerLevelInfo:
            desc = @"INFO";
            break;
            case DALoggerLevelWarning:
            desc = @"WARN";
            break;
            case DALoggerLevelError:
            desc = @"ERROR";
            break;
        default:
            desc = @"UNKNOW";
            break;
    }
    return desc;
}

- (void)dealloc {
    
}


@end
