//
//  UserTimelineController.m
//  CarWeibo
//
//  Created by zhe wang on 11-10-28.
//  Copyright (c) 2011年 nasa.wang. All rights reserved.
//

#import "UserTimelineController.h"
#import "UserTimelineDataSource.h"
#import "CarWeiboAppDelegate.h"
#import "ColorUtils.h"

@interface UserTimelineController (Private)
- (void)scrollToFirstUnread;
- (void)didLeaveTab:(UINavigationController*)navigationController;
@end

@implementation UserTimelineController
@synthesize refreshHeaderView;
@synthesize navController;

- (id)initWithNavController:(UINavigationController *)controller User:(User *)aUser {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        navController = controller;
        user = aUser;
    }
    return self;
}

- (void)viewDidLoad
{
    
    timelineDataSource = [[UserTimelineDataSource alloc] initWithController:self tweetType:TWEET_TYPE_USER User:user];
    self.tableView.dataSource = timelineDataSource;
    self.tableView.delegate   = timelineDataSource;
    
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
    if (!isLoaded) {
        
        
        [self loadTimeline];
        //        [self restoreAndLoadTimeline:YES];
    }
    
    if (refreshHeaderView == nil) {
		
		WZRefreshTableHeaderView *view1 = [[WZRefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, self.view.frame.size.width, self.tableView.bounds.size.height)];
		view1.delegate = timelineDataSource;
		[self.tableView addSubview:view1];
		refreshHeaderView = view1;
		[view1 release];
        
	}
	
	//  update the last update date
	[refreshHeaderView refreshLastUpdatedDate];
}


- (void) dealloc
{
    refreshHeaderView=nil;
    [super dealloc];
}



- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.tableView setContentOffset:contentOffset animated:false];
    [self.tableView reloadData];
    self.navigationController.navigationBar.tintColor = [UIColor navigationColorForTab:tab];
    self.tableView.separatorColor = [UIColor lightGrayColor]; 
    
    CarWeiboAppDelegate *delegate = [CarWeiboAppDelegate getAppDelegate];
    [delegate.rootViewController.navigation setStyle:NAV_NORMAL];
    //    [delegate.rootViewController hideTabBar];
    
    
    UIButton* backButton = [delegate.rootViewController.navigation backButtonWith:[UIImage imageNamed:@"nav_btn_back.png"] highlight:nil leftCapWidth:14.0];
    [backButton addTarget:self action:@selector(back:) forControlEvents:UIControlEventTouchUpInside];
    delegate.rootViewController.navigation.leftButton = backButton;
    
    delegate.rootViewController.navigation.rightButton = nil;
    
    
    [[GANTracker sharedTracker] trackPageview:@"/user_timeline"
                                    withError:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (firstTimeToAppear) {
        firstTimeToAppear = false;
        [self scrollToFirstUnread];
    }
	[super viewDidAppear:animated];
    if (stopwatch) {
        LAP(stopwatch, @"viewDidAppear");
        [stopwatch release];
        stopwatch = nil;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    contentOffset = self.tableView.contentOffset;
}

- (void)viewDidDisappear:(BOOL)animated 
{
}

- (void)didReceiveMemoryWarning 
{
#if 0
    CarWeiboAppDelegate *appDelegate = (CarWeiboAppDelegate*)[UIApplication sharedApplication].delegate;
    if (appDelegate.selectedTab != [self navigationController].tabBarItem.tag) {
        [super didReceiveMemoryWarning];
    }
#endif
}

//
// Public methods
//

- (void)back:(id)sender {
    
    
    [[GANTracker sharedTracker] trackEvent:@"UserInfoView"
                                    action:@"touchDown"
                                     label:@"back"
                                     value:-1
                                 withError:nil];
    
    CarWeiboAppDelegate *delegate = [CarWeiboAppDelegate getAppDelegate];
    delegate.rootViewController.navigation.leftButton = nil;
    
    [delegate.rootViewController.navigation setStyle:NAV_NORMAL];
    //    [delegate.rootViewController showTabBar];
    
    
    [navController popViewControllerAnimated:YES];
    
}

- (void)loadTimeline
{
    [timelineDataSource getTimeline];
    isLoaded = true;
}

- (void)restoreAndLoadTimeline:(BOOL)load
{
    firstTimeToAppear = true;
    stopwatch = [[Stopwatch alloc] init];
    tab       = 0;
    
    if (load) [self loadTimeline];
}

- (IBAction) reload:(id) sender
{
    self.navigationItem.leftBarButtonItem.enabled = false;
    [timelineDataSource getTimeline];
}

- (void)autoRefresh
{
    [self reload:nil];
}

- (void)postViewAnimationDidFinish
{
    if (self.navigationController.topViewController != self) return;
    
    
    if (tab == TAB_FRIENDS) {
        //
        // Do animation if the controller displays friends timeline or sent direct messages.
        //
        NSArray *indexPaths = [NSArray arrayWithObjects:[NSIndexPath indexPathForRow:0 inSection:0], nil];
        [self.tableView beginUpdates];
        [self.tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationTop];
        [self.tableView endUpdates];
    }
    
}

- (void)postTweetDidSucceed:(Status*)status
{
    if (tab == TAB_FRIENDS) {
        [timelineDataSource.timeline insertStatus:status atIndex:0];
    }
}

//
// TwitterFonApPDelegate delegate
//
- (void)didLeaveTab:(UINavigationController*)navigationController
{
    navigationController.tabBarItem.badgeValue = nil;
    for (int i = 0; i < [timelineDataSource.timeline countStatuses]; ++i) {
        Status* sts = [timelineDataSource.timeline statusAtIndex:i];
        sts.unread = false;
    }
    unread = 0;
}


- (void) removeStatus:(Status*)status
{
    [timelineDataSource.timeline removeStatus:status];
    [self.tableView reloadData];
}

- (void) updateFavorite:(Status*)status
{
    [timelineDataSource.timeline updateFavorite:status];
}

- (void)scrollToFirstUnread
{
    BOOL flag = [[NSUserDefaults standardUserDefaults] boolForKey:@"autoScrollToFirstUnread"];
    if (flag == false) return;
    
    if (unread) {
        if (unread < [timelineDataSource.timeline countStatuses]) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:unread inSection:0];
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition: UITableViewScrollPositionBottom animated:true];
        }
    }
}

//
// TimelineDelegate
//
- (void)timelineDidUpdate:(UserTimelineDataSource*)sender count:(int)count insertAt:(int)position
{
    //    self.navigationItem.leftBarButtonItem.enabled = true;
    //    
    //    if (self.navigationController.tabBarController.selectedIndex == tab &&
    //        self.navigationController.topViewController == self) {
    
    [self.tableView beginUpdates];
    if (position) {
        NSMutableArray *deletion = [[[NSMutableArray alloc] init] autorelease];
        [deletion addObject:[NSIndexPath indexPathForRow:position inSection:0]];
        [self.tableView deleteRowsAtIndexPaths:deletion withRowAnimation:UITableViewRowAnimationBottom];
    }
    if (count != 0) {
        NSMutableArray *insertion = [[[NSMutableArray alloc] init] autorelease];
        
        int numInsert = count;
        // Avoid to create too many table cell.
        //            if (numInsert > 8) numInsert = 8;
        for (int i = 0; i < numInsert; ++i) {
            [insertion addObject:[NSIndexPath indexPathForRow:position + i inSection:0]];
        }        
        [self.tableView insertRowsAtIndexPaths:insertion withRowAnimation:UITableViewRowAnimationTop];
    }
    [self.tableView endUpdates];
    
    if (position == 0 && unread == 0) {
        [self performSelector:@selector(scrollToFirstUnread) withObject:nil afterDelay:0.4];
    }
    //    }
    if (count) {
        unread += count;
        //        [self navigationController].tabBarItem.badgeValue = [NSString stringWithFormat:@"%d", unread];
    }
}

- (void)timelineDidFailToUpdate:(UserTimelineDataSource*)sender position:(int)position
{
    //    self.navigationItem.leftBarButtonItem.enabled = true;
}

@end
