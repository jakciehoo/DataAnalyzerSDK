//
//  YRKNetworkHelper.h
//  YRKDataAnalyzer
//
//  Created by jackiehoo on 2019/2/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SuccessBlock)(id responseObject);
typedef void (^FailureBlock)(NSError *error);

@interface YRKNetworkHelper : NSObject

//原生GET网络请求
+ (void)getWithURL:(NSString *)url Params:(NSDictionary *)params success:(SuccessBlock)success failure:(FailureBlock)failure;

+ (void)postWithURL:(NSString *)url records:(NSDictionary *)records success:(SuccessBlock)success failure:(FailureBlock)failure;

@end

NS_ASSUME_NONNULL_END
