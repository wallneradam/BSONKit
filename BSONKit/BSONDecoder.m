//
//  BSONDecoder.m
//  BSONDecoder
//
//  Created by Mattias Levin on 6/11/12. Modified by Adam Wallner on 26/02/13.
//  Copyright (c) 2012 Wadpam. All rights reserved.
//  Copyright (c) 2013 Bitbaro Mobile Kft. All rights reserved.
//

#import <objc/runtime.h>
#import "BSONDecoder.h"


// Uncomment the line below to get debug statements
//#define PRINT_DEBUG
// Debug macros
#ifdef PRINT_DEBUG
//#  define DLOG(fmt, ...) NSLog( (@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#  define DLOG(fmt, ...) NSLog( (@"" fmt), ##__VA_ARGS__);
#else
#  define DLOG(...)
#endif
// ALog always displays output regardless of the DEBUG setting
#define ALOG(fmt, ...) NSLog( (@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);


// NSData category
@implementation NSData (BSONDecoder)

- (id)decodeBSONWithError:(NSError **)error {
    return [[BSONDecoder decoder] decode:self withError:error];
}

@end


/**
 * Usable NSNull for BSON results
 * To be able to use NSNull as NSString, NSNumber, NSArray
 */
@implementation BSONNull

static BSONNull *null = nil;

+ (id) allocWithZone: (NSZone*)z {
    return null;
}

+ (id) alloc {
    return null;
}

+ (void) initialize {
    if (null == nil) {
        null = (BSONNull *)NSAllocateObject(self, 0, NSDefaultMallocZone());
    }
}

/**
 * Return an object that can be used as a placeholder in a collection.
 * This method always returns the same object.
 */
+ (BSONNull *)null {
    return null;
}

- (id)autorelease {
    return self;
}

- (id)copyWithZone:(NSZone*)z {
    return self;
}

- (id)copy {
    return self;
}

- (void)dealloc {
    [super dealloc];
}

- (NSString *)description {
    return @"<bsonnull>";
}

- (NSInteger)integerValue {
    return 0;
}

- (int)intValue {
    return 0;
}

- (BOOL)boolValue {
    return NO;
}

- (CGFloat)floatValue {
    return 0;
}

- (NSNumber *)numberValue {
    return nil;
}

- (NSString *)stringValue {
    return nil;
}

- (NSInteger)count {
    return 0;
}

@end


// Private stuff
@interface BSONDecoder () {
    char *pByte;
}

- (BOOL)decodeNextElementWithCompletionBlock:(void (^)(id eventName, id elementValue))block error:(NSError **)error;

- (NSString *)decodeElementName;
- (NSString *)decodeUTF8String;
- (NSDictionary *)decodeDocumentWithError:(NSError **)error;
- (NSArray *)decodeArrayWithError:(NSError **)error;
- (NSData *)decodeBinayWithError:(NSError **)error;
- (double)decodeDouble;
- (NSData *)decodeObjectId;
- (NSArray *)decodeRegularExpression;
- (id)decodeDBPointer;
- (BOOL)decodeBooleanWithError:(NSError **)error;
- (int32_t)decodeInt32;
- (int64_t)decodeInt64;

- (NSError *)parsingErrorWithDescription:(NSString *)format, ...;

@end


// Implementation
@implementation BSONDecoder


// Create a decoder
+ (BSONDecoder *)decoder {
    return [[[BSONDecoder alloc] init] autorelease];
}


// Decode BSON
- (id)decode:(NSData *)source withError:(NSError **)error {

    if (![source length]) {
        // The source was empty, return error
        *error = [self parsingErrorWithDescription:@"The source binary data was empty and could not be decoded"];
        return nil;
    }

    // Get the byte array of the data
    pByte = (char *) [source bytes];

    // Start decoding the document
    return [self decodeDocumentWithError:error];
}


// Decode next element in the byte array
- (BOOL)decodeNextElementWithCompletionBlock:(void (^)(id eventName, id elementValue))block error:(NSError **)error {

    Byte elementType = (Byte) *pByte;
    DLOG(@"Decode element type 0x%x", elementType);

    // Move the current byte pointer forward
    pByte += sizeof(Byte);

    // Skip ahead and get the element name, it will always be a name parameter regardless of element type
    NSString *elementName = [self decodeElementName];

    // Hold the element value
    id elementValue = nil;

    // Match next byte against all supported element types
    switch (elementType) {
        case 0x01:
            // Double
            elementValue = [NSNumber numberWithDouble:[self decodeDouble]];
            break;
        case 0x02:
            // UTF-8 string
            elementValue = [self decodeUTF8String];
            break;
        case 0x03:
            // Embedded document
            elementValue = [self decodeDocumentWithError:error];
            // Embedded documents are ended with 0x00
            pByte++;
            break;
        case 0x04:
            // Array
            elementValue = [self decodeArrayWithError:error];
            // Array objects are alse documents ended with 0x00
            pByte++;
            break;
        case 0x05:
            // Binary data
            elementValue = [self decodeBinayWithError:error];
            break;
        case 0x06:
            // Unidentified - Depricated, do nothing
            elementValue = nil;
            break;
        case 0x07:
            // ObjectId
            elementValue = [self decodeObjectId];
            break;
        case 0x08:
            // Boolean
            elementValue = [NSNumber numberWithBool:[self decodeBooleanWithError:error]];
            break;
        case 0x09:
            // UTC Datetime, UTC milleseconds since Unix epoch
            // Decode the same way as a int64
            elementValue = [NSNumber numberWithLongLong:[self decodeInt64]];
            break;
        case 0x0A:
            // Nil (Null)
            elementValue = [BSONNull null];
            break;
        case 0x0B:
            // Regular expression
            elementValue = [self decodeRegularExpression];
            break;
        case 0x0C:
            // DBPointer - Depricated, do nothing
            // Move the current byte pointer forwards as musch as the element value
            elementValue = [self decodeDBPointer]; // Will always return nil
            break;
        case 0x0D:
            // JavaScript Code
            // Decode it the same way as a string
            elementValue = [self decodeUTF8String];
            break;
        case 0x0E:
            // Symbol.
            // Not really supported in Objective-C. Decode it the same way as a string
            elementValue = [self decodeUTF8String];
            break;
        case 0x0F:
            // JavaScript Code with scope
            assert(@"JavaScript code with scope element type is not supported");
            // TODO
            break;
        case 0x10:
            // 32-bit integer
            elementValue = [NSNumber numberWithInteger:[self decodeInt32]];
            break;
        case 0x11:
            // Timestamp
            // Decode the same way as a int64 but the content has special meaning for MongoDB replication and sharding.
            // Just decode and let higher layers handle any internal symantic
            elementValue = [NSNumber numberWithLongLong:[self decodeInt64]];
            break;
        case 0x12:
            // 64-bit integer
            elementValue = [NSNumber numberWithLongLong:[self decodeInt64]];
            break;
        case 0xFF:
            // Min Key
            assert(@"Min Key element type is not supported");
            // TODO
            break;
        case 0x7F:
            // Max Key
            assert(@"Max Key integer element type is not supported");
            // TODO
            break;
        default:
            // Unsupported element type
            *error = [self parsingErrorWithDescription:@"Unsupported element type 0x%x", elementType];
            break;
    }

    // Check the outcome of the decoding
    if (!*error && elementValue) {
        // No error reported and contains value
        DLOG(@"Decoded element = %@:%@", elementName, elementValue);
        block(elementName, elementValue);
        return YES;
    } else if (!*error && !elementValue) {
        // No element value set but still no error reported, probably a deprecated element.
        // Just continue without setting any value.
        return YES;
    } else {
        // An error was raised, stop the decoding
        return NO;
    }
}


// Get the elemenet name, C string
- (NSString *)decodeElementName {
    NSString *elementName = [NSString stringWithCString:pByte encoding:NSASCIIStringEncoding];
    // Move the current byte pointer forward
    pByte += [elementName length] + 1; // + 1 to get rid of the ending 0x00
    return elementName;
}


// Decode a UTF-8 String
- (NSString *)decodeUTF8String {

    // The first 4 bytes (int32) contains the total length of the string (including the 0x00 end char)
    int32_t length = [self decodeInt32];

    // Read the string
    NSString *string = [[[NSString alloc] initWithBytes:pByte
                                                 length:(NSUInteger) (length - 1)
                                               encoding:NSUTF8StringEncoding] autorelease];

    // Move the current byte pointer forward
    pByte += length;

    return string;
}


// Docode a document
- (NSDictionary *)decodeDocumentWithError:(NSError **)error {
    // BSON subdocument is the same as document
    char *pStart = pByte;

    // The first 4 bytes (int32) contains the total length of the document
    int32_t size = [self decodeInt32];

    // Set up the result dictionary
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    // Continue decoding next element until we reach the end or get an error
    BOOL success = YES;
    while (success && (size - (pByte - pStart) > 1)) {
        success = [self decodeNextElementWithCompletionBlock:^(id elementName, id elementValue) {
            // Set the element value for the name
            [result setObject:elementValue forKey:elementName];
        } error:error];
    }

    if (success)
        // Finished successful decoding
        return result;
    else
        // Finished decoding with error
        return nil;
}


// Decode array
- (NSArray *)decodeArrayWithError:(NSError **)error {
    // An BSON array is like a BSON document but you ignore the element names, only add the element values to the array
    char *pStart = pByte;

    // The first 4 bytes (int32) contains the total length of the array document
    int32_t size = [self decodeInt32];

    // Set up the result Array
    NSMutableArray *result = [NSMutableArray array];

    // Continue decoding next element until we reach the end or get an error
    BOOL success = YES;
    while (success && (size - (pByte - pStart) > 1)) {
        success = [self decodeNextElementWithCompletionBlock:^(id elementName, id elementValue) {
            // Since it is an array only save the value
            [result addObject:elementValue];
        } error:error];
    }

    if (success)
        // Finished successful decoding
        return result;
    else
        // Finished decoding with error
        return nil;
}


// Decode binary data
- (NSData *)decodeBinayWithError:(NSError **)error {

    // The first 4 bytes (int32) contains the total length of the binary data
    int32_t size = [self decodeInt32];

    // The next byte tells us the type of the binary
    Byte binaryType = (Byte) *pByte;
    DLOG(@"Binary type 0x%x", binaryType);

    // Move the current byte pointer forward
    pByte += sizeof(Byte);

    // Hold the result
    NSData *binary = nil;

    switch (binaryType) {
        case 0x00: // Binary/Generic
        case 0x01: // Function
        case 0x03: // UUID
        case 0x05: // MD5
        case 0x80: // User defined
            // All these types are decoded in the same way.
            // Let the higher layer add any logic based on the type
            binary = [NSData dataWithBytes:pByte length:(NSUInteger) size];
            break;
        case 0x02: // Old binary
            // Old binary format that should no longer be used
            // The next 4 bytes is the size of the binary
            size = [self decodeInt32];
            binary = [NSData dataWithBytes:pByte length:(NSUInteger) size];
            break;
        default:
            // Unknown binary type
            *error =
                    [self parsingErrorWithDescription:@"Unsupported binary type 0x%x when decoding a binary array", binaryType];
            break;
    }

    // Move the current byte pointer forward
    pByte += size;

    return binary;
}


// Decode a double, 8 bytes (64-bit IEEE 754 floating point)
- (double)decodeDouble {
    double_t double64;
    memcpy(&double64, pByte, sizeof(double_t));
    // Move the current byte pointer forward
    pByte += sizeof(double_t);
    return double64;
}


// Decode a regular expression
- (NSArray *)decodeRegularExpression {

    // Get the first C string, the regex pattern
    NSString *regexPattern = [NSString stringWithCString:pByte
                                                encoding:NSUTF8StringEncoding];

    // Get the second C string, the regex options
    NSString *regexOptions = [NSString stringWithCString:pByte + [regexPattern length] + 1
                                                encoding:NSUTF8StringEncoding];


    // Move the current byte pointer forward
    pByte += [regexPattern length] + 1 + [regexOptions length] + 1;

    return [NSArray arrayWithObjects:regexPattern, regexOptions, nil];
}


// Decode a DBPointer
// This is deprecated but we need to move the current pointer forward to throw away any element values
- (id)decodeDBPointer {

    // First skip head the string value
    [self decodeUTF8String];

    // Then jump 12 bytes ahead
    pByte += 12;

    // Always return nil
    return nil;
}


// Decode object id. This is a unqique identifier user by MongoBD. Just decode and let higer layer handle it
- (NSData *)decodeObjectId {
    NSData *objectId = [NSData dataWithBytes:pByte length:12];
    // Move the current byte pointer forward
    pByte += 12;
    return objectId;
}


// Decode a boolean value
- (BOOL)decodeBooleanWithError:(NSError **)error {
    Byte value = (Byte) *pByte;
    // Move the current byte pointer forward
    pByte += sizeof(Byte);

    if (value == 0x00)
        return NO;
    else if (value == 0x01)
        return YES;
    else {
        // Invalid value, report error and stop
        *error = [self parsingErrorWithDescription:@"Unsupported boolean value 0x%x", value];
        return NO;
    }
}


// Decode a 32-bit integer
- (int32_t)decodeInt32 {
    int32_t int32;
    memcpy(&int32, pByte, sizeof(int32_t));
    // Move the current byte pointer forward
    pByte += sizeof(int32_t);
    return int32;
}


// Decode a 64-bit integer
- (int64_t)decodeInt64 {
    int64_t int64;
    memcpy(&int64, pByte, sizeof(int64_t));
    // Move the current byte pointer forward
    pByte += sizeof(int64_t);
    return int64;
}


// Format an error message
- (NSError *)parsingErrorWithDescription:(NSString *)format, ... {
    // Create a formatted string from input parameters
    va_list varArgsList;
    va_start(varArgsList, format);
    NSString *formatString = [[[NSString alloc] initWithFormat:format arguments:varArgsList] autorelease];
    va_end(varArgsList);

    ALOG(@"Parsing error with message: %@", formatString);

    // Create the error and store the state
    NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            NSLocalizedDescriptionKey, formatString,
            nil];
    return [NSError errorWithDomain:@"hu.bitbaro.BSONDecoder" code:1 userInfo:errorInfo];
}


@end



