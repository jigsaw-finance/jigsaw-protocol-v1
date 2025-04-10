// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { ChronicleOracle } from "src/oracles/chronicle/ChronicleOracle.sol";
import { ChronicleOracleFactory } from "src/oracles/chronicle/ChronicleOracleFactory.sol";
import { IChronicleMinimal } from "src/oracles/chronicle/interfaces/IChronicleMinimal.sol";
import { IChronicleOracle } from "src/oracles/chronicle/interfaces/IChronicleOracle.sol";

contract ChronicleOracleUnitTest is Test {
    error OwnableUnauthorizedAccount(address account);

    ChronicleOracle internal chronicleOracle;
    ChronicleOracleFactory internal chronicleOracleFactory;
    address internal chronicleOracleImplementation;

    address internal constant OWNER = address(uint160(uint256(keccak256("owner"))));
    address internal constant UNDERLYING = 0xdC035D45d973E3EC169d2276DDab16f1e407384F; //USDS
    address internal constant CHRONICLE = 0x74661a9ea74fD04975c6eBc6B155Abf8f885636c; // USDS/USD
    uint256 internal constant AGE_VALIDITY_PERIOD = 1 hours;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 22_128_701);

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

    // Tests whether the initialization went right
    function test_chronicle_initialization() public {
        // Check chronicleOracleFactory initialization
        vm.assertEq(chronicleOracleFactory.referenceImplementation(), chronicleOracleImplementation, "Impl wrong");
        vm.assertEq(chronicleOracleFactory.owner(), OWNER, "Owner in factory set wrong");

        // Check chronicleOracle initialization
        vm.assertEq(chronicleOracle.underlying(), UNDERLYING, "underlying in oracle set wrong");
        vm.assertEq(chronicleOracle.chronicle(), CHRONICLE, "chronicle in oracle set wrong");
        vm.assertEq(chronicleOracle.ageValidityPeriod(), AGE_VALIDITY_PERIOD, "AGE_VALIDITY_PERIOD in oracle set wrong");
        vm.assertEq(chronicleOracle.owner(), OWNER, "Owner in oracle set wrong");
        vm.assertEq(chronicleOracle.name(), IERC20Metadata(UNDERLYING).name(), "Name in oracle set wrong");
        vm.assertEq(chronicleOracle.symbol(), IERC20Metadata(UNDERLYING).symbol(), "Symbol in oracle set wrong");
        vm.assertEq(chronicleOracle.ageValidityBuffer(), 15 minutes, "Age validity buffer in oracle set wrong");
    }

    // Tests whether the oracle returns valid rate
    function test_chronicle_peek_when_validResponse() public {
        (bool success, uint256 rate) = chronicleOracle.peek("");

        vm.assertEq(success, true, "Peek failed");
        vm.assertEq(rate, 999_840_517_033_636_936, "Rate is wrong");
    }

    // Tests whether the oracle reverts correctly when the price is too old
    function test_chronicle_peek_when_outdatedPrice() public {
        uint256 ageOutsideBuffer = chronicleOracle.ageValidityBuffer() + 1;

        vm.prank(address(chronicleOracle), address(chronicleOracle));

        (, uint256 actualAge) = IChronicleMinimal(CHRONICLE).readWithAge();
        vm.warp(actualAge + chronicleOracle.ageValidityPeriod() + ageOutsideBuffer);

        uint256 minAllowedAge =
            block.timestamp - (chronicleOracle.ageValidityPeriod() + chronicleOracle.ageValidityBuffer());
        vm.expectRevert(abi.encodeWithSelector(IChronicleOracle.OutdatedPrice.selector, minAllowedAge, actualAge));
        chronicleOracle.peek("");
    }

    // Tests whether the oracle works correctly when the price is older than ageValidityPeriod, but within the buffer
    function test_chronicle_peek_when_within_buffer() public {
        uint256 ageWithinBuffer = chronicleOracle.ageValidityBuffer() - 1;

        vm.prank(address(chronicleOracle), address(chronicleOracle));
        (, uint256 actualAge) = IChronicleMinimal(CHRONICLE).readWithAge();

        vm.warp(actualAge + chronicleOracle.ageValidityPeriod() + ageWithinBuffer);
        (bool success, uint256 rate) = chronicleOracle.peek("");

        vm.assertEq(success, true, "Peek failed");
        vm.assertEq(rate, 999_840_517_033_636_936, "Rate is wrong");
    }

    // Tests whether the oracle returns success false when chronicle reverts
    function test_chronicle_peek_when_chronicleReverts() public {
        address authedDisser = 0x40C33e796be78148CeC983C2202335A0962d172A;
        vm.prank(authedDisser, authedDisser);
        IToll(CHRONICLE).diss({ who: address(chronicleOracle) });

        (bool success, uint256 rate) = chronicleOracle.peek("");

        assertEq(success, false, "Success returned wrong");
        assertEq(rate, 0, "Rate returned wrong");
    }

    function test_chronicle_updateAgeValidityPeriod(
        uint256 _newAge
    ) public {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        chronicleOracle.updateAgeValidityPeriod(0);

        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(IChronicleOracle.InvalidAgeValidityPeriod.selector);
        chronicleOracle.updateAgeValidityPeriod(0);

        uint256 oldAge = chronicleOracle.ageValidityPeriod();
        vm.expectRevert(IChronicleOracle.InvalidAgeValidityPeriod.selector);
        chronicleOracle.updateAgeValidityPeriod(oldAge);

        vm.assume(_newAge != oldAge && _newAge != 0);

        vm.expectEmit();
        emit IChronicleOracle.AgeValidityPeriodUpdated({ oldValue: oldAge, newValue: _newAge });
        chronicleOracle.updateAgeValidityPeriod(_newAge);

        vm.assertEq(chronicleOracle.ageValidityPeriod(), _newAge, "Age wrong after update");
        vm.stopPrank();
    }

    function test_chronicle_renounceOwnership() public {
        vm.expectRevert(bytes("1000"));
        chronicleOracle.renounceOwnership();
    }

    function _updateChroniclePrice(int64 _price, int32 _expo) private { }

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
