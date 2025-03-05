// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { LiquidationManager } from "../../src/LiquidationManager.sol";

import { Manager } from "../../src/Manager.sol";
import { ManagerContainer } from "../../src/ManagerContainer.sol";
import { ILiquidationManager } from "../../src/interfaces/core/ILiquidationManager.sol";
import { IManager } from "../../src/interfaces/core/IManager.sol";

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
    ManagerContainer public managerContainer;
    SampleTokenERC20 public usdc;
    SampleTokenERC20 public weth;

    function setUp() public {
        usdc = new SampleTokenERC20("USDC", "USDC", 0);
        weth = new SampleTokenERC20("WETH", "WETH", 0);
        SampleOracle jUsdOracle = new SampleOracle();
        manager = new Manager(address(this), address(usdc), address(weth), address(jUsdOracle), bytes(""));
        managerContainer = new ManagerContainer(address(this), address(manager));
        liquidationManager = new LiquidationManager(address(this), address(managerContainer));

        manager.setLiquidationManager(address(liquidationManager));
    }

    // Checks if initial state of the contract is correct
    function test_liquidationManager_initialState() public {
        assertEq(liquidationManager.liquidatorBonus(), manager.liquidatorBonus());
        assertEq(liquidationManager.selfLiquidationFee(), manager.selfLiquidationFee());
        assertEq(liquidationManager.paused(), false);
    }

    // Tests setting liquidator bonus from non-Manager's address
    function test_setLiquidatorBonus_when_unauthorized(
        address _caller
    ) public {
        uint256 prevBonus = liquidationManager.liquidatorBonus();
        vm.assume(_caller != address(manager));
        vm.startPrank(_caller, _caller);
        vm.expectRevert(bytes("1000"));

        liquidationManager.setLiquidatorBonus(1);

        assertEq(prevBonus, liquidationManager.liquidatorBonus());
    }

    // Tests setting liquidator bonus from Manager's address
    function test_setLiquidatorBonus_when_authorized(
        uint256 _amount
    ) public {
        uint256 liqP = liquidationManager.LIQUIDATION_PRECISION();

        vm.startPrank(address(manager), address(manager));

        //Tests setting liquidator's bonus, when LiquidatorBonus < LIQUIDATION_PRECISION
        if (_amount < liqP) {
            liquidationManager.setLiquidatorBonus(_amount);
            assertEq(_amount, liquidationManager.liquidatorBonus());
        }
        //Tests setting liquidator's bonus, when LiquidatorBonus > LIQUIDATION_PRECISION
        else {
            //Tests if reverts with error code 2001
            vm.expectRevert(bytes("2001"));
            liquidationManager.setLiquidatorBonus(_amount);
        }
    }

    // Tests the liquidator bonus setting in a real-world scenario via the Manager Contract
    function test_setLiquidatorBonus_when_fromManager(
        uint256 _amount
    ) public {
        vm.assume(_amount < liquidationManager.LIQUIDATION_PRECISION());

        vm.expectEmit();
        emit LiquidatorBonusUpdated(manager.liquidatorBonus(), _amount);

        manager.setLiquidatorBonus(_amount);

        assertEq(_amount, manager.liquidatorBonus());
        assertEq(manager.liquidatorBonus(), liquidationManager.liquidatorBonus());
    }

    // Tests setting SL fee from non-Manager's address
    function test_setSelfLiquidationFee_when_unauthorized(
        address _caller
    ) public {
        uint256 prevFee = liquidationManager.selfLiquidationFee();
        vm.assume(_caller != address(manager));
        vm.startPrank(_caller, _caller);
        vm.expectRevert(bytes("1000"));

        liquidationManager.setSelfLiquidationFee(1);

        assertEq(prevFee, liquidationManager.selfLiquidationFee());
    }

    // Tests setting liquidator bonus from Manager's address
    function test_setSelfLiquidationFee_when_authorized(
        uint256 _amount
    ) public {
        uint256 liqP = liquidationManager.LIQUIDATION_PRECISION();

        vm.startPrank(address(manager), address(manager));

        //Tests setting SL fee , when SL fee  < LIQUIDATION_PRECISION
        if (_amount < liqP) {
            liquidationManager.setSelfLiquidationFee(_amount);
            assertEq(_amount, liquidationManager.selfLiquidationFee());
        }
        //Tests setting SL fee , when SL fee > LIQUIDATION_PRECISION
        else {
            //Tests if reverts with error code 2001
            vm.expectRevert(bytes("2001"));
            liquidationManager.setSelfLiquidationFee(_amount);
        }
    }

    // Tests the liquidator bonus setting in a real-world scenario via the Manager Contract
    function test_setSelfLiquidationFee_when_fromManager(
        uint256 _amount
    ) public {
        vm.assume(_amount < liquidationManager.LIQUIDATION_PRECISION());

        vm.expectEmit();
        emit SelfLiquidationFeeUpdated(manager.selfLiquidationFee(), _amount);

        manager.setSelfLiquidationFee(_amount);

        assertEq(_amount, manager.selfLiquidationFee());
        assertEq(manager.selfLiquidationFee(), liquidationManager.selfLiquidationFee());
    }

    // Tests setting contract paused from non-Owner's address
    function test_setPaused_when_unauthorized(
        address _caller
    ) public {
        vm.assume(_caller != liquidationManager.owner());
        vm.startPrank(_caller, _caller);
        vm.expectRevert();
        liquidationManager.pause();
    }

    // Tests setting contract paused from Owner's address
    function test_setPaused_when_authorized() public {
        //Sets contract paused and checks if after pausing contract is paused and event is emitted
        liquidationManager.pause();
        assertEq(liquidationManager.paused(), true);

        //Sets contract unpaused and checks if after pausing contract is unpaused and event is emitted
        liquidationManager.unpause();
        assertEq(liquidationManager.paused(), false);
    }

    //Tests if renouncing ownership reverts with error code 1000
    function test_renounceOwnership() public {
        vm.expectRevert(bytes("1000"));
        liquidationManager.renounceOwnership();
    }
}
