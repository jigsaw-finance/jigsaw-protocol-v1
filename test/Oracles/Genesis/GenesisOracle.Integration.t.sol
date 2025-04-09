// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { GenesisOracle } from "src/oracles/genesis/GenesisOracle.sol";

import { BasicContractsFixture } from "../..//fixtures/BasicContractsFixture.t.sol";

contract GenesisOracleIntegrationTest is Test, BasicContractsFixture {
    GenesisOracle internal genesisJUsdOracle;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_722_108);
        init();
        genesisJUsdOracle = new GenesisOracle();
    }

    function test_genesisOracle_initialization() public view {
        vm.assertEq(genesisJUsdOracle.name(), "Jigsaw USD", "name set wrong");
        vm.assertEq(genesisJUsdOracle.symbol(), "jUSD", "name set wrong");
    }

    function test_borrow_when_genesisOracle(address _user, uint256 _mintAmount) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 500e18, 100_000e18);
        address collateral = address(usdc);

        vm.startPrank(OWNER, OWNER);
        manager.requestNewJUsdOracle(address(genesisJUsdOracle));
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
