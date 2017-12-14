//
//  OpenInAppHandler.h
//  Owncloud iOs Client
//
//  Created by Pablo Carrascal on 13/12/2017.
//
//

#import <Foundation/Foundation.h>

@interface OpenInAppHandler : NSObject
@property  (readonly) NSURL *tappedLinkURL;
@property  NSURL *finalURL;


-(id)initWithTappedLinkURL:(NSURL *) linkURL;
-(void)openLink;

@end
