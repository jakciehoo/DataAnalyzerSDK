//
//  YRKNetworkHelper.m
//  YRKDataAnalyzer
//
//  Created by jackiehoo on 2019/2/25.
//

#import "YRKNetworkHelper.h"
#import "YRKGzipUtil.h"
#import <YYModel/YYModel.h>

NSString *const ResponseErrorKey = @"com.yiruikecorp.serialization.response.error.response";
NSInteger const Interval = 3;

@implementation YRKNetworkHelper

//原生GET网络请求
+ (void)getWithURL:(NSString *)url Params:(NSDictionary *)params success:(SuccessBlock)success failure:(FailureBlock)failure
{
    //完整URL
    NSString *urlString = [NSString string];
    if (params) {
        //参数拼接url
        NSString *paramStr = [self dealWithParam:params];
        if ([url containsString:@"?"]) {
            urlString = [url stringByAppendingString:paramStr];
        } else {
            urlString = [url stringByAppendingString:[NSString stringWithFormat:@"?%@", paramStr]];
        }
    }else{
        urlString = url;
    }
    //对URL中的中文进行转码
    NSString *pathStr = [urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:pathStr]];
    [request setHTTPMethod:@"GET"];
    request.timeoutInterval = Interval;
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (failure) {
                    failure(error);
                }
            } else {
                if (data) {
                    //利用iOS自带原生JSON解析data数据 保存为Dictionary
                    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                    success(dict);
                    
                }else{
                    
                }
            }
        });
    }];
    
    [task resume];
}

//原生POST请求
+ (void)postWithURL:(NSString *)url records:(NSDictionary *)records success:(SuccessBlock)success failure:(FailureBlock)failure{
    
    @try {
                
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
        [request setHTTPMethod:@"POST"];
        
        NSString *jsonString;
        //NSData *zippedData;
        //NSString *b64String;
        
        jsonString = records.yy_modelToJSONString;
        NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        //zippedData = [YRKGzipUtil gzipData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
        //b64String = [zippedData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn];
        
        //设置请求体
        [request setHTTPBody:jsonData];
        //设置本次请求的数据请求格式
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        // 设置本次请求请求体的长度(因为服务器会根据你这个设定的长度去解析你的请求体中的参数内容)
        [request setValue:[NSString stringWithFormat:@"%ld", jsonData.length] forHTTPHeaderField:@"Content-Length"];
        //设置请求最长时间
        request.timeoutInterval = Interval;
        
        NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
                if (error) {
                    if (failure) {
                        failure(error);
                    }
                } else {
                    if (data) {
                        //利用iOS自带原生JSON解析data数据 保存为Dictionary
                        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
                        success(dict);
                        
                    }else{
                        
                    }
                }

        }];
        [task resume];
        
    } @catch (NSException *exception) {
        
        
    } @finally {
        
    }

}

#pragma mark -- 拼接参数
+ (NSString *)dealWithParam:(NSDictionary *)param
{
    NSArray *allkeys = [param allKeys];
    NSMutableString *result = [NSMutableString string];
    
    for (NSString *key in allkeys) {
        NSString *string = [NSString stringWithFormat:@"%@=%@&", key, param[key]];
        [result appendString:string];
    }
    
    return [result substringToIndex:result.length - 1];
}

#pragma mark
+ (NSString *)showErrorInfoWithStatusCode:(NSInteger)statusCode{
    
    NSString *message = nil;
    switch (statusCode) {
        case 401: {
            
        }
            break;
            
        case 500: {
            message = @"服务器异常！";
        }
            break;
            
        case -1001: {
            message = @"网络请求超时，请稍后重试！";
        }
            break;
            
        case -1002: {
            message = @"不支持的URL！";
        }
            break;
            
        case -1003: {
            message = @"未能找到指定的服务器！";
        }
            break;
            
        case -1004: {
            message = @"服务器连接失败！";
        }
            break;
            
        case -1005: {
            message = @"连接丢失，请稍后重试！";
        }
            break;
            
        case -1009: {
            message = @"互联网连接似乎是离线！";
        }
            break;
            
        case -1012: {
            message = @"操作无法完成！";
        }
            break;
            
        default: {
            message = @"网络请求发生未知错误，请稍后再试！";
        }
            break;
    }
    return message;
    
}

@end
