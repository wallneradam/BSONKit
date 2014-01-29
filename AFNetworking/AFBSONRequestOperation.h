//
//  AFBSONRequestOperation.h
//  Shoptastic
//
//  Created by Wallner Ádám on 2013.02.26..
//  Copyright (c) 2013 Canecom Kft. All rights reserved.
//

#import "AFHTTPRequestOperation.h"

@interface AFBSONRequestOperation : AFHTTPRequestOperation

@property (readonly, nonatomic, strong) id responseBSON;

+ (instancetype)BSONRequestOperationWithRequest:(NSURLRequest *)urlRequest
										success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, id data))success
										failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id data))failure NS_RETURNS_RETAINED  NS_RETURNS_RETAINED;


@end
