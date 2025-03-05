// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

import { IPythOracle } from "./interfaces/IPythOracle.sol";
import { IPythOracleFactory } from "./interfaces/IPythOracleFactory.sol";

/**
 * @title PythOracleFactory
 * @dev This contract creates new instances of Pyth oracles for Jigsaw Protocol using the clone factory pattern.
 */
contract PythOracleFactory is IPythOracleFactory, Ownable2Step {
    /**
     * @notice Address of the underlying pyth oracle.
     */
    address public override pyth;

    /**
     * @notice Address of the reference implementation.
     */
    address public override referenceImplementation;

    /**
     * @notice Creates a new PythOracleFactory contract.
     * @param _initialOwner The initial owner of the contract.
     * @notice Sets the reference implementation address.
     */
    constructor(address _initialOwner, address _pyth, address _referenceImplementation) Ownable(_initialOwner) {
        // Assert that `_pyth` and `referenceImplementation` have code to protect the system.
        require(_pyth.code.length > 0, "3096");
        require(_referenceImplementation.code.length > 0, "3096");

        // Save pyth oracle address for later use.
        emit PythAddressUpdated(_pyth);
        pyth = _pyth;

        // Save the referenceImplementation for cloning.
        emit PythOracleImplementationUpdated(_referenceImplementation);
        referenceImplementation = _referenceImplementation;
    }

    // -- Administration --

    /**
     * @notice Sets the reference implementation address.
     * @param _referenceImplementation Address of the new reference implementation contract.
     */
    function setPythOracleReferenceImplementation(
        address _referenceImplementation
    ) external override onlyOwner {
        // Assert that referenceImplementation has code in it to protect the system from cloning invalid implementation.
        require(_referenceImplementation.code.length > 0, "3096");
        require(_referenceImplementation != referenceImplementation, "3062");

        emit PythOracleImplementationUpdated(_referenceImplementation);
        referenceImplementation = _referenceImplementation;
    }

    // -- Pyth oracle creation --

    /**
     * @notice Creates a new Pyth oracle by cloning the reference implementation.
     *
     * @param _initialOwner The address of the initial owner of the contract.
     * @param _underlying The address of the token the oracle is for.
     * @param _priceId The Pyth's priceId used to determine the price of the `underlying`.
     * @param _age The Age in seconds after which the price is considered invalid.
     *
     * @return newPythOracleAddress Address of the newly created Pyth oracle.
     */
    function createPythOracle(
        address _initialOwner,
        address _underlying,
        bytes32 _priceId,
        uint256 _age
    ) external override returns (address newPythOracleAddress) {
        require(_age > 0, "Zero age");

        // Clone the Pyth oracle implementation.
        newPythOracleAddress = Clones.cloneDeterministic({
            implementation: referenceImplementation,
            salt: keccak256(abi.encodePacked(_initialOwner, _underlying, _priceId))
        });

        // Initialize the new Pyth oracle's contract.
        IPythOracle(newPythOracleAddress).initialize({
            _initialOwner: _initialOwner,
            _underlying: _underlying,
            _pyth: pyth,
            _priceId: _priceId,
            _age: _age
        });
    }

    /**
     * @dev Renounce ownership override to avoid losing contract's ownership.
     */
    function renounceOwnership() public pure virtual override {
        revert("1000");
    }
}
