//
//  GroupInfoController.m
//  UIKit
//
//  Created by kennethmiao on 2018/9/26.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "TUIGroupInfoController.h"
#import "TUIProfileCardCell.h"
#import "TUIGroupMembersCell.h"
#import "TUIGroupMemberCell.h"
#import "TUIButtonCell.h"
#import "TCommonSwitchCell.h"
#import "THeader.h"
#import "TUIGroupMemberController.h"
#import "TModifyView.h"
#import "TAddCell.h"
#import "TUILocalStorage.h"
#import "UIImage+TUIKIT.h"
#import "TCommonTextCell.h"
#import "TUIKit.h"
#import "ReactiveObjC/ReactiveObjC.h"
#import "MMLayout/UIView+MMLayout.h"
#import "Toast/Toast.h"
#import "THelper.h"

#define ADD_TAG @"-1"
#define DEL_TAG @"-2"

@import ImSDK;

@interface TUIGroupInfoController () <TModifyViewDelegate, TGroupMembersCellDelegate>
@property (nonatomic, strong) NSMutableArray *data;
@property (nonatomic, strong) NSMutableArray *memberData;
@property (nonatomic, strong) TIMGroupInfo *groupInfo;
@property TIMGroupMemberInfo *selfInfo;
@property TGroupMembersCellData *groupMembersCellData;
@property TCommonTextCellData *groupMembersCountCellData;
@property TCommonTextCellData *addOptionData;
@property TUIProfileCardCellData *profileCellData;
@property TCommonTextCellData *groupNickNameCellData;
@end

@implementation TUIGroupInfoController
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupViews];
    [self updateData];
}

- (void)setupViews
{
    self.title = @"详细资料";
   
    //left
    UIButton *leftButton = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, 30, 30)];
    [leftButton addTarget:self action:@selector(leftBarButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [leftButton setImage:[UIImage imageNamed:TUIKitResource(@"back")] forState:UIControlStateNormal];
    UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithCustomView:leftButton];
    UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spaceItem.width = -10.0f;
    if (([[[UIDevice currentDevice] systemVersion] floatValue] >= 11.0)) {
        leftButton.contentEdgeInsets =UIEdgeInsetsMake(0, -15, 0, 0);
        leftButton.imageEdgeInsets =UIEdgeInsetsMake(0, -15, 0, 0);
    }
    self.navigationItem.leftBarButtonItems = @[spaceItem,leftItem];
    self.parentViewController.navigationItem.leftBarButtonItems = @[spaceItem,leftItem];
    
    self.tableView.tableFooterView = [[UIView alloc] init];
    self.tableView.backgroundColor = TGroupInfoController_Background_Color;
}

- (void)updateData
{
    @weakify(self)
    _memberData = [NSMutableArray array];
    
    [[TIMGroupManager sharedInstance] getGroupInfo:@[_groupId] succ:^(NSArray *arr) {
        @strongify(self)
        if(arr.count == 1){
            self.groupInfo = arr[0];
            [self setupData];
        }
    } fail:^(int code, NSString *msg) {
        [THelper makeToastError:code msg:msg];
    }];
    
    [[TIMGroupManager sharedInstance] getGroupMembers:self.groupId succ:^(NSArray<TIMGroupMemberInfo *> *members) {
        @strongify(self)
        for (NSInteger i = 0; i < members.count; ++i) {
            TIMGroupMemberInfo *member = members[i];
            if([member.member isEqualToString:[TIMManager sharedInstance].getLoginUser]){
                self.selfInfo = member;
            }
            TGroupMemberCellData *data = [[TGroupMemberCellData alloc] init];
            data.identifier = member.member;
            data.name = member.nameCard;
            [self.memberData addObject:data];
        }
        [self setupData];
    } fail:^(int code, NSString *msg) {
        [THelper makeToastError:code msg:msg];
    }];
}

- (void)setupData
{
    _data = [NSMutableArray array];
    if (self.groupInfo) {
        
        NSMutableArray *commonArray = [NSMutableArray array];
        TUIProfileCardCellData *commonData = [[TUIProfileCardCellData alloc] init];
        commonData.avatarUrl = [NSURL URLWithString:self.groupInfo.faceURL];
        commonData.name = self.groupInfo.groupName;
        commonData.identifier = self.groupInfo.group;
        commonData.signature = self.groupInfo.notification;
        
        if([self isMeOwner] || [self isPrivate]){
            commonData.cselector = @selector(didSelectCommon);
            commonData.showAccessory = YES;
        }
        self.profileCellData = commonData;

        [commonArray addObject:commonData];
        [self.data addObject:commonArray];
        
        
        NSMutableArray *memberArray = [NSMutableArray array];
        TCommonTextCellData *countData = [[TCommonTextCellData alloc] init];
        countData.key = @"群成员";
        countData.value = [NSString stringWithFormat:@"%d人", self.groupInfo.memberNum];
        countData.cselector = @selector(didSelectMembers);
        countData.showAccessory = YES;
        self.groupMembersCountCellData = countData;
        [memberArray addObject:countData];
        
        NSMutableArray *tmpArray = [self getShowMembers:self.memberData];
        TGroupMembersCellData *membersData = [[TGroupMembersCellData alloc] init];
        membersData.members = tmpArray;
        [memberArray addObject:membersData];
        self.groupMembersCellData = membersData;
        [self.data addObject:memberArray];

        
        //group info
        NSMutableArray *groupInfoArray = [NSMutableArray array];
        TCommonTextCellData *typeData = [[TCommonTextCellData alloc] init];
        typeData.key = @"群类型";
        typeData.value = [self getShowGroupType:self.groupInfo.groupType];
        [groupInfoArray addObject:typeData];
        
        TCommonTextCellData *addOptionData = [[TCommonTextCellData alloc] init];
        addOptionData.key = @"加群方式";
        
        //私有群禁止加入，只能邀请
        if ([self.groupInfo.groupType isEqualToString:@"Private"]) {
            addOptionData.value = @"邀请加入";
        } else {
            if ([self isMeOwner]) {
                addOptionData.cselector = @selector(didSelectAddOption:);
                addOptionData.showAccessory = YES;
            }
            addOptionData.value = [self getShowAddOption:self.groupInfo.addOpt];
        }
        [groupInfoArray addObject:addOptionData];
        self.addOptionData = addOptionData;
        [self.data addObject:groupInfoArray];
        
        //personal info
        NSMutableArray *personalArray = [NSMutableArray array];
        TCommonTextCellData *nickData = [[TCommonTextCellData alloc] init];
        nickData.key = @"我的群昵称";
        nickData.value = self.selfInfo.nameCard;
        nickData.cselector = @selector(didSelectGroupNick:);
        nickData.showAccessory = YES;
        self.groupNickNameCellData = nickData;
        [personalArray addObject:nickData];
        
        TCommonSwitchCellData *switchData = [[TCommonSwitchCellData alloc] init];
        if ([[[TUILocalStorage sharedInstance] topConversationList] containsObject:self.groupId]) {
            switchData.on = YES;
        }
        switchData.title = @"置顶聊天";
        switchData.cswitchSelector = @selector(didSelectOnTop:);
        [personalArray addObject:switchData];
        
        [self.data addObject:personalArray];
        
        NSMutableArray *buttonArray = [NSMutableArray array];
        TUIButtonCellData *buttonData = [[TUIButtonCellData alloc] init];
        if ([self isMeOwner]) {
            buttonData.title = @"解散该群";
        } else {
            buttonData.title = @"删除并退出";
        }
        buttonData.style = ButtonRedText;
        buttonData.cbuttonSelector = @selector(deleteGroup:);
        [buttonArray addObject:buttonData];
        [self.data addObject:buttonArray];
        
        [self.tableView reloadData];
    }
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _data.count;
}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor clearColor];
    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 20;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSMutableArray *array = _data[section];
    return array.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableArray *array = _data[indexPath.section];
    NSObject *data = array[indexPath.row];
    if([data isKindOfClass:[TUIProfileCardCellData class]]){
        return [(TUIProfileCardCellData *)data heightOfWidth:Screen_Width];
    }
    else if([data isKindOfClass:[TGroupMembersCellData class]]){
        return [TUIGroupMembersCell getHeight:(TGroupMembersCellData *)data];
    }
    else if([data isKindOfClass:[TUIButtonCellData class]]){
        return [(TUIButtonCellData *)data heightOfWidth:Screen_Width];;
    }
    return 44;
}



- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *array = _data[indexPath.section];
    NSObject *data = array[indexPath.row];
    if([data isKindOfClass:[TUIProfileCardCellData class]]){
        TUIProfileCardCell *cell = [tableView dequeueReusableCellWithIdentifier:TGroupCommonCell_ReuseId];
        if(!cell){
            cell = [[TUIProfileCardCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGroupCommonCell_ReuseId];
        }
        [cell fillWithData:(TUIProfileCardCellData *)data];
        return cell;
    }
    else if([data isKindOfClass:[TCommonTextCellData class]]){
        TCommonTextCell *cell = [tableView dequeueReusableCellWithIdentifier:TKeyValueCell_ReuseId];
        if(!cell){
            cell = [[TCommonTextCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TKeyValueCell_ReuseId];
        }
        [cell fillWithData:(TCommonTextCellData *)data];
        return cell;
    }
    else if([data isKindOfClass:[TGroupMembersCellData class]]){
        TUIGroupMembersCell *cell = [tableView dequeueReusableCellWithIdentifier:TGroupMembersCell_ReuseId];
        if(!cell){
            cell = [[TUIGroupMembersCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGroupMembersCell_ReuseId];
            cell.delegate = self;
        }
        [cell setData:(TGroupMembersCellData *)data];
        return cell;
    }
    else if([data isKindOfClass:[TCommonSwitchCellData class]]){
        TCommonSwitchCell *cell = [tableView dequeueReusableCellWithIdentifier:TSwitchCell_ReuseId];
        if(!cell){
            cell = [[TCommonSwitchCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TSwitchCell_ReuseId];
        }
        [cell fillWithData:(TCommonSwitchCellData *)data];
        return cell;
    }
    else if([data isKindOfClass:[TUIButtonCellData class]]){
        TUIButtonCell *cell = [tableView dequeueReusableCellWithIdentifier:TButtonCell_ReuseId];
        if(!cell){
            cell = [[TUIButtonCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TButtonCell_ReuseId];
        }
        [cell fillWithData:(TUIButtonCellData *)data];
        return cell;
    }
    return nil;
}

- (void)leftBarButtonClick:(UIButton *)sender{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)didSelectMembers
{
    if(_delegate && [_delegate respondsToSelector:@selector(groupInfoController:didSelectMembersInGroup:)]){
        [_delegate groupInfoController:self didSelectMembersInGroup:_groupId];
    }
}

- (void)didSelectAddOption:(UITableViewCell *)cell
{
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:@"加群方式" preferredStyle:UIAlertControllerStyleActionSheet];
    
    [ac addAction:[UIAlertAction actionWithTitle:@"禁止加入" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self setGroupAddOpt:TIM_GROUP_ADD_FORBID];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"管理员审批" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self setGroupAddOpt:TIM_GROUP_ADD_AUTH];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"自动审批" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self setGroupAddOpt:TIM_GROUP_ADD_ANY];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)setGroupAddOpt:(TIMGroupAddOpt)opt
{
    @weakify(self)
    [[TIMGroupManager sharedInstance] modifyGroupAddOpt:_groupId opt:opt succ:^{
        @strongify(self)
        self.addOptionData.value = [self getShowAddOption:opt];
    } fail:^(int code, NSString *msg) {
        [THelper makeToastError:code msg:msg];
    }];
}

- (void)didSelectGroupNick:(TCommonTextCell *)cell
{
    TModifyViewData *data = [[TModifyViewData alloc] init];
    data.title = @"修改我的群昵称";
    TModifyView *modify = [[TModifyView alloc] init];
    modify.tag = 2;
    modify.delegate = self;
    [modify setData:data];
    [modify showInWindow:self.view.window];
}

- (void)didSelectCommon
{
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    if ([self isPrivate] || [self isMeOwner]) {
        [ac addAction:[UIAlertAction actionWithTitle:@"修改群名称" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {

            TModifyViewData *data = [[TModifyViewData alloc] init];
            data.title = @"修改群名称";
            TModifyView *modify = [[TModifyView alloc] init];
            modify.tag = 0;
            modify.delegate = self;
            [modify setData:data];
            [modify showInWindow:self.view.window];
            
        }]];
    }
    if ([self isMeOwner]) {
        [ac addAction:[UIAlertAction actionWithTitle:@"修改群公告" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {

            TModifyViewData *data = [[TModifyViewData alloc] init];
            data.title = @"修改群公告";
            TModifyView *modify = [[TModifyView alloc] init];
            modify.tag = 1;
            modify.delegate = self;
            [modify setData:data];
            [modify showInWindow:self.view.window];
        }]];
    }
    
    if ([self.delegate respondsToSelector:@selector(groupInfoController:didSelectChangeAvatar:)]) {
        if ([self isMeOwner]) {
            [ac addAction:[UIAlertAction actionWithTitle:@"修改头像" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [self.delegate groupInfoController:self didSelectChangeAvatar:self.groupId];
            }]];
        }
    }
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)didSelectOnTop:(TCommonSwitchCell *)cell
{
    if (cell.switcher.on) {
        [[TUILocalStorage sharedInstance] addTopConversation:_groupId];
    } else {
        [[TUILocalStorage sharedInstance] removeTopConversation:_groupId];
    }
}


- (void)modifyView:(TModifyView *)modifyView didModiyContent:(NSString *)content
{
    @weakify(self)
    if(modifyView.tag == 0){
        
        [[TIMGroupManager sharedInstance] modifyGroupName:_groupId groupName:content succ:^{
            @strongify(self)
            self.profileCellData.name = content;
        } fail:^(int code, NSString *msg) {
            [THelper makeToastError:code msg:msg];
        }];
    }
    else if(modifyView.tag == 1){
        [[TIMGroupManager sharedInstance] modifyGroupNotification:_groupId notification:content succ:^{
            @strongify(self)
            self.profileCellData.signature = content;
        } fail:^(int code, NSString *msg) {
            [THelper makeToastError:code msg:msg];
        }];
    }
    else if(modifyView.tag == 2){
        NSString *user = [TIMManager sharedInstance].getLoginUser;
        [[TIMGroupManager sharedInstance] modifyGroupMemberInfoSetNameCard:_groupId user:user nameCard:content succ:^{
            @strongify(self)
            self.groupNickNameCellData.value = content;
        } fail:^(int code, NSString *msg) {
            [THelper makeToastError:code msg:msg];
        }];
    }
}

- (void)deleteGroup:(TUIButtonCell *)cell
{
    
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:@"退出后不会再接收到此群聊消息" preferredStyle:UIAlertControllerStyleActionSheet];

    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        
        @weakify(self)
        if ([self canDelete:self.groupInfo]) {
            [[TIMGroupManager sharedInstance] deleteGroup:self.groupId succ:^{
                @strongify(self)
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[TIMManager sharedInstance] deleteConversationAndMessages:TIM_GROUP receiver:self.groupId];
                    if(self.delegate && [self.delegate respondsToSelector:@selector(groupInfoController:didDeleteGroup:)]){
                        [self.delegate groupInfoController:self didDeleteGroup:self.groupId];
                    }
                });
            } fail:^(int code, NSString *msg) {
                [THelper makeToastError:code msg:msg];
            }];
        } else {
            [[TIMGroupManager sharedInstance] quitGroup:self.groupId succ:^{
                @strongify(self)
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[TIMManager sharedInstance] deleteConversationAndMessages:TIM_GROUP receiver:self.groupId];
                    if(self.delegate && [self.delegate respondsToSelector:@selector(groupInfoController:didQuitGroup:)]){
                        [self.delegate groupInfoController:self didQuitGroup:self.groupId];
                    }
                });
            } fail:^(int code, NSString *msg) {
                [THelper makeToastError:code msg:msg];
            }];
        }
    }]];
    
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)groupMembersCell:(TUIGroupMembersCell *)cell didSelectItemAtIndex:(NSInteger)index
{
    TGroupMemberCellData *mem = self.groupMembersCellData.members[index];
    if(mem.tag == 1){
        //add
        if(_delegate && [_delegate respondsToSelector:@selector(groupInfoController:didAddMembersInGroup:members:)]){
            [_delegate groupInfoController:self didAddMembersInGroup:_groupId members:_memberData];
        }
    }
    else if(mem.tag == 2) {
        //delete
        if(_delegate && [_delegate respondsToSelector:@selector(groupInfoController:didDeleteMembersInGroup:members:)]){
            [_delegate groupInfoController:self didDeleteMembersInGroup:_groupId members:_memberData];
        }
    }
    else
    {
        // TODO:
    }
}

- (void)addMembers:(NSArray *)members
{
    for (TAddCellData *addMember in members) {
        TGroupMemberCellData *data = [[TGroupMemberCellData alloc] init];
        data.identifier = addMember.identifier;
        data.name = addMember.name;
        [_memberData addObject:data];
    }
    
    self.groupMembersCountCellData.value = [NSString stringWithFormat:@"%lu人", (unsigned long)_memberData.count];
    self.groupMembersCellData.members = [self getShowMembers:_memberData];
    
    [self.tableView reloadData];
}

- (void)deleteMembers:(NSArray *)members
{
    NSMutableArray *delArray = [NSMutableArray array];
    for (TAddCellData *delMember in members) {
        for (TGroupMemberCellData *member in _memberData) {
            if([delMember.identifier isEqualToString:member.identifier]){
                [delArray addObject:member];
            }
        }
    }
    [_memberData removeObjectsInArray:delArray];
    
    self.groupMembersCountCellData.value = [NSString stringWithFormat:@"%lu人", (unsigned long)_memberData.count];
    self.groupMembersCellData.members = [self getShowMembers:_memberData];

    [self.tableView reloadData];
}

- (NSMutableArray *)getShowMembers:(NSMutableArray *)members
{
    int maxCount = TGroupMembersCell_Column_Count * TGroupMembersCell_Row_Count;
    if ([self canRemoveMember]) maxCount--;
    if ([self canRemoveMember]) maxCount--;
    NSMutableArray *tmpArray = [NSMutableArray array];

    for (NSInteger i = 0; i < members.count && i < maxCount; ++i) {
        [tmpArray addObject:members[i]];
    }
    if ([self canInviteMember]) {
        TGroupMemberCellData *add = [[TGroupMemberCellData alloc] init];
        add.avatarImage = [UIImage tk_imageNamed:@"add"];
        add.tag = 1;
        [tmpArray addObject:add];
    }
    if ([self canRemoveMember]) {
        TGroupMemberCellData *delete = [[TGroupMemberCellData alloc] init];
        delete.avatarImage = [UIImage tk_imageNamed:@"delete"];
        delete.tag = 2;
        [tmpArray addObject:delete];
    }
    return tmpArray;
}

- (NSString *)getShowGroupType:(NSString *)type
{
    if([type isEqualToString:@"Private"]){
        return @"讨论组";
    }
    else if([type isEqualToString:@"Public"]){
        return @"公开群";
    }
    else if([type isEqualToString:@"ChatRoom"]){
        return @"聊天室";
    }
    return @"";
}

- (NSString *)getShowAddOption:(TIMGroupAddOpt )opt
{
    switch (opt) {
        case TIM_GROUP_ADD_FORBID:
            return @"禁止加入";
            break;
        case TIM_GROUP_ADD_AUTH:
            return @"管理员审批";
            break;
        case TIM_GROUP_ADD_ANY:
            return @"自动审批";
            break;
        default:
            break;
    }
    return @"";
}

- (BOOL)canDelete:(TIMGroupInfo *)info
{
    if([self isPrivate]){
        return NO;
    }
    else{
        if([self isMeOwner]) {
            return YES;
        }
        else{
            return NO;
        }
    }
}

- (BOOL)isMeOwner
{
    return [self.groupInfo.owner isEqualToString:[[TIMManager sharedInstance] getLoginUser]];
}

- (BOOL)isPrivate
{
    return [self.groupInfo.groupType isEqualToString:@"Private"];
}

- (BOOL)canInviteMember
{
    if([self.groupInfo.groupType isEqualToString:@"Private"]){
        return YES;
    }
    else if([self.groupInfo.groupType isEqualToString:@"Public"]){
        return NO;
    }
    else if([self.groupInfo.groupType isEqualToString:@"ChatRoom"]){
        return NO;
    }
    return NO;
}

- (BOOL)canRemoveMember
{
    return [self isMeOwner] && (self.memberData.count > 1);
}

@end
