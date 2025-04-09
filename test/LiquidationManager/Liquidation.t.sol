// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { HoldingManager } from "../../src/HoldingManager.sol";
import { JigsawUSD } from "../../src/JigsawUSD.sol";
import { LiquidationManager } from "../../src/LiquidationManager.sol";
import { Manager } from "../../src/Manager.sol";

import { ReceiptToken } from "../../src/ReceiptToken.sol";
import { ReceiptTokenFactory } from "../../src/ReceiptTokenFactory.sol";
import { SharesRegistry } from "../../src/SharesRegistry.sol";
import { StablesManager } from "../../src/StablesManager.sol";
import { StrategyManager } from "../../src/StrategyManager.sol";

import { ILiquidationManager } from "../../src/interfaces/core/ILiquidationManager.sol";
import { IReceiptToken } from "../../src/interfaces/core/IReceiptToken.sol";
import { ISharesRegistry } from "../../src/interfaces/core/ISharesRegistry.sol";
import { IStrategy } from "../../src/interfaces/core/IStrategy.sol";
import { StrategyWithoutRewardsMock } from "../utils/mocks/StrategyWithoutRewardsMock.sol";

import { SampleOracle } from "../utils/mocks/SampleOracle.sol";
import { SampleTokenBigDecimals } from "../utils/mocks/SampleTokenBigDecimals.sol";
import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";
import { SampleTokenSmallDecimals } from "../utils/mocks/SampleTokenSmallDecimals.sol";

/// @title LiquidationTest
/// @notice This contract encompasses tests and utility functions for conducting fuzzy testing of the `liquidate` and
/// `liquidateBadDebt`
/// functions in the LiquidationManager Contract.
/// @notice for other tests of the LiquidationManager Contract see other files in this directory.
contract LiquidationTest is Test {
    using Math for uint256;

    HoldingManager public holdingManager;

    IReceiptToken public receiptTokenReference;
    LiquidationManager public liquidationManager;
    Manager public manager;
    JigsawUSD public jUsd;
    ReceiptTokenFactory public receiptTokenFactory;
    SampleOracle public usdcOracle;
    SampleTokenERC20 public sampleTokenERC20;
    SampleTokenERC20 public usdc;
    SampleTokenERC20 public weth;
    SharesRegistry public sharesRegistry;
    StablesManager public stablesManager;
    StrategyManager public strategyManager;
    StrategyWithoutRewardsMock public strategyWithoutRewardsMock;

    // collateral to registry mapping
    mapping(address => address) registries;

    // addresses of actors in tests
    address user = vm.addr(uint256(keccak256(bytes("User address"))));
    address liquidator = vm.addr(uint256(keccak256(bytes("Liquidator address"))));

    function setUp() public {
        vm.warp(1_641_070_800);

        usdc = new SampleTokenERC20("USDC", "USDC", 0);
        weth = new SampleTokenERC20("WETH", "WETH", 0);
        SampleOracle jUsdOracle = new SampleOracle();
        manager = new Manager(address(this), address(weth), address(jUsdOracle), bytes(""));
        liquidationManager = new LiquidationManager(address(this), address(manager));

        holdingManager = new HoldingManager(address(this), address(manager));
        jUsd = new JigsawUSD(address(this), address(manager));
        stablesManager = new StablesManager(address(this), address(manager), address(jUsd));
        strategyManager = new StrategyManager(address(this), address(manager));

        manager.setStablecoinManager(address(stablesManager));
        manager.setHoldingManager(address(holdingManager));
        manager.setLiquidationManager(address(liquidationManager));
        manager.setStrategyManager(address(strategyManager));
        manager.setFeeAddress(address(this));

        manager.whitelistToken(address(usdc));

        usdcOracle = new SampleOracle();
        sharesRegistry = new SharesRegistry(
            msg.sender,
            address(manager),
            address(usdc),
            address(usdcOracle),
            bytes(""),
            ISharesRegistry.RegistryConfig({
                collateralizationRate: 50_000,
                liquidationBuffer: 5e3,
                liquidatorBonus: 8e3
            })
        );
        registries[address(usdc)] = address(sharesRegistry);
        stablesManager.registerOrUpdateShareRegistry(address(sharesRegistry), address(usdc), true);

        receiptTokenReference = IReceiptToken(new ReceiptToken());
        receiptTokenFactory = new ReceiptTokenFactory(address(this), (address(receiptTokenReference)));
        manager.setReceiptTokenFactory(address(receiptTokenFactory));

        strategyWithoutRewardsMock = new StrategyWithoutRewardsMock(
            address(manager), address(usdc), address(usdc), address(0), "RUsdc-Mock", "RUSDCM"
        );
        strategyManager.addStrategy(address(strategyWithoutRewardsMock));
    }

    // Tests liquidation when the specified user has no holdings
    // Expects a revert with error "3002" during liquidation attempt
    function test_liquidate_when_isNotHolding(
        address _fakeUser
    ) public {
        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        vm.expectRevert(bytes("3002"));
        liquidationManager.liquidate(_fakeUser, address(usdc), 10 ether, 0, liquidateCalldata);
    }

    // Tests liquidation with an invalid liquidation amount (0)
    // Expects a revert with error "2001" during liquidation attempt
    function test_liquidate_when_invalidLiquidationAmount() public {
        uint256 invalidLiquidationAmount = 0;

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        vm.expectRevert(bytes("2001"));
        liquidationManager.liquidate(address(0), address(usdc), invalidLiquidationAmount, 0, liquidateCalldata);
    }

    // Tests liquidation when the share registry is not active
    // Expects a revert with error "1200" during liquidation attempt
    function test_liquidate_when_registryNotActive() public {
        initiateWithUsdc(user, 10 ether);

        // set registry inactive
        stablesManager.registerOrUpdateShareRegistry(address(sharesRegistry), address(usdc), false);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        vm.expectRevert();
        liquidationManager.liquidate(user, address(usdc), 5, 0, liquidateCalldata);
    }

    // Tests liquidation when the user is solvent
    // Expects a revert with error "3073" during liquidation attempt
    function test_liquidate_when_solvent() public {
        // Initialize user
        initiateWithUsdc(user, 100e6);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        //make liquidation call
        vm.expectRevert(bytes("3073"));
        liquidationManager.liquidate(user, address(usdc), 5, 0, liquidateCalldata);
    }

    // Tests liquidation when the liquidation amount is greater than the borrowed amount
    // Expects a revert with error "2003" during liquidation attempt
    function test_liquidate_when_liquidationAmountGtBorrowedAmount(
        uint256 _userCollateral,
        uint256 _liquidatorCollateral
    ) public {
        vm.assume(_liquidatorCollateral / 2 > _userCollateral / 2);

        // initiate user
        initiateWithUsdc(user, _userCollateral);

        // initiate liquidator
        initiateWithUsdc(liquidator, _liquidatorCollateral);

        // startPrank so every next call is made from liquidator
        vm.startPrank(liquidator, liquidator);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        // make liquidation call
        vm.expectRevert(bytes("2003"));
        liquidationManager.liquidate(user, address(usdc), type(uint256).max, 0, liquidateCalldata);

        vm.stopPrank();
    }

    // Tests liquidation when collateral is denominated in a token with big decimals
    // Checks various states and amounts after liquidation
    function test_liquidate_when_bigDecimals() public {
        uint256 _collateralAmount = 10_000e22;

        TestTempData memory testData;

        // initialize user
        testData.user = user;
        testData.userCollateralAmount = _collateralAmount;
        SampleTokenBigDecimals collateralContract = new SampleTokenBigDecimals("BigDec", "BD", 1e18 * 1e22);
        manager.whitelistToken(address(collateralContract));
        SampleOracle collateralOracle = new SampleOracle();
        SharesRegistry collateralRegistry = new SharesRegistry(
            msg.sender,
            address(manager),
            address(collateralContract),
            address(collateralOracle),
            bytes(""),
            ISharesRegistry.RegistryConfig({
                collateralizationRate: 50_000,
                liquidationBuffer: 5e3,
                liquidatorBonus: 8e3
            })
        );
        registries[address(collateralContract)] = address(collateralRegistry);
        stablesManager.registerOrUpdateShareRegistry(address(collateralRegistry), address(collateralContract), true);

        // calculate mintAmount
        uint256 mintAmount = testData.userCollateralAmount / 2;

        //get tokens for user
        deal(address(collateralContract), testData.user, testData.userCollateralAmount);

        vm.startPrank(testData.user, testData.user);
        // create holding for user
        testData.userHolding = holdingManager.createHolding();
        // make deposit to the holding
        collateralContract.approve(address(holdingManager), testData.userCollateralAmount);
        holdingManager.deposit(address(collateralContract), testData.userCollateralAmount);
        //borrow
        holdingManager.borrow(address(collateralContract), mintAmount, 0, true);
        vm.stopPrank();

        testData.userJUsd = jUsd.balanceOf(testData.user);

        //initialize liquidator
        testData.liquidator = liquidator;
        testData.liquidatorCollateralAmount = _collateralAmount;

        //get tokens for user
        deal(address(collateralContract), testData.liquidator, testData.liquidatorCollateralAmount);

        vm.startPrank(testData.liquidator, testData.liquidator);
        // create holding for user
        holdingManager.createHolding();
        // make deposit to the holding
        collateralContract.approve(address(holdingManager), testData.userCollateralAmount);
        holdingManager.deposit(address(collateralContract), testData.userCollateralAmount);
        //borrow
        holdingManager.borrow(address(collateralContract), mintAmount, 0, true);
        vm.stopPrank();

        testData.liquidatorJUsd = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAmountAfterInitiation = collateralContract.balanceOf(address(testData.liquidator));

        //change the price of the collateral
        collateralOracle.setPriceForLiquidation();

        //initiate liquidation from liquidator's address
        vm.startPrank(testData.liquidator, testData.liquidator);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        //make liquidation call
        testData.expectedLiquidatorCollateral = liquidationManager.liquidate(
            address(testData.user), address(collateralContract), testData.userJUsd, 0, liquidateCalldata
        );

        vm.stopPrank();

        //get state after liquidation
        testData.liquidatorJUsdAfterLiquidation = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAfterLiquidation = collateralContract.balanceOf(testData.liquidator);
        testData.holdingBorrowedAmountAfterLiquidation = sharesRegistry.borrowed(testData.userHolding);

        // perform checks
        assertEq(
            testData.holdingBorrowedAmountAfterLiquidation, 0, "Holding's borrow amount is incorrect after liquidation"
        );
        assertEq(
            testData.liquidatorJUsdAfterLiquidation,
            testData.liquidatorJUsd - testData.userJUsd,
            "jUsd wasn't taken from liquidator after liquidation"
        );
        assertEq(
            testData.liquidatorCollateralAfterLiquidation,
            testData.expectedLiquidatorCollateral,
            "Liquidator didn't receive user's collateral after liquidation"
        );
    }

    // Tests liquidation when minCollateralReceive requirement is not satisfied
    function test_liquidate_when_minCollateralReceive_notSatisfied() public {
        uint256 _collateralAmount = 10_000e6;

        TestTempData memory testData;

        //initialize user
        testData.userCollateralAmount = _collateralAmount;
        testData.user = user;
        SampleTokenSmallDecimals collateralContract = new SampleTokenSmallDecimals("SmallDec", "SD", 1e18 * 1e6);
        manager.whitelistToken(address(collateralContract));
        SampleOracle collateralOracle = new SampleOracle();
        SharesRegistry collateralRegistry = new SharesRegistry(
            msg.sender,
            address(manager),
            address(collateralContract),
            address(collateralOracle),
            bytes(""),
            ISharesRegistry.RegistryConfig({
                collateralizationRate: 50_000,
                liquidationBuffer: 5e3,
                liquidatorBonus: 8e3
            })
        );
        registries[address(collateralContract)] = address(collateralRegistry);
        stablesManager.registerOrUpdateShareRegistry(address(collateralRegistry), address(collateralContract), true);

        // calculate mintAmount
        uint256 mintAmount = testData.userCollateralAmount / 2;

        //get tokens for user
        deal(address(collateralContract), testData.user, testData.userCollateralAmount);

        vm.startPrank(testData.user, testData.user);
        // create holding for user
        testData.userHolding = holdingManager.createHolding();
        // make deposit to the holding
        collateralContract.approve(address(holdingManager), testData.userCollateralAmount);
        holdingManager.deposit(address(collateralContract), testData.userCollateralAmount);
        //borrow
        holdingManager.borrow(address(collateralContract), mintAmount, 0, true);
        vm.stopPrank();

        testData.userJUsd = jUsd.balanceOf(testData.user);

        //initialize liquidator
        testData.liquidator = liquidator;
        testData.liquidatorCollateralAmount = _collateralAmount;

        //get tokens for user
        deal(address(collateralContract), testData.liquidator, testData.liquidatorCollateralAmount);

        vm.startPrank(testData.liquidator, testData.liquidator);
        // create holding for user
        holdingManager.createHolding();
        // make deposit to the holding
        collateralContract.approve(address(holdingManager), testData.userCollateralAmount);
        holdingManager.deposit(address(collateralContract), testData.userCollateralAmount);
        //borrow
        holdingManager.borrow(address(collateralContract), mintAmount, 0, true);
        vm.stopPrank();

        testData.liquidatorJUsd = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAmountAfterInitiation = collateralContract.balanceOf(address(testData.liquidator));

        //change the price of the collateral
        collateralOracle.setPriceForLiquidation();

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        //make liquidation call
        vm.prank(testData.liquidator, testData.liquidator);
        vm.expectRevert(bytes("3097"));
        liquidationManager.liquidate(
            address(testData.user), address(collateralContract), testData.userJUsd, type(uint256).max, liquidateCalldata
        );
    }

    // Tests liquidation when collateral is denominated in a token with small decimals
    // Checks various states and amounts after liquidation
    function test_liquidate_when_smallDecimals() public {
        uint256 _collateralAmount = 10_000e6;

        TestTempData memory testData;

        //initialize user
        testData.userCollateralAmount = _collateralAmount;
        testData.user = user;
        SampleTokenSmallDecimals collateralContract = new SampleTokenSmallDecimals("SmallDec", "SD", 1e18 * 1e6);
        manager.whitelistToken(address(collateralContract));
        SampleOracle collateralOracle = new SampleOracle();
        SharesRegistry collateralRegistry = new SharesRegistry(
            msg.sender,
            address(manager),
            address(collateralContract),
            address(collateralOracle),
            bytes(""),
            ISharesRegistry.RegistryConfig({
                collateralizationRate: 50_000,
                liquidationBuffer: 5e3,
                liquidatorBonus: 8e3
            })
        );
        registries[address(collateralContract)] = address(collateralRegistry);
        stablesManager.registerOrUpdateShareRegistry(address(collateralRegistry), address(collateralContract), true);

        // calculate mintAmount
        uint256 mintAmount = testData.userCollateralAmount / 2;

        //get tokens for user
        deal(address(collateralContract), testData.user, testData.userCollateralAmount);

        vm.startPrank(testData.user, testData.user);
        // create holding for user
        testData.userHolding = holdingManager.createHolding();
        // make deposit to the holding
        collateralContract.approve(address(holdingManager), testData.userCollateralAmount);
        holdingManager.deposit(address(collateralContract), testData.userCollateralAmount);
        //borrow
        holdingManager.borrow(address(collateralContract), mintAmount, 0, true);
        vm.stopPrank();

        testData.userJUsd = jUsd.balanceOf(testData.user);

        //initialize liquidator
        testData.liquidator = liquidator;
        testData.liquidatorCollateralAmount = _collateralAmount;

        //get tokens for user
        deal(address(collateralContract), testData.liquidator, testData.liquidatorCollateralAmount);

        vm.startPrank(testData.liquidator, testData.liquidator);
        // create holding for user
        holdingManager.createHolding();
        // make deposit to the holding
        collateralContract.approve(address(holdingManager), testData.userCollateralAmount);
        holdingManager.deposit(address(collateralContract), testData.userCollateralAmount);
        //borrow
        holdingManager.borrow(address(collateralContract), mintAmount, 0, true);
        vm.stopPrank();

        testData.liquidatorJUsd = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAmountAfterInitiation = collateralContract.balanceOf(address(testData.liquidator));

        //change the price of the collateral
        collateralOracle.setPriceForLiquidation();

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        //make liquidation call
        vm.prank(testData.liquidator, testData.liquidator);
        testData.expectedLiquidatorCollateral = liquidationManager.liquidate(
            address(testData.user), address(collateralContract), testData.userJUsd, 0, liquidateCalldata
        );

        //get state after liquidation
        testData.liquidatorJUsdAfterLiquidation = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAfterLiquidation = collateralContract.balanceOf(testData.liquidator);
        testData.holdingBorrowedAmountAfterLiquidation = sharesRegistry.borrowed(testData.userHolding);

        // perform checks
        assertEq(
            testData.holdingBorrowedAmountAfterLiquidation, 0, "Holding's borrow amount is incorrect after liquidation"
        );
        assertEq(
            testData.liquidatorJUsdAfterLiquidation,
            testData.liquidatorJUsd - testData.userJUsd,
            "jUsd wasn't taken from liquidator after liquidation"
        );
        assertEq(
            testData.liquidatorCollateralAfterLiquidation,
            testData.expectedLiquidatorCollateral,
            "Liquidator didn't receive user's collateral after liquidation"
        );
    }

    // Tests liquidation with strategies
    // Checks various states and amounts after liquidation
    function test_liquidate_when_withStrategies(
        uint256 _collateralAmount
    ) public {
        TestTempData memory testData;

        // initialize user
        testData.user = user;
        testData.userHolding = initiateWithUsdc(testData.user, _collateralAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.userCollateralAmount = usdc.balanceOf(testData.userHolding);

        // initialize liquidator
        testData.liquidator = liquidator;
        testData.liquidatorCollateralAmount = _collateralAmount;
        initiateWithUsdc(testData.liquidator, testData.liquidatorCollateralAmount);
        testData.liquidatorJUsd = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAmountAfterInitiation = usdc.balanceOf(address(testData.liquidator));

        // make investment
        vm.prank(testData.user, testData.user);
        strategyManager.invest(address(usdc), address(strategyWithoutRewardsMock), testData.userCollateralAmount, 0, "");

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;
        liquidateCalldata.strategies = new address[](1);
        liquidateCalldata.strategiesData = new bytes[](1);
        liquidateCalldata.strategies[0] = address(strategyWithoutRewardsMock);
        liquidateCalldata.strategiesData[0] = "";

        console.log(stablesManager.isLiquidatable({ _token: address(usdc), _holding: testData.userHolding }));
        // change the price of the usdc
        usdcOracle.setPriceForLiquidation();
        console.log(stablesManager.isLiquidatable({ _token: address(usdc), _holding: testData.userHolding }));

        // execute liquidation from liquidator's address
        vm.prank(testData.liquidator, testData.liquidator);
        testData.expectedLiquidatorCollateral =
            liquidationManager.liquidate(address(testData.user), address(usdc), testData.userJUsd, 0, liquidateCalldata);

        // get state after liquidation
        testData.liquidatorJUsdAfterLiquidation = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAfterLiquidation = usdc.balanceOf(testData.liquidator);
        testData.holdingBorrowedAmountAfterLiquidation = sharesRegistry.borrowed(testData.userHolding);

        // perform checks
        assertEq(
            testData.holdingBorrowedAmountAfterLiquidation, 0, "Holding's borrow amount is incorrect after liquidation"
        );
        assertEq(
            testData.liquidatorJUsdAfterLiquidation,
            testData.liquidatorJUsd - testData.userJUsd,
            "jUsd wasn't taken from liquidator after liquidation"
        );
        assertEq(
            testData.liquidatorCollateralAfterLiquidation,
            testData.expectedLiquidatorCollateral,
            "Liquidator didn't receive user's collateral after liquidation"
        );
    }

    // Tests if retrieve collateral function reverts correctly when strategy list is provided incorrectly
    function test_liquidate_when_strategyListFormatError(
        uint256 _collateralAmount
    ) public {
        TestTempData memory testData;

        // initialize user
        testData.user = user;
        testData.userHolding = initiateWithUsdc(testData.user, _collateralAmount);
        testData.userCollateralAmount = usdc.balanceOf(testData.userHolding);
        testData.userJUsd = jUsd.balanceOf(testData.user);

        // initialize liquidator
        testData.liquidator = liquidator;
        initiateWithUsdc(testData.liquidator, _collateralAmount);
        testData.liquidatorJUsd = jUsd.balanceOf(testData.liquidator);

        // make investment
        vm.prank(testData.user, testData.user);
        strategyManager.invest(address(usdc), address(strategyWithoutRewardsMock), testData.userCollateralAmount, 0, "");

        // change the price of the usdc
        usdcOracle.setPriceForLiquidation();

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;
        liquidateCalldata.strategies = new address[](2);
        liquidateCalldata.strategiesData = new bytes[](1);

        liquidateCalldata.strategies[0] = address(strategyWithoutRewardsMock);
        liquidateCalldata.strategiesData[0] = "";

        liquidateCalldata.strategies[1] = vm.addr(uint256(keccak256(bytes("Unexisting strategy address"))));

        vm.startPrank(testData.liquidator, testData.liquidator);
        vm.expectRevert(bytes("3026"));
        liquidationManager.liquidate(address(testData.user), address(usdc), testData.userJUsd, 0, liquidateCalldata);

        vm.stopPrank();
    }

    function test_liquidateBadDebt_when_inactiveRegistry() public {
        address collateral = address(420);
        ILiquidationManager.LiquidateCalldata memory liquidateCalldata =
            ILiquidationManager.LiquidateCalldata({ strategies: new address[](0), strategiesData: new bytes[](0) });

        vm.expectRevert(bytes("1200"));
        liquidationManager.liquidateBadDebt({ _user: user, _collateral: collateral, _data: liquidateCalldata });
    }

    function test_liquidateBadDebt_when_NoHolding() public {
        address collateral = address(usdc);
        address _user = address(421);
        ILiquidationManager.LiquidateCalldata memory liquidateCalldata =
            ILiquidationManager.LiquidateCalldata({ strategies: new address[](0), strategiesData: new bytes[](0) });

        vm.expectRevert(bytes("3002"));
        liquidationManager.liquidateBadDebt({ _user: _user, _collateral: collateral, _data: liquidateCalldata });
    }

    function test_liquidateBadDebt_when_NotBadDebt() public {
        address collateral = address(usdc);
        uint256 collateralAmount = 100_000e6;
        initiateWithUsdc(user, collateralAmount);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata =
            ILiquidationManager.LiquidateCalldata({ strategies: new address[](0), strategiesData: new bytes[](0) });

        vm.expectRevert(bytes("3099"));
        liquidationManager.liquidateBadDebt({ _user: user, _collateral: collateral, _data: liquidateCalldata });
    }

    function test_liquidateBadDebt_when_withoutStrategies() public {
        address collateral = address(usdc);
        uint256 collateralAmount = 100_000e6;
        address userHolding = initiateWithUsdc(user, collateralAmount);

        uint256 userJusdBefore = ISharesRegistry(registries[address(usdc)]).borrowed(userHolding);
        uint256 userCollateralBefore = ISharesRegistry(registries[address(usdc)]).collateral(userHolding);

        deal(address(jUsd), address(this), userJusdBefore);
        deal(address(usdc), address(this), 0);

        uint256 totalSupplyBefore = jUsd.totalSupply();

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata =
            ILiquidationManager.LiquidateCalldata({ strategies: new address[](0), strategiesData: new bytes[](0) });

        usdcOracle.setAVeryLowPrice();
        liquidationManager.liquidateBadDebt({ _user: user, _collateral: collateral, _data: liquidateCalldata });

        // 1. user's borrowed = 0
        // 2. jUsd supply -= user's borrowed
        // 3. user's collateral = 0
        // 4. owner's jUsd -= user's borrowed
        // 5. owner's collateral = user's collateral
        assertEq(ISharesRegistry(registries[address(usdc)]).borrowed(userHolding), 0, "Borrowed amount is not 0");
        assertEq(jUsd.totalSupply(), totalSupplyBefore - userJusdBefore, "jUsd supply is not correct");
        assertEq(ISharesRegistry(registries[address(usdc)]).collateral(user), 0, "User's collateral is not 0");
        assertEq(jUsd.balanceOf(address(this)), 0, "Owner's jUsd is not 0");
        assertEq(usdc.balanceOf(address(this)), userCollateralBefore, "Owner's collateral is not correct");
    }

    function test_liquidateBadDebt_when_withStrategies() public {
        address collateral = address(usdc);
        uint256 collateralAmount = 100_000e6;
        address userHolding = initiateWithUsdc(user, collateralAmount);

        uint256 userJusdBefore = ISharesRegistry(registries[address(usdc)]).borrowed(userHolding);
        uint256 userCollateralBefore = ISharesRegistry(registries[address(usdc)]).collateral(userHolding);

        deal(address(jUsd), address(this), userJusdBefore);
        deal(address(usdc), address(this), 0);

        uint256 totalSupplyBefore = jUsd.totalSupply();

        // make investment
        vm.prank(user, user);
        strategyManager.invest(address(usdc), address(strategyWithoutRewardsMock), userCollateralBefore, 0, "");

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata =
            ILiquidationManager.LiquidateCalldata({ strategies: new address[](1), strategiesData: new bytes[](1) });
        liquidateCalldata.strategies[0] = address(strategyWithoutRewardsMock);

        usdcOracle.setAVeryLowPrice();
        liquidationManager.liquidateBadDebt({ _user: user, _collateral: collateral, _data: liquidateCalldata });

        (uint256 investedAmount, uint256 totalShares) = IStrategy(strategyWithoutRewardsMock).recipients(userHolding);

        // 1. user's borrowed = 0
        // 2. jUsd supply -= user's borrowed
        // 3. user's collateral = 0
        // 4. owner's jUsd -= user's borrowed
        // 5. owner's collateral = user's collateral
        // 6. invested amount in strategy = 0
        // 7. total shares in strategy = 0
        assertEq(ISharesRegistry(registries[address(usdc)]).borrowed(userHolding), 0, "Borrowed amount is not 0");
        assertEq(jUsd.totalSupply(), totalSupplyBefore - userJusdBefore, "jUsd supply is not correct");
        assertEq(ISharesRegistry(registries[address(usdc)]).collateral(user), 0, "User's collateral is not 0");
        assertEq(jUsd.balanceOf(address(this)), 0, "Owner's jUsd is not 0");
        assertEq(usdc.balanceOf(address(this)), userCollateralBefore, "Owner's collateral is not correct");
        assertEq(investedAmount, 0, "Strategy's total investments is not 0");
        assertEq(totalShares, 0, "Strategy's total shares is not 0");
    }

    function _prepareBadDebtLiquidation() public { }

    //Utility functions

    function initiateWithUsdc(address _user, uint256 _collateralAmount) public returns (address userHolding) {
        _collateralAmount = bound(_collateralAmount, 500, 100_000);
        _collateralAmount = _collateralAmount * 10 ** usdc.decimals();

        vm.startPrank(_user, _user);

        usdc.getTokens(_collateralAmount);
        userHolding = holdingManager.createHolding();
        usdc.approve(address(holdingManager), _collateralAmount);
        holdingManager.deposit(address(usdc), _collateralAmount);
        holdingManager.borrow(address(usdc), _collateralAmount / 2, 0, true);

        vm.stopPrank();
    }

    function isSolvent(address _user, uint256 _amount, address _holding) public view returns (bool) {
        uint256 borrowedAmount = sharesRegistry.borrowed(_holding);

        if (borrowedAmount == 0) {
            return true;
        }

        uint256 amountValue = _amount.mulDiv(sharesRegistry.getExchangeRate(), manager.EXCHANGE_RATE_PRECISION());
        borrowedAmount += amountValue;

        uint256 _colRate = sharesRegistry.getConfig().collateralizationRate;
        uint256 _exchangeRate = sharesRegistry.getExchangeRate();

        uint256 _result = (
            (1e18 * sharesRegistry.collateral(_user) * _exchangeRate * _colRate)
                / (manager.EXCHANGE_RATE_PRECISION() * manager.PRECISION())
        ) / 1e18;

        return _result >= borrowedAmount;
    }

    function _getCollateralAmountForUSDValue(
        address _collateral,
        uint256 _jUsdAmount,
        uint256 _exchangeRate
    ) private view returns (uint256 totalCollateral) {
        // calculate based on the USD value
        totalCollateral = (1e18 * _jUsdAmount * manager.EXCHANGE_RATE_PRECISION()) / (_exchangeRate * 1e18);

        // transform from 18 decimals to collateral's decimals
        uint256 collateralDecimals = IERC20Metadata(_collateral).decimals();

        if (collateralDecimals > 18) {
            totalCollateral = totalCollateral * (10 ** (collateralDecimals - 18));
        } else if (collateralDecimals < 18) {
            totalCollateral = totalCollateral / (10 ** (18 - collateralDecimals));
        }
    }

    //imitates functioning of _retrieveCollateral function, but does not really retrieve collateral, just
    // computes its amount in strategies
    function _retrieveCollateral(
        address _token,
        address _holding,
        uint256 _amount,
        address[] memory _strategies, //strategies to withdraw from
        bytes[] memory _strategiesData
    ) public view returns (uint256 collateralInStrategies) {
        // perform required checks
        if (IERC20(_token).balanceOf(_holding) >= _amount) {
            return _amount; //nothing to do; holding already has the necessary balance
        }
        require(_strategies.length > 0, "3025");
        require(_strategies.length == _strategiesData.length, "3026");

        // iterate over sent strategies and check collateral
        for (uint256 i = 0; i < _strategies.length; i++) {
            (, uint256 shares) = IStrategy(_strategies[i]).recipients(_holding);
            collateralInStrategies += shares;
            if (IERC20(_token).balanceOf(_holding) + collateralInStrategies >= _amount) {
                break;
            }
        }

        return collateralInStrategies;
    }

    struct TestTempData {
        address user;
        address userHolding;
        uint256 userCollateralAmount;
        uint256 userJUsd;
        address liquidator;
        uint256 liquidatorJUsd;
        uint256 liquidatorCollateralAmount;
        uint256 liquidatorCollateralAmountAfterInitiation;
        uint256 liquidatorJUsdAfterLiquidation;
        uint256 liquidatorCollateralAfterLiquidation;
        uint256 holdingBorrowedAmountAfterLiquidation;
        uint256 expectedLiquidatorCollateral;
    }
}
