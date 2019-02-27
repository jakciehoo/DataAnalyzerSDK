//
//  YRKDataAnalyzer.h
//  Pods
//
//  Created by jackiehoo on 2019/2/20.
//

#import <Foundation/Foundation.h>
#import "YRKDAHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface YRKDataAnalyzer : NSObject
//单例
+ (instancetype)sharedInstance;
/**
 * @abstract
 * 启动SDK，并初始化
 *
 * @param debugMode 调试模式
 * @param userBlock 动态传入其他参数，如用户数据
 */
- (void)startAnalyzerWithAppId:(NSString *)appId debugMode:(YRKDataAnalyzerDebugMode)debugMode userBlock:(NSString *(^)(void))userBlock;
/**
 * @abstract
 * 通过代码埋点
 *
 * @param event 事件名称
 * @param properties 事件相关数据
 */
- (void)track:(NSString *)event withProperties:(NSDictionary *)properties;
/**
 * @abstract
 * 服务器地址，SDK已经提供默认值，一般无需修改
 */
@property (nonatomic, copy) NSString *serverURL;

@end

NS_ASSUME_NONNULL_END
