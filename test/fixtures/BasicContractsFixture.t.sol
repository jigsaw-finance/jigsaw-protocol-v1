// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { ILiquidationManager } from "../../src/interfaces/core/ILiquidationManager.sol";
import { IManager } from "../../src/interfaces/core/IManager.sol";
import { IReceiptToken } from "../../src/interfaces/core/IReceiptToken.sol";
import { ISharesRegistry } from "../../src/interfaces/core/ISharesRegistry.sol";
import { IStrategy } from "../../src/interfaces/core/IStrategy.sol";
import { IStrategyManager } from "../../src/interfaces/core/IStrategyManager.sol";

import { HoldingManager } from "../../src/HoldingManager.sol";
import { JigsawUSD } from "../../src/JigsawUSD.sol";
import { LiquidationManager } from "../../src/LiquidationManager.sol";
import { Manager } from "../../src/Manager.sol";
import { ReceiptToken } from "../../src/ReceiptToken.sol";
import { ReceiptTokenFactory } from "../../src/ReceiptTokenFactory.sol";
import { SharesRegistry } from "../../src/SharesRegistry.sol";
import { StablesManager } from "../../src/StablesManager.sol";
import { StrategyManager } from "../../src/StrategyManager.sol";
import { SampleOracle } from "../utils/mocks/SampleOracle.sol";
import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";
import { StrategyWithoutRewardsMock } from "../utils/mocks/StrategyWithoutRewardsMock.sol";
import { wETHMock } from "../utils/mocks/wETHMock.sol";

abstract contract BasicContractsFixture is Test {
    address internal constant OWNER = address(uint160(uint256(keccak256("owner"))));

    using Math for uint256;

    IReceiptToken public receiptTokenReference;
    HoldingManager internal holdingManager;
    LiquidationManager internal liquidationManager;
    IManager internal manager;
    JigsawUSD internal jUsd;
    ReceiptTokenFactory internal receiptTokenFactory;
    SampleOracle internal usdcOracle;
    SampleOracle internal jUsdOracle;
    SampleTokenERC20 internal usdc;
    wETHMock internal weth;
    SharesRegistry internal sharesRegistry;
    SharesRegistry internal wethSharesRegistry;
    StablesManager internal stablesManager;
    StrategyManager internal strategyManager;
    StrategyWithoutRewardsMock internal strategyWithoutRewardsMock;

    // collateral to registry mapping
    mapping(address => address) internal registries;

    function init() public {
        vm.startPrank(OWNER);
        vm.warp(1_641_070_800);

        usdc = new SampleTokenERC20("USDC", "USDC", 0);
        usdcOracle = new SampleOracle();

        weth = new wETHMock();
        SampleOracle wethOracle = new SampleOracle();

        jUsdOracle = new SampleOracle();

        manager = new Manager(OWNER, address(weth), address(jUsdOracle), bytes(""));

        jUsd = new JigsawUSD(OWNER, address(manager));
        jUsd.updateMintLimit(type(uint256).max);

        holdingManager = new HoldingManager(OWNER, address(manager));
        liquidationManager = new LiquidationManager(OWNER, address(manager));
        stablesManager = new StablesManager(OWNER, address(manager), address(jUsd));
        strategyManager = new StrategyManager(OWNER, address(manager));

        sharesRegistry = new SharesRegistry(
            OWNER,
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

        wethSharesRegistry = new SharesRegistry(
            OWNER,
            address(manager),
            address(weth),
            address(wethOracle),
            bytes(""),
            ISharesRegistry.RegistryConfig({
                collateralizationRate: 50_000,
                liquidationBuffer: 5e3,
                liquidatorBonus: 8e3
            })
        );

        receiptTokenReference = IReceiptToken(new ReceiptToken());
        receiptTokenFactory = new ReceiptTokenFactory(OWNER, address(receiptTokenReference));

        manager.setReceiptTokenFactory(address(receiptTokenFactory));

        manager.setFeeAddress(address(uint160(uint256(keccak256(bytes("Fee address"))))));

        manager.whitelistToken(address(usdc));
        manager.whitelistToken(address(weth));

        manager.setStablecoinManager(address(stablesManager));
        manager.setHoldingManager(address(holdingManager));
        manager.setLiquidationManager(address(liquidationManager));
        manager.setStrategyManager(address(strategyManager));

        strategyWithoutRewardsMock = new StrategyWithoutRewardsMock({
            _manager: address(manager),
            _tokenIn: address(usdc),
            _tokenOut: address(usdc),
            _rewardToken: address(0),
            _receiptTokenName: "RUsdc-Mock",
            _receiptTokenSymbol: "RUSDCM"
        });
        strategyManager.addStrategy(address(strategyWithoutRewardsMock));

        stablesManager.registerOrUpdateShareRegistry(address(wethSharesRegistry), address(weth), true);
        registries[address(weth)] = address(wethSharesRegistry);

        stablesManager.registerOrUpdateShareRegistry(address(sharesRegistry), address(usdc), true);
        registries[address(usdc)] = address(sharesRegistry);
        vm.stopPrank();
    }

    function assumeNotOwnerNotZero(
        address _user
    ) internal pure virtual {
        vm.assume(_user != OWNER);
        vm.assume(_user != address(0));
    }

    // Utility functions

    function initiateUser(
        address _user,
        address _collateral,
        uint256 _mintAmount
    ) public returns (address userHolding) {
        IERC20Metadata collateralContract = IERC20Metadata(_collateral);

        uint256 _collateralAmount =
            _getCollateralAmountForUSDValue(_collateral, _mintAmount, sharesRegistry.getExchangeRate()) * 2;

        //get tokens for user
        deal(_collateral, _user, _collateralAmount);

        //startPrank so every next call is made from the _user address (both msg.sender and
        // tx.origin will be set to _user)
        vm.startPrank(_user, _user);

        // create holding for user
        userHolding = holdingManager.createHolding();

        // make deposit to the holding
        collateralContract.approve(address(holdingManager), _collateralAmount);
        holdingManager.deposit(_collateral, _collateralAmount);

        vm.stopPrank();
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
}
