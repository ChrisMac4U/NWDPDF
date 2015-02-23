//
//  NWDPdf.m
//  PDFSorter
//
//  Created by Chris on 12/10/14.
//  Copyright (c) 2014 WWRD. All rights reserved.
//
// It is expected that you only pass properly formated PDF files to this class.
// It does not perform extensive validation. If the file is invalid, you will
// have an exception thrown and it will not be caught.

#import "NWDPdf.h"

char findCharAtByteFunc(const void * data, unsigned long int dataLength, unsigned long int byte)
{
    
    char c = *((char *) data + byte);
    printf("The character at byte %lu is %c\n", byte, c);
    return c;
}

@interface NWDPdf ()

@property (nonatomic)       NSUInteger eofAddress;
@property (nonatomic)       NSUInteger crossReferenceTableAddressAddress;

- (NSUInteger) findEOFAddress;
- (NSUInteger) findcrossReferenceTableAddress;
- (NSUInteger) findFirstCRAddress;
- (NSArray *)  findAllObjectAddresses;
- (NSUInteger) intFromObjectCR:(char *) objectAddress;


@end

@implementation NWDPdf

#pragma mark - Initializers



- (instancetype) initWithNSURL:(NSURL *)srcURL
{
    // Prefered init type
    self = [super init];
    
    if (self) {
        [self setDocumentURL:srcURL];
        self.PDFData = [[NSData alloc] initWithContentsOfURL:self.documentURL];
        self.fileLength = [self.PDFData length];
        self.eofAddress = [self findEOFAddress];
        self.crossReferenceTableAddress = [self findcrossReferenceTableAddress];
        self.firstCRAddress = [self findFirstCRAddress];
        //NSLog(@"The first cross reference address is %lu", self.firstCRAddress);
        self.objectAddresses = [NSArray arrayWithArray:[self findAllObjectAddresses]];
    }
    return self;
}

- (instancetype) initWithContentsOfPath: (NSString *) pdfFileLocation
{
    _documentURL = [NSURL fileURLWithPath:pdfFileLocation isDirectory:NO];
    
    self = [self initWithNSURL:_documentURL];
    
    return self;
}


- (instancetype) init
{
    [NSException raise:@"Invalid Initializer" format:@"Use initWithNSURL"];
    return nil;
}

- (NSString *) description
{
    NSArray *pathComponents = [self.documentURL pathComponents];
    NSString *fileName = [pathComponents objectAtIndex:[pathComponents count]-1];
    return [NSString stringWithFormat:@"File name: %@", fileName];
}

#pragma mark - Instance Methods

- (NSUInteger) findEOFAddress
{
    // PDF files end with two percent signs then the ASCII letters "EOF".
    // From there we can nagivate back to the previous line, which has
    // an address encoded in ASCII that represents the begining of the
    // look up table for object addresses (also encoded in ASCII).
    
    char percentSign = '%';
    NSUInteger bufferLength = 2;
    for (NSUInteger i = self.fileLength; i > (self.fileLength - 30); i--){
        NSUInteger workingAddress = i-bufferLength;
        unsigned char checkBuffer[bufferLength];
        NSRange checkRange = NSMakeRange(workingAddress, bufferLength);
        [self.PDFData getBytes:&checkBuffer range:checkRange];
        if ((checkBuffer[0] == percentSign) && (checkBuffer[1] == percentSign)){
            return workingAddress;
        }
    }
    return 0;
}

- (NSUInteger) findcrossReferenceTableAddress
{
    if (!self.eofAddress){
        [NSException raise:@"Object Not Found" format:@"EOF address not found in file, file may be corrupt"];
    }
    
    char newLine = '\n';
    NSUInteger bufferLength = 0;
    NSUInteger addressBegin = 0;
    NSUInteger addressEnd = 0;
    NSUInteger i = (self.eofAddress - 1);
    while (i > (self.eofAddress - 20)) {
        char checkCharacter;
        NSRange checkRange = NSMakeRange(i, 1);
        [self.PDFData getBytes:&checkCharacter range:checkRange];
        if ((checkCharacter == newLine) && (!addressEnd)) {
            // saves the address of the last character of the cross reference table address
            addressEnd = i -1;
        }
        else if ((checkCharacter == newLine) && (!addressBegin) && (addressEnd)){
            // Saves the address of the character *before* the cross reference table address begins
            addressBegin = i;
        }
        i--;
    }
    if (addressBegin && addressEnd) {
        bufferLength = addressEnd - addressBegin;
        self.crossReferenceTableAddressAddress = addressBegin;
    }
    else {
        [NSException raise:@"Object Not Found" format:@"EOF address not found in file, file not formatted as expected"];
    }
    
    char crossRefTableAddressRaw[bufferLength+1];
    NSRange addressRange = NSMakeRange(addressBegin +1, bufferLength);
    [self.PDFData getBytes:&crossRefTableAddressRaw range:addressRange];
    NSString *addressAsNSString = [NSString stringWithUTF8String:crossRefTableAddressRaw];
    NSUInteger tableAddress = [addressAsNSString integerValue];
    
    NSLog(@"%@", [self description]);
    NSLog(@"The address of this table is %@", addressAsNSString);
    return tableAddress;
    

}

- (NSUInteger)findFirstCRAddress
{
    if (!self.crossReferenceTableAddress){
        [NSException raise:@"Object Not Found" format:@"Cross Reference address not found in file, file may be corrupt"];
    }
    const size_t startingBlockSize = (sizeof(char) * 10);
    // The first memmory address is always all 10 bytes of 0x30. Initializing that.
    char *firstCRBlock = malloc(startingBlockSize);
    for (int i = 0; i < 10; i++){
        firstCRBlock[i] = '0';
    }
    NSUInteger workingAddress = (self.crossReferenceTableAddress - 1);
    
    char *checkForStart = malloc(startingBlockSize);
    
    // initialize checkForStart to all '\0'
    for (int i = 0; i < 10; i++) {
        checkForStart[i] = '\0';
    }
    // Checking for the first 10 bytes to be all '0'
    do {
        workingAddress++;
        
        NSRange checkRange = NSMakeRange(workingAddress, 10);
        [self.PDFData getBytes:checkForStart range:checkRange];

    }
    while (memcmp(checkForStart, firstCRBlock, startingBlockSize) != 0);
    
    NSLog(@"Trying to find the first byte. The URL is %@ and the first byte starts at %lu", self.documentURL, workingAddress);
    
    free(firstCRBlock);
    free(checkForStart);
    return workingAddress;
}

- (NSUInteger) findAddressForPdfObjectNumber: (NSUInteger) objNumber
{
    return [self.objectAddresses[objNumber] integerValue];
}

- (NSArray *) findAllObjectAddresses
{
    // Stores addresses as NSNumbers in this array;
    // NSNumbers must be unwrapped before using as ints
    NSUInteger startingAddress = self.firstCRAddress;
    NSMutableArray *mutableObjectAddresses = [[NSMutableArray alloc] init];
    char checkChar;
    NSRange checkCharRange = NSMakeRange(startingAddress, 1);
    [self.PDFData getBytes:&checkChar range:checkCharRange];
    NSUInteger counter = 0;
    
    BOOL isAddress = YES;
    do {

        NSUInteger workingAddressLocation = (startingAddress + (counter * 20));
        NSRange newRangeForChecking = NSMakeRange(workingAddressLocation, 1);
        [self.PDFData getBytes:&checkChar range:newRangeForChecking];
        char *addressByte = malloc(10 * sizeof(char));
        
        NSRange addressBuffer = NSMakeRange(workingAddressLocation, 10);
        [self.PDFData getBytes:addressByte range:addressBuffer];
        
        // Check that each character here is numerical
        for (int i = 0; i < 10; i++) {
            if (!(addressByte[i] >= '0' && addressByte[i] <= '9')) {
                isAddress = NO;
                break;
            };
        }
        NSUInteger addressInt = [self intFromObjectCR:addressByte];
        [mutableObjectAddresses addObject:@(addressInt)];
        //NSLog(@"This is object %@ and we found an object at %x", self.documentURL, addressInt);
        free(addressByte);
        
        
        counter += 1;
    }
    while (isAddress);
    
    //NSLog(@"This object is %@, and it we found %@ objects", self.documentURL, @([mutableObjectAddresses count]));
    return [mutableObjectAddresses copy];
}

- (NSUInteger) intFromObjectCR:(char *) objectAddress
{
    NSString *objectAddressAsString = [NSString stringWithUTF8String:(const char*)objectAddress];
    
    return [objectAddressAsString integerValue];
}

- (NSString *) stringFromHexString:(NSString *)str
{
    // Takes a string of hex encoded data and converts to NSString;
    NSMutableData * stringData = [[NSMutableData alloc] init];
    unsigned char wholebyte;
    char byteChar[3] = {'\0', '\0', '\0'};
    if ([str length] % 2 != 0) {
        NSLog(@"The This string has %lu characters. Weird.", [str length]);
        NSLog(@"%@", str);
    }
    for (int i = 0; i < [str length]; i += 2){
        byteChar[0] = [str characterAtIndex:i];
        byteChar[1] = [str characterAtIndex:i + 1];
        wholebyte = (unsigned char)[self hexCharByteToInt:byteChar];
        [stringData appendBytes:&wholebyte length:1];
    }
    
    return [[NSString alloc] initWithData:stringData encoding:NSASCIIStringEncoding];
    
}

- (char) hexStringByteToInt:(NSString *) str
{
    // Returns null if failure
    NSUInteger stringLen = [str length]; // String length must be 2 (two hex characters per byte)
    
    char *chars = malloc(stringLen * sizeof(char));
    NSRange charRange = NSMakeRange(0, 2);
    
    NSData *stringData = [str dataUsingEncoding:NSUTF8StringEncoding];
    [stringData getBytes:chars range:charRange];
    
    // chars should now be a two byte array of '0' to '9', and 'a' to 'f' or 'A' to 'F'
    NSUInteger wholeNumber = 0;
    NSUInteger firstNibble = [self getNSUIntFromEncodedNibble:chars[0]];
    NSUInteger secondNibble = [self getNSUIntFromEncodedNibble:chars[1]];
    
    wholeNumber = ((firstNibble * 0x10) + secondNibble);
    
    free(chars);
    
    char wholeNumberChar = (char) wholeNumber;
    
    return wholeNumberChar;
    
}

- (char) hexCharByteToInt:(char *) twoByteEncodedChar
{
    // Returns null if failure
    NSString *twoByteCharString = [NSString stringWithUTF8String:twoByteEncodedChar];
    return [self hexStringByteToInt:twoByteCharString];
}

- (NSString *) findFullStringEncodedAtLocation:(NSUInteger)loc
{
    NSUInteger endBracketLocation = loc;
    
    char checkForBracket;
    while (checkForBracket != '>'){
        NSRange bracketRange = NSMakeRange(endBracketLocation, 1);
        [self.PDFData getBytes:&checkForBracket range:bracketRange];
        endBracketLocation++;
    }
    
    NSMutableString *groupString = [[NSMutableString alloc] init];
    NSUInteger counter = 0;
    
    // I should try to pull all that data from the PDF then iterate over it.
    NSUInteger stringLength = endBracketLocation - loc;
    char *encodedString = malloc(sizeof(char) * stringLength);
    char charAtPresentByte[3];
    
    
   /* while (counter < endBracketLocation) {
        char charAtPresentByte[2];
        NSRange charRange = NSMakeRange(counter, 1);
        [self.PDFData getBytes:charAtPresentByte range:charRange];
        NSString *charString = [NSString stringWithUTF8String:charAtPresentByte];
        [groupString appendString:charString];
        counter++;
    }*/

    NSUInteger countTotal;
    
    // Since two encoded characters equal one decoded character, we should have an even amount.
    if (stringLength % 2 == 0){
        countTotal = stringLength;
    }
    
    else{
        countTotal = stringLength - 1;
        NSLog(@"String at %lu has an odd number of characters", loc);
    }
    
    NSRange stringRange = NSMakeRange(loc, countTotal);
    [self.PDFData getBytes:encodedString range:stringRange];
    
    for( ; counter < countTotal; counter +=2){
        charAtPresentByte[0] = encodedString[counter];
        charAtPresentByte[1] = encodedString[counter + 1];
        NSString *charString = [NSString stringWithUTF8String:charAtPresentByte];
        [groupString appendFormat:charString];
    }
    free(encodedString);
    return [groupString copy];
}

- (NSArray *) findOpeningBracketsInObject:(int)objNumber
{
    NSMutableArray * mutableObjectLocations = [[NSMutableArray alloc] init];
    NSUInteger objectStartingLocation = [self.objectAddresses[objNumber] integerValue];
    NSUInteger objectEndingLocation   = [self.objectAddresses[objNumber +1] integerValue];
    
    for (NSUInteger i = objectStartingLocation; i < objectEndingLocation; i++){
        NSRange checkRange = NSMakeRange(i, 1);
        char checkChar;
        [self.PDFData getBytes:&checkChar range:checkRange];
        
        if (checkChar == '<'){
            [mutableObjectLocations addObject:[NSNumber numberWithUnsignedInteger:i]];
        }
    }
    return [mutableObjectLocations copy];
}

- (NSUInteger) findEncodedCharByteString:(NSString *) startingString
                          StartingAt:(NSUInteger) loc
{
    
    // Method for finding an arbitrary string encoded in between brackets.
    // Returns the byte location for this string, if found

    NSUInteger len = [startingString length];
    const char * startingStringUTF = [startingString UTF8String]; // Returns null-terminated string
    char *startingStringNoNull = malloc(sizeof(char) * len);
    for (int i = 0; i <= len; i++){
        // Get rid of that null termination;
        startingStringNoNull[i] = startingStringUTF[i];
    }
    
    char *buffer = malloc((sizeof(char) * len));
    
    char checkChar;
    NSUInteger counter = loc;
    
    while (checkChar != '>') {
        NSRange checkRange = NSMakeRange(counter + 2, 1); // encoded charaters are two bytes long;
        [self.PDFData getBytes:&checkChar range:checkRange]; // Populates checkChar for next go around
        
        // check the first character. If that matches the beginning of what we're looking for, then go ahead
        // and continue the rest of the comparison. But no need to burn those cycles if we know from the
        // start that this won't match
        char startingCharEncoded[2];
        NSRange startingCharRange = NSMakeRange(counter, 2);
        [self.PDFData getBytes:startingCharEncoded range:startingCharRange];
        char decodedfirstChar = [self hexCharByteToInt:startingCharEncoded];
        if (decodedfirstChar == startingStringNoNull[0]){
            // Loop through the next x characters and populate char buffer
            for (int i = 0; i <= len; i++) {
                NSRange secondRange = NSMakeRange(counter + i, 2);
                char *encodedCharbuffer = malloc(sizeof(char) * 2);
                [self.PDFData getBytes:encodedCharbuffer range:secondRange];
                NSString *secondCharString = [NSString stringWithUTF8String:encodedCharbuffer];
                char thisChar = [self hexStringByteToInt:secondCharString];
                free(encodedCharbuffer);
                buffer[i] = thisChar;
            }
            
        }
        
        if (strcmp(buffer, startingStringNoNull) == 0) {
            free(buffer);
            return counter;
        }
        counter += 2;
        
    }
    free(buffer);
    return 0;
}

-(BOOL) checkCharForOpeningBracketAtLocation:(NSUInteger)loc
{
    NSRange bracketRange = NSMakeRange(loc, 1);
    char c;
    
    char *itemCheck    = &c;
    
    [self.PDFData getBytes:itemCheck range:bracketRange];
    
    
    if (c == '<'){
        return YES;
    }
    
    else {
        return NO;
    }
}

- (NSUInteger) getNSUIntFromEncodedNibble: (char) nibble
{
    if ((nibble >= '0') && (nibble <= '9')){
        return (NSUInteger) (nibble - '0');
    }
    else if ((nibble >= 'a') && (nibble <= 'f')){
        return (NSUInteger) ((nibble - 'a') + 0xa);
    }
    else if ((nibble >= 'A') && (nibble <= 'F')){
        return  (NSUInteger) ((nibble - 'A') + 0xa);
    }
    else {
        return -1;
    }
}


#pragma mark - Accessors

- (UInt8 *) dataAsUInt8
{
    if (self.PDFData){
        UInt8 *bytes = (UInt8 *) self.PDFData.bytes;
        return bytes;
    }
    return nil;
}


#pragma mark - debugging methods 

- (char) findCharAtByte:(NSUInteger)byte
{
    
    const void * myBytes = malloc(self.fileLength);
    
    myBytes = [self.PDFData bytes];
    char charAtByte = findCharAtByteFunc(myBytes, self.fileLength, byte);
    free((void *)myBytes);
    return charAtByte;
}

@end
