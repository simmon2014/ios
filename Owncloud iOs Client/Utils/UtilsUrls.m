//
//  UtilsUrls.m
//  Owncloud iOs Client
//
//  Created by Javier Gonzalez on 16/10/14.
//

/*
 Copyright (C) 2014, ownCloud, Inc.
 This code is covered by the GNU Public License Version 3.
 For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 You should have received a copy of this license
 along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 */

#import "UtilsUrls.h"
#import "constants.h"
#import "UserDto.h"
#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import "ManageUsersDB.h"

@implementation UtilsUrls

+ (NSString *) getOwnCloudFilePath {
    NSString *output = @"";
    
    //We get the current folder to create the local tree
    //TODO: uncomment this to use the shared folder
    
    NSString *bundleSecurityGroup = [self getBundleOfSecurityGroup];
    
    output = [[[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:bundleSecurityGroup] path];
    output = [NSString stringWithFormat:@"%@/%@",output, k_owncloud_folder];
    
    BOOL isDirectory;
    if (![[NSFileManager defaultManager] fileExistsAtPath:output isDirectory:&isDirectory] || !isDirectory) {
        NSError *error = nil;
        NSDictionary *attr = [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                                         forKey:NSFileProtectionKey];
        [[NSFileManager defaultManager] createDirectoryAtPath:output
                                  withIntermediateDirectories:YES
                                                   attributes:attr
                                                        error:&error];
        if (error) {
            NSLog(@"Error creating directory path: %@", [error localizedDescription]);
        } else {
            [self addSkipBackupAttributeToItemAtURL:[NSURL fileURLWithPath:output]];
        }
    }
    
    output = [output stringByAppendingString:@"/"];
    
    return output;
}

+ (NSString *)getBundleOfSecurityGroup {
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *path = [mainBundle pathForResource: @"Owncloud iOs Client" ofType: @"entitlements"];
    
    NSPropertyListFormat format;
    NSDictionary *entitlement = [NSPropertyListSerialization propertyListFromData:[[NSFileManager defaultManager] contentsAtPath:path] mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil];
    NSArray *securityGroups = [entitlement objectForKey:@"com.apple.security.application-groups"];
    
    return [securityGroups objectAtIndex:0];
}

+ (NSString *)bundleSeedID {
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (__bridge NSString *)kSecClassGenericPassword, (__bridge NSString *)kSecClass,
                           @"bundleSeedID", kSecAttrAccount,
                           @"", kSecAttrService,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           nil];
    CFDictionaryRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound)
        status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status != errSecSuccess)
        return nil;
    NSString *accessGroup = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
    NSArray *components = [accessGroup componentsSeparatedByString:@"."];
    NSString *bundleSeedID = [[components objectEnumerator] nextObject];
    CFRelease(result);
    return bundleSeedID;
}

+ (NSString *) getFullBundleSecurityGroup {
    
    NSString *output;
    
    output = [NSString stringWithFormat:@"%@.%@", [self bundleSeedID], [self getBundleOfSecurityGroup]];
    
    return output;
    
}

//Method to skip a file to a iCloud backup
+ (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL
{
    
    BOOL success = NO;
    
    NSString *reqSysVer = @"5.0";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    
    if ([URL path]!=nil && ![currSysVer isEqualToString:reqSysVer]) {
        assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
        
        NSError *error = nil;
        
        success = [URL setResourceValue: [NSNumber numberWithBool: YES]
                                 forKey: NSURLIsExcludedFromBackupKey error: &error];
        if(!success){
            NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
        }
        
        return success;
        
    }else{
        return success;
    }
    
}

///-----------------------------------
/// @name getRemovedPartOfFilePathAnd
///-----------------------------------
/**
 * Return the part of the path to be removed
 *
 * @param mUserDto -> user dto
 *
 *  http:\/\/domain\/sub1\/sub2\/remote.php\/webdav\/
 * @return  partToRemove -> \/sub1\/sub2\/remote.php\/webdav
 */
//We remove the part of the remote file path that is not necesary
+(NSString *) getRemovedPartOfFilePathAnd:(UserDto *)mUserDto {
    
    NSArray *userUrlSplited = [[self getFullRemoteServerPath:mUserDto] componentsSeparatedByString:@"/"];
    
    NSString *partToRemove = @"";
    
    for(int i = 3 ; i < [userUrlSplited count] ; i++) {
        partToRemove = [NSString stringWithFormat:@"%@/%@", partToRemove, [userUrlSplited objectAtIndex:i]];
        //NSLog(@"partRemoved: %@", partRemoved);
    }
    
    //We remove the first and the last "/"
    if ( [partToRemove length] > 0) {
        partToRemove = [partToRemove substringFromIndex:1];
    }
    if ( [partToRemove length] > 0) {
        partToRemove = [partToRemove substringToIndex:[partToRemove length] - 1];
    }
    
    
    if([partToRemove length] <= 0) {
        partToRemove = [NSString stringWithFormat:@"/%@", k_url_webdav_server];
    } else {
        partToRemove = [NSString stringWithFormat:@"/%@/%@", partToRemove, k_url_webdav_server];
    }
    
    return partToRemove;
}

///-----------------------------------
/// @name getLocalFolderByFilePath
///-----------------------------------
/**
 * Return the file path without
 *
 * @param filePath -> \/sub1\/sub2\/remote.php\/webdav\/Documents
 * @param user -> user dto
 *
 * @return  shortenedPath -> \/Documents
 */
//We generate de local path of the files dinamically
+(NSString *)getLocalFolderByFilePath:(NSString*) filePath andFileName:(NSString*) fileName andUserDto:(UserDto *) mUser {
    
    NSArray *listItems = [[UtilsUrls getFullRemoteServerPath:mUser] componentsSeparatedByString:@"/"];
    NSString *urlWithoutAddress = @"";
    for (int i = 3 ; i < [listItems count] ; i++) {
        urlWithoutAddress = [NSString stringWithFormat:@"%@/%@", urlWithoutAddress, [listItems objectAtIndex:i]];
    }
    
    urlWithoutAddress = [NSString stringWithFormat:@"%@%@",urlWithoutAddress, k_url_webdav_server];
    
    //NSLog(@"urlWithoutAddress: %d", [urlWithoutAddress length]);
    
    urlWithoutAddress = [filePath substringFromIndex:[urlWithoutAddress length]];
    
    
    //NSString *newLocalFolder= [[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches"] stringByAppendingPathComponent:[NSString stringWithFormat:@"%d", mUser.idUser]];
    NSString *newLocalFolder= [[UtilsUrls getOwnCloudFilePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%d", (int)mUser.idUser]];
    
    
    
    newLocalFolder = [NSString stringWithFormat:@"%@/%@%@", newLocalFolder,urlWithoutAddress,fileName];
    
    //We remove the http encoding
    newLocalFolder = [newLocalFolder stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    
    //NSLog(@"newLocalFolder: %@", newLocalFolder);
    return newLocalFolder;
}

//Get the relative path of the document provider using an absolute path
+ (NSString *)getRelativePathForDocumentProviderUsingAboslutePath:(NSString *) abosolutePath{
    
    __block NSString *relativePath;
    
    NSArray *listItems = [abosolutePath componentsSeparatedByString:@"/"];
    
    [listItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        NSString *part = (NSString*) obj;
        
        if (idx == listItems.count - 2) {
            relativePath = part;
            *stop = YES;
        }
        
    }];
    
    relativePath = [NSString stringWithFormat:@"/%@/%@",relativePath,abosolutePath.lastPathComponent];
    
    return relativePath;
}

+ (NSString *) getTempFolderForUploadFiles {
    NSString * output = [NSString stringWithFormat:@"%@temp/",[UtilsUrls getOwnCloudFilePath]];
    
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:output]) {
        NSError *error;
        
        if (![[NSFileManager defaultManager] createDirectoryAtPath:output
                                       withIntermediateDirectories:NO
                                                        attributes:nil
                                                             error:&error])
        {
            NSLog(@"Create directory error: %@", error);
        }
    }
    
    return  output;
}

///-----------------------------------
/// @name getRemoteFilePathWithoutServerPathComponents
///-----------------------------------
/**
 * Return the file path without
 *
 * @param filePath -> http:\/\/domain\/sub1\/sub2\/remote.php\/webdav\/Documents
 * @param user -> user dto
 *
 * @return  shortenedPath -> \/Documents
 */
+(NSString *) getRemoteFilePathWithoutServerPathComponentsFromPath:(NSString *)filePath andUser:(UserDto *)mUserDto {
    NSString *shortenedPath =@"";

    NSString *partToRemove = [UtilsUrls getRemovedPartOfFilePathAnd:mUserDto];
    if([filePath length] >= [partToRemove length]){
        shortenedPath = [filePath substringFromIndex:[partToRemove length]];
    }
    
    return shortenedPath;
}


///-----------------------------------
/// @name getFullRemoteServerPath
///-----------------------------------
/**
 * Return the full server path
 *
 * @param mUserDto -> user dto
 *
 * @return  fullPath -> http:\/\/domain\/sub1\/sub2\/...
 */
+(NSString *) getFullRemoteServerPath:(UserDto *)mUserDto {
    
    NSString *fullPath = nil;
    
    UserDto *user = [ManageUsersDB getActiveUser];
    NSString *urlServerRedirected = [ManageUsersDB getUrlRedirectedByUserDto:user];
    //If urlServerRedirected is nil the server is not redirected
    if (urlServerRedirected) {
        fullPath = urlServerRedirected;
    } else {
        fullPath = mUserDto.url;
    }

    return fullPath;
}


///-----------------------------------
/// @name getFullRemoteWebDavPath
///-----------------------------------
/**
 * Return the full server path with webdav components
 *
 * @param mUserDto -> user dto
 *
 * @return  fullPath -> http:\/\/domain\/sub1\/sub2\/remote.php\/webdav\/
 */
+(NSString *) getFullRemoteWebDavPath:(UserDto *)mUserDto {
    
    NSString *fullWevDavPath = nil;
    
    fullWevDavPath = [NSString stringWithFormat: @"%@%@", [self getFullRemoteServerPath:mUserDto],k_url_webdav_server];
    
    return fullWevDavPath;
}

@end
