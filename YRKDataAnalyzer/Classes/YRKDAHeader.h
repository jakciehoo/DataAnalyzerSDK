//
//  YRKDAHeader.h
//  YRKDataAnalyzer
//
//  Created by jackiehoo on 2019/2/20.
//

#ifndef YRKDAHeader_h
#define YRKDAHeader_h

/**
 * @abstract
 * 网络类型
 *
 * @discussion
 *   YRKDataAnalyzerNetworkTypeNONE - NULL
 *   YRKDataAnalyzerNetworkType2G - 2G
 *   YRKDataAnalyzerNetworkType3G - 3G
 *   YRKDataAnalyzerNetworkType4G - 4G
 *   YRKDataAnalyzerNetworkType5G - 5G
 *   YRKDataAnalyzerNetworkTypeWIFI - WIFI
 *   YRKDataAnalyzerNetworkTypeALL - ALL
 */
typedef NS_OPTIONS(NSInteger, YRKDataAnalyzerNetworkType) {
    YRKDataAnalyzerNetworkTypeNONE      = 0,
    YRKDataAnalyzerNetworkType2G       = 1 << 0,
    YRKDataAnalyzerNetworkType3G       = 1 << 1,
    YRKDataAnalyzerNetworkType4G       = 1 << 2,
    YRKDataAnalyzerNetworkType5G       = 1 << 3,
    YRKDataAnalyzerNetworkTypeWIFI     = 1 << 4,
    YRKDataAnalyzerNetworkTypeALL      = 0xFF,
};

/**
 * @abstract
 * Debug 模式，用于检验数据导入是否正确。该模式下，事件会逐条实时发送，并根据返回值检查
 * 数据导入是否正确。
 *
 * @discussion
 * Debug 模式的具体使用方式，请参考:
 *
 *
 * Debug模式有三种选项:
 *   YRKDataAnalyzerDebugOff - 关闭 DEBUG 模式,默认使用生产环境地址
 *   YRKDataAnalyzerDebugOnly - 打开 DEBUG 模式，但该模式下发送的数据仅用于调试，用于数据校验错误提示开发者，不进行数据导入，不上报数据
 *   YRKDataAnalyzerDebugAndTrack - 打开 DEBUG 模式，用于数据校验错误提示开发者，并提示开发者并将数据导入到 YRKDataAnalyzer 中，默认是用测试环境地址
 */
typedef NS_ENUM(NSInteger, YRKDataAnalyzerDebugMode) {
    YRKDataAnalyzerDebugOff,
    YRKDataAnalyzerDebugOnly,
    YRKDataAnalyzerDebugAndTrack,
};



#endif /* YRKDAHeader_h */
