//
//  TContactsController.m
//  TUIKit
//
//  Created by annidyfeng on 2019/3/25.
//  Copyright © 2019年 Tencent. All rights reserved.
//

#import "TUIContactController.h"
#import "THeader.h"
#import "TUIKit.h"
#import "NSString+Common.h"
#import "TUIFriendProfileControllerServiceProtocol.h"
#import "TCServiceManager.h"
#import "ReactiveObjC.h"
#import "MMLayout/UIView+MMLayout.h"
#import "TUIBlackListController.h"
#import "TUINewFriendViewController.h"
#import "TUIConversationListController.h"
#import "TUIChatController.h"
#import "TUIGroupConversationListController.h"
#import "TUIContactActionCell.h"

@import ImSDK;

#define kContactCellReuseId @"ContactCellReuseId"
#define kContactActionCellReuseId @"ContactActionCellReuseId"

@interface TUIContactController () <UITableViewDelegate,UITableViewDataSource,TUIConversationListControllerDelegagte>
@property UITableView *tableView;
@property NSArray<TUIContactActionCellData *> *firstGroupData;
@end

@implementation TUIContactController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSMutableArray *list = @[].mutableCopy;
    [list addObject:({
        TUIContactActionCellData *data = [[TUIContactActionCellData alloc] init];
        data.icon = [UIImage imageNamed:TUIKitResource(@"new_friend")];
        data.title = @"新的联系人";
        data.cselector = @selector(onAddNewFriend:);
        data;
    })];
    [list addObject:({
        TUIContactActionCellData *data = [[TUIContactActionCellData alloc] init];
        data.icon = [UIImage imageNamed:TUIKitResource(@"public_group")];
        data.title = @"群聊";
        data.cselector = @selector(onGroupConversation:);
        data;
    })];
    [list addObject:({
        TUIContactActionCellData *data = [[TUIContactActionCellData alloc] init];
        data.icon = [UIImage imageNamed:TUIKitResource(@"blacklist")];
        data.title = @"黑名单";
        data.cselector = @selector(onBlackList:);
        data;
    })];
    self.firstGroupData = [NSArray arrayWithArray:list];
    
    
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    [self.view addSubview:_tableView];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [_tableView setSectionIndexBackgroundColor:[UIColor clearColor]];
    [_tableView setSectionIndexColor:[UIColor darkGrayColor]];
    [_tableView setBackgroundColor:[UIColor colorWithRed:240.0/255 green:240.0/255 blue:240.0/255 alpha:1]];
    //cell无数据时，不显示间隔线
    UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
    [_tableView setTableFooterView:v];
    
    _tableView.separatorInset = UIEdgeInsetsMake(0, 58, 0, 0);
    
    [_tableView registerClass:[TCommonContactCell class] forCellReuseIdentifier:kContactCellReuseId];
    [_tableView registerClass:[TUIContactActionCell class] forCellReuseIdentifier:kContactActionCellReuseId];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:TUIKitNotification_onAddFriends object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:TUIKitNotification_onDelFriends object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadData) name:TUIKitNotification_onFriendProfileUpdate object:nil];
   
    
    @weakify(self)
    [RACObserve(self.viewModel, isLoadFinished) subscribeNext:^(id finished) {
        @strongify(self)
        if ([(NSNumber *)finished boolValue]) {
            [self.tableView reloadData];
        }
    }];
    [RACObserve(self.viewModel, pendencyCnt) subscribeNext:^(NSNumber *x) {
        self.firstGroupData[0].redNum = [x integerValue];
    }];
    [self reloadData];
}

- (TContactViewModel *)viewModel
{
    if (_viewModel == nil) {
        _viewModel = [TContactViewModel new];
    }
    return _viewModel;
}


- (void)reloadData {
    [_viewModel loadContacts];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
{
    return self.viewModel.groupList.count + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.firstGroupData.count;
    } else {
        NSString *group = self.viewModel.groupList[section-1];
        NSArray *list = self.viewModel.dataDict[group];
        return list.count;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 0)
        return nil;
    
#define TEXT_TAG 1
    static NSString *headerViewId = @"ContactDrawerView";
    UITableViewHeaderFooterView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:headerViewId];
    if (!headerView)
    {
        headerView = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:headerViewId];
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        textLabel.tag = TEXT_TAG;
        textLabel.font = [UIFont systemFontOfSize:16];
        textLabel.textColor = RGB(0x80, 0x80, 0x80);
        [headerView addSubview:textLabel];
        textLabel.mm_fill().mm_left(12);
        textLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    }
    UILabel *label = [headerView viewWithTag:TEXT_TAG];
    label.text = self.viewModel.groupList[section-1];
    
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 56;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0)
        return 0;
    
    return 33;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    NSMutableArray *array = [NSMutableArray arrayWithObject:@""];
    [array addObjectsFromArray:self.viewModel.groupList];
    return array;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        TUIContactActionCell *cell = [tableView dequeueReusableCellWithIdentifier:kContactActionCellReuseId forIndexPath:indexPath];
        [cell fillWithData:self.firstGroupData[indexPath.row]];
        return cell;
    } else {
        TCommonContactCell *cell = [tableView dequeueReusableCellWithIdentifier:kContactCellReuseId forIndexPath:indexPath];
        NSString *group = self.viewModel.groupList[indexPath.section-1];
        NSArray *list = self.viewModel.dataDict[group];
        TCommonContactCellData *data = list[indexPath.row];
        data.cselector = @selector(onSelectFriend:);
        [cell fillWithData:data];
        return cell;
    }
}

- (void)onSelectFriend:(TCommonContactCell *)cell
{
    TCommonContactCellData *data = cell.contactData;
    
    id<TUIFriendProfileControllerServiceProtocol> vc = [[TCServiceManager shareInstance] createService:@protocol(TUIFriendProfileControllerServiceProtocol)];
    if ([vc isKindOfClass:[UIViewController class]]) {
        vc.friendProfile = data.friendProfile;
        [self.navigationController pushViewController:(UIViewController *)vc animated:YES];
    }
}


//
- (void)onAddNewFriend:(TCommonTableViewCell *)cell
{
    TUINewFriendViewController *vc = TUINewFriendViewController.new;
    [self.navigationController pushViewController:vc animated:YES];
    [self.viewModel clearPendencyCnt];
}

- (void)onGroupConversation:(TCommonTableViewCell *)cell
{
    TUIGroupConversationListController *vc = TUIGroupConversationListController.new;
    vc.title = @"群聊";
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)onBlackList:(TCommonContactCell *)cell
{
    TUIBlackListController *vc = TUIBlackListController.new;
    [self.navigationController pushViewController:vc animated:YES];
}


- (void)conversationListController:(TUIConversationListController *)conversationController didSelectConversation:(TUIConversationCell *)conversation;
{
    TIMConversation *conv = [[TIMManager sharedInstance] getConversation:conversation.convData.convType receiver:conversation.convData.convId];
    TUIChatController *chat = [[TUIChatController alloc] initWithConversation:conv];
    chat.title = conversation.convData.title;
    [self.navigationController pushViewController:chat animated:YES];
}
@end
