pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Staker } from "../../src/Staker.sol";

import { IStaker } from "../../src/interfaces/core/IStaker.sol";

import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";
import { StakerInvariantTestHandler } from "./StakerInvariantTestHandler.t.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract StakerInvariantTest is Test {
    address internal OWNER = vm.addr(uint256(keccak256(bytes("Owner"))));
    address internal tokenIn;
    address internal rewardToken;

    StakerInvariantTestHandler private handler;
    Staker internal staker;

    function setUp() external {
        vm.warp(1_641_070_800);
        vm.startPrank(OWNER, OWNER);

        tokenIn = address(new SampleTokenERC20("TokenIn", "TI", 0));
        rewardToken = address(new SampleTokenERC20("RewardToken", "RT", 0));
        staker = new Staker(OWNER, tokenIn, rewardToken, 365 days);

        vm.stopPrank();

        handler = new StakerInvariantTestHandler(OWNER, staker, tokenIn, rewardToken);
        targetContract(address(handler));
    }

    // Test that staker's tokenIn balance is correct at all times
    function invariant_staker_tokenInBalance_equals_tracked_deposits() external {
        assertEq(
            handler.totalDeposited() - handler.totalWithdrawn(),
            IERC20(tokenIn).balanceOf(address(staker)),
            "Staker's tokenIn balance incorrect"
        );
    }

    // Test that staker's reward token's balance is correct at all times
    function invariant_staker_rewardTokenBalance_equals_tracked_deposits() external {
        assertEq(
            handler.totalRewardsAmount() - handler.totalRewardsClaimed(),
            IERC20(rewardToken).balanceOf(address(staker)),
            "Staker's reward token balance incorrect"
        );
    }

    // Test that the total of all deposits is equal to the pool's totalSupply
    function invariant_staker_totalSupply_equal_deposits() public {
        assertGe(
            staker.totalSupply(), handler.totalDeposited() - handler.totalWithdrawn(), "Staker's total supply incorrect"
        );
    }

    // Test that the sum of all user rewards is equal to the the sum of all amounts of rewards distributed
    function invariant_total_rewards() external {
        assertEq(handler.totalRewardsAmount(), handler.getUserRewards(), "Staker's rewards count incorrect");
    }
}
