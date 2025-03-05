// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Manager } from "../../src/Manager.sol";
import { ManagerContainer } from "../../src/ManagerContainer.sol";

import { Staker } from "../../src/Staker.sol";

import { IStaker } from "../../src/interfaces/core/IStaker.sol";
import { SampleOracle } from "../utils/mocks/SampleOracle.sol";
import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract StakerTest is Test {
    event SavedFunds(address indexed token, uint256 amount);
    event RewardsDurationUpdated(uint256 newDuration);
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    address internal OWNER = vm.addr(uint256(keccak256(bytes("Owner"))));
    address internal tokenIn;
    address internal rewardToken;

    Manager internal manager;
    ManagerContainer internal managerContainer;
    SampleTokenERC20 internal usdc;
    SampleTokenERC20 internal weth;
    Staker internal staker;

    function setUp() public {
        vm.warp(1_641_070_800);
        vm.startPrank(OWNER, OWNER);

        usdc = new SampleTokenERC20("USDC", "USDC", 0);
        weth = new SampleTokenERC20("WETH", "WETH", 0);
        SampleOracle jUsdOracle = new SampleOracle();
        manager = new Manager(OWNER, address(usdc), address(weth), address(jUsdOracle), bytes(""));
        managerContainer = new ManagerContainer(address(this), address(manager));

        tokenIn = address(new SampleTokenERC20("TokenIn", "TI", 0));
        rewardToken = address(new SampleTokenERC20("RewardToken", "RT", 0));

        staker = new Staker(OWNER, tokenIn, rewardToken, 365 days);
        vm.stopPrank();
    }

    // Checks if initial state of the contract is correct
    function test_staker_initialState() public {
        assertEq(staker.tokenIn(), tokenIn, "TokenIn set up incorrect");
        assertEq(staker.rewardToken(), rewardToken, "Reward token set up incorrect");
        assertEq(staker.owner(), OWNER, "Owner set up incorrect");
    }

    // Tests if initialization of the contract with invalid TokenIn address reverts correctly
    function test_init_staker_when_invalidTokenIn() public {
        vm.expectRevert(bytes("3000"));
        Staker failedStaker = new Staker(address(this), address(0), rewardToken, 365 days);
        failedStaker;
    }

    // Tests if initialization of the contract with invalid RewardToken address reverts correctly
    function test_init_staker_when_invalidRewardToken() public {
        vm.expectRevert(bytes("3000"));
        Staker failedStaker = new Staker(address(this), tokenIn, address(0), 365 days);
        failedStaker;
    }

    // Tests setting contract paused from non-Owner's address
    function test_setPaused_when_unauthorized(
        address _caller
    ) public {
        vm.assume(_caller != staker.owner());
        vm.prank(_caller, _caller);
        vm.expectRevert();

        staker.pause();
    }

    // Tests setting contract paused from Owner's address
    function test_setPaused_when_authorized() public {
        vm.startPrank(OWNER, OWNER);
        staker.pause();
        assertEq(staker.paused(), true);

        staker.unpause();
        assertEq(staker.paused(), false);
        vm.stopPrank();
    }

    // Tests if setRewardsDuration reverts correctly when caller is unauthorized
    function test_setRewardsDuration_when_unauthorized(
        address _caller
    ) public {
        vm.assume(_caller != staker.owner());
        vm.prank(_caller, _caller);
        vm.expectRevert();
        staker.setRewardsDuration(1);
    }

    // Tests if setRewardsDuration reverts correctly when previous rewards period hasn't finished yet
    function test_setRewardsDuration_when_periodNotEnded() public {
        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(bytes("3087"));
        staker.setRewardsDuration(1);
        vm.stopPrank();
    }

    // Tests if setRewardsDuration works correctly when authorized
    function test_setRewardsDuration_when_authorized(
        uint256 _amount
    ) public {
        vm.warp(block.timestamp + staker.rewardsDuration() + 1);
        vm.startPrank(OWNER, OWNER);
        vm.expectEmit();
        emit RewardsDurationUpdated(_amount);
        staker.setRewardsDuration(_amount);
        vm.stopPrank();

        assertEq(staker.rewardsDuration(), _amount, "Rewards duration set incrorect");
    }

    // Tests if addRewards reverts correctly when caller is unauthorized
    function test_addRewards_when_unauthorized(
        address _caller
    ) public {
        vm.assume(_caller != staker.owner());
        vm.prank(_caller, _caller);
        vm.expectRevert();
        staker.addRewards(address(1), 1);
    }

    // Tests if addRewards reverts correctly when amount == 0
    function test_addRewards_when_invalidAmount() public {
        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("2001"));
        staker.addRewards(address(1), 0);
    }

    // Tests if addRewards reverts correctly when rewardsDuration == 0
    function test_addRewards_when_rewardsDuration0() public {
        // We fast forward to the period when current reward distribution ends,
        // so we can change the reward duration
        vm.warp(block.timestamp + staker.rewardsDuration() + 1);

        mintRewardsAndApprove(OWNER, 100_000_000_000);

        vm.startPrank(OWNER, OWNER);
        staker.setRewardsDuration(0);
        vm.expectRevert(bytes("3089"));
        staker.addRewards(OWNER, 1);
        vm.stopPrank();
    }

    // Tests if addRewards reverts correctly when _amount is small, which leads to rewardRate being 0
    function test_addRewards_when_amountTooSmall(
        uint256 _amount
    ) public {
        vm.assume(_amount != 0 && _amount / staker.rewardsDuration() == 0);

        mintRewardsAndApprove(OWNER, _amount);

        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("3088"));
        staker.addRewards(address(OWNER), _amount);
    }

    // Tests if addRewards works correctly when block.timestamp >= periodFinish
    function test_addRewards_when_periodFinished(
        uint256 _amount
    ) public {
        vm.assume(_amount / staker.rewardsDuration() != 0);
        // We fast forward to the period when current reward distribution ends,
        // so we can test block.timestamp >= periodFinish branch
        vm.warp(block.timestamp + staker.rewardsDuration() + 1);

        mintRewardsAndApprove(OWNER, _amount);

        vm.startPrank(OWNER, OWNER);
        vm.expectEmit();
        emit RewardAdded(_amount);
        staker.addRewards(address(OWNER), _amount);

        assertEq(staker.rewardRate(), _amount / staker.rewardsDuration(), "Rewards added incorrectly");
    }

    // Tests if addRewards works correctly when block.timestamp < periodFinish
    function test_addRewards_when_periodNotFinished(
        uint256 _amount
    ) public {
        vm.assume(_amount / staker.rewardsDuration() != 0);

        mintRewardsAndApprove(OWNER, _amount);

        vm.startPrank(OWNER, OWNER);
        vm.expectEmit();
        emit RewardAdded(_amount);
        staker.addRewards(address(OWNER), _amount);

        assertEq(staker.rewardRate(), _amount / staker.rewardsDuration(), "Rewards added incorrectly");
    }

    // Tests if totalSuply works correctly
    function test_totalSupply(uint256 _amount, address _caller) public {
        vm.assume(_amount != 0 && _amount <= 1e34);
        vm.assume(_caller != address(0));

        deal(rewardToken, address(staker), 1);
        deal(tokenIn, _caller, _amount);

        vm.startPrank(_caller, _caller);
        IERC20Metadata(tokenIn).approve(address(staker), _amount);
        staker.deposit(_amount);
        vm.stopPrank();

        assertEq(staker.totalSupply(), _amount, "Total supply incorrect");
    }

    // Tests if balanceOf works correctly
    function test_balanceOf(uint256 _amount, address _caller) public {
        vm.assume(_amount != 0 && _amount <= 1e34);
        vm.assume(_caller != address(0));

        deal(rewardToken, address(staker), 1);
        deal(tokenIn, _caller, _amount);

        vm.startPrank(_caller, _caller);
        IERC20Metadata(tokenIn).approve(address(staker), _amount);
        staker.deposit(_amount);
        vm.stopPrank();

        assertEq(staker.balanceOf(_caller), _amount, "Balance of investor incorrect");
    }

    // Tests if lastTimeRewardApplicable works correctly
    function test_lastTimeRewardApplicable() public {
        assertEq(
            staker.lastTimeRewardApplicable(),
            block.timestamp < staker.periodFinish() ? block.timestamp : staker.periodFinish(),
            "lastTimeRewardApplicable incorrect"
        );
    }

    // Tests if rewardPerToken works correctly
    function test_rewardPerToken_when_totalSupplyNot0(
        uint256 investment
    ) public {
        vm.assume(investment != 0 && investment < 1e34);
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));
        deal(tokenIn, investor, investment);

        mintRewardsAndApprove(OWNER, 1e18);

        vm.prank(OWNER, OWNER);
        staker.addRewards(OWNER, 1e18);

        vm.startPrank(investor, investor);
        IERC20Metadata(tokenIn).approve(address(staker), investment);
        staker.deposit(investment);
        vm.stopPrank();

        // We fast forward 10 days to have some rewards generated
        uint256 warpAmount = 10 days;
        vm.warp(block.timestamp + warpAmount);

        assertEq(
            staker.rewardPerToken(),
            staker.rewardPerTokenStored() + ((warpAmount * staker.rewardRate() * 1e18) / staker.totalSupply()),
            "Reward per token incorrect"
        );
    }

    // Tests if getRewardForDuration works correctly
    function test_getRewardForDuration(
        uint256 _amount
    ) public {
        vm.assume(_amount / staker.rewardsDuration() != 0);
        mintRewardsAndApprove(OWNER, _amount);

        vm.prank(OWNER, OWNER);
        staker.addRewards(OWNER, _amount);

        assertEq(
            staker.getRewardForDuration(),
            staker.rewardRate() * staker.rewardsDuration(),
            "RewardForDuration incorrect "
        );
    }

    // Tests if deposit reverts correctly when invalid amount
    function test_deposit_when_invalidAmount() public {
        vm.expectRevert(bytes("2001"));
        staker.deposit(0);
    }

    // Tests if deposit reverts correctly when paused
    function test_deposit_when_paused() public {
        vm.prank(staker.owner(), staker.owner());
        staker.pause();

        vm.expectRevert();
        staker.deposit(1);
    }

    // Tests if deposit reverts correctly when contract's reward balance is insufficient
    function test_deposit_when_insufficientRewards() public {
        vm.expectRevert(bytes("3090"));
        staker.deposit(1);
    }

    // Tests if deposit reverts correctly when reached supply limit
    function test_deposit_when_reachedSupplyLimit() public {
        deal(staker.rewardToken(), address(staker), 1);
        vm.expectRevert(bytes("3091"));
        staker.deposit(type(uint256).max);
    }

    // Tests if deposit works correctly
    function test_deposit_when_authorized(
        uint256 investment
    ) public {
        vm.assume(investment != 0 && investment < 1e34);
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));

        deal(rewardToken, address(OWNER), 1e18);
        deal(tokenIn, investor, investment);

        vm.startPrank(OWNER, OWNER);
        IERC20Metadata(rewardToken).approve(address(staker), type(uint256).max);
        staker.addRewards(OWNER, 1e18);
        vm.stopPrank();

        vm.startPrank(investor, investor);
        IERC20Metadata(tokenIn).approve(address(staker), investment);
        vm.expectEmit();
        emit Staked(investor, investment);
        staker.deposit(investment);
        vm.stopPrank();

        assertEq(staker.balanceOf(investor), investment, "Investor's balance after deposit incorrect");
        assertEq(staker.totalSupply(), investment, "Total supply after deposit incorrect");
    }

    // Tests if withdraw reverts correctly when invalid amount
    function test_withdraw_when_invalidAmount() public {
        vm.expectRevert(bytes("2001"));
        staker.withdraw(0);
    }

    // Tests if withdraw works correctly when authorized
    function test_withdraw_when_authorized(
        uint256 investment
    ) public {
        vm.assume(investment != 0 && investment < 1e34);
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));

        deal(rewardToken, address(OWNER), 1e18);
        deal(tokenIn, investor, investment);

        vm.startPrank(OWNER, OWNER);
        IERC20Metadata(rewardToken).approve(address(staker), type(uint256).max);
        staker.addRewards(OWNER, 1e18);
        vm.stopPrank();

        vm.startPrank(investor, investor);
        IERC20Metadata(tokenIn).approve(address(staker), investment);
        staker.deposit(investment);
        vm.expectEmit();
        emit Withdrawn(investor, investment);
        staker.withdraw(investment);
        vm.stopPrank();

        assertEq(staker.balanceOf(investor), 0, "Investor's balance after withdraw incorrect");
        assertEq(staker.totalSupply(), 0, "Total supply after withdraw incorrect");
    }

    // Tests if claimRewards reverts correctly when there are no rewards to claim
    function test_claimRewards_when_noRewards() public {
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));
        uint256 investorRewardBalanceBefore = IERC20Metadata(rewardToken).balanceOf(investor);

        vm.startPrank(investor, investor);
        vm.expectRevert(bytes("3092"));
        staker.claimRewards();

        assertEq(
            IERC20Metadata(rewardToken).balanceOf(investor),
            investorRewardBalanceBefore,
            "Investor wrongfully got rewards when never deposited"
        );
    }

    // Tests if claimRewards fails if user has already withdrawn his investment
    function test_claimRewards_when_investmentWithdrawn(
        uint256 investment
    ) public {
        vm.assume(investment > 2 && investment < 1e25);
        address investor1 = vm.addr(uint256(keccak256(bytes("Investor1"))));
        address investor2 = vm.addr(uint256(keccak256(bytes("Investor2"))));

        deal(rewardToken, address(OWNER), 1e18);
        deal(tokenIn, investor1, investment);
        deal(tokenIn, investor2, investment / 2);

        vm.startPrank(OWNER, OWNER);
        IERC20Metadata(rewardToken).approve(address(staker), type(uint256).max);
        staker.addRewards(OWNER, 1e18);
        vm.stopPrank();

        vm.startPrank(investor1, investor1);
        IERC20Metadata(tokenIn).approve(address(staker), investment);
        staker.deposit(investment);
        vm.stopPrank();

        vm.startPrank(investor2, investor2);
        IERC20Metadata(tokenIn).approve(address(staker), investment / 2);
        staker.deposit(investment / 2);
        vm.stopPrank();

        vm.warp(block.timestamp + 30 days);
        uint256 rewardsPerTokenBeforeExit = staker.rewardPerToken();

        vm.prank(investor1, investor1);
        staker.exit();

        vm.warp(block.timestamp + 30 days);

        assertEq(staker.rewards(investor1), 0, "Investor wrongfully got rewards after full withdrawal");
        assertGt(staker.rewardPerToken(), rewardsPerTokenBeforeExit, "rewardPerToken didn't increase");
    }

    // Tests if claimRewards works correctly when authorized
    function test_claimRewards_when_authorized(
        uint256 investment
    ) public {
        vm.assume(investment != 0 && investment < 1e34);
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));
        uint256 stakerRewardBalance = 1e18;

        deal(tokenIn, investor, investment);
        mintRewardsAndApprove(OWNER, stakerRewardBalance);

        vm.prank(OWNER, OWNER);
        staker.addRewards(OWNER, 1e18);

        vm.startPrank(investor, investor);
        IERC20Metadata(tokenIn).approve(address(staker), investment);
        staker.deposit(investment);
        // We fast forward 10 days to have some rewards generated
        uint256 warpAmount = 10 days;
        vm.warp(block.timestamp + warpAmount);
        uint256 investorRewards = staker.earned(investor);
        vm.expectEmit();
        emit RewardPaid(investor, investorRewards);
        staker.claimRewards();
        vm.stopPrank();

        assertEq(
            IERC20Metadata(rewardToken).balanceOf(investor),
            investorRewards,
            "Investor's reward balance wrong after claimRewards"
        );
        assertEq(
            IERC20Metadata(rewardToken).balanceOf(address(staker)),
            stakerRewardBalance - investorRewards,
            "Staker's reward balance wrong after claimRewards"
        );
        assertEq(staker.rewards(investor), 0, "Investor's rewards count didn't change  after claimRewards");
    }

    // Tests if exit works correctly when authorized
    function test_exit_when_authorized(
        uint256 investment
    ) public {
        vm.assume(investment != 0 && investment < 1e34);
        address investor = vm.addr(uint256(keccak256(bytes("Investor"))));
        uint256 stakerRewardBalance = 1e18;
        deal(tokenIn, investor, investment);

        mintRewardsAndApprove(OWNER, stakerRewardBalance);

        vm.prank(OWNER, OWNER);
        staker.addRewards(OWNER, stakerRewardBalance);

        vm.startPrank(investor, investor);

        IERC20Metadata(tokenIn).approve(address(staker), investment);
        staker.deposit(investment);

        // We fast forward 10 days to have some rewards generated
        uint256 warpAmount = 10 days;
        vm.warp(block.timestamp + warpAmount);

        uint256 investorRewards = staker.earned(investor);

        vm.expectEmit();
        emit Withdrawn(investor, investment);

        emit RewardPaid(investor, investorRewards);
        staker.exit();

        vm.stopPrank();

        assertEq(staker.balanceOf(investor), 0, "Investor's balance after exit incorrect");
        assertEq(staker.totalSupply(), 0, "Total supply after exit incorrect");
        assertEq(
            IERC20Metadata(rewardToken).balanceOf(investor),
            investorRewards,
            "Investor's reward balance wrong after claimRewards"
        );
        assertEq(
            IERC20Metadata(rewardToken).balanceOf(address(staker)),
            stakerRewardBalance - investorRewards,
            "Staker's reward balance wrong after claimRewards"
        );
        assertEq(staker.rewards(investor), 0, "Investor's rewards count didn't change  after claimRewards");
    }

    //Tests if renouncing ownership reverts correctly
    function test_renounceOwnership_staker() public {
        vm.expectRevert(bytes("1000"));
        staker.renounceOwnership();
    }

    function mintRewardsAndApprove(address _user, uint256 _amount) private {
        vm.startPrank(_user, _user);
        deal(rewardToken, _user, _amount);
        IERC20Metadata(rewardToken).approve(address(staker), _amount);
        vm.stopPrank();
    }
}
