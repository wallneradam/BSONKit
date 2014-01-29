//
//  AFBSONRequestOperation.m
//  Shoptastic
//
//  Created by Wallner Ádám on 2013.02.26..
//  Copyright (c) 2013 Canecom Kft. All rights reserved.
//

#import "AFBSONRequestOperation.h"
#import "BSONDecoder.h"


@interface AFBSONRequestOperation ()

@property(readwrite, nonatomic, strong) id responseBSON;
@property(readwrite, nonatomic, strong) NSError *BSONError;
@end


@implementation AFBSONRequestOperation

@synthesize BSONError = _BSONError;


+ (AFBSONRequestOperation *)BSONRequestOperationWithRequest:(NSURLRequest *)urlRequest
                                        success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, id data))success
                                        failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id data))failure NS_RETURNS_RETAINED  NS_RETURNS_RETAINED {
    AFBSONRequestOperation *requestOperation = [[AFBSONRequestOperation alloc] initWithRequest:urlRequest];
    [requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (success) {
            success(operation.request, operation.response, responseObject);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (failure) {
            failure(operation.request, operation.response, error, [(AFBSONRequestOperation *) operation responseBSON]);
        }
    }];

    [requestOperation release];
    return requestOperation;
}


- (id)responseBSON {
    if (!_responseBSON && [self.responseData length] > 0 && [self isFinished] && !self.BSONError) {
        NSError *error = nil;
        if ([self.responseData length] == 0) {
            self.responseBSON = nil;
        } else {
            self.responseBSON = [self.responseData decodeBSONWithError:&error];
        }
        self.BSONError = error;
    }

    return _responseBSON;
}


- (NSError *)error {
    if (_BSONError) {
        return _BSONError;
    } else {
        return [super error];
    }
}


#pragma mark - AFHTTPRequestOperation

+ (NSSet *)acceptableContentTypes {
    return [NSSet setWithObjects:@"application/bson", nil];
}

- (void)setCompletionBlockWithSuccess:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                              failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreturn-stack-address"
    self.completionBlock = ^{
        if (self.error) {
            if (failure) {
                failure(self, self.error);
            }
        } else {
            id BSON = self.responseBSON;

            if (self.BSONError) {
                if (failure) {
                    failure(self, self.error);
                }
            } else {
                if (success) {
                    success(self, BSON);
                }
            }
        }
    };
#pragma clang diagnostic pop
}


@end
