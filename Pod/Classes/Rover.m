//
//  Rover.m
//  Rover
//
//  Created by Sean Rucker on 2014-06-23.
//  Copyright (c) 2014 Rover Labs Inc. All rights reserved.
//

#import "Rover.h"

@interface Rover () <RVVisitManagerDelegate, RXVisitViewControllerDelegate>

@property (readonly, strong, nonatomic) RVConfig *config;
@property (nonatomic, strong) RVVisitManager *visitManager;
@property (nonatomic, strong) RVVisit *currentVisit;

@property (nonatomic, strong) UIViewController *modalViewController;

@end

@implementation Rover {
    RVCustomer *_customer;
}

#pragma mark - Class methods

static Rover *sharedInstance = nil;

+ (Rover *)setup:(RVConfig *)config {
    
    UIApplication *application = [UIApplication sharedApplication];
    if ([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
        Class userSettingClass = NSClassFromString(@"UIUserNotificationSettings");
        if (userSettingClass) {
            [application registerUserNotificationSettings:[userSettingClass settingsForTypes:config.allowedUserNotificationTypes categories:nil]];
        }
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] initWithConfig:config];
    });
    
    return sharedInstance;
}

+ (Rover *)shared {
    if (sharedInstance == nil) {
        NSLog(@"%@ warning shared called before setup:", self);
    }
    return sharedInstance;
}

+ (UIViewController *)findCurrentViewController:(UIViewController *)vc {
    if (vc.presentedViewController) {
        return [Rover findCurrentViewController:vc.presentedViewController];
    } else if ([vc isKindOfClass:[UISplitViewController class]]) {
        UISplitViewController *svc = (UISplitViewController *)vc;
        if (svc.viewControllers.count > 0) {
            return [Rover findCurrentViewController:svc.viewControllers.lastObject];
        } else {
            return vc;
        }
    } else if ([vc isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nvc = (UINavigationController *)vc;
        if (nvc.viewControllers.count > 0) {
            return [Rover findCurrentViewController:nvc.topViewController];
        } else {
            return vc;
        }
    } else if ([vc isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tbc = (UITabBarController *)vc;
        if (tbc.viewControllers.count > 0) {
            return [Rover findCurrentViewController:tbc.selectedViewController];
        } else {
            return vc;
        }
    } else {
        return vc;
    }
}

#pragma mark - Properties

- (RVCustomer *)customer {
    if (_customer) {
        return _customer;
    }
    
    _customer = [RVCustomer cachedCustomer];
    return _customer;
}

- (RVVisit *)currentVisit {
    if (_currentVisit && _visitManager.regionManager.currentRegions.count > 0) {
        CLBeaconRegion *beaconRegion = _visitManager.regionManager.currentRegions.anyObject;
        if ([_currentVisit isInLocationRegion:beaconRegion]) {
            return _currentVisit;
        };
    }
    
    if (_visitManager.latestVisit.isAlive) {
        return _visitManager.latestVisit;
    }
    
    return nil;
}

#pragma mark - Initialization

- (instancetype)initWithConfig:(RVConfig *)config {
    self = [super init];
    if (self) {
        _config = config;
        
        _visitManager = [RVVisitManager new];
        _visitManager.delegate = self;
        
        if (config.serverURL) {
            RVNetworkingManager *networkingManager = [RVNetworkingManager sharedManager];
            networkingManager.baseURL = [NSURL URLWithString:config.serverURL];
        } else {
            NSLog(@"%@ warning empty server URL", self);
        }
        
        if ([config.applicationToken length]) {
            [[RVNetworkingManager sharedManager] setAuthToken:config.applicationToken];
        } else {
            NSLog(@"%@ warning empty application token", self);
        }
        
        if ([config.beaconUUIDs count]) {
            [_visitManager.regionManager setBeaconUUIDs:config.beaconUUIDs];
        } else {
            NSLog(@"%@ warning empty beacon uuids", self);
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
    }
    return self;
}

#pragma mark - Public methods

- (id)configValueForKey:(NSString *)key {
    return [_config valueForKey:key];
}

- (void)startMonitoring {
    [_visitManager.regionManager startMonitoring];
}

- (void)stopMonitoring {
    [_visitManager.regionManager stopMonitoring];
}

- (void)simulateBeaconWithUUID:(NSUUID *)UUID major:(CLBeaconMajorValue)major minor:(CLBeaconMinorValue)minor
{
    [_visitManager.regionManager simulateBeaconWithUUID:UUID major:major minor:minor];
}

- (void)presentModal {
    
    if ([self.currentVisit.visitedTouchpoints filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(RVTouchpoint *touchpoint, NSDictionary *bindings) {
        return touchpoint.cards.count > 0;
    }]].count == 0) {
        NSLog(@"%@ warning showModal called but there are no cards to display", self);
        return;
    }
    
    // Delegate
    if ([self.delegate respondsToSelector:@selector(roverWillDisplayModalViewController)]) {
        [self.delegate roverWillDisplayModalViewController];
    }

    _modalViewController = [[self.config.modalViewControllerClass alloc] init];
    
    if ([_modalViewController isKindOfClass:[RXVisitViewController class]]) {
        ((RXVisitViewController *)_modalViewController).delegate = self;
        
        NSArray *touchpoints = _config.accumulatingTouchpoints ? [[self.currentVisit.visitedTouchpoints reverseObjectEnumerator] allObjects] : [self.currentVisit.currentTouchpoints allObjects];
        
        [((RXVisitViewController *)_modalViewController) setTouchpoints:[[touchpoints filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(RVTouchpoint *touchpoint, NSDictionary *bindings) {
            return touchpoint.cards.count > 0;
        }]] mutableCopy]];
    }
    
    if ([_modalViewController isKindOfClass:[RXModalViewController class]]) {
        [((RXModalViewController *)_modalViewController) setBackdropBlurRadius:self.config.modalBackdropBlurRadius];
        [((RXModalViewController *)_modalViewController) setBackdropTintColor:self.config.modalBackdropTintColor];
    }
    
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *currentViewController = [Rover findCurrentViewController:rootViewController];
    [currentViewController presentViewController:_modalViewController animated:YES completion:nil];
    
    // Delegate
    if ([self.delegate respondsToSelector:@selector(roverDidDisplayModalViewController)]) {
        [self.delegate roverDidDisplayModalViewController];
    }
}

#pragma mark - Utility

- (void)sendNotification:(NSString *)message {
    // TODO: consider the case where the first noti has already been delivered (want to be silent)
    
    UILocalNotification *note = [[UILocalNotification alloc] init];
    note.alertBody = message;
    
    if (self.config.notificationSoundName) {
        note.soundName = self.config.notificationSoundName;
    }
    [[UIApplication sharedApplication] presentLocalNotificationNow:note];
}

- (void)trackEvent:(NSString *)event params:(NSDictionary *)params {
    if (self.currentVisit) {
        [[RVNetworkingManager sharedManager] trackEvent:event params:params visit:self.currentVisit];
    }
}

#pragma mark - RVVisitManagerDelegate

- (void)visitManager:(RVVisitManager *)manager didEnterLocation:(RVLocation *)location visit:(RVVisit *)visit {
    // This should be the only place where we set this iVar
    _currentVisit = visit;
    
    [[RVImagePrefetcher sharedImagePrefetcher] prefetchURLs:_currentVisit.allImageUrls];
    
    [self trackEvent:@"location.enter" params:nil];
    
    // Delegate
    if ([self.delegate respondsToSelector:@selector(roverVisit:didEnterLocation:)]) {
        [self.delegate roverVisit:_currentVisit didEnterLocation:_currentVisit.location];
    }
}

- (void)visitManager:(RVVisitManager *)manager didPotentiallyExitLocation:(RVLocation *)location visit:(RVVisit *)visit {
    [self trackEvent:@"location.exit" params:nil];
    
    // Delegate
    if ([self.delegate respondsToSelector:@selector(roverVisit:didPotentiallyExitLocation:aliveForAnother:)]) {
        [self.delegate roverVisit:visit didPotentiallyExitLocation:visit.location aliveForAnother:visit.keepAlive];
    }
}

- (void)visitManager:(RVVisitManager *)manager didExpireVisit:(RVVisit *)visit {
    // Delegate
    if ([self.delegate respondsToSelector:@selector(roverVisitDidExpire:)]) {
        [self.delegate roverVisitDidExpire:visit];
    }
}

- (void)visitManager:(RVVisitManager *)manager didEnterTouchpoint:(RVTouchpoint *)touchpoint visit:(RVVisit *)visit {
    // Touchpoint Tracking
    [self trackEvent:@"touchpoint.enter" params:@{@"touchpoint": touchpoint.ID}];
    
    // Card Delivered Tracking
    [touchpoint.cards enumerateObjectsUsingBlock:^(RVCard *card, NSUInteger idx, BOOL *stop) {
        [self trackEvent:@"card.deliver" params:@{@"card": card.ID}];
    }];
    
    
    // Current Modal Update
    if ([_modalViewController isKindOfClass:[RXVisitViewController class]]) {
        RXVisitViewController *visitViewController = (RXVisitViewController *)_modalViewController;
        if (![visitViewController.touchpoints containsObject:touchpoint]) {
            if (self.config.accumulatingTouchpoints) {
                if (touchpoint.cards.count > 0) {
                    
                    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            
                            [visitViewController addTouchpoint:touchpoint];
                        });
                    } else {
                        
                        [visitViewController addTouchpoint:touchpoint];
                    }
                    
                }
            } else {
                [visitViewController setTouchpoints:[[visit.currentTouchpoints allObjects] mutableCopy]];
                [visitViewController.tableView reloadData];
            }
        }
    }
    
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        // do something else (banner or something)
        
        // Touchpoint Tracking
        [self trackEvent:@"touchpoint.open" params:@{@"touchpoint": touchpoint.ID}];
        
        if (!touchpoint.notificationDelivered || !self.config.accumulatingTouchpoints) {
            UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
            UIViewController *currentViewController = [Rover findCurrentViewController:rootViewController];
            
            if (self.config.autoPresentModal && [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive && ![currentViewController isKindOfClass:_config.modalViewControllerClass] && ![currentViewController isKindOfClass:[RXDetailViewController class]]) {
                [self presentModal];
            }
        }
        
        touchpoint.notificationDelivered = YES;
    } else if (!touchpoint.notificationDelivered) {
        
        if (touchpoint.notification) {
            [self sendNotification:touchpoint.notification];
        }
        
        touchpoint.notificationDelivered = YES;
    }
    

    
    // Delegate
    if ([self.delegate respondsToSelector:@selector(roverVisit:didEnterTouchpoint:)]) {
        [self.delegate roverVisit:visit didEnterTouchpoint:touchpoint];
    }
}

- (void)visitManager:(RVVisitManager *)manager didExitTouchpoint:(RVTouchpoint *)touchpoint visit:(RVVisit *)visit {
    [self trackEvent:@"touchpoint.exit" params:@{@"touchpoint": touchpoint.ID}];
    
    if (!self.config.accumulatingTouchpoints && _modalViewController) {
        if ([_modalViewController isKindOfClass:[RXVisitViewController class]]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                RXVisitViewController *visitModalViewController = (RXVisitViewController *)_modalViewController;
                
                [visitModalViewController setTouchpoints:[[visit.currentTouchpoints allObjects] mutableCopy]];
                [visitModalViewController.tableView reloadData];
                
                if (visitModalViewController.touchpoints.count == 0) {
                    [visitModalViewController dismissViewControllerAnimated:YES completion:nil];
                }
            });
        }
    }
    
    // Delegate
    if ([self.delegate respondsToSelector:@selector(roverVisit:didExitTouchpoint:)]) {
        [self.delegate roverVisit:visit didExitTouchpoint:touchpoint];
    }
}

- (BOOL)visitManager:(RVVisitManager *)manager shouldCreateVisit:(RVVisit *)visit {
    visit.simulate = self.config.sandboxMode;
    
    // Delegate
    if ([self.delegate respondsToSelector:@selector(roverShouldCreateVisit:)]) {
        if (![self.delegate roverShouldCreateVisit:visit]) {
            return NO;
        }
    }
    
    [[RVNetworkingManager sharedManager] postVisit:visit];
    
    // Delegate
    if ([self.delegate respondsToSelector:@selector(roverDidCreateVisit:)]) {
        [self.delegate roverDidCreateVisit:visit];
    }
    
    return YES;
}


#pragma mark - Application Notifications

- (void)applicationDidBecomeActive:(NSNotification *)note {
    
    if (self.currentVisit) {
        // Touchpoint Tracking
        [self.currentVisit.currentTouchpoints enumerateObjectsUsingBlock:^(RVTouchpoint *touchpoint, BOOL *stop) {
            [self trackEvent:@"touchpoint.open" params:@{@"touchpoint": touchpoint.ID}];
        }];
        
        // Auto Modal
        if (self.config.autoPresentModal && self.currentVisit.visitedTouchpoints.count > 0) {

            UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
            UIViewController *currentViewController = [Rover findCurrentViewController:rootViewController];
            
            if ([currentViewController isKindOfClass:[RXDetailViewController class]]) {
                [currentViewController dismissViewControllerAnimated:YES completion:nil];
            } else if (![currentViewController isKindOfClass:_config.modalViewControllerClass]) {
                
                [self presentModal];
                NSLog(@"present");
            }
        }
    }

}

#pragma mark - RXVisitViewControllerDelegate

- (void)visitViewController:(RXVisitViewController *)viewController didDisplayCard:(RVCard *)card {
    [self trackEvent:@"card.view" params:@{@"card": card.ID}];
    
    if ([self.delegate respondsToSelector:@selector(roverVisit:didDisplayCard:)]) {
        [self.delegate roverVisit:self.currentVisit didDisplayCard:card];
    }
}

- (void)visitViewController:(RXVisitViewController *)viewController didDiscardCard:(RVCard *)card {
    [self trackEvent:@"card.discard" params:@{@"card": card.ID}];
    
    if ([self.delegate respondsToSelector:@selector(roverVisit:didDiscardCard:)]) {
        [self.delegate roverVisit:self.currentVisit didDiscardCard:card];
    }
}

- (void)visitViewController:(RXVisitViewController *)viewController didClickCard:(RVCard *)card URL:(NSURL *)url {
    [self trackEvent:@"card.click" params:@{@"card": card.ID, @"url": url.absoluteString}];
    
    if ([self.delegate respondsToSelector:@selector(roverVisit:didClickCard:withURL:)]) {
        [self.delegate roverVisit:self.currentVisit didClickCard:card withURL:url];
    }
}

- (void)visitViewControllerDidGetDismissed:(RXVisitViewController *)viewController {
    _modalViewController = nil;
}

@end
