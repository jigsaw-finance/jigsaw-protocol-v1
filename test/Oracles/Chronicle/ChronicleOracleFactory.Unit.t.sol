// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ChronicleOracle} from "src/oracles/chronicle/ChronicleOracle.sol";
import {ChronicleOracleFactory} from "src/oracles/chronicle/ChronicleOracleFactory.sol";

contract ChronicleOracleFactoryUnitTest is Test {
    error OwnableUnauthorizedAccount(address account);

    ChronicleOracle internal chronicleOracle;
    ChronicleOracleFactory internal chronicleOracleFactory;
    address internal chronicleOracleImplementation;

    address internal constant OWNER = address(uint160(uint256(keccak256("owner"))));
    address internal constant UNDERLYING = 0xdC035D45d973E3EC169d2276DDab16f1e407384F; //USDS
    address internal constant CHRONICLE = 0x74661a9ea74fD04975c6eBc6B155Abf8f885636c; // USDS/USD

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 22_128_701);

        chronicleOracleImplementation = address(new ChronicleOracle());
        chronicleOracleFactory = new ChronicleOracleFactory({
            _initialOwner: OWNER,
            _referenceImplementation: chronicleOracleImplementation
        });
    }

    // Tests whether the constructor reverts when code length is zero
    function test_chronicle_factory_constructor_when_code_length_zero() public {
        vm.startPrank(OWNER, OWNER);

        chronicleOracleImplementation = address(0);
        vm.expectRevert(bytes("3096"));
        chronicleOracleFactory = new ChronicleOracleFactory({
            _initialOwner: OWNER,
            _referenceImplementation: chronicleOracleImplementation
        });
    }

    // Tests whether the setReferenceImplementation went right
    function test_chronicle_factory_setReferenceImplementation_when_auth() public {
        address newChronicleOracleImplementation = address(new ChronicleOracle());
        vm.startPrank(OWNER, OWNER);
        chronicleOracleFactory.setReferenceImplementation(newChronicleOracleImplementation);
    }

    // Tests whether the setReferenceImplementation reverts when called by an unauthorized address
    function test_chronicle_factory_setReferenceImplementation_when_unauthorized() public {
        address caller = address(uint160(uint256(keccak256("caller"))));
        vm.startPrank(caller, caller);
        address newChronicleOracleImplementation = address(new ChronicleOracle());
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        chronicleOracleFactory.setReferenceImplementation(newChronicleOracleImplementation);
    }

    // Tests whether the setReferenceImplementation reverts when same implementation address is passed
    function test_chronicle_factory_setReferenceImplementation_when_same_address() public {
        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(bytes("3062"));
        chronicleOracleFactory.setReferenceImplementation(chronicleOracleImplementation);
    }

    // Tests whether the setReferenceImplementation reverts when code length is zero
    function test_chronicle_factory_setReferenceImplementation_when_code_length_zero() public {
        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(bytes("3096"));
        chronicleOracleFactory.setReferenceImplementation(address(0));
    }

    // Tests whether the setReferenceImplementation reverts when age validity is zero
    function test_chronicle_factory_createChronicleOracle_when_age_validity_zero() public {
        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(bytes("Zero age"));

        chronicleOracleFactory.createChronicleOracle({
            _initialOwner: OWNER,
            _underlying: UNDERLYING,
            _chronicle: CHRONICLE,
            _ageValidityPeriod: 0
        });
    }

    function test_chronicle_renounceOwnership() public {
        vm.expectRevert(bytes("1000"));
        chronicleOracleFactory.renounceOwnership();
    }
}