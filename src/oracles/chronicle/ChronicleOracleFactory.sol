// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { IChronicleOracle } from "./interfaces/IChronicleOracle.sol";
import { IChronicleOracleFactory } from "./interfaces/IChronicleOracleFactory.sol";
/**
 * @title ChronicleOracleFactory
 * @dev This contract creates new instances of Chronicle oracles for Jigsaw Protocol using the clone factory pattern.
 */

contract ChronicleOracleFactory is IChronicleOracleFactory, Ownable2Step {
    /**
     * @notice Address of the reference implementation.
     */
    address public override referenceImplementation;

    /**
     * @notice Creates a new ChronicleOracleFactory contract.
     * @param _initialOwner The initial owner of the contract.
     * @param _referenceImplementation The reference implementation address.
     */
    constructor(address _initialOwner, address _referenceImplementation) Ownable(_initialOwner) {
        // Assert that `referenceImplementation` have code to protect the system.
        require(_referenceImplementation.code.length > 0, "3096");

        // Save the referenceImplementation for cloning.
        emit ChronicleOracleImplementationUpdated(_referenceImplementation);
        referenceImplementation = _referenceImplementation;
    }

    // -- Administration --

    /**
     * @notice Sets the reference implementation address.
     * @param _referenceImplementation Address of the new reference implementation contract.
     */
    function setReferenceImplementation(
        address _referenceImplementation
    ) external override onlyOwner {
        // Assert that referenceImplementation has code in it to protect the system from cloning invalid implementation.
        require(_referenceImplementation.code.length > 0, "3096");
        require(_referenceImplementation != referenceImplementation, "3062");

        emit ChronicleOracleImplementationUpdated(_referenceImplementation);
        referenceImplementation = _referenceImplementation;
    }

    // -- Chronicle oracle creation --

    /**
     * @notice Creates a new Chronicle oracle by cloning the reference implementation.
     *
     * @param _initialOwner The address of the initial owner of the contract.
     * @param _underlying The address of the token the oracle is for.
     * @param _chronicle The Address of the Chronicle Oracle.
     * @param _ageValidityPeriod The Age in seconds after which the price is considered invalid.
     *
     * @return newChronicleOracleAddress Address of the newly created Chronicle oracle.
     */
    function createChronicleOracle(
        address _initialOwner,
        address _underlying,
        address _chronicle,
        uint256 _ageValidityPeriod
    ) external override returns (address newChronicleOracleAddress) {
        require(_ageValidityPeriod > 0, "Zero age");

        // Clone the Chronicle oracle implementation.
        newChronicleOracleAddress = Clones.cloneDeterministic({
            implementation: referenceImplementation,
            salt: keccak256(abi.encodePacked(_initialOwner, _underlying, _chronicle))
        });

        // Initialize the new Chronicle oracle's contract.
        IChronicleOracle(newChronicleOracleAddress).initialize({
            _initialOwner: _initialOwner,
            _underlying: _underlying,
            _chronicle: _chronicle,
            _ageValidityPeriod: _ageValidityPeriod
        });
    }

    /**
     * @dev Renounce ownership override to avoid losing contract's ownership.
     */
    function renounceOwnership() public pure virtual override {
        revert("1000");
    }
}
