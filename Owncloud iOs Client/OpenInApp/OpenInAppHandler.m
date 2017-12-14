//
//  OpenInAppHandler.m
//  Owncloud iOs Client
//
//  Created by Pablo Carrascal on 13/12/2017.
//
//

#import "OpenInAppHandler.h"
#import "AppDelegate.h"
#import "OCCommunication.h"


@implementation OpenInAppHandler

-(id)initWithTappedLinkURL:(NSURL *)linkURL {
    
    self = [super init];
    
    if (self) {
        _tappedLinkURL = linkURL;
    }
    return self;
}

-(void)openLink {

    DLog(@"the tapped link for the open in app is: %@", _tappedLinkURL.absoluteString);
    _finalURL = [[AppDelegate sharedOCCommunication] getFullPathFromPrivateLink: _tappedLinkURL];
    
}

@end
