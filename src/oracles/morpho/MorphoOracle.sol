// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable2StepUpgradeable } from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import { IOracle } from "./interfaces/IOracle.sol";

/**
 * @title MorphoOracleUpgradeable
 *
 * @notice An upgradeable oracle implementation for Morpho markets
 *
 * @dev This contract implements the IOracle interface and provides price information for collateral tokens quoted in
 * loan tokens. It is designed to be upgradeable using the UUPS pattern and includes two-step ownership transfer for
 * security.
 *
 * @author Hovooo (@hovooo)
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract MorphoOracle is IOracle, Ownable2StepUpgradeable, UUPSUpgradeable {
    /**
     * @notice Initial price used for Morpho Market
     */
    uint256 private _price;

    // -- Constructor --

    constructor() {
        _disableInitializers();
    }

    // -- Initialization --

    /**
     * @notice Initializes the MorphoOracleUpgradeable contract.
     *
     * @dev Initializes the Ownable, Ownable2Step and UUPSUpgradeable contracts, sets up the initial price based
     * on the token `loanToken` and `collateralToken` decimals.
     *
     * @param _initialOwner The address that will be set as the initial owner of the contract.
     * @param _loanToken The address of the loan token.
     * @param _collateralToken The address of the collateral token.
     */
    function initialize(address _initialOwner, address _loanToken, address _collateralToken) public initializer {
        __Ownable_init(_initialOwner);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        // Corresponds to the price of 10**(collateral token decimals) assets of collateral token quoted in 10 **(loan
        // token decimals) assets of loan token with 36 + loan token decimals - collateral token decimals decimals of
        // precision.
        _price = 10 ** (36 + IERC20Metadata(_loanToken).decimals() - IERC20Metadata(_collateralToken).decimals());
    }

    // -- Getters --

    /**
     * @notice Returns the price of 1 asset of collateral token quoted in 1 asset of loan token, scaled by 1e36.
     * @dev It corresponds to the price of 10**(collateral token decimals) assets of collateral token quoted in
     * 10**(loan token decimals) assets of loan token with `36 + loan token decimals - collateral token decimals`
     * decimals of precision.
     */
    function price() external view override returns (uint256) {
        return _price;
    }

    // -- Administration --

    /**
     * @notice Ensures that the caller is authorized to upgrade the contract.
     * @dev This function is called by the `upgradeToAndCall` function as part of the UUPS upgrade process.
     * Only the owner of the contract is authorized to perform upgrades, ensuring that only authorized parties
     * can modify the contract's logic.
     * @param _newImplementation The address of the new implementation contract.
     */
    function _authorizeUpgrade(
        address _newImplementation
    ) internal override onlyOwner { }

    /**
     * @dev Renounce ownership override to avoid losing contract's ownership.
     */
    function renounceOwnership() public pure virtual override {
        revert("1000");
    }
}
