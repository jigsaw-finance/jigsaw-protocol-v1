// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { ChainlinkOracle } from "src/oracles/chainlink/ChainlinkOracle.sol";
import { ChainlinkOracleFactory } from "src/oracles/chainlink/ChainlinkOracleFactory.sol";

import { AggregatorV3Interface } from "src/oracles/chainlink/interfaces/AggregatorV3Interface.sol";
import { IChainlinkOracle } from "src/oracles/chainlink/interfaces/IChainlinkOracle.sol";

contract ChainlinkOracleUnitTest is Test {
    error OwnableUnauthorizedAccount(address account);

    ChainlinkOracle internal chainlinkOracle;
    ChainlinkOracleFactory internal chainlinkOracleFactory;
    address internal chainlinkOracleImplementation;

    address internal constant OWNER = address(uint160(uint256(keccak256("owner"))));
    address internal constant UNDERLYING = 0xdAC17F958D2ee523a2206206994597C13D831ec7; //USDT
    address internal constant CHAINLINK = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D; // USDT/USD
    uint256 internal constant AGE_VALIDITY_PERIOD = 3 hours;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 22_573_623);

        chainlinkOracleImplementation = address(new ChainlinkOracle());
        chainlinkOracleFactory = new ChainlinkOracleFactory({
            _initialOwner: OWNER,
            _referenceImplementation: chainlinkOracleImplementation
        });

        chainlinkOracle = ChainlinkOracle(
            chainlinkOracleFactory.createChainlinkOracle({
                _initialOwner: OWNER,
                _underlying: UNDERLYING,
                _chainlinkOracle: CHAINLINK,
                _ageValidityPeriod: AGE_VALIDITY_PERIOD
            })
        );
    }

    // Tests whether the initialization went right
    function test_chainlink_initialization() public {
        // Check chainlinkOracleFactory initialization
        vm.assertEq(chainlinkOracleFactory.referenceImplementation(), chainlinkOracleImplementation, "Impl wrong");
        vm.assertEq(chainlinkOracleFactory.owner(), OWNER, "Owner in factory set wrong");

        // Check chainlinkOracle initialization
        vm.assertEq(chainlinkOracle.underlying(), UNDERLYING, "underlying in oracle set wrong");
        vm.assertEq(chainlinkOracle.chainlinkOracle(), CHAINLINK, "chainlink in oracle set wrong");
        vm.assertEq(chainlinkOracle.ageValidityPeriod(), AGE_VALIDITY_PERIOD, "AGE_VALIDITY_PERIOD in oracle set wrong");
        vm.assertEq(chainlinkOracle.owner(), OWNER, "Owner in oracle set wrong");
        vm.assertEq(chainlinkOracle.name(), IERC20Metadata(UNDERLYING).name(), "Name in oracle set wrong");
        vm.assertEq(chainlinkOracle.symbol(), IERC20Metadata(UNDERLYING).symbol(), "Symbol in oracle set wrong");
        vm.assertEq(chainlinkOracle.ageValidityBuffer(), 15 minutes, "Age validity buffer in oracle set wrong");
    }

    // Tests whether the oracle returns valid rate
    function test_chainlink_peek_when_validResponse() public {
        (bool success, uint256 rate) = chainlinkOracle.peek("");

        vm.assertEq(success, true, "Peek failed");
        vm.assertEq(rate, 1_000_125_420_000_000_000, "Rate is wrong");
    }

    // Tests whether the oracle works correctly when the price is older than ageValidityPeriod, but within the buffer
    function test_chainlink_peek_when_within_buffer() public {
        uint256 ageWithinBuffer = chainlinkOracle.ageValidityBuffer() - 1;
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(CHAINLINK).latestRoundData();
        uint256 actualAge = block.timestamp - updatedAt;

        vm.warp(actualAge + chainlinkOracle.ageValidityPeriod() + ageWithinBuffer);
        (bool success, uint256 rate) = chainlinkOracle.peek("");

        vm.assertEq(success, true, "Peek failed");
        vm.assertEq(rate, 1_000_125_420_000_000_000, "Rate is wrong");
    }

    // Tests whether the oracle returns success false when CHAINLINK reverts
    function test_chainlink_peek_when_chainlinkReverts() public {
        vm.store(
            address(chainlinkOracle),
            bytes32(uint256(1)),
            bytes32(uint256(uint160(address(new ChainlinkRevertOracle()))))
        );
        (bool success, uint256 rate) = chainlinkOracle.peek("");

        assertEq(success, false, "Success returned wrong");
        assertEq(rate, 0, "Rate returned wrong");
    }

    function test_chainlink_updateAgeValidityPeriod(
        uint256 _newAge
    ) public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        chainlinkOracle.updateAgeValidityPeriod(0);

        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(IChainlinkOracle.InvalidAgeValidityPeriod.selector);
        chainlinkOracle.updateAgeValidityPeriod(0);

        uint256 oldAge = chainlinkOracle.ageValidityPeriod();
        vm.expectRevert(IChainlinkOracle.InvalidAgeValidityPeriod.selector);
        chainlinkOracle.updateAgeValidityPeriod(oldAge);

        vm.assume(_newAge != oldAge && _newAge != 0);

        vm.expectEmit();
        emit IChainlinkOracle.AgeValidityPeriodUpdated({ oldValue: oldAge, newValue: _newAge });
        chainlinkOracle.updateAgeValidityPeriod(_newAge);

        vm.assertEq(chainlinkOracle.ageValidityPeriod(), _newAge, "Age wrong after update");
        vm.stopPrank();
    }

    function test_chainlink_updateAgeValidityBuffer(
        uint256 _newAge
    ) public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        chainlinkOracle.updateAgeValidityBuffer(0);

        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(IChainlinkOracle.InvalidAgeValidityBuffer.selector);
        chainlinkOracle.updateAgeValidityBuffer(0);

        uint256 oldAge = chainlinkOracle.ageValidityBuffer();
        vm.expectRevert(IChainlinkOracle.InvalidAgeValidityBuffer.selector);
        chainlinkOracle.updateAgeValidityBuffer(oldAge);

        vm.assume(_newAge != oldAge && _newAge != 0);

        vm.expectEmit();
        emit IChainlinkOracle.AgeValidityBufferUpdated({ oldValue: oldAge, newValue: _newAge });
        chainlinkOracle.updateAgeValidityBuffer(_newAge);

        vm.assertEq(chainlinkOracle.ageValidityBuffer(), _newAge, "Age wrong after update");
        vm.stopPrank();
    }

    function test_chainlink_renounceOwnership() public {
        vm.expectRevert(bytes("1000"));
        chainlinkOracle.renounceOwnership();
    }

    function _updateChainlinkPrice(int64 _price, int32 _expo) private { }
}

contract ChainlinkRevertOracle {
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        revert();
    }
}
