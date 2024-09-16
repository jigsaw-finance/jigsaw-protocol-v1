// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { IHolding } from "./interfaces/core/IHolding.sol";
import { IHoldingManager } from "./interfaces/core/IHoldingManager.sol";
import { IManager } from "./interfaces/core/IManager.sol";
import { IManagerContainer } from "./interfaces/core/IManagerContainer.sol";

import { ISharesRegistry } from "./interfaces/core/ISharesRegistry.sol";
import { IStablesManager } from "./interfaces/core/IStablesManager.sol";
import { IStrategy } from "./interfaces/core/IStrategy.sol";
import { IStrategyManager } from "./interfaces/core/IStrategyManager.sol";

/**
 * @title StrategyManager
 *
 * @notice Manages investments of the user's assets into the whitelisted strategies to generate applicable revenue.
 *
 * @dev This contract inherits functionalities from  `Ownable2Step`, `ReentrancyGuard`, and `Pausable`.
 *
 * @author Hovooo (@hovooo), Cosmin Grigore (@gcosmintech).
 *
 * @custom:security-contact support@jigsaw.finance
 */
contract StrategyManager is IStrategyManager, Ownable2Step, ReentrancyGuard, Pausable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    /**
     * @notice Returns whitelisted Strategies' info.
     */
    mapping(address strategy => StrategyInfo info) public override strategyInfo;

    /**
     * @notice Stores the strategies holding has invested in.
     */
    mapping(address holding => EnumerableSet.AddressSet strategies) private holdingToStrategy;

    /**
     * @notice Returns the contract that contains the address of the Manager contract.
     */
    IManagerContainer public immutable override managerContainer;

    /**
     * @notice Creates a new StrategyManager contract.
     * @param _initialOwner The initial owner of the contract.
     * @param _managerContainer contract that contains the address of the Manager contract.
     */
    constructor(address _initialOwner, address _managerContainer) Ownable(_initialOwner) {
        require(_managerContainer != address(0), "3065");
        managerContainer = IManagerContainer(_managerContainer);
    }

    // -- User specific methods --

    /**
     * @notice Invests `_token` into `_strategy`.
     *
     * @notice Requirements:
     * - Strategy must be whitelisted.
     * - Amount must be non-zero.
     * - Token specified for investment must be whitelisted.
     * - Msg.sender must have holding.
     *
     * @notice Effects:
     * - Performs investment to the specified `_strategy`.
     * - Deposits holding's collateral to the specified `_strategy`.
     * - Adds `_strategy` used for investment to the holdingToStrategy data structure.
     *
     * @notice Emits:
     * - Invested event indicating successful investment operation.
     *
     * @dev 'tokenInAmount' will be equal to '_amount' in case the '_asset' is the same as strategy 'tokenIn()'.
     *
     * @param _token address.
     * @param _strategy address.
     * @param _amount to be invested.
     * @param _data needed by each individual strategy.
     *
     * @return tokenOutAmount receipt tokens amount.
     * @return tokenInAmount tokenIn amount.
     */
    function invest(
        address _token,
        address _strategy,
        uint256 _amount,
        bytes calldata _data
    )
        external
        override
        validStrategy(_strategy)
        validAmount(_amount)
        validToken(_token)
        whenNotPaused
        nonReentrant
        returns (uint256 tokenOutAmount, uint256 tokenInAmount)
    {
        address _holding = _getHoldingManager().userHolding(msg.sender);
        require(_getHoldingManager().isHolding(_holding), "3002");
        require(strategyInfo[_strategy].active, "1202");
        require(IStrategy(_strategy).tokenIn() == _token, "3085");

        (tokenOutAmount, tokenInAmount) = _invest(_holding, _token, _strategy, _amount, _data);

        emit Invested(_holding, msg.sender, _token, _strategy, _amount, tokenOutAmount, tokenInAmount);
        return (tokenOutAmount, tokenInAmount);
    }

    /**
     * @notice Claims investment from one strategy and invests it into another.
     *
     * @notice Requirements:
     * - The `strategyFrom` and `strategyTo` must be valid and active.
     * - The `strategyFrom` and `strategyTo` must be different.
     * - Msg.sender must have a holding.
     *
     * @notice Effects:
     * - Claims the investment from `strategyFrom`.
     * - Invests the claimed amount into `strategyTo`.
     *
     * @notice Emits:
     * - InvestmentMoved event indicating successful investment movement operation.
     *
     * @dev Some strategies won't give back any receipt tokens; in this case 'tokenOutAmount' will be 0.
     * @dev 'tokenInAmount' will be equal to '_amount' in case the '_asset' is the same as strategy 'tokenIn()'.
     *
     * @param _token The address of the token.
     * @param _data The MoveInvestmentData object containing strategy and amount details.
     *
     * @return tokenOutAmount The amount of receipt tokens returned.
     * @return tokenInAmount The amount of tokens invested in the new strategy.
     */
    function moveInvestment(
        address _token,
        MoveInvestmentData calldata _data
    )
        external
        override
        validStrategy(_data.strategyFrom)
        validStrategy(_data.strategyTo)
        nonReentrant
        whenNotPaused
        returns (uint256 tokenOutAmount, uint256 tokenInAmount)
    {
        address _holding = _getHoldingManager().userHolding(msg.sender);
        require(_getHoldingManager().isHolding(_holding), "3002");
        require(_data.strategyFrom != _data.strategyTo, "3086");
        require(strategyInfo[_data.strategyTo].active, "1202");

        (uint256 claimResult,) = _claimInvestment(_holding, _data.strategyFrom, _data.shares, _token, _data.dataFrom);
        (tokenOutAmount, tokenInAmount) = _invest(_holding, _token, _data.strategyTo, claimResult, _data.dataTo);

        emit InvestmentMoved(
            _holding,
            msg.sender,
            _token,
            _data.strategyFrom,
            _data.strategyTo,
            _data.shares,
            tokenOutAmount,
            tokenInAmount
        );

        return (tokenOutAmount, tokenInAmount);
    }

    /**
     * @notice Claims a strategy investment.
     *
     * @notice Requirements:
     * - The `_strategy` must be valid.
     * - Msg.sender must be allowed to execute the call.
     * - `_shares` must be of valid amount.
     * - Specified `_holding` must exist within protocol.
     *
     * @notice Effects:
     * - Withdraws investment from `_strategy`.
     * - Updates `holdingToStrategy` if needed.
     *
     * @notice Emits:
     * - StrategyClaim event indicating successful claim operation.
     *
     * @dev Withdraws investment from a strategy.
     * @dev Some strategies will allow only the tokenIn to be withdrawn.
     * @dev 'AssetAmount' will be equal to 'tokenInAmount' in case the '_asset' is the same as strategy 'tokenIn()'.
     *
     * @param _holding holding's address.
     * @param _strategy strategy to invest into.
     * @param _shares shares amount.
     * @param _asset token address to be received.
     * @param _data extra data.
     *
     * @return assetAmount returned asset amount obtained from the operation.
     * @return tokenInAmount returned token in amount.
     */
    function claimInvestment(
        address _holding,
        address _strategy,
        uint256 _shares,
        address _asset,
        bytes calldata _data
    )
        external
        override
        validStrategy(_strategy)
        onlyAllowed(_holding)
        validAmount(_shares)
        nonReentrant
        whenNotPaused
        returns (uint256 assetAmount, uint256 tokenInAmount)
    {
        require(_getHoldingManager().isHolding(_holding), "3002");

        (assetAmount, tokenInAmount) = _claimInvestment(_holding, _strategy, _shares, _asset, _data);

        emit StrategyClaim(_holding, msg.sender, _asset, _strategy, _shares, assetAmount, tokenInAmount);
    }

    /**
     * @notice Claims rewards from strategy.
     *
     * @notice Requirements:
     * - The `_strategy` must be valid.
     * - Msg.sender must have valid holding within protocol.
     *
     * @notice Effects:
     * - Claims rewards from strategies.
     * - Adds accrued rewards as a collateral for holding.
     *
     * @param _strategy strategy to invest into.
     * @param _data extra data.
     *
     * @return rewards reward amounts.
     * @return tokens reward tokens.
     */
    function claimRewards(
        address _strategy,
        bytes calldata _data
    )
        external
        override
        validStrategy(_strategy)
        nonReentrant
        whenNotPaused
        returns (uint256[] memory rewards, address[] memory tokens)
    {
        address _holding = _getHoldingManager().userHolding(msg.sender);
        require(_getHoldingManager().isHolding(_holding), "3002");

        (rewards, tokens) = IStrategy(_strategy).claimRewards({ _recipient: _holding, _data: _data });

        for (uint256 i = 0; i < rewards.length; i++) {
            _accrueRewards({ _token: tokens[i], _amount: rewards[i], _holding: _holding });
        }
    }

    // -- Utilities --

    // @todo update holding invocation to better control the access and make it safe for user.
    /**
     * @notice Invokes a generic call on the holding.
     *
     * @notice Requirements:
     * - Msg.sender must be allowed invoker.
     *
     * @notice Effects:
     * - Executes _call from the `_holding`'s address.
     *
     * @param _holding address the call is invoked for.
     * @param _contract to be called by holding.
     * @param _call data.
     *
     * @return success flag indicating if the call has succeeded.
     * @return result data obtained from the external call.
     */
    function invokeHolding(
        address _holding,
        address _contract,
        bytes calldata _call
    ) external override returns (bool success, bytes memory result) {
        require(_getManager().allowedInvokers(msg.sender), "1000");
        (success, result) = IHolding(_holding).genericCall({ _contract: _contract, _call: _call });
    }

    /**
     * @notice Invokes an approve operation for holding.
     *
     * @notice Requirements:
     * - Msg.sender must be allowed invoker.
     *
     * @notice Effects:
     * - Gives approve from the `_holding`'s address for `_spender`.
     *
     * @param _holding address the approve is given from.
     * @param _token which the approval is given.
     * @param _spender the contract's address.
     * @param _amount the approval amount.
     */
    function invokeApprove(address _holding, address _token, address _spender, uint256 _amount) external override {
        require(_getManager().allowedInvokers(msg.sender), "1000");
        IHolding(_holding).approve(_token, _spender, _amount);
    }

    /**
     * @notice Invokes a transfer operation for holding.
     *
     * @notice Requirements:
     * - Msg.sender must be allowed invoker.
     *
     * @notice Effects:
     * - Makes a transfer from the `_holding`'s address to `_to` address.
     *
     * @param _holding the address of holding the call is invoked for.
     * @param _token the asset for which the approval is performed.
     * @param _to the receiver address.
     * @param _amount the approval amount.
     */
    function invokeTransferal(address _holding, address _token, address _to, uint256 _amount) external override {
        require(_getManager().allowedInvokers(msg.sender), "1000");
        IHolding(_holding).transfer({ _token: _token, _to: _to, _amount: _amount });
    }

    // -- Administration --

    /**
     * @notice Adds a new strategy to the whitelist.
     * @param _strategy strategy's address.
     */
    function addStrategy(address _strategy) public override onlyOwner validAddress(_strategy) {
        require(!strategyInfo[_strategy].whitelisted, "3014");
        StrategyInfo memory info = StrategyInfo(0, false, false);
        info.performanceFee = _getManager().performanceFee();
        info.active = true;
        info.whitelisted = true;

        strategyInfo[_strategy] = info;

        emit StrategyAdded(_strategy);
        _getManager().addNonWithdrawableToken(IStrategy(_strategy).getReceiptTokenAddress());
    }

    /**
     * @notice Updates an existing strategy info.
     * @param _strategy strategy's address.
     * @param _info info.
     */
    function updateStrategy(
        address _strategy,
        StrategyInfo calldata _info
    ) external override onlyOwner validStrategy(_strategy) {
        strategyInfo[_strategy] = _info;
        emit StrategyUpdated(_strategy, _info.active, _info.performanceFee);
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
     * @notice Returns all the strategies holding has invested in.
     * @dev Should be only called off-chain as can be high gas consuming.
     * @param _holding address for which the strategies are requested.
     */
    function getHoldingToStrategy(address _holding) external view returns (address[] memory) {
        return holdingToStrategy[_holding].values();
    }

    // -- Private methods --

    /**
     * @notice Accrues rewards for a specific token and amount to a holding address.
     *
     * @notice Effects:
     * - Adds collateral to the holding if the amount is greater than 0 and the share registry address is not zero.
     *
     * @notice Emits:
     * - CollateralAdjusted event indicating successful collateral adjustment operation.
     *
     * @param _token address for which rewards are being accrued.
     * @param _amount of the token to accrue as rewards.
     * @param _holding address to which the rewards are accrued.
     */
    function _accrueRewards(address _token, uint256 _amount, address _holding) private {
        if (_amount > 0) {
            (, address shareRegistry) = _getStablesManager().shareRegistryInfo(_token);

            if (shareRegistry != address(0)) {
                //add collateral
                emit CollateralAdjusted(_holding, _token, _amount, true);
                _getStablesManager().addCollateral(_holding, _token, _amount);
            }
        }
    }

    /**
     * @notice Invests a specified amount of a token from a holding into a strategy.
     *
     * @notice Effects:
     * - Deposits the specified amount of the token into the given strategy.
     * - Updates the holding's invested strategies set.
     *
     * @param _holding address from which the investment is made.
     * @param _token address to be invested.
     * @param _strategy address into which the token is invested.
     * @param _amount token to invest.
     * @param _data required by the strategy's deposit function.
     *
     * @return tokenOutAmount The amount of tokens received from the strategy.
     * @return tokenInAmount The amount of tokens invested into the strategy.
     */
    function _invest(
        address _holding,
        address _token,
        address _strategy,
        uint256 _amount,
        bytes calldata _data
    ) private returns (uint256 tokenOutAmount, uint256 tokenInAmount) {
        (tokenOutAmount, tokenInAmount) = IStrategy(_strategy).deposit(_token, _amount, _holding, _data);
        require(tokenOutAmount > 0, "3030");

        // Add strategy to the set, which stores holding's all invested strategies
        holdingToStrategy[_holding].add(_strategy);
    }

    /**
     * @notice Withdraws invested amount from a strategy.
     *
     * @notice Effects:
     * - Withdraws investment from `_strategy`.
     * - Removes strategy from holding's invested strategies set if `remainingShares` == 0.
     *
     * @param _holding address from which the investment is being claimed.
     * @param _strategy address from which the investment is being claimed.
     * @param _shares number to be withdrawn from the strategy.
     * @param _asset address to be withdrawn from the strategy.
     * @param _data data required by the strategy's withdraw function.
     *
     * @return assetResult The amount of the asset withdrawn from the strategy.
     * @return tokenInResult The amount of tokens received in exchange for the withdrawn asset.
     */
    function _claimInvestment(
        address _holding,
        address _strategy,
        uint256 _shares,
        address _asset,
        bytes calldata _data
    ) private returns (uint256, uint256) {
        IStrategy strategyContract = IStrategy(_strategy);
        // First check if holding has enough receipt tokens to burn.
        _checkReceiptTokenAvailability({ _strategy: strategyContract, _shares: _shares, _holding: _holding });

        (uint256 assetResult, uint256 tokenInResult) = strategyContract.withdraw(_shares, _holding, _asset, _data);
        require(assetResult > 0, "3016");

        // If after the claim holding no longer has shares in the strategy remove that strategy from the set
        (, uint256 remainingShares) = IStrategy(_strategy).recipients(_holding);
        if (0 == remainingShares) holdingToStrategy[_holding].remove(_strategy);

        return (assetResult, tokenInResult);
    }

    /**
     * @notice Checks the availability of receipt tokens in the holding.
     *
     * @notice Requirements:
     * - Holding must have enough receipt tokens for the specified number of shares.
     *
     * @param _strategy contract's instance.
     * @param _shares number being checked for receipt token availability.
     * @param _holding address for which the receipt token availability is being checked.
     */
    function _checkReceiptTokenAvailability(IStrategy _strategy, uint256 _shares, address _holding) private view {
        uint256 tokenDecimals = _strategy.sharesDecimals();
        (, uint256 totalShares) = _strategy.recipients(_holding);
        uint256 rtAmount = _shares > totalShares ? totalShares : _shares;

        if (tokenDecimals > 18) {
            rtAmount = rtAmount / (10 ** (tokenDecimals - 18));
        } else {
            rtAmount = rtAmount * (10 ** (18 - tokenDecimals));
        }

        require(IERC20(_strategy.getReceiptTokenAddress()).balanceOf(_holding) >= rtAmount);
    }

    /**
     * @notice Retrieves the instance of the Manager contract.
     * @return IManager contract's instance.
     */
    function _getManager() private view returns (IManager) {
        return IManager(managerContainer.manager());
    }

    /**
     * @notice Retrieves the instance of the Holding Manager contract.
     * @return IHoldingManager contract's instance.
     */
    function _getHoldingManager() private view returns (IHoldingManager) {
        return IHoldingManager(_getManager().holdingManager());
    }

    /**
     * @notice Retrieves the instance of the Stables Manager contract.
     * @return IStablesManager contract's instance.
     */
    function _getStablesManager() private view returns (IStablesManager) {
        return IStablesManager(_getManager().stablesManager());
    }

    // -- Modifiers --

    /**
     * @dev Modifier to check if the address is valid (not zero address).
     * @param _address being checked.
     */
    modifier validAddress(address _address) {
        require(_address != address(0), "3000");
        _;
    }

    /**
     * @dev Modifier to check if the strategy address is valid (whitelisted).
     * @param _strategy address being checked.
     */
    modifier validStrategy(address _strategy) {
        require(strategyInfo[_strategy].whitelisted, "3029");
        _;
    }

    /**
     * @dev Modifier to check if the amount is valid (greater than zero).
     * @param _amount being checked.
     */
    modifier validAmount(uint256 _amount) {
        require(_amount > 0, "2001");
        _;
    }

    /**
     * @dev Modifier to check if the sender is allowed to perform the action.
     * @param _holding address being accessed.
     */
    modifier onlyAllowed(address _holding) {
        require(
            _getManager().holdingManager() == msg.sender || _getManager().liquidationManager() == msg.sender
                || _getHoldingManager().holdingUser(_holding) == msg.sender,
            "1000"
        );
        _;
    }

    /**
     * @dev Modifier to check if the token is valid (whitelisted).
     * @param _token address being checked.
     */
    modifier validToken(address _token) {
        require(_getManager().isTokenWhitelisted(_token), "3001");
        _;
    }
}
