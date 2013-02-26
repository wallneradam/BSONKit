//
//  BSONKitTests.m
//  BSONKitTests
//
//  Created by Mattias Levin on 6/12/12.
//  Copyright (c) 2012 Wadpam. All rights reserved.
//

#import "BSONKitTests.h"
#import "BSONDecoder.h"

@implementation BSONKitTests


- (void)testDecodeInteger32 {
    char bytes[] = {20,0,0,0,16,105,110,116,101,103,101,114,51,50,0,10,0,0,0,0};
    NSData *bJSON = [NSData dataWithBytes:bytes length:20];
    
    NSError *error = nil;
    NSDictionary *result = [bJSON decodeBSONWithError:&error];
    NSInteger i = [[result objectForKey:@"integer32"] integerValue];
    
    NSLog(@"int32: %i", i); // should be 10
}


- (void)testDecodeInteger64 {
    char bytes[] = {20,0,0,0,18,105,110,116,54,52,0,227,181,79,3,0,0,0,0,0};
    NSData *bJSON = [NSData dataWithBytes:bytes length:20];
    
    NSError *error = nil;
    NSDictionary *result = [bJSON decodeBSONWithError:&error];
    long long i = [[result objectForKey:@"int64"] longLongValue];

    NSLog(@"int64: %lld", i); //should be 55555555
}


@end
