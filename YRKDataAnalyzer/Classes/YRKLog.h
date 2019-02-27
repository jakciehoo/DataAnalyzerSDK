//
//  YRKLog.h
//  YRKDataAnalyzer
//
//  Created by jackiehoo on 2019/2/20.
//

#import <Foundation/Foundation.h>

#ifndef __YRKDASDK__DALogger__
#define __YRKDASDK__DALogger__

#define DALogLevel(lvl,fmt,...)\
[YRKLog log : YES                                      \
level : lvl                                                  \
file : __FILE__                                            \
function : __PRETTY_FUNCTION__                       \
line : __LINE__                                           \
format : (fmt), ## __VA_ARGS__]

#define DALog(fmt,...)\
DALogLevel(DALoggerLevelInfo,(fmt), ## __VA_ARGS__)

#define DAError DALog
#define DADebug DALog

#endif/* defined(__SensorsAnalyticsSDK__SALogger__) */


typedef NS_ENUM(NSUInteger,DALoggerLevel){
    DALoggerLevelInfo = 1,
    DALoggerLevelWarning ,
    DALoggerLevelError ,
};

NS_ASSUME_NONNULL_BEGIN

@interface YRKLog : NSObject

//@property(class , readonly, strong) YRKLog *sharedInstance;
+ (BOOL)isLoggerEnabled;
+ (void)enableLog:(BOOL)enableLog;
+ (void)log:(BOOL)asynchronous
      level:(NSInteger)level
       file:(const char *)file
   function:(const char *)function
       line:(NSUInteger)line
     format:(NSString *)format, ... ;

@end

NS_ASSUME_NONNULL_END
