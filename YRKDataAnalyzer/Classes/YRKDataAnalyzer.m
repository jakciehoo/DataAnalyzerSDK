//
//  YRKDataAnalyzer.m
//  Pods
//
//  Created by jackiehoo on 2019/2/20.
//

#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#include <sys/sysctl.h>

#import <OpenUDID/OpenUDID.h>
#import <JQFMDB/JQFMDB.h>
#import <YYModel/YYModel.h>

#import "YRKDataAnalyzer.h"

#import "YRKLog.h"
#import "NetWorkInfoManager.h"
#import "DeviceInfoManager.h"
#import "YRKReachability.h"
#import "YRKNetworkHelper.h"
#import "JSONUtil.h"
#import "YRKEvent.h"

#define DA_DEBUG 1
#define VERSION @"1.0.0"
#define DBNAME @"com.yiruikecorp.da.sqlite"
#define TABLENAME @"da"

#define TEST_SERVER @"http://test.xiaoban.ren/data/report/api"
#define ONLINE_SERVER @"http://api.xiaoban.ren/data/report/api"



//中国运营商 mcc 标识
static NSString* const CARRIER_CHINA_MCC = @"460";

void *YRKDAQueueTag = &YRKDAQueueTag;


@interface YRKDataAnalyzer ()

@property (nonatomic, strong) dispatch_queue_t serialQueue;

@property (nonatomic, strong) dispatch_queue_t readWriteQueue;

@property (nonatomic, copy) NSString *appId;

@property (nonatomic, copy) NSDictionary *commonParamDict;

@property (nonatomic, assign) int threshold;//控制内存最大数量

@property (nonatomic, copy) NSString *(^userBlock)(void);

@property (nonatomic, copy) NSDictionary *config;

@property (nonatomic, strong) NSMutableArray *dataList;

@property (nonatomic, strong) JQFMDB *db;

@property (nonatomic, strong) NSTimer *timer;//定时器

@property (nonatomic, assign) BOOL sdkSwitch;//SDK控制开关

@property (nonatomic, assign) BOOL enableAccelerate;//加速

/**
 * @proeprty
 *
 * @abstract
 * 当App进入后台时，是否执行flush将数据发送到SensrosAnalytics
 *
 * @discussion
 * 默认值为 YES
 */
@property (nonatomic, assign) BOOL flushBeforeEnterBackground;

@property (nonatomic, assign) YRKDataAnalyzerDebugMode debugMode;//debug模式

@end

@implementation YRKDataAnalyzer


#pragma mark - 初始化

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static YRKDataAnalyzer *sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[YRKDataAnalyzer alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.sdkSwitch = YES;//SDK默认启用
        self.enableAccelerate = NO; //默认不启用加速
        self.flushBeforeEnterBackground = YES; //是否进入后台时上传数据
        
        self.threshold = 5;
        NSString *label = [NSString stringWithFormat:@"com.yiruikecorp.da.serialQueue.%p", self];
        self.serialQueue = dispatch_queue_create([label UTF8String], DISPATCH_QUEUE_SERIAL);
        //Sets the key/value data for the specified dispatch queue.
        //Use this method to associate custom context data with a dispatch queue. Blocks executing on the queue can use the dispatch_get_specific function to retrieve this data while they are running.
        dispatch_queue_set_specific(self.serialQueue, YRKDAQueueTag, &YRKDAQueueTag, NULL);
        
        NSString *readWriteLabel = [NSString stringWithFormat:@"com.yiruikecorp.da.readWriteQueue.%p", self];
        self.readWriteQueue = dispatch_queue_create([readWriteLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        
    }
    return self;
}

- (void)startAnalyzerWithAppId:(NSString *)appId debugMode:(YRKDataAnalyzerDebugMode)debugMode userBlock:(NSString *(^)(void))userBlock {

    if (![appId isKindOfClass:[NSString class]]) {
        NSAssert(![appId isKindOfClass:[NSString class]], @"AppId不能为空");
    }
    
    if (![appId length]) {
        NSAssert(![appId length], @"AppId不能为空");
    }
    
    self.appId = appId;
    self.debugMode = debugMode;
    
    [self enableLog];//开启日志
    
    DALog(@"%@",[NSString stringWithFormat:@"DA initialize time start:%@",@([NSDate date].timeIntervalSince1970)]);

    
    if (userBlock) {
        self.userBlock = userBlock;
    }
    
    //注册监听,顺序放在
    [self setUpListeners];
    
    //创建数据库
    JQFMDB *db = [JQFMDB shareDatabase:DBNAME];
    self.db = db;
    if (![db jq_isExistTable:TABLENAME]) {
        [db jq_createTable:TABLENAME dicOrModel:[YRKEvent class]];
    }
    
    DALog(@"%@" ,[NSString stringWithFormat:@"DA initialize time end:%@", @([NSDate date].timeIntervalSince1970)]);
}

#pragma mark - 获取配置

- (void)getRemoteConfig {
    
    dispatch_async(self.serialQueue, ^{
        DALog(@"getRemoteConfig runs on thread:%@", [NSThread currentThread]);
        @try {
            NSString *configVersion;
            self.config = [[NSUserDefaults standardUserDefaults] objectForKey:@"YRKDASDKConfig"];
            if (self.config) {
                configVersion = self.config[@"confVersion"];
            }
            
            NSString *networkTypeString = [self getNetWorkState];
            YRKDataAnalyzerNetworkType networkType = [self toNetworkType:networkTypeString];
            
            NSString *urlString = [self.serverURL stringByAppendingPathComponent:@"getReportConf"];
            if (urlString == nil || urlString.length == 0 || networkType == YRKDataAnalyzerNetworkTypeNONE) {
                return;
            }
            
            NSDictionary *param = @{@"appId" : self.appId ?: @"", @"appVersion" : [self appVersion] ?: @"", @"sdkVersion" : [self libVersion] ?: @"", @"os" : @"i", @"confVersion" : configVersion ?: @"0"};
            
            __weak typeof(self) weakSelf = self;
            [YRKNetworkHelper getWithURL:urlString Params:param success:^(id  _Nonnull responseObject) {
                if(responseObject) {
                    NSDictionary *data = (NSDictionary *)responseObject;
                    if ([data[@"code"] integerValue] == 200) {
                        if ([data[@"data"] isKindOfClass:[NSDictionary class]]) {
                            weakSelf.config = data[@"data"];
                            [[NSUserDefaults standardUserDefaults] setObject:data[@"data"] ?:@"" forKey:@"YRKDASDKConfig"];
                        }
                    }
                }
            } failure:^(NSError * _Nonnull error) {
                if (error) {
                    
                }
            }];
        } @catch (NSException *exception) {
            
        } @finally {
            
        }
    });
}

#pragma mark - 埋点
- (void)track:(NSString *)event withProperties:(NSDictionary *)properties {
    
    if (!self.sdkSwitch) {
        DALog(@"%@",@"SDK开关关闭");
        return;
    }
    
    if (![event isKindOfClass:[NSString class]]) {
        NSAssert(![event isKindOfClass:[NSString class]], @"event不能为空");
    }
    
    dispatch_async(self.serialQueue, ^{
        
        YRKEvent *eventObj = [[YRKEvent alloc] init];
        eventObj.event = event;
        eventObj.eventTime = @([@([NSDate date].timeIntervalSince1970 * 1000) integerValue]).stringValue;
        if ([properties isKindOfClass:[NSDictionary class]]) {
            eventObj.extendInfo = properties.yy_modelToJSONString;
        }
        
        DALog(@"埋入一条数据%@",eventObj.yy_modelToJSONString);
        
        [self.dataList addObject:eventObj];
        
        if (self.config) {
            self.threshold = [self.config[@"memCount"] intValue];
            if (self.threshold <= 0) {
                self.threshold = 30;
            }
        }
        
        if (self.dataList.count >= self.threshold) {
            NSArray *dataList = [self.dataList copy];
            NSArray *errorIndexs = [self.db jq_insertTable:TABLENAME dicOrModelArray:dataList];
            
            if (errorIndexs.count) {
                DALog(@"埋入数据失败，失败的个数：%@",errorIndexs.count);
            } else {
                [self.dataList removeAllObjects];
            }
        }
    });
    

}

#pragma mark - 缓存数据

#pragma mark - 上报数据

- (void)startFlushTimer {
    
    if (!self.sdkSwitch) {
        DALog(@"%@",@"SDK开关关闭");
        return;
    }
    
    if (!self.config) {
        DADebug(@"配置获取失败，无法开启定时器.");
        return;
    }
    [self stopFlushTimer];
    DADebug(@"starting flush timer.");
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimeInterval interval = [self.config[@"interval"] floatValue];
        if (DA_DEBUG) {
            interval = 5;
        }
        self.timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                      target:self
                                                    selector:@selector(flushBackground)
                                                    userInfo:nil
                                                     repeats:YES];
        [[NSRunLoop currentRunLoop]addTimer:self.timer forMode:NSRunLoopCommonModes];
    });
}

- (void)stopFlushTimer {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.timer) {
            [self.timer invalidate];
        }
        self.timer = nil;
    });
}

- (void)flushBackground {
    dispatch_async(self.serialQueue, ^{
        [self flush];
    });
}

- (void)flush {
    
    if (!self.sdkSwitch) {
        DALog(@"%@",@"DA SDK开关关闭");
    }
    
    if (_serverURL == nil || [_serverURL isEqualToString:@""]) {
        return;
    }
    if (!self.config) {
        DADebug(@"DA配置获取失败，无法上传数据.");
        return;
    }
    
    dispatch_semaphore_t flushSem = dispatch_semaphore_create(0);
    
    NSInteger recordsCount = [self.db jq_tableItemCount:TABLENAME];
    

    if (recordsCount <= 0 && self.dataList.count == 0) {
        DADebug(@"DA缓存中没有数据，无需上传.");
        self.enableAccelerate = NO;//启用加速

        return;
    }
    
    DALog(@"DA缓存数据个数%ld", recordsCount);
    
    NSInteger count = [self.config[@"uploadCount"] integerValue];
    
    if (recordsCount >= [self.config[@"maxMemCount"] integerValue]) {
        self.enableAccelerate = YES;//启用加速
        DALog(@"DA启用加速模式%ld", self.enableAccelerate);
    }
    
    if (self.enableAccelerate) {
        count = [self.config[@"maxUploadCount"] integerValue];
    }
    
    // 判断当前网络类型是否符合同步数据的网络策略
    NSString *networkType = [self getNetWorkState];
    if (!([self toNetworkType:networkType])) {
        return;
    }
    
    NSArray *records = [self.db jq_lookupTable:TABLENAME dicOrModel:[YRKEvent class] whereFormat:[NSString stringWithFormat:@"ORDER BY pkid ASC LIMIT %ld",count]];
    BOOL isAddMem = records.count < count;
    if (isAddMem) {
        NSArray *dataList = [self.dataList copy];
        if (dataList.count) {
            NSMutableArray *newList = [dataList mutableCopy];
            [newList addObjectsFromArray:records];
            records = [newList copy];
        }
    }
    
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    NSMutableDictionary *commonParam = [NSMutableDictionary dictionaryWithCapacity:1];
    NSString *userId = self.userBlock();
    [commonParam setValue:userId ?: @"" forKey:@"userId"];
    [commonParam addEntriesFromDictionary:[self commonParamDict]];
    [data setValue:commonParam forKey:@"commonInfo"];
    [data setValue:records forKey:@"eventInfoList"];
    
    if (self.debugMode == YRKDataAnalyzerDebugOnly) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    
    [YRKNetworkHelper postWithURL:self.serverURL records:data success:^(id  _Nonnull responseObject) {
        NSDictionary *response = responseObject;
        if([response[@"code"] integerValue] == 200) {
//            dispatch_async(weakSelf.serialQueue, ^{
                if (isAddMem) {
                    [weakSelf.dataList removeAllObjects];
                }
                BOOL flag = [weakSelf.db jq_deleteTable:TABLENAME whereFormat:[NSString stringWithFormat:@"WHERE pkid in (SELECT pkid from da ORDER BY pkid ASC LIMIT %ld)", (long)count]];
                if (flag) {
                    DALog(@"DA上报数据成功，并清理缓存数据");
                }
                dispatch_semaphore_signal(flushSem);

//            });

        } else {
            dispatch_semaphore_signal(flushSem);

        }


    } failure:^(NSError * _Nonnull error) {
        dispatch_semaphore_signal(flushSem);

    }];
    
    dispatch_semaphore_wait(flushSem, DISPATCH_TIME_FOREVER);

}

#pragma mark - 监听相关
- (void)setUpListeners {
    if (!self.sdkSwitch) {
        DALog(@"%@",@"DA SDK开关关闭");
    }
    
    // 监听 App 启动或结束事件
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillEnterForeground:)
                               name:UIApplicationWillEnterForegroundNotification
                             object:nil];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidBecomeActive:)
                               name:UIApplicationDidBecomeActiveNotification
                             object:nil];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillResignActive:)
                               name:UIApplicationWillResignActiveNotification
                             object:nil];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationDidEnterBackground:)
                               name:UIApplicationDidEnterBackgroundNotification
                             object:nil];
    
    [notificationCenter addObserver:self
                           selector:@selector(applicationWillTerminateNotification:)
                               name:UIApplicationWillTerminateNotification
                             object:nil];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    
        //获取远程配置
        [self performSelector:@selector(getRemoteConfig) withObject:nil afterDelay:0 inModes:@[NSRunLoopCommonModes,NSDefaultRunLoopMode]];
}

- (void)applicationWillResignActive:(NSNotification *)notification {
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    //取消未发出的请求
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(getRemoteConfig) object:nil];

    //后台任务
    UIApplication *application = UIApplication.sharedApplication;
    __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    // 结束后台任务
    void (^endBackgroundTask)(void) = ^(){
        [application endBackgroundTask:backgroundTaskIdentifier];
        backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    };
    
    backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
        endBackgroundTask();
    }];
    
    if (self.flushBeforeEnterBackground) {
        dispatch_async(self.serialQueue, ^{
            [self flush];
            endBackgroundTask();
        });
    }else {
        dispatch_async(self.serialQueue, ^{
            endBackgroundTask();
        });
    }
}

-(void)applicationWillTerminateNotification:(NSNotification *)notification {
    dispatch_async(self.serialQueue, ^{
    });
}

#pragma mark - 公共参数

- (NSDictionary *)collectAutomaticProperties {
    NSMutableDictionary *p = [NSMutableDictionary dictionary];
    UIDevice *device = [UIDevice currentDevice];
    NSString *deviceModel = [self deviceModel];
    NSString *osVersion = [device systemVersion];
    struct CGSize nativeSize = [UIScreen mainScreen].nativeBounds.size;
    CGFloat scale = [UIScreen mainScreen].scale;
    struct CGSize size = CGSizeMake(nativeSize.width / scale, nativeSize.height / scale);
    
    NSString *openUDID = [[NSUserDefaults standardUserDefaults] stringForKey:@"yrk_d_i_o"];
    if (!openUDID) {
        openUDID = [OpenUDID value] ?: @"";
        [[NSUserDefaults standardUserDefaults] setObject:openUDID forKey:@"yrk_d_i_o"];
    }
    
    NSString *idfa = [self getIDFA];
    NSString *idfv = [self getIDFV];
    
    CTCarrier *carrier = [[[CTTelephonyNetworkInfo alloc] init] subscriberCellularProvider];
    if (carrier != nil) {
        NSString *networkCode = [carrier mobileNetworkCode];
        NSString *countryCode = [carrier mobileCountryCode];
        
        NSString *carrierName = @"4";
        //中国运营商
        if (countryCode && [countryCode isEqualToString:CARRIER_CHINA_MCC]) {
            if (networkCode) {
                //中国移动
                if ([networkCode isEqualToString:@"00"] || [networkCode isEqualToString:@"02"] || [networkCode isEqualToString:@"07"] || [networkCode isEqualToString:@"08"]) {
                    carrierName= @"1";
                }
                //中国联通
                if ([networkCode isEqualToString:@"01"] || [networkCode isEqualToString:@"06"] || [networkCode isEqualToString:@"09"]) {
                    carrierName= @"2";
                }
                //中国电信
                if ([networkCode isEqualToString:@"03"] || [networkCode isEqualToString:@"05"] || [networkCode isEqualToString:@"11"]) {
                    carrierName= @"3";
                } else {
                    carrierName= @"0";
                }
            }
        } else { //国外运营商解析
            //加载当前 bundle
            carrierName = @"4";
        }
        
        if (carrierName != nil) {
            [p setValue:carrierName forKey:@"provider"];
        } else {
            if (carrier.carrierName) {
                if ([carrier.carrierName isEqualToString:@"中国移动"]) {
                    carrierName= @"1";
                } else if ([carrier.carrierName isEqualToString:@"中国联通"]) {
                    carrierName= @"2";
                } else if ([carrier.carrierName isEqualToString:@"中国电信"]) {
                    carrierName= @"3";
                } else {
                    carrierName= @"0";
                }
                [p setValue:carrierName forKey:@"provider"];
            }
        }
    }
    
    // Use setValue semantics to avoid adding keys where value can be nil.
    [p setValue:[self appVersion] forKey:@"appVersion"];
    [p setValue:self.appId forKey:@"appId"];
    [p setValue:osVersion forKey:@"osVersion"];
    [p setValue:[self libVersion] forKey:@"sdkVersion"];
    [p setValue:@"i" forKey:@"os"];
    [p setValue:deviceModel forKey:@"deviceType"];
    [p setValue:openUDID forKey:@"deviceId"];
    [p setValue:openUDID forKey:@"yrkDevId"];
    [p setValue:idfa forKey:@"idfa"];
    [p setValue:idfv forKey:@"idfv"];
    
    NSString *localIP = [NetWorkInfoManager getLocalIPAddress:NO];
    [p setValue:localIP forKey:@"ipv6"];

    NSString *wlanIP = [NetWorkInfoManager getWlanIPAddress];
    [p setValue:wlanIP forKey:@"ip"];
    
    NSString *mac = [[DeviceInfoManager sharedManager] getMacAddress];
    [p setValue:mac forKey:@"mac"];
    
    NSString *resolution = [NSString stringWithFormat:@"%@*%@", @((NSInteger)size.width), @((NSInteger)size.height)];
    [p setValue:resolution forKey:@"resolution"];
    NSString *network = [self getNetWorkState];
    [p setValue:network forKey:@"network"];
    
    if (self.userBlock) {
        NSString *userId = self.userBlock();
        [p setValue:userId forKey:@"userId"];
    }
    
    [p setValue:@"AppStore" forKey:@"channelId"];

    return [p copy];
}

#pragma mark - private method

- (NSString *)deviceModel {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char answer[size];
    sysctlbyname("hw.machine", answer, &size, NULL, 0);
    NSString *results = @(answer);
    return results;
}

- (NSString *)libVersion {
    return VERSION;
}

- (NSString *)appVersion {
    return [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
}

- (NSDictionary *)commonParamDict {
    if (!_commonParamDict) {
        _commonParamDict = [self collectAutomaticProperties];
    }
    return _commonParamDict;
}

- (NSString *)getNetWorkState {
    NSString* network = @"0";
    @try {
        YRKReachability *reachability = [YRKReachability reachabilityForInternetConnection];
        YRKNetworkStatus status = [reachability currentReachabilityStatus];
        
        if (status == YRKReachableViaWiFi) {
            network = @"1";
        } else if (status == YRKReachableViaWWAN) {
            static CTTelephonyNetworkInfo *netinfo = nil;
            if (!netinfo) {
                netinfo = [[CTTelephonyNetworkInfo alloc] init];
            }
            if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyGPRS]) {
                network = @"2";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyEdge]) {
                network = @"2";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyWCDMA]) {
                network = @"3";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSDPA]) {
                network = @"3";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSUPA]) {
                network = @"3";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMA1x]) {
                network = @"3";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORev0]) {
                network = @"3";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevA]) {
                network = @"3";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevB]) {
                network = @"3";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyeHRPD]) {
                network = @"3";
            } else if ([netinfo.currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyLTE]) {
                network = @"4";
            } else if (netinfo.currentRadioAccessTechnology) {
                network = @"9";
            }
            
        } else {
            network = @"0";
        }
    } @catch(NSException *exception) {
        DADebug(@"%@: %@", self, exception);
    }
    return network;
}

- (NSString *)getIDFA {
    NSString *idfa = NULL;
    
    Class ASIdentifierManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (ASIdentifierManagerClass) {
        SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
        id sharedManager = ((id (*)(id, SEL))[ASIdentifierManagerClass methodForSelector:sharedManagerSelector])(ASIdentifierManagerClass, sharedManagerSelector);
        SEL advertisingIdentifierSelector = NSSelectorFromString(@"advertisingIdentifier");
        NSUUID *uuid = ((NSUUID* (*)(id, SEL))[sharedManager methodForSelector:advertisingIdentifierSelector])(sharedManager, advertisingIdentifierSelector);
        idfa = [uuid UUIDString];
        // 在 iOS 10.0 以后，当用户开启限制广告跟踪，advertisingIdentifier 的值将是全零
        // 00000000-0000-0000-0000-000000000000
        if (!idfa || [idfa hasPrefix:@"00000000"]) {
            idfa = NULL;
        }
    }
    return idfa;
}

- (NSString *)getIDFV {
    NSString *idfv = NULL;
    // 没有IDFA，则使用IDFV
    if (!idfv && NSClassFromString(@"UIDevice")) {
        idfv = [[UIDevice currentDevice].identifierForVendor UUIDString];
    }
    return idfv;
}

- (YRKDataAnalyzerNetworkType)toNetworkType:(NSString *)networkType {
    if ([@"0" isEqualToString:networkType]) {
        return YRKDataAnalyzerNetworkTypeNONE;
    } else if ([@"1" isEqualToString:networkType]) {
        return YRKDataAnalyzerNetworkTypeWIFI;
    } else if ([@"2" isEqualToString:networkType]) {
        return YRKDataAnalyzerNetworkType2G;
    }   else if ([@"3" isEqualToString:networkType]) {
        return YRKDataAnalyzerNetworkType3G;
    }   else if ([@"4" isEqualToString:networkType]) {
        return YRKDataAnalyzerNetworkType4G;
    }else if ([@"UNKNOWN" isEqualToString:networkType]) {
        return YRKDataAnalyzerNetworkType5G;
    }
    return YRKDataAnalyzerNetworkTypeNONE;
}

- (NSString *)serverURL {
    if (!_serverURL) {
        if (_debugMode == YRKDataAnalyzerDebugOff) {
            _serverURL = ONLINE_SERVER;
        } else {
            _serverURL = TEST_SERVER;
        }
    }
    return _serverURL;
}

- (NSMutableArray *)dataList {
    if (!_dataList) {
        _dataList = [NSMutableArray array];
    }
    return _dataList;
}

- (void)enableLog {
    BOOL printLog = NO;
    if (self.debugMode != YRKDataAnalyzerDebugOff) {
        printLog = YES;
    }
    [YRKLog enableLog:printLog];
}

- (void)setConfig:(NSDictionary *)config {
    if (_config != config) {
        _config = config;
        _sdkSwitch = [self.config[@"sdkSwitch"] boolValue];
        //开启定时器
        if (_timer == nil || ![_timer isValid]) {
            [self startFlushTimer];
        }
        if (!_sdkSwitch) {//关闭SDK的情况下
            //停止 SDK 的 flushtimer
            [self stopFlushTimer];
            //本地数据上报
            [self flushBackground];
        }
    }
}


@end
