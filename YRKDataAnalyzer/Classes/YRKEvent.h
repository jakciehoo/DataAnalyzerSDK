//
//  YRKEvent.h
//  YRKDataAnalyzer
//
//  Created by jackiehoo on 2019/2/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YRKEvent : NSObject

@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *appVersion;
@property (nonatomic, copy) NSString *event;
@property (nonatomic, copy) NSString *eventTime;
@property (nonatomic, copy) NSString *extendInfo;

@end

NS_ASSUME_NONNULL_END
