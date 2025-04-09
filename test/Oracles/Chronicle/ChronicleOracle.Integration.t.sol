// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { BasicContractsFixture } from "../../fixtures/BasicContractsFixture.t.sol";

import { ChronicleOracle } from "src/oracles/chronicle/ChronicleOracle.sol";
import { ChronicleOracleFactory } from "src/oracles/chronicle/ChronicleOracleFactory.sol";

import { IChronicleMinimal } from "src/oracles/chronicle/interfaces/IChronicleMinimal.sol";
import { IChronicleOracle } from "src/oracles/chronicle/interfaces/IChronicleOracle.sol";

contract ChronicleOracleUnitTest is BasicContractsFixture {
    error OwnableUnauthorizedAccount(address account);

    ChronicleOracle internal chronicleOracle;
    ChronicleOracleFactory internal chronicleOracleFactory;
    address internal chronicleOracleImplementation;

    address internal constant UNDERLYING = 0xdC035D45d973E3EC169d2276DDab16f1e407384F; //USDS
    address internal constant CHRONICLE = 0x74661a9ea74fD04975c6eBc6B155Abf8f885636c; // USDS/USD
    uint256 internal constant AGE_VALIDITY_PERIOD = 1 hours;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 22_128_701);

        init();

        chronicleOracleImplementation = address(new ChronicleOracle());
        chronicleOracleFactory = new ChronicleOracleFactory({
            _initialOwner: OWNER,
            _referenceImplementation: chronicleOracleImplementation
        });

        chronicleOracle = ChronicleOracle(
            chronicleOracleFactory.createChronicleOracle({
                _initialOwner: OWNER,
                _underlying: UNDERLYING,
                _chronicle: CHRONICLE,
                _ageValidityPeriod: AGE_VALIDITY_PERIOD
            })
        );

        _whitelist(address(chronicleOracle));
    }

    function test_borrow_when_chronicleOracle(address _user, uint256 _mintAmount) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 500e18, 100_000e18);
        address collateral = address(usdc); // pretend USDS is USDC

        // update usdc oracle
        vm.startPrank(OWNER, OWNER);
        sharesRegistry.requestNewOracle(address(chronicleOracle));

        skip(sharesRegistry.timelockAmount() + 1);
        sharesRegistry.setOracle();
        vm.stopPrank();

        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(address(holdingManager), address(holdingManager));
        stablesManager.borrow(holding, collateral, _mintAmount, 0, true);

        // allow 1% approximation
        vm.assertApproxEqRel(jUsd.balanceOf(_user), _mintAmount, 0.01e18, "Borrow failed when authorized");
        vm.assertApproxEqRel(
            stablesManager.totalBorrowed(collateral), _mintAmount, 0.01e18, "Total borrowed wasn't updated after borrow"
        );
    }

    function _whitelist(
        address _who
    ) private {
        address authedKisser = 0x40C33e796be78148CeC983C2202335A0962d172A;
        vm.prank(authedKisser, authedKisser);
        IToll(CHRONICLE).kiss({ who: _who });
    }
}

interface IToll {
    /// @notice Grants address `who` toll.
    /// @dev Only callable by auth'ed address.
    /// @param who The address to grant toll.
    function kiss(
        address who
    ) external;

    /// @notice Renounces address `who`'s toll.
    /// @dev Only callable by auth'ed address.
    /// @param who The address to renounce toll.
    function diss(
        address who
    ) external;
}
