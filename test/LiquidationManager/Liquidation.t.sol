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
import { ManagerContainer } from "../../src/ManagerContainer.sol";
import { ReceiptToken } from "../../src/ReceiptToken.sol";
import { ReceiptTokenFactory } from "../../src/ReceiptTokenFactory.sol";
import { SharesRegistry } from "../../src/SharesRegistry.sol";
import { StablesManager } from "../../src/StablesManager.sol";
import { StrategyManager } from "../../src/StrategyManager.sol";

import { ILiquidationManager } from "../../src/interfaces/core/ILiquidationManager.sol";
import { IReceiptToken } from "../../src/interfaces/core/IReceiptToken.sol";
import { IStrategy } from "../../src/interfaces/core/IStrategy.sol";
import { StrategyWithoutRewardsMock } from "../utils/mocks/StrategyWithoutRewardsMock.sol";

import { SampleOracle } from "../utils/mocks/SampleOracle.sol";
import { SampleTokenBigDecimals } from "../utils/mocks/SampleTokenBigDecimals.sol";
import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";
import { SampleTokenSmallDecimals } from "../utils/mocks/SampleTokenSmallDecimals.sol";

/// @title LiquidationTest
/// @notice This contract encompasses tests and utility functions for conducting fuzzy testing of the `liquidate`
/// function in the LiquidationManager Contract.
/// @notice for other tests of the LiquidationManager Contract see other files in this directory.
contract LiquidationTest is Test {
    using Math for uint256;

    HoldingManager public holdingManager;

    IReceiptToken public receiptTokenReference;
    LiquidationManager public liquidationManager;
    Manager public manager;
    ManagerContainer public managerContainer;
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
        manager = new Manager(address(this), address(usdc), address(weth), address(jUsdOracle), bytes(""));
        managerContainer = new ManagerContainer(address(this), address(manager));
        liquidationManager = new LiquidationManager(address(this), address(managerContainer));

        holdingManager = new HoldingManager(address(this), address(managerContainer));
        jUsd = new JigsawUSD(address(this), address(managerContainer));
        stablesManager = new StablesManager(address(this), address(managerContainer), address(jUsd));
        strategyManager = new StrategyManager(address(this), address(managerContainer));

        manager.setStablecoinManager(address(stablesManager));
        manager.setHoldingManager(address(holdingManager));
        manager.setLiquidationManager(address(liquidationManager));
        manager.setStrategyManager(address(strategyManager));
        manager.setFeeAddress(address(this));

        manager.whitelistToken(address(usdc));

        usdcOracle = new SampleOracle();
        sharesRegistry = new SharesRegistry(
            msg.sender, address(managerContainer), address(usdc), address(usdcOracle), bytes(""), 50_000
        );
        registries[address(usdc)] = address(sharesRegistry);
        stablesManager.registerOrUpdateShareRegistry(address(sharesRegistry), address(usdc), true);

        receiptTokenReference = IReceiptToken(new ReceiptToken());
        receiptTokenFactory = new ReceiptTokenFactory(address(this), (address(receiptTokenReference)));
        manager.setReceiptTokenFactory(address(receiptTokenFactory));

        strategyWithoutRewardsMock = new StrategyWithoutRewardsMock(
            address(managerContainer), address(usdc), address(usdc), address(0), "RUsdc-Mock", "RUSDCM"
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
        liquidationManager.liquidate(_fakeUser, address(usdc), 10 ether, liquidateCalldata);
    }

    // Tests liquidation with an invalid liquidation amount (0)
    // Expects a revert with error "2001" during liquidation attempt
    function test_liquidate_when_invalidLiquidationAmount() public {
        uint256 invalidLiquidationAmount = 0;

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        vm.expectRevert(bytes("2001"));
        liquidationManager.liquidate(address(0), address(usdc), invalidLiquidationAmount, liquidateCalldata);
    }

    // Tests liquidation when the share registry is not active
    // Expects a revert with error "1200" during liquidation attempt
    function test_liquidate_when_registryNotActive() public {
        initiateWithUsdc(user, 10 ether);

        // set registry inactive
        stablesManager.registerOrUpdateShareRegistry(address(sharesRegistry), address(usdc), false);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        vm.expectRevert();
        liquidationManager.liquidate(user, address(usdc), 5, liquidateCalldata);
    }

    // Tests liquidation when the user is solvent
    // Expects a revert with error "3073" during liquidation attempt
    function test_liquidate_when_solvent() public {
        // Initialize user
        initiateWithUsdc(user, 100e6);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        //make liquidation call
        vm.expectRevert(bytes("3073"));
        liquidationManager.liquidate(user, address(usdc), 5, liquidateCalldata);
    }

    // Tests liquidation when the liquidation amount is greater than the borrowed amount
    // Expects a revert with error "2003" during liquidation attempt
    function test_liquidate_when_liquidationAmounGtBorrowedAmount(
        uint256 _userCollateral,
        uint256 _liquidatorCollateral
    ) public {
        vm.assume(_liquidatorCollateral <= 1000e18);
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
        liquidationManager.liquidate(user, address(usdc), _liquidatorCollateral / 2, liquidateCalldata);

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
            address(managerContainer),
            address(collateralContract),
            address(collateralOracle),
            bytes(""),
            50_000
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
        holdingManager.borrow(address(collateralContract), mintAmount, true);
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
        holdingManager.borrow(address(collateralContract), mintAmount, true);
        vm.stopPrank();

        testData.liquidatorJUsd = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAmountAfterInitiation = collateralContract.balanceOf(address(testData.liquidator));

        //get feeAdress balance before liquidation
        testData.feeAddressBalanceAfterInitiation = collateralContract.balanceOf(manager.feeAddress());

        //change the price of the collateral
        collateralOracle.setPriceForLiquidation();

        //initiate liquidation from liquidator's address
        vm.startPrank(testData.liquidator, testData.liquidator);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        //compute expected liquidatorReward and jUsdAmountToBurn after liquidation
        (testData.liquidatorReward, testData.totalRequiredCollateral, testData.jUsdAmountToBurn) =
        computeLiquidationAmounts(
            address(testData.user), address(collateralContract), testData.userJUsd, liquidateCalldata
        );

        //make liquidation call
        liquidationManager.liquidate(
            address(testData.user), address(collateralContract), testData.userJUsd, liquidateCalldata
        );

        vm.stopPrank();

        //get state after liquidation
        testData.liquidatorJUsdAfterLiquidation = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAfterLiquidation = collateralContract.balanceOf(testData.liquidator);
        testData.feeAddressBalanceAfterLiquidation = collateralContract.balanceOf(manager.feeAddress());
        testData.holdingBorrowedAmountAfterLiquidation = sharesRegistry.borrowed(testData.userHolding);

        //compute expected amounts
        testData.expectedLiquidatorCollateralAfterLiquidation =
            testData.liquidatorCollateralAmountAfterInitiation + testData.liquidatorReward;

        testData.expectedFeeAddressBalance =
            testData.feeAddressBalanceAfterInitiation + testData.totalRequiredCollateral - testData.liquidatorReward;

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
            testData.expectedLiquidatorCollateralAfterLiquidation,
            "Liquidator didn't receive user's collateral after liquidation"
        );

        assertEq(
            testData.feeAddressBalanceAfterLiquidation,
            testData.expectedFeeAddressBalance,
            "feeAddress didn't receive fee after liquidation"
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
            address(managerContainer),
            address(collateralContract),
            address(collateralOracle),
            bytes(""),
            50_000
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
        holdingManager.borrow(address(collateralContract), mintAmount, true);
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
        holdingManager.borrow(address(collateralContract), mintAmount, true);
        vm.stopPrank();

        testData.liquidatorJUsd = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAmountAfterInitiation = collateralContract.balanceOf(address(testData.liquidator));

        //get feeAdress balance before liquidation
        testData.feeAddressBalanceAfterInitiation = collateralContract.balanceOf(manager.feeAddress());

        //change the price of the collateral
        collateralOracle.setPriceForLiquidation();

        //initiate liquidation from liquidator's address
        vm.startPrank(testData.liquidator, testData.liquidator);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        //compute expected liquidatorReward and jUsdAmountToBurn after liquidation
        (testData.liquidatorReward, testData.totalRequiredCollateral, testData.jUsdAmountToBurn) =
        computeLiquidationAmounts(
            address(testData.user), address(collateralContract), testData.userJUsd, liquidateCalldata
        );

        //make liquidation call
        liquidationManager.liquidate(
            address(testData.user), address(collateralContract), testData.userJUsd, liquidateCalldata
        );

        vm.stopPrank();

        //get state after liquidation
        testData.liquidatorJUsdAfterLiquidation = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAfterLiquidation = collateralContract.balanceOf(testData.liquidator);
        testData.feeAddressBalanceAfterLiquidation = collateralContract.balanceOf(manager.feeAddress());
        testData.holdingBorrowedAmountAfterLiquidation = sharesRegistry.borrowed(testData.userHolding);

        //compute expected amounts
        testData.expectedLiquidatorCollateralAfterLiquidation =
            testData.liquidatorCollateralAmountAfterInitiation + testData.liquidatorReward;

        testData.expectedFeeAddressBalance =
            testData.feeAddressBalanceAfterInitiation + testData.totalRequiredCollateral - testData.liquidatorReward;

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
            testData.expectedLiquidatorCollateralAfterLiquidation,
            "Liquidator didn't receive user's collateral after liquidation"
        );

        assertEq(
            testData.feeAddressBalanceAfterLiquidation,
            testData.expectedFeeAddressBalance,
            "feeAddress didn't receive fee after liquidation"
        );
    }

    // Tests liquidation with strategies
    // Checks various states and amounts after liquidation
    function test_liquidate_when_withStrategies(uint256 _collateralAmount, bool invest) public {
        vm.assume(_collateralAmount <= 1000e18);
        TestTempData memory testData;

        // initialize user
        testData.user = user;
        testData.userCollateralAmount = _collateralAmount;
        testData.userHolding = initiateWithUsdc(testData.user, testData.userCollateralAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);

        // initialize liquidator
        testData.liquidator = liquidator;
        testData.liquidatorCollateralAmount = _collateralAmount;
        initiateWithUsdc(testData.liquidator, testData.liquidatorCollateralAmount);
        testData.liquidatorJUsd = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAmountAfterInitiation = usdc.balanceOf(address(testData.liquidator));

        // get feeAdress balance before liquidation
        testData.feeAddressBalanceAfterInitiation = usdc.balanceOf(manager.feeAddress());

        if (invest) {
            // make investment
            vm.prank(testData.user);
            if (testData.userCollateralAmount == 0) {
                vm.expectRevert(bytes("2001"));
            }
            strategyManager.invest(
                address(usdc), address(strategyWithoutRewardsMock), testData.userCollateralAmount, ""
            );
        }

        // change the price of the usdc
        usdcOracle.setPriceForLiquidation();

        // execute liquidation from liquidator's address
        vm.startPrank(testData.liquidator, testData.liquidator);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        if (invest) {
            liquidateCalldata.strategies = new address[](1);
            liquidateCalldata.strategies[0] = address(strategyWithoutRewardsMock);
            liquidateCalldata.strategiesData = new bytes[](1);
            liquidateCalldata.strategiesData[0] = "";
        }

        //compute expected liquidatorReward and jUsdAmountToBurn after liquidation
        (testData.liquidatorReward, testData.totalRequiredCollateral, testData.jUsdAmountToBurn) =
            computeLiquidationAmounts(address(testData.user), address(usdc), testData.userJUsd, liquidateCalldata);

        // handle possible errors when making liquidation call
        if (jUsd.balanceOf(testData.liquidator) < testData.userJUsd) {
            vm.expectRevert("ERC20: burn amount exceeds balance");
            liquidationManager.liquidate(address(testData.user), address(usdc), testData.userJUsd, liquidateCalldata);
            return;
        }

        if (testData.userJUsd == 0) {
            vm.expectRevert(bytes("2001"));
        }
        //make liquidation call
        liquidationManager.liquidate(address(testData.user), address(usdc), testData.userJUsd, liquidateCalldata);

        vm.stopPrank();

        // get state after liquidation
        testData.liquidatorJUsdAfterLiquidation = jUsd.balanceOf(testData.liquidator);
        testData.liquidatorCollateralAfterLiquidation = usdc.balanceOf(testData.liquidator);
        testData.feeAddressBalanceAfterLiquidation = usdc.balanceOf(manager.feeAddress());
        testData.holdingBorrowedAmountAfterLiquidation = sharesRegistry.borrowed(testData.userHolding);

        // compute expected amounts
        testData.expectedLiquidatorCollateralAfterLiquidation =
            testData.liquidatorCollateralAmountAfterInitiation + testData.liquidatorReward;
        testData.expectedHoldingBorrowedAmountAfterLiquidation = testData.userJUsd - testData.jUsdAmountToBurn;
        testData.expectedFeeAddressBalance =
            testData.feeAddressBalanceAfterInitiation + testData.totalRequiredCollateral - testData.liquidatorReward;

        // perform checks
        assertEq(
            testData.holdingBorrowedAmountAfterLiquidation,
            testData.expectedHoldingBorrowedAmountAfterLiquidation,
            "Holding's borrow amount is incorrect after liquidation"
        );
        assertEq(
            testData.liquidatorJUsdAfterLiquidation,
            testData.liquidatorJUsd - testData.jUsdAmountToBurn,
            "jUsd wasn't taken from liquidator after liquidation"
        );
        assertEq(
            testData.liquidatorCollateralAfterLiquidation,
            testData.expectedLiquidatorCollateralAfterLiquidation,
            "Liquidator didn't receive user's collateral after liquidation"
        );

        assertApproxEqAbs(
            testData.feeAddressBalanceAfterLiquidation,
            testData.expectedFeeAddressBalance,
            2,
            "feeAddress didn't receive fee after liquidation"
        );
    }

    // Tests if retrieve collateral function reverts correctly when strategy list is provided incorrectly
    function test_liquidate_when_strategyListFormatError(
        uint256 _collateralAmount
    ) public {
        vm.assume(_collateralAmount > 1e18 && _collateralAmount <= 1000e18);
        TestTempData memory testData;

        // initialize user
        testData.user = user;
        testData.userCollateralAmount = _collateralAmount;
        testData.userHolding = initiateWithUsdc(testData.user, testData.userCollateralAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);

        // initialize liquidator
        testData.liquidator = liquidator;
        testData.liquidatorCollateralAmount = _collateralAmount;
        initiateWithUsdc(testData.liquidator, testData.liquidatorCollateralAmount);
        testData.liquidatorJUsd = jUsd.balanceOf(testData.liquidator);

        // make investment
        vm.prank(testData.user);
        if (testData.userCollateralAmount == 0) {
            vm.expectRevert(bytes("2001"));
        }
        strategyManager.invest(address(usdc), address(strategyWithoutRewardsMock), testData.userCollateralAmount, "");

        // change the price of the usdc
        usdcOracle.setPriceForLiquidation();

        // execute liquidation from liquidator's address
        vm.startPrank(testData.liquidator, testData.liquidator);

        ILiquidationManager.LiquidateCalldata memory liquidateCalldata;

        liquidateCalldata.strategies = new address[](1);
        liquidateCalldata.strategies[0] = address(strategyWithoutRewardsMock);
        liquidateCalldata.strategiesData = new bytes[](1);
        liquidateCalldata.strategiesData[0] = "";

        //compute expected liquidatorReward and jUsdAmountToBurn after liquidation
        (testData.liquidatorReward, testData.totalRequiredCollateral, testData.jUsdAmountToBurn) =
            computeLiquidationAmounts(address(testData.user), address(usdc), testData.userJUsd, liquidateCalldata);

        liquidateCalldata.strategies = new address[](2);
        liquidateCalldata.strategies[0] = address(strategyWithoutRewardsMock);
        liquidateCalldata.strategies[1] = vm.addr(uint256(keccak256(bytes("Unexisting strategy address"))));
        if (testData.userJUsd == 0) {
            vm.expectRevert(bytes("2001"));
        } else {
            vm.expectRevert(bytes("3026"));
        }
        //make liquidation call
        liquidationManager.liquidate(address(testData.user), address(usdc), testData.userJUsd, liquidateCalldata);

        vm.stopPrank();
    }

    //Utility functions

    function initiateWithUsdc(address _user, uint256 _collateralAmount) public returns (address userHolding) {
        // calculate mintAmount
        uint256 mintAmount = _collateralAmount / 2;

        // startPrank so every next call is made from the _user address (both msg.sender and tx.origin will be
        // set to _user)
        vm.startPrank(_user, _user);

        // check whether further addition will cause overflow
        (bool isNotOverflow,) = _collateralAmount.tryAdd(usdc.totalSupply());

        // expect overflow revert if _collateralAmount + usdc.totalSupply() will result in overflow
        if (!isNotOverflow) {
            vm.expectRevert(stdError.arithmeticError);
        }

        // get some usdc tokens for user
        usdc.getTokens(_collateralAmount);

        // create holding for user
        userHolding = holdingManager.createHolding();

        usdc.approve(address(holdingManager), _collateralAmount);

        bool enoughBalance = usdc.balanceOf(_user) >= _collateralAmount;

        //make deposit for user
        if (_collateralAmount == 0) {
            vm.expectRevert(bytes("2001"));
        }
        if (!enoughBalance) {
            vm.expectRevert("ERC20: transfer amount exceeds balance");
        }

        holdingManager.deposit(address(usdc), _collateralAmount);

        // borrow
        // check if mint operation will be >= jUsd.mintLimit;
        bool exceedsMintLimit = jUsd.totalSupply() + mintAmount > jUsd.mintLimit();
        bool isUserSolvent = isSolvent(_user, mintAmount, address(userHolding));

        if (mintAmount == 0) {
            vm.expectRevert(bytes("3010"));
        }
        if (exceedsMintLimit) {
            vm.expectRevert(bytes("2007"));
        } else if (!isUserSolvent) {
            vm.expectRevert(bytes("3009"));
        }

        holdingManager.borrow(address(usdc), mintAmount, true);

        vm.stopPrank();
    }

    function isSolvent(address _user, uint256 _amount, address _holding) public view returns (bool) {
        uint256 borrowedAmount = sharesRegistry.borrowed(_holding);

        if (borrowedAmount == 0) {
            return true;
        }

        uint256 amountValue = _amount.mulDiv(sharesRegistry.getExchangeRate(), manager.EXCHANGE_RATE_PRECISION());
        borrowedAmount += amountValue;

        uint256 _colRate = sharesRegistry.collateralizationRate();
        uint256 _exchangeRate = sharesRegistry.getExchangeRate();

        uint256 _result = (
            (1e18 * sharesRegistry.collateral(_user) * _exchangeRate * _colRate)
                / (manager.EXCHANGE_RATE_PRECISION() * manager.PRECISION())
        ) / 1e18;

        return _result >= borrowedAmount;
    }

    function computeLiquidationAmounts(
        address _user,
        address _collateral,
        uint256 _jUsdAmountToBurn,
        ILiquidationManager.LiquidateCalldata memory _data
    )
        public
        view
        returns (uint256 totalLiquidatorCollateral, uint256 totalRequiredCollateral, uint256 jUsdAmountToBurn)
    {
        address holding = holdingManager.userHolding(_user);

        uint256 exchangeRate = SharesRegistry(registries[_collateral]).getExchangeRate();
        totalRequiredCollateral = _getCollateralAmountForUSDValue(_collateral, _jUsdAmountToBurn, exchangeRate);

        uint256 totalAvailableCollateral = SharesRegistry(registries[_collateral]).collateral(holding);

        totalRequiredCollateral =
            totalRequiredCollateral > totalAvailableCollateral ? totalAvailableCollateral : totalRequiredCollateral;

        totalLiquidatorCollateral = (totalRequiredCollateral * liquidationManager.liquidatorBonus())
            / liquidationManager.LIQUIDATION_PRECISION();

        totalRequiredCollateral += totalLiquidatorCollateral;

        uint256 finalAvailableCollateralAmount = (_data.strategies.length > 0)
            ? _retrieveCollateral(_collateral, holding, totalRequiredCollateral, _data.strategies, _data.strategiesData)
            : totalRequiredCollateral - totalLiquidatorCollateral;

        if (totalRequiredCollateral >= finalAvailableCollateralAmount) {
            totalRequiredCollateral = finalAvailableCollateralAmount;

            // LC = FAC / (1 + (p/100))
            totalLiquidatorCollateral = _user != msg.sender
                ? (
                    totalRequiredCollateral
                        / (10 + liquidationManager.liquidatorBonus().mulDiv(10, liquidationManager.LIQUIDATION_PRECISION()))
                ) / 10
                : 0;
        }

        uint256 collateralWithJUsdDecimals = (totalRequiredCollateral != 0) ? totalRequiredCollateral : 0;
        uint256 collateralDecimals = IERC20Metadata(_collateral).decimals();
        if (collateralDecimals > 18) {
            collateralWithJUsdDecimals = collateralWithJUsdDecimals / (10 ** (collateralDecimals - 18));
        } else if (collateralDecimals < 18) {
            collateralWithJUsdDecimals = collateralWithJUsdDecimals / 10 ** (18 - collateralDecimals);
        }
        jUsdAmountToBurn = collateralWithJUsdDecimals.mulDiv(exchangeRate, manager.EXCHANGE_RATE_PRECISION());
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
        uint256 liquidatorReward;
        uint256 liquidatorJUsdAfterLiquidation;
        uint256 liquidatorCollateralAfterLiquidation;
        uint256 feeAddressBalanceAfterInitiation;
        uint256 feeAddressBalanceAfterLiquidation;
        uint256 holdingBorrowedAmountAfterLiquidation;
        uint256 totalRequiredCollateral;
        uint256 jUsdAmountToBurn;
        uint256 expectedLiquidatorCollateral;
        uint256 expectedFeeAddressBalance;
        uint256 expectedLiquidatorCollateralAfterLiquidation;
        uint256 expectedHoldingBorrowedAmountAfterLiquidation;
    }
}
