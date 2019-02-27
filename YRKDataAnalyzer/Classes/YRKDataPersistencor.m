//
//  YRKDataPersistencor.m
//  YRKDataAnalyzer
//
//  Created by jackiehoo on 2019/2/25.
//

#import "YRKDataPersistencor.h"
#import "JSONUtil.h"
#import <sqlite3.h>
#import "YRKLog.h"

@implementation YRK_DataPersistencor {
    sqlite3 *_database;
    JSONUtil *_jsonUtil;
    NSInteger _messageCount;
    CFMutableDictionaryRef _dbStmtCache;
}

- (void) closeDatabase {
    if (_dbStmtCache) CFRelease(_dbStmtCache);
    _dbStmtCache = NULL;
    
    sqlite3_close(_database);
    sqlite3_shutdown();
    DADebug(@"%@ close database", self);
}

- (void) dealloc {
    [self closeDatabase];
}

- (id)initWithFilePath:(NSString *)filePath {
    self = [super init];
    _jsonUtil = [[JSONUtil alloc] init];
    if (sqlite3_initialize() != SQLITE_OK) {
        DAError(@"failed to initialize SQLite.");
        return nil;
    }
    if (sqlite3_open_v2([filePath UTF8String], &_database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL) == SQLITE_OK ) {
        // 创建一个缓存表
        NSString *_sql = @"create table if not exists dataCache (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, content TEXT)";
        char *errorMsg;
        if (sqlite3_exec(_database, [_sql UTF8String], NULL, NULL, &errorMsg)==SQLITE_OK) {
            DADebug(@"Create dataCache Success.");
        } else {
            DAError(@"Create dataCache Failure %s",errorMsg);
            return nil;
        }
        CFDictionaryKeyCallBacks keyCallbacks = kCFCopyStringDictionaryKeyCallBacks;
        CFDictionaryValueCallBacks valueCallbacks = {0};
        _dbStmtCache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &keyCallbacks, &valueCallbacks);
        
        _messageCount = [self sqliteCount];
        
        DADebug(@"SQLites is opened. current count is %ul", _messageCount);
    } else {
        if (_dbStmtCache) CFRelease(_dbStmtCache);
        _dbStmtCache = NULL;
        
        DAError(@"failed to open SQLite db.");
        return nil;
    }
    return self;
}

- (void)addObejct:(id)obj withType:(NSString *)type {
    UInt64 maxCacheSize = 1000;
    if (_messageCount >= maxCacheSize) {
        DAError(@"touch MAX_MESSAGE_SIZE:%d, try to delete some old events", maxCacheSize);
        BOOL ret = [self removeFirstRecords:100 withType:@"Post"];
        if (ret) {
            _messageCount = [self sqliteCount];
        } else {
            DAError(@"touch MAX_MESSAGE_SIZE:%d, try to delete some old events FAILED", maxCacheSize);
            return;
        }
    }
    NSData* jsonData = [_jsonUtil JSONSerializeObject:obj];
    NSString* query = @"INSERT INTO dataCache(type, content) values(?, ?)";
    sqlite3_stmt *insertStatement = [self dbCacheStmt:query];
    int rc;
    if (insertStatement) {
        sqlite3_bind_text(insertStatement, 1, [type UTF8String], -1, SQLITE_TRANSIENT);
        @try {
            sqlite3_bind_text(insertStatement, 2, [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] UTF8String], -1, SQLITE_TRANSIENT);
        } @catch (NSException *exception) {
            DAError(@"Found NON UTF8 String, ignore");
            return;
        }
        rc = sqlite3_step(insertStatement);
        if(rc != SQLITE_DONE) {
            DAError(@"insert into dataCache fail, rc is %d", rc);
        } else {
            _messageCount ++;
            DADebug(@"insert into dataCache success, current count is %lu", _messageCount);
        }
    } else {
        DAError(@"insert into dataCache error");
    }
}

- (NSArray *)getFirstRecords:(NSUInteger)recordSize withType:(NSString *)type {
    if (_messageCount == 0) {
        return @[];
    }
    NSMutableArray* contentArray = [[NSMutableArray alloc] init];
    NSString* query = [NSString stringWithFormat:@"SELECT content FROM dataCache ORDER BY id ASC LIMIT %lu", (unsigned long)recordSize];
    
    sqlite3_stmt* stmt = [self dbCacheStmt:query];
    if(stmt) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            @try {
                char* jsonChar = (char*)sqlite3_column_text(stmt, 0);
                if (!jsonChar) {
                    DAError(@"Failed to query column_text, error:%s", sqlite3_errmsg(_database));
                    return nil;
                }
                NSData *jsonData = [[NSString stringWithUTF8String:jsonChar] dataUsingEncoding:NSUTF8StringEncoding];
                NSError *err;
                NSMutableDictionary *eventDict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                                 options:NSJSONReadingMutableContainers
                                                                                   error:&err];
                if (!err) {
                    UInt64 time = [[NSDate date] timeIntervalSince1970] * 1000;
                    [eventDict setValue:@(time) forKey:@"_flush_time"];
                }
                [contentArray addObject:[[NSString alloc] initWithData:[_jsonUtil JSONSerializeObject:eventDict] encoding:NSUTF8StringEncoding]];
            } @catch (NSException *exception) {
                DAError(@"Found NON UTF8 String, ignore");
            }
        }
    } else {
        DAError(@"Failed to prepare statement, error:%s", sqlite3_errmsg(_database));
        return nil;
    }
    return [NSArray arrayWithArray:contentArray];
}

- (void) deleteAll {
    NSString* query = @"DELETE FROM dataCache";
    char* errMsg;
    @try {
        if (sqlite3_exec(_database, [query UTF8String], NULL, NULL, &errMsg) != SQLITE_OK) {
            DAError(@"Failed to delete record msg=%s", errMsg);
        }
    } @catch (NSException *exception) {
        DAError(@"Failed to delete record exception=%@",exception);
    }
    
    _messageCount = [self sqliteCount];
}

- (BOOL) removeFirstRecords:(NSUInteger)recordSize withType:(NSString *)type {
    NSUInteger removeSize = MIN(recordSize, _messageCount);
    NSString* query = [NSString stringWithFormat:@"DELETE FROM dataCache WHERE id IN (SELECT id FROM dataCache ORDER BY id ASC LIMIT %lu);", (unsigned long)removeSize];
    char* errMsg;
    @try {
        if (sqlite3_exec(_database, [query UTF8String], NULL, NULL, &errMsg) != SQLITE_OK) {
            DAError(@"Failed to delete record msg=%s", errMsg);
            return NO;
        }
    } @catch (NSException *exception) {
        DAError(@"Failed to delete record exception=%@",exception);
        return NO;
    }
    _messageCount = [self sqliteCount];
    return YES;
}

- (NSInteger) count {
    return _messageCount;
}

- (NSInteger) sqliteCount {
    NSString* query = @"select count(*) from dataCache";
    NSInteger count = 0;
    sqlite3_stmt* statement = [self dbCacheStmt:query];
    if(statement) {
        while (sqlite3_step(statement) == SQLITE_ROW) {
            count = sqlite3_column_int(statement, 0);
        }
    }
    else {
        DAError(@"Failed to prepare statement");
    }
    return count;
}

- (BOOL) vacuum {
#ifdef SENSORS_ANALYTICS_ENABLE_VACUUM
    @try {
        NSString* query = @"VACUUM";
        char* errMsg;
        if (sqlite3_exec(_database, [query UTF8String], NULL, NULL, &errMsg) != SQLITE_OK) {
            DAError(@"Failed to delete record msg=%s", errMsg);
            return NO;
        }
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
#else
    return YES;
#endif
}


- (sqlite3_stmt *) dbCacheStmt:(NSString *)sql {
    if (sql.length == 0 || !_dbStmtCache) return NULL;
    sqlite3_stmt *stmt = (sqlite3_stmt *)CFDictionaryGetValue(_dbStmtCache, (__bridge const void *)(sql));
    if (!stmt) {
        int result = sqlite3_prepare_v2(_database, sql.UTF8String, -1, &stmt, NULL);
        if (result != SQLITE_OK) {
            DAError(@"%s line:%d sqlite stmt prepare error (%d): %s", __FUNCTION__, __LINE__, result, sqlite3_errmsg(_database));
            return NULL;
        }
        CFDictionarySetValue(_dbStmtCache, (__bridge const void *)(sql), stmt);
    } else {
        sqlite3_reset(stmt);
    }
    return stmt;
}

@end
