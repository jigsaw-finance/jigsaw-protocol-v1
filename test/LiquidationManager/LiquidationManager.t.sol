// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { ILiquidationManager } from "../../src/interfaces/core/ILiquidationManager.sol";
import { LiquidationManager } from "../../src/LiquidationManager.sol";

import { IManager } from "../../src/interfaces/core/IManager.sol";
import { Manager } from "../../src/Manager.sol";

import { SampleOracle } from "../utils/mocks/SampleOracle.sol";
import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";

/// @title LiquidationManagerTest
/// @notice This contract includes tests specifically designed for conducting fuzzy testing of the
///         general-purpose functions within the LiquidationManager Contract, including:
///         - setLiquidatorBonus()
///         - setSelfLiquidationFee()
///         - setPaused()
///         - renounceOwnership()
/// @notice For additional tests related to the LiquidationManager Contract, refer to other files in this
/// directory.
contract LiquidationManagerTest is Test {
    event LiquidatorBonusUpdated(uint256 oldAmount, uint256 newAmount);
    event SelfLiquidationFeeUpdated(uint256 oldAmount, uint256 newAmount);

    LiquidationManager public liquidationManager;
    Manager public manager;
    SampleTokenERC20 public usdc;
    SampleTokenERC20 public weth;
    address internal OWNER = vm.addr(uint256(keccak256(bytes("OWNER"))));

    function setUp() public {
        usdc = new SampleTokenERC20("USDC", "USDC", 0);
        weth = new SampleTokenERC20("WETH", "WETH", 0);
        SampleOracle jUsdOracle = new SampleOracle();
        manager = new Manager(OWNER, address(weth), address(jUsdOracle), bytes(""));
        liquidationManager = new LiquidationManager(OWNER, address(manager));

        vm.prank(OWNER, OWNER);
        manager.setLiquidationManager(address(liquidationManager));
    }

    // Checks if initial state of the contract is correct
    function test_liquidationManager_initialState() public {
        assertEq(liquidationManager.selfLiquidationFee(), 8e3);
        assertEq(liquidationManager.MAX_SELF_LIQUIDATION_FEE(), 10e3);
        assertEq(liquidationManager.LIQUIDATION_PRECISION(), 1e5);
        assertEq(liquidationManager.paused(), false);

        vm.expectRevert(bytes("3065"));
        new LiquidationManager(OWNER, address(0));
    }

    // Tests setting SL fee from non-Manager's address
    function test_setSelfLiquidationFee_when_unauthorized(
        address _caller
    ) public {
        uint256 prevFee = liquidationManager.selfLiquidationFee();
        vm.assume(_caller != address(manager));
        vm.startPrank(_caller, _caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));

        liquidationManager.setSelfLiquidationFee(1);

        assertEq(prevFee, liquidationManager.selfLiquidationFee());
    }

    // Tests the liquidator bonus setting in a real-world scenario through owner
    function test_setSelfLiquidationFee_when_authorized() public {
        vm.startPrank(OWNER, OWNER);
        uint256 maxFee = liquidationManager.MAX_SELF_LIQUIDATION_FEE();

        vm.expectRevert(bytes("3066"));
        liquidationManager.setSelfLiquidationFee(maxFee + 1);

        vm.expectEmit();
        emit SelfLiquidationFeeUpdated(liquidationManager.selfLiquidationFee(), maxFee);
        liquidationManager.setSelfLiquidationFee(maxFee);

        assertEq(maxFee, liquidationManager.selfLiquidationFee());

        vm.stopPrank();
    }

    // Tests setting contract paused from non-Owner's address
    function test_setPaused_when_unauthorized(
        address _caller
    ) public {
        vm.assume(_caller != OWNER);
        vm.startPrank(_caller, _caller);
        vm.expectRevert();
        liquidationManager.pause();
    }

    // Tests setting contract paused from Owner's address
    function test_setPaused_when_authorized() public {
        //Sets contract paused and checks if after pausing contract is paused and event is emitted
        vm.prank(OWNER, OWNER);
        liquidationManager.pause();
        assertEq(liquidationManager.paused(), true);

        //Sets contract unpaused and checks if after pausing contract is unpaused and event is emitted
        vm.prank(OWNER, OWNER);
        liquidationManager.unpause();
        assertEq(liquidationManager.paused(), false);
    }

    //Tests if renouncing ownership reverts with error code 1000
    function test_renounceOwnership() public {
        vm.expectRevert(bytes("1000"));
        liquidationManager.renounceOwnership();
    }

    //Tests if renouncing ownership reverts with error code 1000
    function test_validAddress(address _user) public {
        vm.startPrank(OWNER, OWNER);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;
        vm.expectRevert(bytes("3000"));
        liquidationManager.liquidateBadDebt(_user, address(0), liquidateCalldata);

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        vm.expectRevert(bytes("3000"));
        liquidationManager.selfLiquidate(address(0), 100, swapParams, strategiesParams);

        vm.expectRevert(bytes("3000"));
        liquidationManager.liquidate(_user, address(0), 100, 0, liquidateCalldata);
    }
}
