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

import { EverRevertingOracle } from "../../src/oracles/genesis/EverRevertingOracle.sol";

contract DeploySwellTest is Test {
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

    function setUp() public {
        vm.createSelectFork(vm.envString("SWELL_RPC_URL"));
        vm.startPrank(OWNER);

        weth = wETHMock(payable(0x4200000000000000000000000000000000000006));

        jUsdOracle = new SampleOracle();

        manager = new Manager(OWNER, address(weth), address(jUsdOracle), bytes(""));

        jUsd = new JigsawUSD(OWNER, address(manager));
        jUsd.updateMintLimit(type(uint256).max);

        holdingManager = new HoldingManager(OWNER, address(manager));
        liquidationManager = new LiquidationManager(OWNER, address(manager));
        stablesManager = new StablesManager(OWNER, address(manager), address(jUsd));
        strategyManager = new StrategyManager(OWNER, address(manager));

        receiptTokenReference = IReceiptToken(new ReceiptToken());
        receiptTokenFactory = new ReceiptTokenFactory(OWNER, address(receiptTokenReference));

        manager.setReceiptTokenFactory(address(receiptTokenFactory));

        manager.setFeeAddress(address(uint160(uint256(keccak256(bytes("Fee address"))))));

        manager.whitelistToken(address(weth));

        manager.setStablecoinManager(address(stablesManager));
        manager.setHoldingManager(address(holdingManager));
        manager.setLiquidationManager(address(liquidationManager));
        manager.setStrategyManager(address(strategyManager));

        wethSharesRegistry = new SharesRegistry(
            OWNER,
            address(manager),
            address(weth),
            address(new EverRevertingOracle()),
            bytes(""),
            ISharesRegistry.RegistryConfig({
                collateralizationRate: 20_000,
                liquidationBuffer: 5e3,
                liquidatorBonus: 8e3
            })
        );

        stablesManager.registerOrUpdateShareRegistry(address(wethSharesRegistry), address(weth), true);
        registries[address(weth)] = address(wethSharesRegistry);

        vm.stopPrank();
    }

    function test_depositWithoutRegistry_Swell() public {
        address user = makeAddr("user");
        address collateral = address(weth);
        uint256 depositAmount = 1000e18;

        //get tokens for user
        deal(collateral, user, depositAmount);

        //startPrank so every next call is made from the _user address (both msg.sender and
        // tx.origin will be set to _user)
        vm.startPrank(user, user);

        // create holding for user
        address userHolding = holdingManager.createHolding();

        // make deposit to the holding
        IERC20(collateral).approve(address(holdingManager), depositAmount);
        holdingManager.deposit(collateral, depositAmount);

        vm.expectRevert();
        holdingManager.borrow(collateral, depositAmount, 0, true);
    }
}
