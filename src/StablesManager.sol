// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { OperationsLib } from "./libraries/OperationsLib.sol";

import { IHoldingManager } from "./interfaces/core/IHoldingManager.sol";
import { IJigsawUSD } from "./interfaces/core/IJigsawUSD.sol";
import { IManager } from "./interfaces/core/IManager.sol";
import { ISharesRegistry } from "./interfaces/core/ISharesRegistry.sol";
import { IStablesManager } from "./interfaces/core/IStablesManager.sol";

/**
 * @title StablesManager
 *
 * @notice Manages operations with protocol's stablecoin and user's collateral.
 *
 * @dev This contract inherits functionalities from `Ownable2Step`, `Pausable`.
 *
 * @author Hovooo (@hovooo), Cosmin Grigore (@gcosmintech).
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract StablesManager is IStablesManager, Ownable2Step, Pausable {
    using Math for uint256;

    /**
     * @notice Returns total borrowed jUSD amount using `token`.
     */
    mapping(address token => uint256 borrowedAmount) public override totalBorrowed;

    /**
     * @notice Returns config info for each token.
     */
    mapping(address token => ShareRegistryInfo info) public override shareRegistryInfo;

    /**
     * @notice Returns protocol's stablecoin address.
     */
    IJigsawUSD public immutable override jUSD;

    /**
     * @notice Contract that contains all the necessary configs of the protocol.
     */
    IManager public immutable override manager;

    // -- Constructor --

    /**
     * @notice Creates a new StablesManager contract.
     *
     * @param _initialOwner The initial owner of the contract.
     * @param _manager Contract that holds all the necessary configs of the protocol.
     * @param _jUSD The protocol's stablecoin address.
     */
    constructor(address _initialOwner, address _manager, address _jUSD) Ownable(_initialOwner) {
        require(_manager != address(0), "3065");
        require(_jUSD != address(0), "3001");
        manager = IManager(_manager);
        jUSD = IJigsawUSD(_jUSD);
    }

    // -- User specific methods --

    /**
     * @notice Registers new collateral.
     *
     * @dev The amount will be transformed to shares.
     *
     * @notice Requirements:
     * - The caller must be allowed to perform this action directly. If user - use Holding Manager Contract.
     * - The `_token` must be whitelisted.
     * - The `_token`'s registry must be active.
     *
     * @notice Effects:
     * - Adds collateral for the holding.
     *
     * @notice Emits:
     * - `AddedCollateral` event indicating successful collateral addition operation.
     *
     * @param _holding The holding for which collateral is added.
     * @param _token Collateral token.
     * @param _amount Amount of tokens to be added as collateral.
     */
    function addCollateral(
        address _holding,
        address _token,
        uint256 _amount
    ) external override whenNotPaused onlyAllowed {
        require(shareRegistryInfo[_token].active, "1201");

        emit AddedCollateral({ holding: _holding, token: _token, amount: _amount });
        _getRegistry(_token).registerCollateral({ _holding: _holding, _share: _amount });
    }

    /**
     * @notice Unregisters collateral.
     *
     * @notice Requirements:
     * - The contract must not be paused.
     * - The caller must be allowed to perform this action directly. If user - use Holding Manager Contract.
     * - The token's registry must be active.
     * - `_holding` must stay solvent after collateral removal.
     *
     * @notice Effects:
     * - Removes collateral for the holding.
     *
     * @notice Emits:
     * - `RemovedCollateral` event indicating successful collateral removal operation.
     *
     * @param _holding The holding for which collateral is removed.
     * @param _token Collateral token.
     * @param _amount Amount of collateral.
     */
    function removeCollateral(
        address _holding,
        address _token,
        uint256 _amount
    ) external override onlyAllowed whenNotPaused {
        require(shareRegistryInfo[_token].active, "1201");

        emit RemovedCollateral({ holding: _holding, token: _token, amount: _amount });
        _getRegistry(_token).unregisterCollateral({ _holding: _holding, _share: _amount });
        require(isSolvent({ _token: _token, _holding: _holding }), "3009");
    }

    /**
     * @notice Unregisters collateral.
     *
     * @notice Requirements:
     * - The caller must be the LiquidationManager.
     * - The token's registry must be active.
     *
     * @notice Effects:
     * - Force removes collateral from the `_holding` in case of liquidation, without checking if user is solvent after
     * collateral removal.
     *
     * @notice Emits:
     * - `RemovedCollateral` event indicating successful collateral removal operation.
     *
     * @param _holding The holding for which collateral is added.
     * @param _token Collateral token.
     * @param _amount Amount of collateral.
     */
    function forceRemoveCollateral(address _holding, address _token, uint256 _amount) external override whenNotPaused {
        require(msg.sender == manager.liquidationManager(), "1000");
        require(shareRegistryInfo[_token].active, "1201");

        emit RemovedCollateral({ holding: _holding, token: _token, amount: _amount });
        _getRegistry(_token).unregisterCollateral({ _holding: _holding, _share: _amount });
    }

    /**
     * @notice Mints stablecoin to the user.
     *
     * @notice Requirements:
     * - The caller must be allowed to perform this action directly. If user - use Holding Manager Contract.
     * - The token's registry must be active.
     * - `_amount` must be greater than zero.
     *
     * @notice Effects:
     * - Mints stablecoin based on the collateral amount.
     * - Updates the total borrowed jUSD amount for `_token`, used for borrowing.
     * - Updates `_holdings`'s borrowed amount in `token`'s registry contract.
     * - Ensures the holding remains solvent.
     *
     * @notice Emits:
     * - `Borrowed`.
     *
     * @param _holding The holding for which collateral is added.
     * @param _token Collateral token.
     * @param _amount The collateral amount equivalent for borrowed jUSD.
     * @param _minJUsdAmountOut The minimum amount of jUSD that is expected to be received.
     * @param _mintDirectlyToUser If true, mints to user instead of holding.
     *
     * @return jUsdMintAmount The amount of jUSD minted.
     *
     */
    function borrow(
        address _holding,
        address _token,
        uint256 _amount,
        uint256 _minJUsdAmountOut,
        bool _mintDirectlyToUser
    ) external override onlyAllowed whenNotPaused returns (uint256 jUsdMintAmount) {
        require(_amount > 0, "3010");
        require(shareRegistryInfo[_token].active, "1201");

        BorrowTempData memory tempData = BorrowTempData({
            registry: ISharesRegistry(shareRegistryInfo[_token].deployedAt),
            exchangeRatePrecision: manager.EXCHANGE_RATE_PRECISION(),
            amount: 0,
            amountValue: 0
        });

        // Ensure amount uses 18 decimals.
        tempData.amount = _transformTo18Decimals({ _amount: _amount, _decimals: IERC20Metadata(_token).decimals() });

        // Get the USD value for the provided collateral amount.
        tempData.amountValue =
            tempData.amount.mulDiv(tempData.registry.getExchangeRate(), tempData.exchangeRatePrecision);

        // Get the jUSD amount based on the provided collateral's USD value.
        jUsdMintAmount = tempData.amountValue.mulDiv(tempData.exchangeRatePrecision, manager.getJUsdExchangeRate());

        // Ensure the amount of jUSD minted is greater than the minimum amount specified by the user.
        require(jUsdMintAmount >= _minJUsdAmountOut, "2100");

        emit Borrowed({ holding: _holding, jUsdMinted: jUsdMintAmount, mintToUser: _mintDirectlyToUser });

        // Update internal values.
        totalBorrowed[_token] += jUsdMintAmount;

        // Update holding's borrowed amount.
        tempData.registry.setBorrowed({
            _holding: _holding,
            _newVal: tempData.registry.borrowed(_holding) + jUsdMintAmount
        });

        // Based on user's choice, jUSD is minted directly to them or the `_holding`.
        jUSD.mint({
            _to: _mintDirectlyToUser ? _getHoldingManager().holdingUser(_holding) : _holding,
            _amount: jUsdMintAmount
        });

        // Make sure user is solvent after borrowing operation.
        require(isSolvent({ _token: _token, _holding: _holding }), "3009");
    }

    /**
     * @notice Repays debt.
     *
     * @notice Requirements:
     * - The caller must be allowed to perform this action directly. If user - use Holding Manager Contract.
     * - The token's registry must be active.
     * - The holding must have a positive borrowed amount.
     * - `_amount` must not exceed `holding`'s borrowed amount.
     * - `_amount` must be greater than zero.
     * - `_burnFrom` must not be the zero address.
     *
     * @notice Effects:
     * - Updates the total borrowed jUSD amount for `_token`, used for borrowing.
     * - Updates `_holdings`'s borrowed amount in `token`'s registry contract.
     * - Burns `_amount` jUSD tokens from `_burnFrom` address
     *
     * @notice Emits:
     * - `Repaid` event indicating successful repay operation.
     *
     * @param _holding The holding for which repay is performed.
     * @param _token Collateral token.
     * @param _amount The repaid jUSD amount.
     * @param _burnFrom The address to burn from.
     */
    function repay(
        address _holding,
        address _token,
        uint256 _amount,
        address _burnFrom
    ) external override onlyAllowed whenNotPaused {
        require(shareRegistryInfo[_token].active, "1201");
        ISharesRegistry registry = ISharesRegistry(shareRegistryInfo[_token].deployedAt);
        require(registry.borrowed(_holding) > 0, "3011");
        require(registry.borrowed(_holding) >= _amount, "2003");
        require(_amount > 0, "3012");
        require(_burnFrom != address(0), "3000");

        // Update internal values.
        totalBorrowed[_token] -= _amount;

        emit Repaid({ holding: _holding, amount: _amount, burnFrom: _burnFrom });
        // Update holding's borrowed amount.
        registry.setBorrowed({ _holding: _holding, _newVal: registry.borrowed(_holding) - _amount });
        // Burn jUSD.
        jUSD.burnFrom({ _user: _burnFrom, _amount: _amount });
    }

    // -- Administration --

    /**
     * @notice Registers a share registry contract for a token.
     *
     * @notice Requirements:
     * - `_token` must not be the zero address.
     * - `_token` must match the token in the registry.
     *
     * @notice Effects:
     * - Adds or updates the share registry info for the token.
     *
     * @notice Emits:
     * - `RegistryAdded` if a new registry is added.
     * - `RegistryUpdated` if an existing registry is updated.
     *
     * @param _registry Registry contract address.
     * @param _token Token address.
     * @param _active Set it as active or inactive.
     *
     */
    function registerOrUpdateShareRegistry(address _registry, address _token, bool _active) external onlyOwner {
        require(_token != address(0), "3007");
        require(_token == ISharesRegistry(_registry).token(), "3008");

        ShareRegistryInfo memory info;
        info.active = _active;

        if (shareRegistryInfo[_token].deployedAt == address(0)) {
            info.deployedAt = _registry;
            manager.addWithdrawableToken(_token);
            emit RegistryAdded({ token: _token, registry: _registry });
        } else {
            info.deployedAt = shareRegistryInfo[_token].deployedAt;
            emit RegistryUpdated({ token: _token, registry: _registry });
        }

        shareRegistryInfo[_token] = info;
    }

    /**
     * @notice Triggers stopped state.
     */
    function pause() external override onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @notice Returns to normal state.
     */
    function unpause() external override onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @notice Override to avoid losing contract ownership.
     */
    function renounceOwnership() public pure override {
        revert("1000");
    }

    // -- Getters --

    /**
     * @notice Returns true if user is solvent for the specified token.
     *
     * @dev The method reverts if block.timestamp - _maxTimeRange > exchangeRateUpdatedAt.
     *
     * @notice Requirements:
     * - `_holding` must not be the zero address.
     * - There must be registry for `_token`.
     *
     * @param _token The token for which the check is done.
     * @param _holding The user address.
     *
     * @return flag indicating whether `holding` is solvent.
     */
    function isSolvent(address _token, address _holding) public view override returns (bool) {
        require(_holding != address(0), "3031");
        ISharesRegistry registry = _getRegistry(_token);
        require(address(registry) != address(0), "3008");

        if (registry.borrowed(_holding) == 0) return true;

        return getRatio({ _holding: _holding, registry: registry, rate: registry.getConfig().collateralizationRate })
            >= registry.borrowed(_holding).mulDiv(manager.getJUsdExchangeRate(), manager.EXCHANGE_RATE_PRECISION());
    }

    /**
     * @notice Checks if a holding can be liquidated for a specific token.
     *
     * @notice Requirements:
     * - `_holding` must not be the zero address.
     * - There must be registry for `_token`.
     *
     * @param _token The token for which the check is done.
     * @param _holding The user address.
     *
     * @return flag indicating whether `holding` is liquidatable.
     */
    function isLiquidatable(address _token, address _holding) public view override returns (bool) {
        require(_holding != address(0), "3031");
        ISharesRegistry registry = _getRegistry(_token);
        require(address(registry) != address(0), "3008");

        if (registry.borrowed(_holding) == 0) return false;

        // Compute threshold for specified collateral
        ISharesRegistry.RegistryConfig memory registryConfig = registry.getConfig();
        uint256 threshold = registryConfig.collateralizationRate + registryConfig.liquidationBuffer;

        // Returns true when the ratio is below the liquidation threshold
        return getRatio({ _holding: _holding, registry: registry, rate: threshold })
            <= registry.borrowed(_holding).mulDiv(manager.getJUsdExchangeRate(), manager.EXCHANGE_RATE_PRECISION());
    }

    /**
     * @notice Computes the solvency ratio.
     *
     * @dev Solvency ratio is calculated based on the used collateral type, its collateralization and exchange rates,
     * and `_holding`'s borrowed amount.
     *
     * @param _holding The holding address to check for.
     * @param registry The Shares Registry Contract for the token.
     * @param rate The rate to compute ratio for (either collateralization rate for `isSolvent` or liquidation
     * threshold for `isLiquidatable`).
     *
     * @return The calculated solvency ratio.
     */
    function getRatio(address _holding, ISharesRegistry registry, uint256 rate) public view returns (uint256) {
        // Get collateral's exchange rate.
        uint256 exchangeRate = registry.getExchangeRate();
        // Get holding's available collateral amount.
        uint256 colAmount = registry.collateral(_holding);
        // Calculate the final divider for precise calculations.
        uint256 precision = manager.EXCHANGE_RATE_PRECISION() * manager.PRECISION();

        // Calculate the solvency ratio.
        uint256 result = colAmount * rate * exchangeRate / precision;
        // Transform to 18 decimals if needed.
        return _transformTo18Decimals({ _amount: result, _decimals: IERC20Metadata(registry.token()).decimals() });
    }

    // -- Private methods --

    /**
     * @notice Transforms the provided amount based on its original decimals to fit into 18 decimals.
     *
     * @param _amount The amount to transform.
     * @param _decimals The original number of decimals.
     *
     * @return The amount adjusted to 18 decimals.
     */
    function _transformTo18Decimals(uint256 _amount, uint256 _decimals) private pure returns (uint256) {
        if (_decimals < 18) return _amount * (10 ** (18 - _decimals));
        if (_decimals > 18) return _amount / (10 ** (_decimals - 18));

        return _amount;
    }

    /**
     * @notice Gets the Shares registry for a specific token.
     * @param _token address for which the registry is being fetched.
     * @return The Shares Registry Contract.
     */
    function _getRegistry(
        address _token
    ) private view returns (ISharesRegistry) {
        return ISharesRegistry(shareRegistryInfo[_token].deployedAt);
    }

    /**
     * @notice Gets the Holding Manager Contract.
     * @dev Returns the address of the Holding Manager Contract from the Manager Contract.
     * @return The Holding Manager Contract.
     */
    function _getHoldingManager() private view returns (IHoldingManager) {
        return IHoldingManager(manager.holdingManager());
    }

    // -- Modifiers --

    /**
     * @notice Ensures the caller is allowed to perform the call.
     *
     * @notice The caller must either be:
     * - Holding Manager Contract, or
     * - Liquidation Manager Contract, or
     * - Strategy Manager Contract.
     */
    modifier onlyAllowed() {
        require(
            msg.sender == manager.holdingManager() || msg.sender == manager.liquidationManager()
                || msg.sender == manager.strategyManager(),
            "1000"
        );
        _;
    }
}
