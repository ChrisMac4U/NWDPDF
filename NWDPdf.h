//
//  NWDPdf.h
//  PDFSorter
//
//  Created by Chris on 12/10/14.
//  Copyright (c) 2014 WWRD. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NWDPdf : NSObject


@property (nonatomic)       NSUInteger fileLength;
@property (nonatomic)       NSUInteger crossReferenceTableAddress; // The byte where the PDF cross reference table starts
@property (nonatomic)       NSUInteger firstCRAddress;
@property (strong, nonatomic)       NSArray *objectAddresses;
@property (strong, nonatomic)       NSData *PDFData;
@property (strong, nonatomic)       NSURL *documentURL;

- (instancetype) initWithContentsOfPath: (NSString *) pdfFileLocation; 

- (instancetype) initWithNSURL: (NSURL *)srcURL; // Preferred initializer

- (char) findCharAtByte:(NSUInteger)byte;

- (NSUInteger) findAddressForPdfObjectNumber: (NSUInteger) objNumber;

- (char) hexStringByteToInt:(NSString *)str;

- (char) hexCharByteToInt:(char *) encodedChar;

- (NSString *) stringFromHexString:(NSString *)str;

- (UInt8 *)dataAsUInt8;

- (NSString *) findFullStringEncodedAtLocation:(NSUInteger) loc;

- (NSArray *) findOpeningBracketsInObject:(int) objNumber;

- (BOOL) checkCharForOpeningBracketAtLocation: (NSUInteger) loc;

- (NSUInteger) findEncodedCharByteString: (NSString *) startingString
                          StartingAt:(NSUInteger) loc ;


@end
