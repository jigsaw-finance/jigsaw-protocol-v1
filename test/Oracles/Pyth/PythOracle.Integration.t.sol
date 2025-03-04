// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IPyth } from "@pyth/IPyth.sol";
import { MockPyth } from "@pyth/MockPyth.sol";
import { PythStructs } from "@pyth/PythStructs.sol";

import { BasicContractsFixture } from "../..//fixtures/BasicContractsFixture.t.sol";

import { PythOracle } from "src/oracles/pyth/PythOracle.sol";
import { PythOracleFactory } from "src/oracles/pyth/PythOracleFactory.sol";
import { IPythOracle } from "src/oracles/pyth/interfaces/IPythOracle.sol";

contract PythOracleIntegrationTest is BasicContractsFixture {
    PythOracle internal pythOracle;
    PythOracleFactory internal pythOracleFactory;
    address internal pythOracleImplementation;

    address internal constant PYTH = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;
    bytes32 internal constant PRICE_ID = 0x0;
    uint256 internal constant AGE = type(uint256).max;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_722_108);

        init();

        pythOracleImplementation = address(new PythOracle());
        pythOracleFactory = new PythOracleFactory({
            _initialOwner: OWNER,
            _pyth: PYTH,
            _referenceImplementation: pythOracleImplementation
        });
    }

    function test_borrow_when_pythOracle(address _user, uint256 _mintAmount) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 1e18, 100_000e18);
        address collateral = address(usdc);

        // update usdc oracle
        vm.startPrank(OWNER, OWNER);
        sharesRegistry.requestNewOracle(
            address(
                PythOracle(
                    pythOracleFactory.createPythOracle({
                        _initialOwner: OWNER,
                        _underlying: address(usdc),
                        _priceId: 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a,
                        _age: AGE
                    })
                )
            )
        );
        skip(sharesRegistry.timelockAmount() + 1);
        sharesRegistry.setOracle();
        vm.stopPrank();

        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(address(holdingManager), address(holdingManager));
        stablesManager.borrow(holding, collateral, _mintAmount, true);

        // allow 1% approximation
        vm.assertApproxEqRel(jUsd.balanceOf(_user), _mintAmount, 0.01e18, "Borrow failed when authorized");
        vm.assertApproxEqRel(
            stablesManager.totalBorrowed(collateral), _mintAmount, 0.01e18, "Total borrowed wasn't updated after borrow"
        );
    }
}
