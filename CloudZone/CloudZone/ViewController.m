//
//  ViewController.m
//  CloudZone
//
//  Copyright (c) 2015 AgileBits Inc. All rights reserved.
//

#import "ViewController.h"
#import "CloudSDKView.h"
#import "Constants.h"
#import "AppDelegate.h"

#import CloudSDKImport

#ifdef AGILECLOUDSDK
#import "AgileCloudSDKView.h"
#endif

NSString *const savedRecordName = @"SavedRecordID";

#if AGILECLOUDSDK
@interface ViewController ()  <CKMediatorDelegate>
@property (nonatomic, strong) AgileCloudSDKView *cloudSDKView;
#else
@interface ViewController ()
@property (nonatomic, strong) CloudSDKView *cloudSDKView;
#endif

@property (nonatomic, strong) CKRecord *savedRecord;

@end

@implementation ViewController

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

	((AppDelegate *)[NSApp delegate]).viewController = self;

#if AGILECLOUDSDK
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cloudIdentityDidChange:) name:NSUbiquityIdentityDidChangeNotification object:nil];

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		[[CKMediator sharedMediator] setDelegate:self];
	});
	

	self.cloudSDKView = [[AgileCloudSDKView alloc] initWithFrame:self.view.bounds];
    self.cloudSDKView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[self.cloudSDKView.logoutButton setTarget:self];
	[self.cloudSDKView.logoutButton setAction:@selector(didClickLogoutButton)];
	[self.cloudSDKView.loginButton setTarget:self];
	[self.cloudSDKView.loginButton setAction:@selector(didClickLoginButton)];
	[self.view addSubview:self.cloudSDKView];

	// make sure we register to handle the redirect URL from
	// a cloud login from Safari
	NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
	[appleEventManager setEventHandler:[CKMediator sharedMediator]
						   andSelector:@selector(handleGetURLEvent:withReplyEvent:)
						 forEventClass:kInternetEventClass
							andEventID:kAEGetURL];
#else
    self.cloudSDKView = [[CloudSDKView alloc] initWithFrame:self.view.bounds];
    self.cloudSDKView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.view addSubview:self.cloudSDKView];
#endif
	
	[self.cloudSDKView.startTestsButton setTarget:self];
	[self.cloudSDKView.startTestsButton setAction:@selector(startTests)];
	[self.cloudSDKView.subscribeButton setTarget:self];
	[self.cloudSDKView.subscribeButton setAction:@selector(listenForPushNotifications)];
	[self.cloudSDKView.saveRecordButton setTarget:self];
	[self.cloudSDKView.saveRecordButton setAction:@selector(saveRecord)];

	[self loadSavedRecord];
}

- (void)startTests {
	__block NSInteger numberOfCompletedTests = 0;
	__block void (^testCompleted)() = ^{
		numberOfCompletedTests++;
		if(numberOfCompletedTests == 8){
			NSLog(@"*****************************");
			NSLog(@"All %ld tests completed", numberOfCompletedTests);
			NSLog(@"*****************************");
		}else{
			NSLog(@"*****************************");
			NSLog(@"%ld tests completed so far...", numberOfCompletedTests);
			NSLog(@"*****************************");
		}
		
		// Yes, it's terrible to pass in the testCompleted block inside the testCompleted block. Will fix someday.  - kevin 2016-04-14
		if(numberOfCompletedTests == 1) {
			[self testCloudRecordsWithAllFieldTypes:testCompleted];
		}else if(numberOfCompletedTests == 2) {
			[self testCloudSubscriptions:testCompleted];
		}else if(numberOfCompletedTests == 3) {
			[self testCloudOperationAPI:testCompleted];
		}else if(numberOfCompletedTests == 4) {
			[self testCloudRecordsWithAllFieldTypesWithOperations:testCompleted];
		}else if(numberOfCompletedTests == 5) {
			[self testCloudRecordConvenienceAPI:testCompleted];
		}else if(numberOfCompletedTests == 6) {
			[self testCloudZoneConvenienceAPI:testCompleted];
		}else if(numberOfCompletedTests == 7) {
			[self testCloudAssetsWithOperations:testCompleted];
		}
	};
	
	[self testImmediateCloudAuth:testCompleted];
	
	//
	// this test is useful to run from the CloudZone
	// app to trigger notifications that can be recieved
	// when AgileCloudZone is listening for push notifications
	//    [self testCreateAndDeleteRecordLoop];
}

#if AGILECLOUDSDK
#pragma mark - CKMediatorDelegate

- (void)mediator:(CKMediator *)mediator saveSessionToken:(NSString *)token {
	// this is a sample only. You should store your session token more securely
	[[NSUserDefaults standardUserDefaults] setObject:token forKey:@"AgileCloudSDK_sessionToken"];
}

- (NSString *)loadSessionTokenForMediator:(CKMediator *)mediator {
	// this is a sample only. You should store your session token more securely
	return [[NSUserDefaults standardUserDefaults] stringForKey:@"AgileCloudSDK_sessionToken"];
}

- (void)mediator:(CKMediator *)mediator logLevel:(int)level object:(id)object at:(SEL)method format:(NSString *)format,... NS_FORMAT_FUNCTION(5,6) {
	if (level > 5) {
		return;
	}
	
	va_list args;
	
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	
	NSLog(@"AgileCloudSDKLog %d: %@", level, message);
}

#pragma mark - Notifications

- (void)cloudIdentityDidChange:(NSNotification *)notification {
	if ([notification.userInfo[@"accountStatus"] integerValue] == CKAccountStatusAvailable) {
		self.cloudSDKView.logoutButton.hidden = NO;
		self.cloudSDKView.loginButton.hidden = YES;
		[self loadSavedRecord];
	} else {
		self.cloudSDKView.logoutButton.hidden = YES;
		self.cloudSDKView.loginButton.hidden = NO;
	}
	
	CKContainer *defCont = [CKContainer defaultContainer];
	NSLog(@"container 1: %@", defCont.containerIdentifier);
}
#endif

#pragma mark - Notification Tests

- (void)testNotificationOperations:(void (^)())completionBlock {
	//
	// these operations don't have an equivalent web service to use.
	//
	[[NSApplication sharedApplication] registerForRemoteNotificationTypes:NSRemoteNotificationTypeBadge];
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		CKFetchNotificationChangesOperation* noteChangesOp = [[CKFetchNotificationChangesOperation alloc] init];
		noteChangesOp.notificationChangedBlock = ^(CKNotification *notification){
			CKMarkNotificationsReadOperation* markReadOp = [[CKMarkNotificationsReadOperation alloc] initWithNotificationIDsToMarkRead:@[notification.notificationID]];
			markReadOp.markNotificationsReadCompletionBlock =^(NSArray <CKNotificationID *> * __nullable notificationIDsMarkedRead, NSError * __nullable operationError){
				NSAssert(!operationError, @"Error marking notification as marked as read: %@", operationError);
				NSAssert([notificationIDsMarkedRead count], @"The notification was not marked as read.");
				
				completionBlock();
			};
			[[CKContainer defaultContainer] addOperation:markReadOp];
		};
		noteChangesOp.fetchNotificationChangesCompletionBlock = ^(CKServerChangeToken *serverChangeToken, NSError *operationError){
			NSAssert(serverChangeToken, @"No server change token received.");
			NSAssert(!operationError, @"Error fetching notification changes: %@", operationError);
		};
		[[CKContainer defaultContainer] addOperation:noteChangesOp];
	});
}

- (void)listenForPushNotifications {
	[[[CKContainer defaultContainer] privateCloudDatabase] fetchAllSubscriptionsWithCompletionHandler:^(NSArray<CKSubscription *> *_Nullable subscriptions, NSError *_Nullable error) {
		__block NSArray* subsToDelete = @[];
		[subscriptions enumerateObjectsUsingBlock:^(CKSubscription * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
			subsToDelete = [subsToDelete arrayByAddingObject:[obj subscriptionID]];
		}];
		
		CKModifySubscriptionsOperation* delSubOp = [[CKModifySubscriptionsOperation alloc] initWithSubscriptionsToSave:@[] subscriptionIDsToDelete:subsToDelete];
		delSubOp.modifySubscriptionsCompletionBlock = ^(NSArray* savedSubs, NSArray* deletedSubs, NSError* err){
			NSAssert(!err, @"Error modifying subscription, %@", err);
#ifdef AGILECLOUDSDK
			CKSubscription* newSub = [[CKSubscription alloc] initWithRecordType:@"AllFieldType" filters:@[] options:CKSubscriptionOptionsFiresOnRecordCreation];
#else
			NSDate* date = [NSDate dateWithTimeInterval:-60.0 * 120 sinceDate:[NSDate date]];
			CKSubscription* newSub = [[CKSubscription alloc] initWithRecordType:@"AllFieldType" predicate:[NSPredicate predicateWithFormat:@"creationDate > %@", date] options:CKSubscriptionOptionsFiresOnRecordDeletion];
#endif
			[[[CKContainer defaultContainer] privateCloudDatabase] saveSubscription:newSub completionHandler:^(CKSubscription *subscription, NSError *error) {
				NSAssert(subscription, @"subscription coult not save.");
				NSAssert(!error, @"error saving subscription: %@", error);
				[[NSApplication sharedApplication] registerForRemoteNotificationTypes:NSRemoteNotificationTypeAlert];
			}];
		};
		[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:delSubOp];
	}];
}

#pragma mark - Create and Delete Record Loop

- (void)testCreateAndDeleteRecordLoop {
	CKRecord *testRecord = [[CKRecord alloc] initWithRecordType:@"AllFieldType"];
	testRecord[@"StringField"] = @"mumble";
	
	CKModifyRecordsOperation *multiAssetOp = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[testRecord] recordIDsToDelete:nil];
	multiAssetOp.atomic = NO;
	multiAssetOp.modifyRecordsCompletionBlock = ^(NSArray *modifiedRecords, NSArray *deletedRecordIDs, NSError *err) {
		NSAssert([modifiedRecords count], @"No record created.");
		NSAssert(!err, @"Error creating record: %@", err);
		[NSThread sleepForTimeInterval:4];
		CKRecordID* savedRecordID = [[modifiedRecords firstObject] recordID];
		if(!err){
			[self performSelectorOnMainThread:@selector(testDeleteAndCreateRecordLoop:) withObject:savedRecordID waitUntilDone:NO];
		}else{
			[self performSelectorOnMainThread:@selector(testCreateAndDeleteRecordLoop) withObject:nil waitUntilDone:NO];
		}
	};
	[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:multiAssetOp];
}

- (void)testDeleteAndCreateRecordLoop:(CKRecordID *)recordIDToDelete {
	CKModifyRecordsOperation *multiAssetOp = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[] recordIDsToDelete:@[recordIDToDelete]];
	multiAssetOp.modifyRecordsCompletionBlock = ^(NSArray *modifiedRecords, NSArray *deletedRecordIDs, NSError *err) {
		NSAssert([deletedRecordIDs count], @"Record not deleted.");
		NSAssert(!err, @"Error deleting record: %@", err);
		[NSThread sleepForTimeInterval:4];
		[self performSelectorOnMainThread:@selector(testCreateAndDeleteRecordLoop) withObject:nil waitUntilDone:NO];
	};
	[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:multiAssetOp];
}

#pragma mark - Test Cases

- (void)testImmediateCloudAuth:(void (^)())completionBlock {
	[[CKContainer defaultContainer] accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
		NSAssert(!error, @"Error fetching auth status: %@", error);
		
		completionBlock();
	}];
}

- (void)testCloudRecordsWithAllFieldTypes:(void (^)())completionBlock {
	CKRecordZone *zone = [[CKRecordZone alloc] initWithZoneName:@"persistentRecordZone"];
	[[[CKContainer defaultContainer] privateCloudDatabase] saveRecordZone:zone completionHandler:^(CKRecordZone *zone, NSError *error) {
		NSAssert(zone, @"no zone saved");
		NSAssert(!error, @"error saving record zone: %@", error);
		
		CKRecordID* recordID = [[CKRecordID alloc] initWithRecordName:@"7A7730D2-8E25-4175-BCCA-A3565DEF025B" zoneID:zone.zoneID];
		CKRecord *newRecord = [[CKRecord alloc] initWithRecordType:@"AllFieldType" recordID:recordID];
		newRecord[@"BytesField"] = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] URLForImageResource:@"palmtree.jpg"]];
		CKModifyRecordsOperation *modifyOperation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[newRecord] recordIDsToDelete:nil];
		modifyOperation.savePolicy = CKRecordSaveAllKeys;
		
		modifyOperation.modifyRecordsCompletionBlock = ^(NSArray *modifiedRecords, NSArray *deletedRecordIDs, NSError *err) {
			[[[CKContainer defaultContainer] privateCloudDatabase] fetchRecordWithID:recordID completionHandler:^(CKRecord * _Nullable record, NSError * _Nullable error) {
				//
				// note, for this test you need to manually create a record with the above ID.
				// the tests will never delete it, but will fetch it to test fetching existing records
				NSAssert(record, @"record %@ not found", recordID.recordName);
				NSAssert(!error, @"testCloudRecordsWithAllFieldTypes: error fetching record: %@", recordID.recordName);
				
				NSImage* image = [[NSImage alloc] initWithData:record[@"BytesField"]];
				NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, NO );
				NSString *desktopPath = [[paths objectAtIndex:0] stringByExpandingTildeInPath];
				[ViewController saveImage:image atPath:[desktopPath stringByAppendingPathComponent:@"CloudZoneTestImage-A3565DEF025B.png"]];
				
				record[@"StringField"] = @"foobar";
				[[[CKContainer defaultContainer] privateCloudDatabase] saveRecord:record completionHandler:^(CKRecord * _Nullable record, NSError * _Nullable error) {
					NSAssert(record, @"error saving record %@", recordID.recordName);
					NSAssert(!error, @"error: %@", error);
					
					completionBlock();
				}];
			}];
		};
		[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modifyOperation];
	}];
}

- (void)testCloudSubscriptions:(void (^)())completionBlock {
	[[[CKContainer defaultContainer] privateCloudDatabase] fetchAllSubscriptionsWithCompletionHandler:^(NSArray<CKSubscription *> *_Nullable subscriptions, NSError *_Nullable error) {
		NSAssert(!error, @"Error fetching all subscriptions: %@", error);
		
		NSArray* subsToDelete = @[];
		for (CKSubscription* sub in subscriptions){
			subsToDelete = [subsToDelete arrayByAddingObject:sub.subscriptionID];
		}
		
		// delete all subscriptions
		CKModifySubscriptionsOperation* delSubOp = [[CKModifySubscriptionsOperation alloc] initWithSubscriptionsToSave:@[] subscriptionIDsToDelete:subsToDelete];
		delSubOp.modifySubscriptionsCompletionBlock = ^(NSArray* savedSubs, NSArray* deletedSubs, NSError* err){
			NSAssert([deletedSubs count] == [subsToDelete count], @"Could not Delete the subscription.");
			NSAssert(!err, @"error modifying subscriptions %@", err);
#ifdef AGILECLOUDSDK
			CKSubscription* newSub = [[CKSubscription alloc] initWithRecordType:@"AllFieldType" filters:@[] options:CKSubscriptionOptionsFiresOnRecordUpdate];
#else
			CKSubscription* newSub = [[CKSubscription alloc] initWithRecordType:@"AllFieldType" predicate:[NSPredicate predicateWithFormat:@"StringField='asdf'"] options:CKSubscriptionOptionsFiresOnRecordUpdate];
#endif
			[[[CKContainer defaultContainer] privateCloudDatabase] saveSubscription:newSub completionHandler:^(CKSubscription *subscription, NSError *error) {
				NSAssert(subscription, @"could not save subscription");
				NSAssert(!error, @"error saving subscription %@", error);
				
				[[[CKContainer defaultContainer] privateCloudDatabase] fetchAllSubscriptionsWithCompletionHandler:^(NSArray<CKSubscription *> *_Nullable subscriptions, NSError *_Nullable error) {
					NSAssert([subscriptions count], @"no subscriptions fetched");
					NSAssert(!error, @"error fetching subscriptions: %@", error);
					
					CKSubscription* currSub = [subscriptions firstObject];
					if(currSub){
						[[[CKContainer defaultContainer] privateCloudDatabase] deleteSubscriptionWithID:currSub.subscriptionID completionHandler:^(NSString *subscriptionID, NSError *error) {
							NSAssert(subscriptionID, @"subscription %@ not deleted", subscriptionID);
							NSAssert(!error, @"error deleting subscription: %@", error);
							
							[[[CKContainer defaultContainer] privateCloudDatabase] deleteSubscriptionWithID:newSub.subscriptionID completionHandler:^(NSString *subscriptionID, NSError *error) {
								NSAssert(subscriptionID, @"subscription %@ not deleted", subscriptionID);
								NSAssert(!error, @"error deleting subscription: %@", error);
								[self _testCloudSubscriptionsAfterDelete:completionBlock];
							}];
						}];
					}else{
						[self _testCloudSubscriptionsAfterDelete:completionBlock];
					}
				}];
			}];
		};
		[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:delSubOp];
	}];
}


- (void)_testCloudSubscriptionsAfterDelete:(void (^)())completionBlock {
	// create subscription for any update on our persistent record
	CKRecordZone *zone = [[CKRecordZone alloc] initWithZoneName:@"persistentRecordZone"];
#ifdef AGILECLOUDSDK
	NSArray *filters = @[[[CKFilter alloc] initWithComparator:CK_EQUALS fieldName:@"StringField" fieldType:@"STRING" fieldValue:@"test string"]];
	CKReference *ref = [[CKReference alloc] initWithRecordID:[[CKRecordID alloc] initWithRecordName:@"foobar"] action:CKReferenceActionNone];
	filters = @[[[CKFilter alloc] initWithComparator:CK_EQUALS fieldName:@"ReferenceField" fieldType:@"REFERENCE" fieldValue:ref]];
	CKSubscription *sub = [[CKSubscription alloc] initWithRecordType:@"AllFieldType" filters:filters options:CKSubscriptionOptionsFiresOnRecordCreation];
#else
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"StringField = 'test string'"];
	CKSubscription *sub = [[CKSubscription alloc] initWithRecordType:@"AllFieldType" predicate:predicate options:CKSubscriptionOptionsFiresOnRecordCreation];
#endif
	sub.notificationInfo = [[CKNotificationInfo alloc] init];
	sub.notificationInfo.alertBody = @"foobar alert";
	sub.notificationInfo.soundName = @"mySound";
	sub.zoneID = zone.zoneID;
	
	[[[CKContainer defaultContainer] privateCloudDatabase] saveSubscription:sub completionHandler:^(CKSubscription *subscription, NSError *error) {
		NSAssert(subscription, @"subscription not saved, error: %@", error);
		NSAssert(!error, @"error saving subscription %@", error);
		
		[[[CKContainer defaultContainer] privateCloudDatabase] fetchAllSubscriptionsWithCompletionHandler:^(NSArray<CKSubscription *> * _Nullable subscriptions, NSError * _Nullable error) {
			NSAssert([subscriptions count], @"subscriptions not saved");
			NSAssert(!error, @"error saving subscriptions: %@", error);
			
			CKSubscription* existingSub = [subscriptions firstObject];
			existingSub.notificationInfo = nil;
			
#ifdef AGILECLOUDSDK
			CKSubscription* newSub = [[CKSubscription alloc] initWithRecordType:@"AllFieldType" filters:@[] options:CKSubscriptionOptionsFiresOnRecordUpdate];
#else
			CKSubscription* newSub = [[CKSubscription alloc] initWithRecordType:@"AllFieldType" predicate:[NSPredicate predicateWithFormat:@"StringField='asdf'"] options:CKSubscriptionOptionsFiresOnRecordUpdate];
#endif
			CKModifySubscriptionsOperation* addSubOp = [[CKModifySubscriptionsOperation alloc] initWithSubscriptionsToSave:@[newSub, existingSub] subscriptionIDsToDelete:@[]];
			addSubOp.modifySubscriptionsCompletionBlock = ^(NSArray* savedSubs, NSArray* deletedSubs, NSError* err){
				NSAssert([savedSubs count] == 2, @"both subscriptions not saved");
				NSAssert(!existingSub.notificationInfo.alertBody, @"no notification info for the modified sub");
				NSAssert(!error, @"error modifying subscriptions: %@", error);
				
				CKModifySubscriptionsOperation* delSubOp = [[CKModifySubscriptionsOperation alloc] initWithSubscriptionsToSave:@[] subscriptionIDsToDelete:@[newSub.subscriptionID]];
				delSubOp.modifySubscriptionsCompletionBlock = ^(NSArray* savedSubs, NSArray* deletedSubs, NSError* err){
					NSAssert([deletedSubs count] == 1, @"subscription not deleted");
					
					completionBlock();
				};
				[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:delSubOp];
			};
			[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:addSubOp];
		}];
	}];
}

- (void)testCloudAssetsWithOperations:(void (^)())completionBlock {
	CKRecordZone *zone = [[CKRecordZone alloc] initWithZoneName:@"persistentRecordZone"];
	NSString *recordWithAsset = @"A4A40E35-66D0-4D9E-ACD0-F34D04DF0F69";
	CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName:recordWithAsset zoneID:zone.zoneID];
	CKRecord *newRecord = [[CKRecord alloc] initWithRecordType:@"AllFieldType" recordID:recordID];
	CKModifyRecordsOperation *modifyOperation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[newRecord] recordIDsToDelete:nil];
	modifyOperation.savePolicy = CKRecordSaveAllKeys;
	
	modifyOperation.modifyRecordsCompletionBlock = ^(NSArray *modifiedRecords, NSArray *deletedRecordIDs, NSError *err) {
		__block CKRecord *fetchedRecordWithAsset;
		CKFetchRecordsOperation *fetchOp = [[CKFetchRecordsOperation alloc] initWithRecordIDs:@[recordID]];
		fetchOp.perRecordProgressBlock = ^(CKRecordID *recordID, double progress) {
			NSLog(@"fetch record progress: %.2f %@", progress, recordID);
		};
		fetchOp.perRecordCompletionBlock = ^(CKRecord *record, CKRecordID *recordID, NSError *error) {
			NSAssert(!error, @"testCloudAssetsWithOperations: error fetching record: %@", error);
			NSLog(@"per record complete: %@", record.recordID);
			NSLog(@" - : %@", [record[@"AssetField"] fileURL]);
		};
		fetchOp.fetchRecordsCompletionBlock = ^(NSDictionary /* CKRecordID * -> CKRecord */ *recordsByRecordID, NSError *operationError) {
			NSAssert([[recordsByRecordID allKeys] count], @"could not fetch records");
			NSAssert(!operationError, @"error fetching records: %@", operationError);
			
			fetchedRecordWithAsset = [[recordsByRecordID allValues] firstObject];
			CKModifyRecordsOperation *recordWithAssetOp = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[fetchedRecordWithAsset] recordIDsToDelete:nil];
			recordWithAssetOp.modifyRecordsCompletionBlock = ^(NSArray *modifiedRecords, NSArray *deletedRecordIDs, NSError *err) {
				NSAssert([modifiedRecords count], @"could not save record");
				NSAssert(!err, @"error saving record: %@", err);
				
				// update the asset
				NSURL *fileURL = [[NSBundle mainBundle] URLForImageResource:@"palmtree.jpg"];
				fetchedRecordWithAsset[@"AssetField"] = [[CKAsset alloc] initWithFileURL:fileURL];
				CKModifyRecordsOperation *recordWithAssetOp = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[fetchedRecordWithAsset] recordIDsToDelete:nil];
				recordWithAssetOp.modifyRecordsCompletionBlock = ^(NSArray *modifiedRecords, NSArray *deletedRecordIDs, NSError *err) {
					NSAssert([modifiedRecords count], @"No records modified.");
					NSAssert(!err, @"Error modifying record: %@", err);
					
					CKAsset* asset1 = [[CKAsset alloc] initWithFileURL:[[NSBundle mainBundle] URLForImageResource:@"palmtree.jpg"]];
					CKAsset* asset2 = [[CKAsset alloc] initWithFileURL:[[NSBundle mainBundle] URLForImageResource:@"sunset"]];
					
					CKRecord* recordWithMultipleAssets = [[CKRecord alloc] initWithRecordType:@"AllFieldType" zoneID:zone.zoneID];
					recordWithMultipleAssets[@"AssetListField"] = @[asset1, asset2];
					
					CKModifyRecordsOperation *multiAssetOp = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[recordWithMultipleAssets] recordIDsToDelete:nil];
					multiAssetOp.modifyRecordsCompletionBlock = ^(NSArray *modifiedRecords, NSArray *deletedRecordIDs, NSError *err) {
						NSAssert([modifiedRecords count], @"Could not modify multi-asset record: error %@", err);
						NSAssert(!err, @"Error modifying multi-asset record. %@", err);
						
						completionBlock();
					};
					[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:multiAssetOp];
				};
				[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:recordWithAssetOp];
			};
			[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:recordWithAssetOp];
		};
		[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:fetchOp];
	};
	[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modifyOperation];
}


- (void)testCloudRecordsWithAllFieldTypesWithOperations:(void (^)())completionBlock {
	CKRecordZone *zone = [[CKRecordZone alloc] initWithZoneName:@"persistentRecordZone"];
	CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName:@"7A7730D2-8E25-4175-BCCA-A3565DEF025B" zoneID:zone.zoneID];
	CKRecordID *missingRecordID = [[CKRecordID alloc] initWithRecordName:@"missingRecord" zoneID:zone.zoneID];
	
	CKFetchRecordsOperation *fetchOp = [[CKFetchRecordsOperation alloc] initWithRecordIDs:@[recordID, missingRecordID]];
	fetchOp.perRecordProgressBlock = ^(CKRecordID *recordID, double progress) {
		NSLog(@"fetch record progress: %.2f %@", progress, recordID);
	};
	fetchOp.perRecordCompletionBlock = ^(CKRecord *record, CKRecordID *recordID, NSError *error) {
		if([recordID isEqual:missingRecordID] && !error){
			NSAssert(error, @"missing record should have error");
		}else if(![recordID isEqual:missingRecordID] && error){
			NSAssert(!error, @"shouldn't have error for existing record: %@", error);
		}
		NSLog(@"per record complete: %@", record.recordID);
	};
	fetchOp.fetchRecordsCompletionBlock = ^(NSDictionary /* CKRecordID * -> CKRecord */ *recordsByRecordID, NSError *operationError) {
		NSAssert([recordsByRecordID count], @"nothing fetched");
		NSAssert(operationError, @"no partial error due to missing record");
		
		CKRecord* record = [[recordsByRecordID allValues] firstObject];
		record[@"StringField"] = @"jumble";
		record[@"IntField"] = @(NO);
		
		CKModifyRecordsOperation* modOp = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[record] recordIDsToDelete:nil];
		modOp.modifyRecordsCompletionBlock = ^(NSArray* modifiedRecords, NSArray* deletedRecordIDs, NSError* err){
			NSAssert([modifiedRecords count], @"no saved records");
			NSAssert(!err, @"error fetching saved records %@", err);
			
			CKRecord* addRecord = [[CKRecord alloc] initWithRecordType:@"AllFieldType" recordID:[[CKRecordID alloc] initWithRecordName:[[NSUUID UUID]UUIDString] zoneID:record.recordID.zoneID]];
			addRecord[@"StringField"] = @"a new record";
			
			CKModifyRecordsOperation* modOp2 = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[addRecord] recordIDsToDelete:nil];
			modOp2.modifyRecordsCompletionBlock = ^(NSArray* modifiedRecords, NSArray* deletedRecordIDs, NSError* err){
				NSAssert([modifiedRecords count], @"no records saved");
				NSAssert(!err, @"error saving records: %@", err);
				
				CKFetchRecordChangesOperation* recordChangesOperation = [[CKFetchRecordChangesOperation alloc] initWithRecordZoneID:record.recordID.zoneID previousServerChangeToken:nil];
				recordChangesOperation.recordChangedBlock = ^(CKRecord* record){
					NSLog(@" - was changed %@", [record recordID]);
				};
				recordChangesOperation.recordWithIDWasDeletedBlock = ^(CKRecordID* recordID){
					NSLog(@" - was deleted %@", recordID);
				};
				recordChangesOperation.fetchRecordChangesCompletionBlock = ^(CKServerChangeToken* token, NSData* notUsed, NSError* opErr){
					NSAssert(token, @"no token received for changed records");
					NSAssert(!opErr, @"error fetching record changes: %@", opErr);
					
					CKRecord* hydratedRecord = [[CKRecord alloc] initWithRecordType:addRecord.recordType recordID:addRecord.recordID];
					hydratedRecord[@"StringField"] = @"modified record";
					CKModifyRecordsOperation* modOp3 = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[hydratedRecord] recordIDsToDelete:nil];
					modOp3.savePolicy = CKRecordSaveAllKeys;
					modOp3.modifyRecordsCompletionBlock = ^(NSArray* modifiedRecords, NSArray* deletedRecordIDs, NSError* err){
						NSAssert([modifiedRecords count], @"record not modified");
						NSAssert(!err, @"error modifying record: %@", err);
						
						CKModifyRecordsOperation* modOp4 = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:nil recordIDsToDelete:@[addRecord.recordID]];
						modOp4.modifyRecordsCompletionBlock = ^(NSArray* modifiedRecords, NSArray* deletedRecordIDs, NSError* err){
							NSAssert([deletedRecordIDs count], @"record not deleted");
							NSAssert(!err, @"error deleting record: %@", err);
							
							CKModifyRecordsOperation* modOp5 = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[addRecord] recordIDsToDelete:nil];
							modOp5.perRecordProgressBlock = ^(CKRecord *record, double progress){
								NSLog(@" - %@ %.2f", [record recordID], progress);
							};
							modOp5.perRecordCompletionBlock = ^(CKRecord *record, NSError *error){
								NSAssert(record, @"can't save a deleted record");
								NSAssert(error, @"expected error");
								NSLog(@" - %@ %@", [record recordID], err);
							};
							modOp5.modifyRecordsCompletionBlock = ^(NSArray* modifiedRecords, NSArray* deletedRecordIDs, NSError* err){
								NSAssert(![modifiedRecords count], @"can't save a deleted record");
								NSAssert(err, @"expected error");
								
								CKFetchRecordChangesOperation* nextChangesOperation = [[CKFetchRecordChangesOperation alloc] initWithRecordZoneID:record.recordID.zoneID previousServerChangeToken:token];
								nextChangesOperation.recordChangedBlock = ^(CKRecord* record){
									NSLog(@" - was changed %@", [record recordID]);
								};
								nextChangesOperation.recordWithIDWasDeletedBlock = ^(CKRecordID* recordID){
									NSLog(@" - was deleted %@", recordID);
								};
								nextChangesOperation.fetchRecordChangesCompletionBlock = ^(CKServerChangeToken* token, NSData* notUsed, NSError* opErr){
									NSAssert(token, @"no record change token received");
									NSAssert(!opErr, @"error fetching record changes: %@", opErr);
									
									completionBlock();
								};
								[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:nextChangesOperation];
							};
							[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modOp5];
						};
						[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modOp4];
					};
					[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modOp3];
				};
				[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:recordChangesOperation];
			};
			[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modOp2];
		};
		[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modOp];
	};
	[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:fetchOp];
}


- (void)testCloudRecordConvenienceAPI:(void (^)())completionBlock {
	NSLog(@"=============================");
	NSLog(@"testCloudRecordConvenienceAPI");
	NSLog(@"=============================");
	
	NSLog(@"Fetching all zones");
	
#if AGILECLOUDSDK
	NSArray *containerProperties = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CloudContainers"];
	NSString *cloudIdentifier = [containerProperties[0] objectForKey:@"CloudContainerName"];
#else
	NSString *cloudIdentifier = [[CKContainer defaultContainer] containerIdentifier];
#endif
	
	[[[CKContainer containerWithIdentifier:cloudIdentifier] privateCloudDatabase] fetchAllRecordZonesWithCompletionHandler:^(NSArray *zones, NSError *error) {
		NSAssert([zones count], @"could not fetch zones");
		NSAssert(!error, @"error fetching zones: %@", error);
	}];
	
	[[[CKContainer defaultContainer] privateCloudDatabase] fetchAllRecordZonesWithCompletionHandler:^(NSArray *zones, NSError *error) {
		CKRecordID* recordID = [[CKRecordID alloc] initWithRecordName:@"missingRecordID"];
		
		[[[CKContainer defaultContainer] privateCloudDatabase] fetchRecordWithID:recordID completionHandler:^(CKRecord *record, NSError *error) {
			NSAssert(error && error.code == CKErrorUnknownItem, @"operation completed without CKErrorUnknownItem error");
			NSLog(@"error (expected): %@", error);
		}];
		
		CKRecordZone* zone = [[CKRecordZone alloc] initWithZoneName:@"testRecordZone"];
		[[[CKContainer defaultContainer] privateCloudDatabase] saveRecordZone:zone completionHandler:^(CKRecordZone *zone, NSError *error) {
			NSAssert(zone, @"zone not saved");
			NSAssert(!error, @"error saving zone: %@", error);
			
			CKRecordID* recordID = [[CKRecordID alloc] initWithRecordName:[[NSUUID UUID] UUIDString] zoneID:zone.zoneID];
			CKRecord* recordToSave = [[CKRecord alloc] initWithRecordType:@"SampleRecordType" recordID:recordID];
			recordToSave[@"myfield"] = @"foobar";
			recordToSave[@"otherfield"] = @"mumble";
			[[[CKContainer defaultContainer] privateCloudDatabase] saveRecord:recordToSave completionHandler:^(CKRecord *originalRecord, NSError *error) {
				NSAssert(originalRecord, @"record does not exist");
				NSAssert(originalRecord == recordToSave, @"record does not match input");
				NSAssert(!error, @"error saving record: %@", error);
				
				originalRecord[@"myfield"] = @"foobar2";
				
				NSAssert([originalRecord.changedKeys count] == 1, @"all changed keys are gone");
				[[[CKContainer defaultContainer] privateCloudDatabase] saveRecord:originalRecord completionHandler:^(CKRecord *record, NSError *error) {
					NSAssert(record, @"record not updated");
					NSAssert(record == originalRecord, @"record does not match original");
					NSAssert([record.changedKeys count] == 0, @"changed keys remain");
					
					[[[CKContainer defaultContainer] privateCloudDatabase] fetchRecordWithID:record.recordID completionHandler:^(CKRecord *record, NSError *error) {
						NSAssert(record, @"could not fetch record");
						NSAssert(!error, @"error fetching record: %@", error);
						[[[CKContainer defaultContainer] privateCloudDatabase] deleteRecordWithID:record.recordID completionHandler:^(CKRecordID *recordID, NSError *error) {
							NSAssert(recordID, @"could not delete record");
							NSAssert(!error, @"error deleting record: %@", error);
							
							[[[CKContainer defaultContainer] privateCloudDatabase] deleteRecordZoneWithID:zone.zoneID completionHandler:^(CKRecordZoneID *zoneID, NSError *error) {
								NSAssert(zoneID, @"zone not deleted");
								NSAssert(!error, @"error deleting zone: %@", error);
								NSLog(@"zone deleted: %@", zoneID);
								
								completionBlock();
							}];
						}];
					}];
				}];
			}];
		}];
	}];
}

- (void)testCloudZoneConvenienceAPI:(void (^)())completionBlock {
	NSLog(@"=============================");
	NSLog(@"testCloudZoneConvenienceAPI");
	NSLog(@"=============================");
	
	NSLog(@"Fetching all zones");
	[[[CKContainer defaultContainer] privateCloudDatabase] fetchAllRecordZonesWithCompletionHandler:^(NSArray *zones, NSError *error) {
		NSAssert([zones count], @"zones not fetched");
		NSAssert(!error, @"error fetching zones: %@", error);
		
		CKRecordZone* zone = [[CKRecordZone alloc] initWithZoneName:@"customZoneName"];
		[[[CKContainer defaultContainer] privateCloudDatabase] saveRecordZone:zone completionHandler:^(CKRecordZone *zone, NSError *error) {
			NSAssert(zone, @"could not save zone");
			NSAssert(!error, @"error saving zone: %@", error);
			
			[[[CKContainer defaultContainer] privateCloudDatabase] fetchRecordZoneWithID:zone.zoneID completionHandler:^(CKRecordZone *zone, NSError *error) {
				NSAssert(zone, @"could not fetch zone");
				NSAssert(!error, @"error fetching zone: %@", error);
				
				[[[CKContainer defaultContainer] privateCloudDatabase] deleteRecordZoneWithID:zone.zoneID completionHandler:^(CKRecordZoneID *zoneID, NSError *error) {
					NSAssert(zoneID, @"zone not deleted");
					NSAssert(!error, @"error deleting zone: %@", error);
					
					[[[CKContainer defaultContainer] privateCloudDatabase] fetchRecordZoneWithID:zone.zoneID completionHandler:^(CKRecordZone *zone, NSError *error) {
						NSAssert(!zone, @"zone still remains");
						NSAssert(error, @"operation completed without expected error");
						
						completionBlock();
					}];
				}];
			}];
		}];
	}];
}


- (void)testCloudOperationAPI:(void (^)())completionBlock {
	NSLog(@"=============================");
	NSLog(@"cloudOperationAPI");
	NSLog(@"=============================");
	
	NSLog(@"Fetching all zones");
	CKFetchRecordZonesOperation *op = [CKFetchRecordZonesOperation fetchAllRecordZonesOperation];
	op.fetchRecordZonesCompletionBlock = ^(NSDictionary *recordZonesByZoneID, NSError *operationError) {
		NSAssert([[recordZonesByZoneID allKeys] count], @"can not fetch zones");
		NSAssert(!operationError, @"zones fectched with error: %@", operationError);
		
		CKRecordZone* zoneToSave = [[CKRecordZone alloc] initWithZoneName:@"customZoneName"];
		CKModifyRecordZonesOperation* modOp = [[CKModifyRecordZonesOperation alloc] initWithRecordZonesToSave:@[zoneToSave]
																						recordZoneIDsToDelete:@[]];
		modOp.modifyRecordZonesCompletionBlock = ^(NSArray *savedRecordZones, NSArray *deletedRecordZoneIDs, NSError *operationError){
			NSAssert([savedRecordZones count], @"record zones not saved");
			NSAssert(!operationError, @"zones saved with error: %@", operationError);
			NSLog(@"saved zones ok");
			
			CKFetchRecordZonesOperation* fetchOp = [[CKFetchRecordZonesOperation alloc] initWithRecordZoneIDs:@[zoneToSave.zoneID]];
			fetchOp.fetchRecordZonesCompletionBlock = ^(NSDictionary * recordZonesByZoneID, NSError * operationError){
				NSAssert([[recordZonesByZoneID allKeys] count], @"coud not fetch zones");
				NSAssert(!operationError, @"error fetching zones: %@", operationError);
				NSLog(@"fetch zones ok");
				
				CKModifyRecordZonesOperation* delOp = [[CKModifyRecordZonesOperation alloc] initWithRecordZonesToSave:@[]
																								recordZoneIDsToDelete:@[zoneToSave.zoneID]];
				delOp.modifyRecordZonesCompletionBlock = ^(NSArray *savedRecordZones, NSArray *deletedRecordZoneIDs, NSError *operationError){
					NSAssert([deletedRecordZoneIDs count], @"zones not deleted");
					NSAssert(!operationError, @"error deleting zones: %@", operationError);
					NSLog(@"modify zones ok");
					
					CKFetchRecordZonesOperation* errOp = [[CKFetchRecordZonesOperation alloc] initWithRecordZoneIDs:@[zoneToSave.zoneID]];
					errOp.fetchRecordZonesCompletionBlock = ^(NSDictionary * recordZonesByZoneID, NSError * operationError){
						NSAssert(![[recordZonesByZoneID allKeys] count], @"zones remain after deletion attempt");
						NSAssert(operationError, @"operation completed without expected error");
						NSLog(@"fetch zones ok");
						
						completionBlock();
					};
					[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:errOp];
				};
				[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:delOp];
			};
			[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:fetchOp];
		};
		[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modOp];
	};
	[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:op];
}


+ (void)saveImage:(NSImage *)image atPath:(NSString *)path {
	CGImageRef cgRef = [image CGImageForProposedRect:NULL
											 context:nil
											   hints:nil];
	NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
	[newRep setSize:[image size]]; // if you want the same resolution
	NSData *pngData = [newRep representationUsingType:NSPNGFileType properties:@{}];
	[pngData writeToFile:path atomically:YES];
}

#pragma mark - Records

- (void)loadSavedRecord {
	CKRecordID *recordID = [[CKRecordID alloc] initWithRecordName:savedRecordName];
	[[[CKContainer defaultContainer] privateCloudDatabase] fetchRecordWithID:recordID completionHandler:^(CKRecord * _Nullable record, NSError * _Nullable error) {
		if (error != nil) {
			NSLog(@"Could not fetch saved record: %@", error);
		}
		else if (record != nil) {
			self.savedRecord = record;
			self.cloudSDKView.recordTextField.stringValue = record[@"StringField"];
			NSLog(@"Fetched saved record.");
		}
		else {
			NSLog(@"No record");
		}
	}];
}

- (void)saveRecord {
	CKRecord *recordToSave = self.savedRecord ? : [[CKRecord alloc] initWithRecordType:@"AllFieldType" recordID:[[CKRecordID alloc] initWithRecordName:savedRecordName]];
	recordToSave[@"StringField"] = self.cloudSDKView.recordTextField.stringValue;
	
	CKModifyRecordsOperation *modifyOperation = [[CKModifyRecordsOperation alloc] initWithRecordsToSave:@[recordToSave] recordIDsToDelete:nil];
	modifyOperation.atomic = NO;
	modifyOperation.modifyRecordsCompletionBlock = ^(NSArray *modifiedRecords, NSArray *deletedRecordIDs, NSError *error) {
		if (error != nil) {
			NSLog(@"Error saving record: %@", error);
		}
		else if (modifiedRecords.count == 1) {
			NSLog(@"Saved record");
		}
	};
	modifyOperation.savePolicy = CKRecordSaveAllKeys;
	[[[CKContainer defaultContainer] privateCloudDatabase] addOperation:modifyOperation];
}

#pragma mark - AgileCloudSDKView actions

#if AGILECLOUDSDK
- (void)didClickLogoutButton {
	[[CKMediator sharedMediator] logout];
}

- (void)didClickLoginButton {
	[[CKMediator sharedMediator] login];
}
#endif

@end
