// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { MockPyth } from "@pyth/MockPyth.sol";
import { PythStructs } from "@pyth/PythStructs.sol";

import { PythOracle } from "src/oracles/pyth/PythOracle.sol";

import { PythOracleFactory } from "src/oracles/pyth/PythOracleFactory.sol";
import { IPythOracle } from "src/oracles/pyth/interfaces/IPythOracle.sol";

contract PythOracleUnitTest is Test {
    error OwnableUnauthorizedAccount(address account);

    MockPyth internal mockPyth;
    PythOracle internal pythOracle;
    PythOracleFactory internal pythOracleFactory;
    PythOracleFactory internal mockPythOracleFactory;
    address internal pythOracleImplementation;

    address internal constant OWNER = address(uint160(uint256(keccak256("owner"))));
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant PYTH = 0x4305FB66699C3B2702D4d05CF36551390A4c69C6;
    bytes32 internal constant PRICE_ID = 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6;
    uint256 internal constant AGE = type(uint256).max;

    modifier withRegularOracle() {
        pythOracle = PythOracle(
            pythOracleFactory.createPythOracle({ _initialOwner: OWNER, _underlying: WETH, _priceId: PRICE_ID, _age: AGE })
        );
        _;
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_722_108);

        mockPyth = new MockPyth({ _validTimePeriod: 1 seconds, _singleUpdateFeeInWei: 0 });

        pythOracleImplementation = address(new PythOracle());
        pythOracleFactory = new PythOracleFactory({
            _initialOwner: OWNER,
            _pyth: PYTH,
            _referenceImplementation: pythOracleImplementation
        });
        mockPythOracleFactory = new PythOracleFactory({
            _initialOwner: OWNER,
            _pyth: address(mockPyth),
            _referenceImplementation: pythOracleImplementation
        });
    }

    // Tests whether the initialization went right
    function test_pyth_initialization() public withRegularOracle {
        // Check pythOracleFactory initialization
        vm.assertEq(pythOracleFactory.referenceImplementation(), pythOracleImplementation, "Impl wrong");
        vm.assertEq(pythOracleFactory.owner(), OWNER, "Owner in factory set wrong");

        // Check pythOracle initialization
        vm.assertEq(pythOracle.owner(), OWNER, "Owner in oracle set wrong");
        vm.assertEq(pythOracle.underlying(), WETH, "underlying in oracle set wrong");
        vm.assertEq(pythOracle.pyth(), PYTH, "PYTH in oracle set wrong");
        vm.assertEq(pythOracle.priceId(), PRICE_ID, "PRICE_ID in oracle set wrong");
        vm.assertEq(pythOracle.age(), AGE, "AGE in oracle set wrong");
        vm.assertEq(pythOracle.name(), IERC20Metadata(WETH).name(), "Name in oracle set wrong");
        vm.assertEq(pythOracle.symbol(), IERC20Metadata(WETH).symbol(), "Symbol in oracle set wrong");
    }

    // Tests whether the oracle returns success false when price is too old
    function test_pyth_peek_when_fail() public {
        pythOracle = PythOracle(
            pythOracleFactory.createPythOracle({
                _initialOwner: OWNER,
                _underlying: WETH,
                _priceId: PRICE_ID,
                _age: 1 seconds
            })
        );

        (bool success, uint256 rate) = pythOracle.peek("");

        vm.assertEq(success, false, "Peek must have returned false");
        vm.assertEq(rate, 0, "Peek must have returned 0");
    }

    // Tests whether the oracle returns valid rate
    function test_pyth_peek_when_validResponse() public withRegularOracle {
        (bool success, uint256 rate) = pythOracle.peek("");

        vm.assertEq(success, true, "Peek failed");
        vm.assertEq(rate, 3_286_215_397_790_000_000_000, "Rate is wrong");
    }

    function test_pyth_peek_when_NegativeOraclePrice() public {
        pythOracle = PythOracle(
            mockPythOracleFactory.createPythOracle({
                _initialOwner: OWNER,
                _underlying: WETH,
                _priceId: PRICE_ID,
                _age: AGE
            })
        );

        // Set pyth price to a negative value
        _updateMockPythPrice(int64(-1), int32(-8));

        // Expect the next call to revert with the correct error
        vm.expectRevert(IPythOracle.InvalidOraclePrice.selector);
        pythOracle.peek("");
    }

    function test_pyth_peek_when_ExpoTooBig() public {
        pythOracle = PythOracle(
            mockPythOracleFactory.createPythOracle({
                _initialOwner: OWNER,
                _underlying: WETH,
                _priceId: PRICE_ID,
                _age: AGE
            })
        );

        // Set pyth price with a big expo
        _updateMockPythPrice(int64(10), int32(1));

        // Expect the next call to revert with the correct error
        vm.expectRevert(IPythOracle.ExpoTooBig.selector);
        pythOracle.peek("");
    }

    function test_pyth_peek_when_ExpoTooSmall() public {
        pythOracle = PythOracle(
            mockPythOracleFactory.createPythOracle({
                _initialOwner: OWNER,
                _underlying: WETH,
                _priceId: PRICE_ID,
                _age: AGE
            })
        );

        // Set pyth price with a small expo
        _updateMockPythPrice(int64(10), int32(-19));

        // Expect the next call to revert with the correct error
        vm.expectRevert(IPythOracle.ExpoTooSmall.selector);
        pythOracle.peek("");
    }

    function test_pyth_peek_when_notConfident() public {
        pythOracle = PythOracle(
            mockPythOracleFactory.createPythOracle({
                _initialOwner: OWNER,
                _underlying: WETH,
                _priceId: PRICE_ID,
                _age: AGE
            })
        );

        // Set pyth price with a small expo
        _updateMockPythPrice(int64(100_000_000), uint64(1_000_000), int32(-8));

        // Expect the next call to revert with the correct error
        (bool success, uint256 rate) = pythOracle.peek("");

        vm.assertEq(success, true, "Peek failed");
        vm.assertEq(rate, (100_000_000 - 1_000_000) * 10 ** (18 - 8), "Rate is wrong");
    }

    function test_pyth_peek_when_confidenceTooHigh() public {
        pythOracle = PythOracle(
            mockPythOracleFactory.createPythOracle({
                _initialOwner: OWNER,
                _underlying: WETH,
                _priceId: PRICE_ID,
                _age: AGE
            })
        );

        // Set pyth price with a small expo
        _updateMockPythPrice(int64(100_000_000), uint64(1_000_000_000_000_000_000), int32(-8));

        // Expect the next call to revert with the correct error
        vm.expectRevert(IPythOracle.InvaidConfidence.selector);
        pythOracle.peek("");
    }

    function test_pyth_updateAge(
        uint256 _newAge
    ) public withRegularOracle {
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        pythOracle.updateAge(0);

        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(IPythOracle.InvalidAge.selector);
        pythOracle.updateAge(0);

        uint256 oldAge = pythOracle.age();
        vm.expectRevert(IPythOracle.InvalidAge.selector);
        pythOracle.updateAge(oldAge);

        vm.assume(_newAge != oldAge && _newAge != 0);

        vm.expectEmit();
        emit IPythOracle.AgeUpdated({ oldValue: oldAge, newValue: _newAge });
        pythOracle.updateAge(_newAge);

        vm.assertEq(pythOracle.age(), _newAge, "Age wrong after update");
        vm.stopPrank();
    }

    function test_pyth_updateConfidencePercentage(
        uint256 _newConfidence
    ) public withRegularOracle {
        _newConfidence = bound(_newConfidence, 1, pythOracle.CONFIDENCE_PRECISION());

        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, address(this)));
        pythOracle.updateConfidencePercentage(0);

        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(IPythOracle.InvalidConfidencePercentage.selector);
        pythOracle.updateConfidencePercentage(0);

        uint256 oldConfidence = pythOracle.minConfidencePercentage();
        vm.expectRevert(IPythOracle.InvalidConfidencePercentage.selector);
        pythOracle.updateConfidencePercentage(oldConfidence);

        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(IPythOracle.InvalidConfidencePercentage.selector);
        pythOracle.updateConfidencePercentage(1e4 + 1);

        vm.assume(_newConfidence != oldConfidence);

        vm.expectEmit();
        emit IPythOracle.ConfidencePercentageUpdated({ oldValue: oldConfidence, newValue: _newConfidence });
        pythOracle.updateConfidencePercentage(_newConfidence);

        vm.assertEq(pythOracle.minConfidencePercentage(), _newConfidence, "Confidence percentage wrong after update");
        vm.stopPrank();
    }

    function test_pyth_renounceOwnership() public withRegularOracle {
        vm.expectRevert(bytes("1000"));
        pythOracle.renounceOwnership();
    }

    function _updateMockPythPrice(int64 _price, int32 _expo) private {
        bytes[] memory priceUpdateData = new bytes[](1);
        priceUpdateData[0] = abi.encode(
            PythStructs.PriceFeed(
                PRICE_ID,
                PythStructs.Price(_price, uint64(1), _expo, vm.getBlockTimestamp()),
                PythStructs.Price(_price, uint64(1), _expo, vm.getBlockTimestamp())
            ),
            0
        );

        mockPyth.updatePriceFeeds(priceUpdateData);
    }

    function _updateMockPythPrice(int64 _price, uint64 _confidence, int32 _expo) private {
        bytes[] memory priceUpdateData = new bytes[](1);
        priceUpdateData[0] = abi.encode(
            PythStructs.PriceFeed(
                PRICE_ID,
                PythStructs.Price(_price, _confidence, _expo, vm.getBlockTimestamp()),
                PythStructs.Price(_price, _confidence, _expo, vm.getBlockTimestamp())
            ),
            0
        );

        mockPyth.updatePriceFeeds(priceUpdateData);
    }
}
