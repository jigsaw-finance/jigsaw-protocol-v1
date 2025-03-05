pragma solidity ^0.8.20;

import "forge-std/console.sol";

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { Staker } from "../../src/Staker.sol";
import { IStaker } from "../../src/interfaces/core/IStaker.sol";

contract StakerInvariantTestHandler is CommonBase, StdCheats, StdUtils {
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal OWNER;
    Staker internal staker;
    address internal tokenIn;
    address internal rewardToken;

    address[] public USER_ADDRESSES = [
        address(uint160(uint256(keccak256("user1")))),
        address(uint160(uint256(keccak256("user2")))),
        address(uint160(uint256(keccak256("user3")))),
        address(uint160(uint256(keccak256("user4")))),
        address(uint160(uint256(keccak256("user5"))))
    ];

    EnumerableSet.AddressSet internal investorsSet;

    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public totalRewardsAmount;
    uint256 public totalRewardsClaimed;

    constructor(address _owner, Staker _staker, address _tokenIn, address _rewardToken) {
        OWNER = _owner;
        staker = _staker;
        tokenIn = _tokenIn;
        rewardToken = _rewardToken;
    }

    // Make a deposit for a user
    function deposit(uint256 amount, uint256 user_idx) public virtual {
        address user = pickUpUser(user_idx);

        amount = bound(amount, 1, 1e34);

        if (IERC20Metadata(tokenIn).balanceOf(user) < amount) {
            deal(tokenIn, user, amount);
        }

        vm.startPrank(user, user);
        IERC20Metadata(tokenIn).approve(address(staker), amount);
        staker.deposit(amount);
        vm.stopPrank();

        totalDeposited += amount;
        investorsSet.add(user);
    }

    // Withdraw deposit for a user
    function withdraw(uint256 amount, uint256 user_idx) external {
        address user = pickUpUserFromInvestors(user_idx);
        if (user == address(0)) return;

        uint256 userBalance = staker.balanceOf(user);
        uint256 withdrawAmount = bound(amount, 1, userBalance);

        vm.prank(user);
        staker.withdraw(withdrawAmount);

        if (withdrawAmount == userBalance) investorsSet.remove(user);

        totalWithdrawn += withdrawAmount;
    }

    // Claim rewards for a user
    function claimRewards(uint256 user_idx, uint256 time) external {
        time = bound(time, 30 minutes, 1 days);
        vm.warp(block.timestamp + time);

        if (block.timestamp >= staker.periodFinish()) return;

        address user = pickUpUserFromInvestors(user_idx);

        if (totalRewardsAmount == 0) return;

        uint256 userRewards = staker.earned(user);
        if (userRewards == 0) return;

        vm.prank(user);
        staker.claimRewards();
    }

    // Owner's handlers

    function addRewards(
        uint256 _rewards
    ) external {
        _rewards = bound(_rewards, 1e18, 1000e18);

        if (investorsSet.length() == 0) return;

        deal(rewardToken, OWNER, _rewards);
        vm.prank(OWNER, OWNER);
        IERC20Metadata(rewardToken).approve(address(staker), _rewards);
        staker.addRewards(OWNER, _rewards);

        totalRewardsAmount += _rewards;
    }

    // Utility functions

    function pickUpUser(
        uint256 user_idx
    ) public view returns (address) {
        user_idx = user_idx % USER_ADDRESSES.length;
        return USER_ADDRESSES[user_idx];
    }

    function pickUpUserFromInvestors(
        uint256 user_idx
    ) public view returns (address) {
        uint256 investorsNumber = investorsSet.length();
        if (investorsNumber == 0) return address(0);

        user_idx = bound(user_idx, 0, investorsNumber - 1);

        return investorsSet.at(user_idx);
    }

    function getUserRewards() public view returns (uint256 userRewards) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            userRewards += staker.earned(USER_ADDRESSES[i]);
        }
    }
}
