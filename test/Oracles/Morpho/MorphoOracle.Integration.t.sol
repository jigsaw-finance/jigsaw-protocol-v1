// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { MorphoOracle } from "src/oracles/morpho/MorphoOracle.sol";

import { IMorphoBase, MarketParams } from "./IMorpho.sol";

import { DeployMorphoOracle } from "script/deployment/09_DeployMorphoOracle.s.sol";

contract MorphoOracleTest is Test {
    address internal jUSD = 0x000000096CB3D4007fC2b79b935C4540C5c2d745;

    address internal cUSDO = 0xaD55aebc9b8c03FC43cd9f62260391c13c23e7c0;
    address internal lvlUSD = 0x7C1156E515aA1A2E851674120074968C905aAF37;
    address internal rUSD = 0x09D4214C03D01F49544C0448DBE3A27f768F2b34;

    address internal morphoAdaptiveCurveIRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    uint256 internal lltv = 945_000_000_000_000_000;
    address internal collateralToken = jUSD;

    address[] internal morphoOracles;
    IMorphoBase internal morpho;

    DeployMorphoOracle internal morphoOraclesDeployer;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        morpho = IMorphoBase(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

        morphoOraclesDeployer = new DeployMorphoOracle();
        morphoOracles = morphoOraclesDeployer.run();
    }

    function test_morphoIntegration() public {
        uint256 supplyAmt = 100_000e18;
        address loanToken = cUSDO;
        address receiver = vm.randomAddress();

        MarketParams memory marketParams = MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: address(morphoOracles[0]),
            irm: morphoAdaptiveCurveIRM,
            lltv: lltv
        });

        // CREATE MORPHO MARKET
        morpho.createMarket(marketParams);

        IERC20Metadata(collateralToken).approve(address(morpho), type(uint256).max);
        IERC20Metadata(loanToken).approve(address(morpho), type(uint256).max);

        // SUPPLY COLLATERAL TOKENS
        deal(collateralToken, address(this), supplyAmt);
        morpho.supplyCollateral({ marketParams: marketParams, assets: supplyAmt, onBehalf: address(this), data: "" });

        // SUPPLY LOAN TOKENS
        deal(loanToken, address(this), supplyAmt);
        morpho.supply({ marketParams: marketParams, assets: supplyAmt, shares: 0, onBehalf: address(this), data: "" });

        // BORROW
        uint256 borrowAmt = bound(supplyAmt, 200e18, 300e18);
        morpho.borrow({
            marketParams: marketParams,
            assets: borrowAmt,
            shares: 0,
            onBehalf: address(this),
            receiver: receiver
        });

        vm.assertEq(IERC20Metadata(loanToken).balanceOf(address(receiver)), borrowAmt, "Borrow failed");
    }
}
