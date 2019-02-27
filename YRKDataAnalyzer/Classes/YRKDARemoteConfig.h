//
//  YRKDARemoteConfig.h
//  YRKDataAnalyzer
//
//  Created by jackiehoo on 2019/2/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YRKDARemoteConfig : NSObject

@property (nonatomic, assign) NSInteger memCount;
@property (nonatomic, assign) NSInteger interval;
@property (nonatomic, assign) NSInteger uploadCount;
@property (nonatomic, assign) NSInteger maxMemCount;
@property (nonatomic, assign) NSInteger maxUploadCount;

+ (instancetype)configWithDict:(NSDictionary *)dict;

- (instancetype)initWithDict:(NSDictionary *)dict;


@end

NS_ASSUME_NONNULL_END
