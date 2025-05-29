// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { IChainlinkOracle } from "./interfaces/IChainlinkOracle.sol";
import { IChainlinkOracleFactory } from "./interfaces/IChainlinkOracleFactory.sol";

/**
 * @title ChainlinkOracleFactory
 * @dev This contract creates new instances of Chainlink oracles for Jigsaw Protocol using the clone factory pattern.
 */
contract ChainlinkOracleFactory is IChainlinkOracleFactory, Ownable2Step {
    /**
     * @notice Address of the reference implementation.
     */
    address public override referenceImplementation;

    /**
     * @notice Creates a new ChainlinkOracleFactory contract.
     * @param _initialOwner The initial owner of the contract.
     * @param _referenceImplementation The reference implementation address.
     */
    constructor(address _initialOwner, address _referenceImplementation) Ownable(_initialOwner) {
        // Assert that `referenceImplementation` have code to protect the system.
        require(_referenceImplementation.code.length > 0, "3096");

        // Save the referenceImplementation for cloning.
        emit ChainlinkOracleImplementationUpdated(_referenceImplementation);
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

        emit ChainlinkOracleImplementationUpdated(_referenceImplementation);
        referenceImplementation = _referenceImplementation;
    }

    // -- Chainlink oracle creation --

    /**
     * @notice Creates a new Chainlink oracle by cloning the reference implementation.
     *
     * @param _initialOwner The address of the initial owner of the contract.
     * @param _underlying The address of the token the oracle is for.
     * @param _chainlinkOracle The Address of the Chainlink Oracle.
     * @param _ageValidityPeriod The Age in seconds after which the price is considered invalid.
     *
     * @return newChainlinkOracleAddress Address of the newly created Chainlink oracle.
     */
    function createChainlinkOracle(
        address _initialOwner,
        address _underlying,
        address _chainlinkOracle,
        uint256 _ageValidityPeriod
    ) external override returns (address newChainlinkOracleAddress) {
        require(_chainlinkOracle.code.length > 0, "3096");
        require(_ageValidityPeriod > 0, "Zero age");

        // Clone the Chainlink oracle implementation.
        newChainlinkOracleAddress = Clones.cloneDeterministic({
            implementation: referenceImplementation,
            salt: keccak256(abi.encodePacked(_initialOwner, _underlying, _chainlinkOracle))
        });

        // Initialize the new Chainlink oracle's contract.
        IChainlinkOracle(newChainlinkOracleAddress).initialize({
            _initialOwner: _initialOwner,
            _underlying: _underlying,
            _chainlinkOracle: _chainlinkOracle,
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
