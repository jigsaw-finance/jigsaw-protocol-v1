// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { IQuoterV2 } from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";

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
import { SwapManager } from "../../src/SwapManager.sol";

import { ILiquidationManager } from "../../src/interfaces/core/ILiquidationManager.sol";
import { IReceiptToken } from "../../src/interfaces/core/IReceiptToken.sol";
import { IStrategy } from "../../src/interfaces/core/IStrategy.sol";

import { INonfungiblePositionManager } from "../utils/INonfungiblePositionManager.sol";
import { TickMath } from "../utils/TickMath.sol";
import { SampleOracle } from "../utils/mocks/SampleOracle.sol";
import { SampleOracleUniswap } from "../utils/mocks/SampleOracleUniswap.sol";
import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";
import { StrategyWithoutRewardsMock } from "../utils/mocks/StrategyWithoutRewardsMock.sol";

interface IUSDC is IERC20Metadata {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function configureMinter(address minter, uint256 minterAllowedAmount) external;
    function masterMinter() external view returns (address);
}

/// @title SelfLiquidationTest
/// @notice This contract encompasses tests and utility functions for conducting fork fuzzy testing of the
/// {selfLiquidate} function in the LiquidationManager Contract.
/// @notice for other tests of the LiquidationManager Contract see other files in this directory.
contract SelfLiquidationTest is Test {
    using Math for uint256;

    HoldingManager public holdingManager;
    IERC20Metadata public weth;
    INonfungiblePositionManager public nonfungiblePositionManager;
    IReceiptToken public receiptTokenReference;
    IUniswapV3Factory public uniswapFactory;
    IUSDC public usdc;
    IQuoterV2 public quoter;
    LiquidationManager public liquidationManager;
    Manager public manager;
    ManagerContainer public managerContainer;
    JigsawUSD public jUsd;
    ReceiptTokenFactory public receiptTokenFactory;
    SampleOracle public usdcOracle;
    SampleOracleUniswap public usdtOracle;
    SampleTokenERC20 public sampleTokenERC20;
    StablesManager public stablesManager;
    StrategyManager public strategyManager;
    StrategyWithoutRewardsMock public strategyWithoutRewardsMock;
    SwapManager public swapManager;

    //addresses of tokens used in tests on Arbitrum chain
    address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    //address of UniswapSwapRouter used in tests on Arbitrum chain
    address UniswapSwapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    mapping(address => SharesRegistry) public registries;
    uint256 internal uniswapPoolCap = 1_000_000_000;

    address public jUsdPool;
    uint256 public jUsdPoolMintTokenId;

    struct SelfLiquidationTestTempData {
        address collateral;
        address user;
        address userHolding;
        uint256 userCollateralAmount;
        uint256 userJUsd;
        uint256 selfLiquidationAmount;
        uint256 mintAmount;
        uint256 jUsdTotalSupplyBeforeSL;
        uint256 requiredCollateral;
        uint256 expectedFeeBalanceAfterSL;
        uint256 protocolFee;
        uint256 feeBalanceAfterSL;
        uint256 stabilityPoolBalanceAfterSL;
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"));

        uniswapFactory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        nonfungiblePositionManager = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
        quoter = IQuoterV2(0x61fFE014bA17989E743c5F6cB21bF9697530B21e);

        usdc = IUSDC(USDC);
        weth = IERC20Metadata(WETH);

        manager = new Manager(address(this), USDC, WETH, address(1), bytes(""));
        managerContainer = new ManagerContainer(address(this), address(manager));

        SampleOracle jUsdOracle = new SampleOracle();
        manager.requestNewJUsdOracle(address(jUsdOracle));
        vm.warp(block.timestamp + manager.timelockAmount());
        manager.setJUsdOracle();

        jUsd = new JigsawUSD(address(this), address(managerContainer));

        liquidationManager = new LiquidationManager(address(this), address(managerContainer));
        holdingManager = new HoldingManager(address(this), address(managerContainer));
        stablesManager = new StablesManager(address(this), address(managerContainer), address(jUsd));
        strategyManager = new StrategyManager(address(this), address(managerContainer));
        swapManager =
            new SwapManager(address(this), address(uniswapFactory), UniswapSwapRouter, address(managerContainer));

        manager.setStablecoinManager(address(stablesManager));
        manager.setHoldingManager(address(holdingManager));
        manager.setLiquidationManager(address(liquidationManager));
        manager.setStrategyManager(address(strategyManager));
        manager.setFeeAddress(vm.addr(uint256(keccak256(bytes("Fee Address")))));
        manager.setSwapManager(address(swapManager));

        manager.whitelistToken(USDC);
        manager.whitelistToken(USDT);

        usdcOracle = new SampleOracle();
        registries[USDC] = new SharesRegistry(
            msg.sender,
            address(managerContainer),
            USDC,
            address(usdcOracle),
            bytes(""),
            50_000 // _collateralizationRate
        );
        stablesManager.registerOrUpdateShareRegistry(address(registries[USDC]), USDC, true);

        usdtOracle = new SampleOracleUniswap(uniswapFactory.getPool(USDC, USDT, uint24(100)), USDT);
        registries[USDT] = new SharesRegistry(
            msg.sender,
            address(managerContainer),
            USDT,
            address(usdtOracle),
            bytes(""),
            50_000 //_collateralizationRate
        );
        stablesManager.registerOrUpdateShareRegistry(address(registries[USDT]), USDT, true);

        receiptTokenReference = IReceiptToken(new ReceiptToken());
        receiptTokenFactory = new ReceiptTokenFactory(address(this), address(receiptTokenReference));
        manager.setReceiptTokenFactory(address(receiptTokenFactory));

        strategyWithoutRewardsMock = new StrategyWithoutRewardsMock(
            address(managerContainer), address(usdc), address(usdc), address(0), "RUsdc-Mock", "RUSDCM"
        );
        strategyManager.addStrategy(address(strategyWithoutRewardsMock));
    }

    // This test evaluates the self-liquidation mechanism when user doesn't have a holding
    function test_selfLiquidate_when_invalidHolding() public {
        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        vm.expectRevert(bytes("3002"));
        liquidationManager.selfLiquidate(USDC, 1, swapParams, strategiesParams);
    }

    // This test evaluates the self-liquidation mechanism when collateral's registry is inactive
    function test_selfLiquidate_when_collateralRegistryActive() public {
        SelfLiquidationTestTempData memory testData;

        testData.collateral = USDC;
        testData.mintAmount = 100 * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        stablesManager.registerOrUpdateShareRegistry(
            address(registries[testData.collateral]), testData.collateral, false
        );

        vm.prank(testData.user, testData.user);
        vm.expectRevert();
        liquidationManager.selfLiquidate(testData.collateral, 1, swapParams, strategiesParams);
    }

    // This test evaluates the self-liquidation mechanism when user is insolvent
    function test_selfLiquidate_when_insolvent() public {
        SelfLiquidationTestTempData memory testData;

        testData.collateral = USDC;
        testData.mintAmount = 100 * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        usdcOracle.setAVeryLowPrice();

        vm.startPrank(testData.user, testData.user);
        vm.expectRevert(bytes("3075"));
        liquidationManager.selfLiquidate(testData.collateral, 1, swapParams, strategiesParams);
    }

    // This test evaluates the self-liquidation mechanism when self-liquidation amount > borrowed amount
    function test_selfLiquidate_when_jUsdAmountTooBig() public {
        SelfLiquidationTestTempData memory testData;

        testData.collateral = USDC;
        testData.mintAmount = 100 * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        vm.prank(testData.user, testData.user);
        vm.expectRevert(bytes("2003"));
        liquidationManager.selfLiquidate(testData.collateral, type(uint256).max, swapParams, strategiesParams);
    }

    // This test evaluates the self-liquidation mechanism when self-liquidation amount is that small that
    // due to solidity's rounding required collateral becomes 0
    function test_selfLiquidate_when_jUsdAmountTooSmall() public {
        SelfLiquidationTestTempData memory testData;

        testData.collateral = USDC;
        testData.mintAmount = 100 * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        vm.prank(testData.user, testData.user);
        vm.expectRevert(bytes("3080"));
        liquidationManager.selfLiquidate(testData.collateral, 1, swapParams, strategiesParams);
    }

    // This test evaluates the self-liquidation mechanism when the {slippagePercentage} is set too high
    function test_selfLiquidate_when_slippageTooHigh(uint256 _amount, uint256 _slippagePercentage) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < uniswapPoolCap);
        vm.assume(_slippagePercentage > liquidationManager.LIQUIDATION_PRECISION());

        testData.collateral = USDC;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd / 2;

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        swapParams.slippagePercentage = _slippagePercentage;
        swapParams.amountInMaximum = type(uint256).max;

        vm.prank(testData.user, testData.user);
        vm.expectRevert(bytes("3081"));
        liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );
    }

    // This test evaluates the self-liquidation mechanism when {amountIn} is set too big, i.e.
    // {slippagePercentage} doesn't allow that big deviation
    function test_selfLiquidate_when_amountInTooBig(
        uint256 _amount
    ) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < uniswapPoolCap);

        testData.collateral = USDC;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd / 2;
        testData.userCollateralAmount = IERC20(testData.collateral).balanceOf(testData.userHolding);
        testData.jUsdTotalSupplyBeforeSL = jUsd.totalSupply();
        testData.requiredCollateral = _getCollateralAmountForUSDValue(
            testData.collateral, testData.selfLiquidationAmount, registries[testData.collateral].getExchangeRate()
        );
        testData.protocolFee = testData.requiredCollateral.mulDiv(
            liquidationManager.selfLiquidationFee(), liquidationManager.LIQUIDATION_PRECISION()
        );
        testData.requiredCollateral += testData.protocolFee;

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        // we allow 0,1% slippage for this test case, but that will not be enough and function
        // should revert with error "3078"
        swapParams.slippagePercentage = 0.1e3;
        swapParams.amountInMaximum = testData.requiredCollateral * 2;

        vm.prank(testData.user, testData.user);
        vm.expectRevert(bytes("3078"));
        liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );
    }

    // This test evaluates the self-liquidation mechanism when the required collateral exceeds the collateral
    // amount available in holding
    function test_selfLiquidate_when_notEnoughAvailableCollateral(
        uint256 _amount
    ) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < uniswapPoolCap);

        testData.collateral = USDC;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd / 2;
        testData.userCollateralAmount = IERC20(testData.collateral).balanceOf(testData.userHolding);
        testData.jUsdTotalSupplyBeforeSL = jUsd.totalSupply();
        testData.requiredCollateral = _getCollateralAmountForUSDValue(
            testData.collateral, testData.selfLiquidationAmount, registries[testData.collateral].getExchangeRate()
        );
        testData.protocolFee = testData.requiredCollateral.mulDiv(
            liquidationManager.selfLiquidationFee(), liquidationManager.LIQUIDATION_PRECISION()
        );
        testData.requiredCollateral += testData.protocolFee;

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        // we allow 100% slippage for this test case, but there will not be enough collateral and function
        // should revert with error "3076"
        swapParams.slippagePercentage = 1e5;
        swapParams.amountInMaximum = testData.requiredCollateral * 2;

        vm.startPrank(testData.user, testData.user);

        // Reduce amount of available collateral even more to get wanted error
        strategyManager.invest(address(usdc), address(strategyWithoutRewardsMock), testData.userCollateralAmount, "");

        vm.expectRevert(bytes("3076"));
        liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );

        vm.stopPrank();
    }

    // This test evaluates the self-liquidation mechanism when:
    //      * invalid path provided
    //      * collateral is denominated in USDC
    function test_selfLiquidate_when_invalidPath_USDC() public {
        SelfLiquidationTestTempData memory testData;

        testData.collateral = USDC;
        testData.mintAmount = 100 * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        vm.prank(testData.user, testData.user);
        vm.expectRevert(bytes("3077"));
        liquidationManager.selfLiquidate(testData.collateral, testData.mintAmount / 100, swapParams, strategiesParams);
    }

    // This test evaluates the self-liquidation mechanism when:
    //      * invalid path provided
    //      * collateral is denominated in USDT
    function test_selfLiquidate_when_invalidPath_USDT() public {
        SelfLiquidationTestTempData memory testData;

        testData.collateral = USDT;
        testData.mintAmount = 100 * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        vm.prank(testData.user, testData.user);
        vm.expectRevert(bytes("3077"));
        liquidationManager.selfLiquidate(testData.collateral, testData.mintAmount / 100, swapParams, strategiesParams);
    }

    // This test evaluates the self-liquidation mechanism when:
    //      * the entire user debt is self-liquidated
    //      * without strategies
    //      * collateral is denominated in USDC
    //      * no jUsd in the Uniswap pool
    function test_selfLiquidate_when_fullDebt_USDC_withoutStrategies_jUSDPoolEmpty(
        uint256 _amount
    ) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < uniswapPoolCap);
        testData.collateral = USDC;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd;
        testData.userCollateralAmount = IERC20(testData.collateral).balanceOf(testData.userHolding);
        testData.requiredCollateral = _getCollateralAmountForUSDValue(
            testData.collateral, testData.selfLiquidationAmount, registries[testData.collateral].getExchangeRate()
        );
        testData.protocolFee = testData.requiredCollateral.mulDiv(
            liquidationManager.selfLiquidationFee(), liquidationManager.LIQUIDATION_PRECISION()
        );
        testData.requiredCollateral += testData.protocolFee;
        testData.expectedFeeBalanceAfterSL =
            IERC20(testData.collateral).balanceOf(manager.feeAddress()) + testData.protocolFee;

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        swapParams.swapPath = abi.encodePacked(jUsd, uint24(100), testData.collateral);
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        vm.prank(testData.user, testData.user);
        vm.expectRevert(bytes("3083"));
        liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );
    }

    // This test evaluates the self-liquidation mechanism when:
    //      * the entire user debt is self-liquidated
    //      * without strategies
    //      * collateral is denominated in USDT
    //      * no jUsd in the Uniswap pool
    function test_selfLiquidate_when_fullDebt_USDT_withoutStrategies_jUSDPoolEmpty(
        uint256 _amount
    ) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < 100_000);

        testData.collateral = USDT;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd;
        testData.userCollateralAmount = IERC20(USDT).balanceOf(testData.userHolding);
        testData.jUsdTotalSupplyBeforeSL = jUsd.totalSupply();
        testData.requiredCollateral = _getCollateralAmountForUSDValue(
            testData.collateral, testData.selfLiquidationAmount, registries[testData.collateral].getExchangeRate()
        );
        testData.protocolFee = testData.requiredCollateral.mulDiv(
            liquidationManager.selfLiquidationFee(), liquidationManager.LIQUIDATION_PRECISION()
        );
        testData.requiredCollateral += testData.protocolFee;
        testData.expectedFeeBalanceAfterSL =
            IERC20(testData.collateral).balanceOf(manager.feeAddress()) + testData.protocolFee;

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        swapParams.swapPath = abi.encodePacked(address(jUsd), uint24(100), USDC, uint24(100), testData.collateral);

        (swapParams.amountInMaximum,,,) = quoter.quoteExactOutput(
            abi.encodePacked(testData.collateral, uint24(100), USDC), testData.requiredCollateral
        );
        swapParams.slippagePercentage = 1e3; // we allow 1% slippage for this test case

        vm.prank(testData.user, testData.user);
        vm.expectRevert(bytes("3083"));
        liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );
    }

    // This test evaluates the self-liquidation mechanism when:
    //      * the entire user debt is self-liquidated
    //      * without strategies
    //      * collateral is denominated in USDC
    //      * there is jUsd in the Uniswap pool
    function test_selfLiquidate_when_fullDebt_USDC_withoutStrategies_jUSDPoolNotEmpty(
        uint256 _amount
    ) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < uniswapPoolCap);

        _createJUsdUsdcPool();

        testData.collateral = USDC;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd;
        testData.userCollateralAmount = IERC20(testData.collateral).balanceOf(testData.userHolding);
        testData.jUsdTotalSupplyBeforeSL = jUsd.totalSupply();
        testData.requiredCollateral = _getCollateralAmountForUSDValue(
            testData.collateral, testData.selfLiquidationAmount, registries[testData.collateral].getExchangeRate()
        );
        testData.protocolFee = testData.requiredCollateral.mulDiv(
            liquidationManager.selfLiquidationFee(), liquidationManager.LIQUIDATION_PRECISION()
        );
        testData.requiredCollateral += testData.protocolFee;
        uint256 feeBalanceBeforeSL = IERC20(testData.collateral).balanceOf(manager.feeAddress());

        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;
        ILiquidationManager.SwapParamsCalldata memory swapParams;
        swapParams.swapPath = abi.encodePacked(address(jUsd), uint24(100), testData.collateral);
        (swapParams.amountInMaximum,,,) = quoter.quoteExactOutput(swapParams.swapPath, testData.selfLiquidationAmount);
        swapParams.slippagePercentage = 0.1e3; // we allow 0.1% slippage for this test case
        swapParams.deadline = block.timestamp;

        uint256 limit = testData.requiredCollateral
            + testData.requiredCollateral.mulDiv(swapParams.slippagePercentage, liquidationManager.LIQUIDATION_PRECISION());
        if (swapParams.amountInMaximum > limit) return;

        vm.prank(testData.user, testData.user);
        liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );

        assertGe(
            IERC20(testData.collateral).balanceOf(manager.feeAddress()), feeBalanceBeforeSL, "Fee balance incorrect"
        );
        assertEq(
            registries[testData.collateral].borrowed(testData.userHolding),
            testData.userJUsd - testData.selfLiquidationAmount,
            "Total borrow incorrect"
        );
        assertEq(
            testData.jUsdTotalSupplyBeforeSL - testData.selfLiquidationAmount,
            jUsd.totalSupply(),
            "Total supply incorrect"
        );
        assertApproxEqRel(
            testData.userCollateralAmount - testData.requiredCollateral,
            IERC20(testData.collateral).balanceOf(testData.userHolding),
            0.001e18, // 0.1 % approimation
            "Holding collateral incorrect"
        );
    }

    // This test evaluates the self-liquidation mechanism when:
    //      * the entire user debt is self-liquidated
    //      * without strategies
    //      * collateral is denominated in USDT
    //      * there is jUsd in the Uniswap pool
    function test_selfLiquidate_when_fullDebt_USDT_withoutStrategies_jUSDPoolNotEmpty(
        uint256 _amount
    ) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < 100_000);

        _createJUsdUsdcPool();

        testData.collateral = USDT;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd;
        testData.userCollateralAmount = IERC20(USDT).balanceOf(testData.userHolding);
        testData.jUsdTotalSupplyBeforeSL = jUsd.totalSupply();
        testData.requiredCollateral = _getCollateralAmountForUSDValue(
            testData.collateral, testData.selfLiquidationAmount, registries[testData.collateral].getExchangeRate()
        );
        testData.protocolFee = testData.requiredCollateral.mulDiv(
            liquidationManager.selfLiquidationFee(), liquidationManager.LIQUIDATION_PRECISION()
        );
        testData.requiredCollateral += testData.protocolFee;
        testData.expectedFeeBalanceAfterSL =
            IERC20(testData.collateral).balanceOf(manager.feeAddress()) + testData.protocolFee;

        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;
        ILiquidationManager.SwapParamsCalldata memory swapParams;

        swapParams.swapPath = abi.encodePacked(address(jUsd), uint24(100), USDC, uint24(100), testData.collateral);
        (swapParams.amountInMaximum,,,) = quoter.quoteExactOutput(swapParams.swapPath, testData.selfLiquidationAmount);
        swapParams.slippagePercentage = 0.1e3; // we allow 0.1% slippage for this test case
        swapParams.amountInMaximum = swapParams.amountInMaximum * 101 / 100;
        swapParams.deadline = block.timestamp;

        vm.prank(testData.user, testData.user);
        liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );

        assertApproxEqRel(
            IERC20(testData.collateral).balanceOf(manager.feeAddress()),
            testData.expectedFeeBalanceAfterSL,
            0.08e18, // 8% approximation
            "FEE balance incorrect"
        );
        assertEq(
            registries[testData.collateral].borrowed(testData.userHolding),
            testData.userJUsd - testData.selfLiquidationAmount,
            "Total borrow incorrect"
        );
        assertEq(
            testData.jUsdTotalSupplyBeforeSL - testData.selfLiquidationAmount,
            jUsd.totalSupply(),
            "Total supply incorrect"
        );
        assertApproxEqRel(
            testData.userCollateralAmount - testData.requiredCollateral,
            IERC20(testData.collateral).balanceOf(testData.userHolding),
            0.01e18, // 1% approximation
            "Holding collateral incorrect"
        );
    }

    // This test evaluates the self-liquidation mechanism when:
    //      * the entire user debt is self-liquidated
    //      * with strategies
    //      * collateral is denominated in USDC
    //      * there is jUsd in the Uniswap pool
    function test_selfLiquidate_when_fullDebt_USDC_withStrategies_jUSDPoolNotEmpty(
        uint256 _amount
    ) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < uniswapPoolCap);

        _createJUsdUsdcPool();

        testData.collateral = USDC;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd;
        testData.userCollateralAmount = IERC20(testData.collateral).balanceOf(testData.userHolding);
        testData.jUsdTotalSupplyBeforeSL = jUsd.totalSupply();
        testData.requiredCollateral = _getCollateralAmountForUSDValue(
            testData.collateral, testData.selfLiquidationAmount, registries[testData.collateral].getExchangeRate()
        );
        testData.protocolFee = testData.requiredCollateral.mulDiv(
            liquidationManager.selfLiquidationFee(), liquidationManager.LIQUIDATION_PRECISION()
        );
        testData.requiredCollateral += testData.protocolFee;
        uint256 feeBalanceBeforeSL = IERC20(testData.collateral).balanceOf(manager.feeAddress());

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        swapParams.swapPath = abi.encodePacked(address(jUsd), uint24(100), testData.collateral);
        (swapParams.amountInMaximum,,,) = quoter.quoteExactOutput(swapParams.swapPath, testData.selfLiquidationAmount);
        swapParams.slippagePercentage = 0.1e3; // we allow 0.1% slippage for this test case
        swapParams.deadline = block.timestamp;

        vm.startPrank(testData.user, testData.user);
        strategyManager.invest(address(usdc), address(strategyWithoutRewardsMock), testData.userCollateralAmount, "");
        uint256 strategyBalanceBeforeSL = usdc.balanceOf(address(strategyWithoutRewardsMock));

        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;
        strategiesParams.useHoldingBalance = true;
        strategiesParams.strategies = new address[](1);
        strategiesParams.strategies[0] = address(strategyWithoutRewardsMock);
        strategiesParams.strategiesData = new bytes[](1);
        strategiesParams.strategiesData[0] = "";

        uint256 limit = testData.requiredCollateral
            + testData.requiredCollateral.mulDiv(swapParams.slippagePercentage, liquidationManager.LIQUIDATION_PRECISION());
        if (swapParams.amountInMaximum > limit) return;

        liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );
        vm.stopPrank();

        assertGe(
            IERC20(testData.collateral).balanceOf(manager.feeAddress()), feeBalanceBeforeSL, "Fee balance incorrect"
        );
        assertEq(
            registries[testData.collateral].borrowed(testData.userHolding),
            testData.userJUsd - testData.selfLiquidationAmount,
            "Total borrow incorrect"
        );
        assertEq(
            testData.jUsdTotalSupplyBeforeSL - testData.selfLiquidationAmount,
            jUsd.totalSupply(),
            "Total supply incorrect"
        );
        assertEq(0, IERC20(testData.collateral).balanceOf(testData.userHolding), "Holding collateral incorrect");
        assertApproxEqRel(
            strategyBalanceBeforeSL - testData.requiredCollateral,
            usdc.balanceOf(address(strategyWithoutRewardsMock)),
            0.08e18,
            "Strategy balance incorrect"
        );
    }

    // This test evaluates the self-liquidation mechanism when:
    //      * 1/2 user's debt is self-liquidated
    //      * with strategies - full user's debt should be liquidated
    //      and only collateral from the strategy should be taken, without
    //      affecting holding's collateral
    //      * collateral is denominated in USDC
    //      * there is jUsd in the Uniswap pool
    function test_selfLiquidate_when_halfDebt_USDC_withStrategiesOnly_jUSDPoolNotEmpty(
        uint256 _amount
    ) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < uniswapPoolCap);

        _createJUsdUsdcPool();

        testData.collateral = USDC;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd / 2;
        testData.userCollateralAmount = IERC20(testData.collateral).balanceOf(testData.userHolding);
        testData.jUsdTotalSupplyBeforeSL = jUsd.totalSupply();
        testData.requiredCollateral = _getCollateralAmountForUSDValue(
            testData.collateral, testData.selfLiquidationAmount, registries[testData.collateral].getExchangeRate()
        );
        testData.protocolFee = testData.requiredCollateral.mulDiv(
            liquidationManager.selfLiquidationFee(), liquidationManager.LIQUIDATION_PRECISION()
        );
        testData.requiredCollateral += testData.protocolFee;
        uint256 feeBalanceBeforeSL = IERC20(testData.collateral).balanceOf(manager.feeAddress());

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        swapParams.swapPath = abi.encodePacked(address(jUsd), uint24(100), testData.collateral);
        (swapParams.amountInMaximum,,,) = quoter.quoteExactOutput(swapParams.swapPath, testData.selfLiquidationAmount);
        swapParams.slippagePercentage = 0.1e3; // we allow 0.1% slippage for this test case
        swapParams.deadline = block.timestamp;

        uint256 investAmount = swapParams.amountInMaximum * 2;

        vm.startPrank(testData.user, testData.user);

        strategyManager.invest(address(usdc), address(strategyWithoutRewardsMock), investAmount, "");

        uint256 strategyBalanceBeforeSL = usdc.balanceOf(address(strategyWithoutRewardsMock));

        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;
        strategiesParams.useHoldingBalance = false;
        strategiesParams.strategies = new address[](1);
        strategiesParams.strategies[0] = address(strategyWithoutRewardsMock);
        strategiesParams.strategiesData = new bytes[](1);
        strategiesParams.strategiesData[0] = "";

        uint256 limit = testData.requiredCollateral
            + testData.requiredCollateral.mulDiv(swapParams.slippagePercentage, liquidationManager.LIQUIDATION_PRECISION());
        if (swapParams.amountInMaximum > limit) return;

        if (swapParams.amountInMaximum > strategyBalanceBeforeSL) {
            vm.expectRevert(bytes("3076"));
            liquidationManager.selfLiquidate(
                testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
            );
            return;
        }

        (uint256 collateralUsed,) = liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );
        vm.stopPrank();

        assertGe(
            IERC20(testData.collateral).balanceOf(manager.feeAddress()), feeBalanceBeforeSL, "Fee balance incorrect"
        );
        assertEq(
            registries[testData.collateral].borrowed(testData.userHolding),
            testData.userJUsd - testData.selfLiquidationAmount,
            "Total borrow incorrect"
        );
        assertEq(
            testData.jUsdTotalSupplyBeforeSL - testData.selfLiquidationAmount,
            jUsd.totalSupply(),
            "Total supply incorrect"
        );
        assertEq(
            testData.userCollateralAmount - investAmount,
            IERC20(testData.collateral).balanceOf(testData.userHolding),
            "Holding collateral incorrect"
        );
        assertEq(
            strategyBalanceBeforeSL - collateralUsed,
            usdc.balanceOf(address(strategyWithoutRewardsMock)),
            "Strategy balance incorrect"
        );
    }

    // This test evaluates the self-liquidation mechanism when:
    //      * the entire user debt is self-liquidated
    //      * with strategies, but there is enough collateral in holding (strategies should be ignored)
    //      * collateral is denominated in USDC
    //      * there is jUsd in the Uniswap pool
    function test_selfLiquidate_when_fullDebt_USDC_withStrategies_jUSDPoolNotEmpty_useOnlyHoldingBalance(
        uint256 _amount
    ) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < uniswapPoolCap);

        _createJUsdUsdcPool();

        testData.collateral = USDC;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd;
        testData.userCollateralAmount = IERC20(testData.collateral).balanceOf(testData.userHolding);
        testData.jUsdTotalSupplyBeforeSL = jUsd.totalSupply();
        testData.requiredCollateral = _getCollateralAmountForUSDValue(
            testData.collateral, testData.selfLiquidationAmount, registries[testData.collateral].getExchangeRate()
        );
        testData.protocolFee = testData.requiredCollateral.mulDiv(
            liquidationManager.selfLiquidationFee(), liquidationManager.LIQUIDATION_PRECISION()
        );
        testData.requiredCollateral += testData.protocolFee;
        uint256 feeBalanceBeforeSL = IERC20(testData.collateral).balanceOf(manager.feeAddress());

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        swapParams.swapPath = abi.encodePacked(address(jUsd), uint24(100), testData.collateral);
        (swapParams.amountInMaximum,,,) = quoter.quoteExactOutput(swapParams.swapPath, testData.selfLiquidationAmount);
        swapParams.slippagePercentage = 0.1e3; // we allow 0.1% slippage for this test case
        swapParams.deadline = block.timestamp;

        vm.prank(testData.user, testData.user);
        strategyManager.invest(address(usdc), address(strategyWithoutRewardsMock), testData.userCollateralAmount, "");
        uint256 strategyBalanceBeforeSL = usdc.balanceOf(address(strategyWithoutRewardsMock));

        // Increase holding's balance so strategies are ingnored
        _getUSDC(testData.userHolding, testData.requiredCollateral * 2);
        testData.userCollateralAmount = IERC20(testData.collateral).balanceOf(testData.userHolding);

        vm.startPrank(testData.user, testData.user);

        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;
        strategiesParams.useHoldingBalance = true;
        strategiesParams.strategies = new address[](1);
        strategiesParams.strategies[0] = address(strategyWithoutRewardsMock);
        strategiesParams.strategiesData = new bytes[](1);
        strategiesParams.strategiesData[0] = "";

        uint256 limit = testData.requiredCollateral
            + testData.requiredCollateral.mulDiv(swapParams.slippagePercentage, liquidationManager.LIQUIDATION_PRECISION());
        if (swapParams.amountInMaximum > limit) return;
        liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );
        vm.stopPrank();

        uint256 expectedHoldingBalance = swapParams.amountInMaximum > testData.requiredCollateral
            ? testData.userCollateralAmount - swapParams.amountInMaximum
            : testData.userCollateralAmount - testData.requiredCollateral;

        assertGe(
            IERC20(testData.collateral).balanceOf(manager.feeAddress()), feeBalanceBeforeSL, "Fee balance incorrect"
        );
        assertEq(
            registries[testData.collateral].borrowed(testData.userHolding),
            testData.userJUsd - testData.selfLiquidationAmount,
            "Total borrow incorrect"
        );
        assertEq(
            testData.jUsdTotalSupplyBeforeSL - testData.selfLiquidationAmount,
            jUsd.totalSupply(),
            "Total supply incorrect"
        );
        assertEq(
            expectedHoldingBalance,
            IERC20(testData.collateral).balanceOf(testData.userHolding),
            "Holding collateral incorrect"
        );
        assertEq(
            strategyBalanceBeforeSL, usdc.balanceOf(address(strategyWithoutRewardsMock)), "Strategy balance incorrect"
        );
    }

    // This test evaluates the self-liquidation mechanism when:
    //      * the entire user debt is self-liquidated
    //      * without strategies
    //      * collateral is denominated in USDT
    //      * there is jUsd in the Uniswap pool
    //      * {slippagePercentage} and {amountInMaximum} are set higher
    function test_selfLiquidate_when_fullDebt_USDT_withoutStrategies_jUSDPoolNotEmpty_highSlippage(
        uint256 _amount
    ) public {
        SelfLiquidationTestTempData memory testData;
        vm.assume(_amount > 0 && _amount < 100_000);

        _createJUsdUsdcPool();

        testData.collateral = USDT;
        testData.mintAmount = _amount * (10 ** jUsd.decimals());
        testData.user = address(1);
        testData.userHolding = initiateUser(testData.user, testData.collateral, testData.mintAmount);
        testData.userJUsd = jUsd.balanceOf(testData.user);
        testData.selfLiquidationAmount = testData.userJUsd;
        testData.userCollateralAmount = IERC20(testData.collateral).balanceOf(testData.userHolding);
        testData.jUsdTotalSupplyBeforeSL = jUsd.totalSupply();
        testData.requiredCollateral = _getCollateralAmountForUSDValue(
            testData.collateral, testData.selfLiquidationAmount, registries[testData.collateral].getExchangeRate()
        );
        testData.protocolFee = testData.requiredCollateral.mulDiv(
            liquidationManager.selfLiquidationFee(), liquidationManager.LIQUIDATION_PRECISION()
        );
        testData.requiredCollateral += testData.protocolFee;
        testData.expectedFeeBalanceAfterSL =
            IERC20(testData.collateral).balanceOf(manager.feeAddress()) + testData.protocolFee;

        ILiquidationManager.SwapParamsCalldata memory swapParams;
        ILiquidationManager.StrategiesParamsCalldata memory strategiesParams;

        swapParams.swapPath = abi.encodePacked(address(jUsd), uint24(100), USDC, uint24(100), testData.collateral);
        swapParams.slippagePercentage = 50e3; // we allow 50% slippage for this test case
        swapParams.amountInMaximum = testData.requiredCollateral
            + testData.requiredCollateral.mulDiv(swapParams.slippagePercentage, liquidationManager.LIQUIDATION_PRECISION());
        swapParams.deadline = block.timestamp;

        deal(testData.collateral, testData.userHolding, testData.requiredCollateral * 2);
        testData.userCollateralAmount = IERC20(testData.collateral).balanceOf(testData.userHolding);

        vm.prank(testData.user, testData.user);
        liquidationManager.selfLiquidate(
            testData.collateral, testData.selfLiquidationAmount, swapParams, strategiesParams
        );

        assertApproxEqRel(
            IERC20(testData.collateral).balanceOf(manager.feeAddress()),
            testData.expectedFeeBalanceAfterSL,
            0.08e18, //8% approximation
            "FEE balance incorrect"
        );
        assertEq(
            registries[testData.collateral].borrowed(testData.userHolding),
            testData.userJUsd - testData.selfLiquidationAmount,
            "Total borrow incorrect"
        );
        assertEq(
            jUsd.totalSupply(),
            testData.jUsdTotalSupplyBeforeSL - testData.selfLiquidationAmount,
            "Total supply incorrect"
        );
        assertApproxEqRel(
            testData.userCollateralAmount - testData.requiredCollateral,
            IERC20(testData.collateral).balanceOf(testData.userHolding),
            0.001e18, //0.1% approximation
            "Holding collateral incorrect"
        );
    }

    //Utility functions

    function initiateUser(
        address _user,
        address _collateral,
        uint256 _mintAmount
    ) public returns (address userHolding) {
        jUsd.updateMintLimit(type(uint256).max);
        IERC20Metadata collateralContract = IERC20Metadata(_collateral);

        uint256 _collateralAmount =
            _getCollateralAmountForUSDValue(_collateral, _mintAmount, registries[_collateral].getExchangeRate()) * 2;

        //get tokens for user
        if (_collateral == USDC) {
            _getUSDC(_user, _collateralAmount);
        } else {
            deal(_collateral, _user, _collateralAmount);
        }

        //startPrank so every next call is made from the _user address (both msg.sender and
        // tx.origin will be set to _user)
        vm.startPrank(_user, _user);

        // create holding for user
        userHolding = holdingManager.createHolding();

        // make deposit to the holding
        collateralContract.approve(address(holdingManager), _collateralAmount);
        holdingManager.deposit(_collateral, _collateralAmount);

        // borrow
        //check if mint operation will be > jUsd.mintLimit;
        bool exceedsMintLimit = jUsd.totalSupply() + _mintAmount > jUsd.mintLimit();
        bool isUserSolvent = isSolvent(_user, _collateral, _mintAmount, address(userHolding));

        //borrow jUsd
        if (_mintAmount == 0) {
            vm.expectRevert(bytes("3010"));
        }
        if (exceedsMintLimit) {
            vm.expectRevert(bytes("2007"));
        }
        if (!isUserSolvent) {
            vm.expectRevert(bytes("3009"));
        }
        holdingManager.borrow(_collateral, _collateralAmount / 4, true);

        vm.stopPrank();
    }

    function _getUSDC(address _receiver, uint256 amount) internal {
        vm.prank(usdc.masterMinter());
        usdc.configureMinter(_receiver, type(uint256).max);

        vm.prank(_receiver);
        usdc.mint(_receiver, amount);
    }

    function isSolvent(
        address _user,
        address _collateral,
        uint256 _amount,
        address _holding
    ) public view returns (bool) {
        uint256 borrowedAmount = registries[_collateral].borrowed(_holding);

        if (borrowedAmount == 0) {
            return true;
        }

        uint256 amountValue =
            _amount.mulDiv(registries[_collateral].getExchangeRate(), manager.EXCHANGE_RATE_PRECISION());
        borrowedAmount += amountValue;

        uint256 _colRate = registries[_collateral].collateralizationRate();
        uint256 _exchangeRate = registries[_collateral].getExchangeRate();

        uint256 _result = (
            (1e18 * registries[_collateral].collateral(_user) * _exchangeRate * _colRate)
                / (manager.EXCHANGE_RATE_PRECISION() * manager.PRECISION())
        ) / 1e18;

        return _result >= borrowedAmount;
    }

    function _getCollateralAmountForUSDValue(
        address _collateral,
        uint256 _jUSDAmount,
        uint256 _exchangeRate
    ) private view returns (uint256 totalCollateral) {
        // calculate based on the USD value
        totalCollateral = (1e18 * _jUSDAmount * manager.EXCHANGE_RATE_PRECISION()) / (_exchangeRate * 1e18);

        // transform from 18 decimals to collateral's decimals
        uint256 collateralDecimals = IERC20Metadata(_collateral).decimals();

        if (collateralDecimals > 18) {
            totalCollateral = totalCollateral * (10 ** (collateralDecimals - 18));
        } else if (collateralDecimals < 18) {
            totalCollateral = totalCollateral / (10 ** (18 - collateralDecimals));
        }
    }

    //imitates functioning of _retrieveCollateral function, but
    //does not really retrieve collateral, just computes its amount in strategies
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

    // crestes Uniswap pool for jUsd and initiates it with volume of {uniswapPoolCap}
    function _createJUsdUsdcPool() internal returns (address pool, uint256 tokenId) {
        address token0 = address(jUsd);
        address token1 = USDC;

        uint256 jUsdAmount = uniswapPoolCap * 10 ** jUsd.decimals();
        uint256 usdcAmount = uniswapPoolCap * 10 ** usdc.decimals();
        uint24 fee = 100;
        uint160 sqrtPriceX96 = 79_228_162_514_264_337_593_543; //price of approx 1 to 1

        pool = nonfungiblePositionManager.createAndInitializePoolIfNecessary(token0, token1, fee, sqrtPriceX96);

        //get usdc and jUsd and approve spending
        deal(address(jUsd), address(this), jUsdAmount * 2, true);
        _getUSDC(address(this), usdcAmount * 2);

        jUsd.approve(address(nonfungiblePositionManager), type(uint256).max);
        usdc.approve(address(nonfungiblePositionManager), type(uint256).max);

        (tokenId,,,) = nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: TickMath.MIN_TICK,
                tickUpper: TickMath.MAX_TICK,
                amount0Desired: jUsdAmount,
                amount1Desired: usdcAmount,
                amount0Min: 1,
                amount1Min: 1,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
    }
}
