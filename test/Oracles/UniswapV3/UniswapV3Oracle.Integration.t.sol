// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { UniswapV3Oracle } from "src/oracles/uniswap/UniswapV3Oracle.sol";
import { IUniswapV3Oracle } from "src/oracles/uniswap/interfaces/IUniswapV3Oracle.sol";

import { BasicContractsFixture } from "../..//fixtures/BasicContractsFixture.t.sol";

contract UniswapV3OracleIntegrationTest is Test, BasicContractsFixture {
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDC_POOL = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6; // USDT/USDC pool

    UniswapV3Oracle internal uniswapJUsdOracle;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_722_108);

        address[] memory initialPools = new address[](1);
        initialPools[0] = USDC_POOL;

        init();

        uniswapJUsdOracle = new UniswapV3Oracle({
            _initialOwner: OWNER,
            _jUSD: USDT,
            _quoteToken: USDC,
            _quoteTokenOracle: address(usdcOracle),
            _uniswapV3Pools: initialPools
        });
    }

    function test_borrow_when_uniswapOracle(address _user, uint256 _mintAmount) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 500e18, 100_000e18);
        address collateral = address(usdc);

        vm.startPrank(OWNER, OWNER);
        manager.requestNewJUsdOracle(address(uniswapJUsdOracle));
        skip(manager.timelockAmount() + 1);
        manager.acceptNewJUsdOracle();
        vm.stopPrank();

        address holding = initiateUser(_user, collateral, _mintAmount);
        vm.prank(address(holdingManager), address(holdingManager));
        stablesManager.borrow(holding, collateral, _mintAmount, 0, true);

        vm.assertEq(jUsd.balanceOf(_user), _mintAmount, "Borrow failed when authorized");
        vm.assertEq(stablesManager.totalBorrowed(collateral), _mintAmount, "Total borrowed wasn't updated after borrow");
    }
}
